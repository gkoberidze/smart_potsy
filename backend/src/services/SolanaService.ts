import {
  clusterApiUrl,
  Connection,
  Keypair,
  PublicKey,
  Transaction,
  TransactionInstruction,
  SystemProgram,
  sendAndConfirmTransaction,
  LAMPORTS_PER_SOL,
} from "@solana/web3.js";
import { createHash } from "crypto";
import { Logger } from "pino";

// ─── SPL Memo Program ────────────────────────────────────────────────────────
//
// Already deployed on ALL Solana clusters — no custom smart contract needed.
// It permanently records any text string we pass to it on-chain.
//
const MEMO_PROGRAM_ID = new PublicKey(
  "MemoSq4gqABAXKb96qnH8TysNcWxMyWCqXgDLGmfcHr"
);

// ─── Types ───────────────────────────────────────────────────────────────────

export interface TelemetryWindow {
  deviceId: string;
  windowStart: string;       // ISO string — start of the aggregation window
  windowEnd: string;         // ISO string — end of the aggregation window
  rowCount: number;          // how many telemetry rows were averaged
  avgAirTemperature: number | null;
  avgAirHumidity: number | null;
  avgSoilTemperature: number | null;
  avgSoilMoisture: number | null;
  avgLightLevel: number | null;
}

export interface AnchorResult {
  /** Permanent Solana transaction ID — the on-chain proof */
  signature: string;
  /** SHA-256 hash of the canonicalised sensor averages */
  hash: string;
  /** ISO timestamp captured just before submission */
  anchoredAt: string;
  /** Direct link to Solana Explorer for this transaction */
  explorerUrl: string;
}

// ─── Internal helpers ────────────────────────────────────────────────────────

/**
 * Sorts object keys alphabetically before JSON.stringify.
 *
 * Required so that the same data always produces the same hash,
 * regardless of the column order returned by PostgreSQL.
 */
const sortedStringify = (obj: object): string => {
  const sort = (val: unknown): unknown => {
    if (Array.isArray(val)) return val.map(sort);
    if (val !== null && typeof val === "object") {
      return Object.keys(val as Record<string, unknown>)
        .sort()
        .reduce<Record<string, unknown>>((acc, k) => {
          acc[k] = sort((val as Record<string, unknown>)[k]);
          return acc;
        }, {});
    }
    return val;
  };
  return JSON.stringify(sort(obj));
};

/** SHA-256 → lowercase 64-char hex string */
const sha256 = (input: string): string =>
  createHash("sha256").update(input, "utf8").digest("hex");

/**
 * Loads the Solana keypair from SOLANA_PRIVATE_KEY (Base-58 encoded).
 * Throws early with a clear message rather than failing mid-transaction.
 */
const loadKeypair = (): Keypair => {
  const raw = process.env.SOLANA_PRIVATE_KEY;
  if (!raw) {
    throw new Error(
      "SOLANA_PRIVATE_KEY is not set. " +
      "Generate a Devnet wallet and add its Base-58 secret key to backend/.env"
    );
  }
  try {
    // bs58 ships as a dependency of @solana/web3.js
    const bs58 = require("bs58") as { decode: (s: string) => Uint8Array };
    return Keypair.fromSecretKey(bs58.decode(raw));
  } catch {
    throw new Error(
      "SOLANA_PRIVATE_KEY is malformed — it must be a Base-58 encoded string."
    );
  }
};

// Lazily-initialised; reused across hourly cron invocations in the same process
let _connection: Connection | null = null;

const getConnection = (): Connection => {
  if (!_connection) {
    const rpcUrl = process.env.SOLANA_RPC_URL ?? clusterApiUrl("devnet");
    _connection = new Connection(rpcUrl, "confirmed");
  }
  return _connection;
};

// ─── Public API ──────────────────────────────────────────────────────────────

/**
 * anchorTelemetry
 * ───────────────
 * Hashes one hour of sensor averages and writes the hash permanently
 * to Solana Devnet via the SPL Memo program.
 *
 * Called exclusively from telemetryCron — never from HTTP routes.
 *
 * HOW IT WORKS ON-CHAIN:
 *   The memo written to Solana is:
 *     "smart-potsy:v1:<deviceId>:<hash>:<anchoredAt>"
 *   Anyone can look up the transaction signature on Solana Explorer
 *   and verify that the hash matches the raw sensor data in PostgreSQL.
 */
export const anchorTelemetry = async (
  data: TelemetryWindow,
  logger: Logger
): Promise<AnchorResult> => {
  const connection = getConnection();
  const keypair = loadKeypair();

  // 1. Hash the payload deterministically
  const canonical = sortedStringify(data);
  const hash = sha256(canonical);
  const anchoredAt = new Date().toISOString();

  const memoText = `smart-potsy:v1:${data.deviceId}:${hash}:${anchoredAt}`;

  logger.info(
    { deviceId: data.deviceId, hash: hash.substring(0, 16) + "..." },
    "Anchoring telemetry to Solana Devnet"
  );

  // 2. Guard: make sure the wallet has enough SOL for the transaction fee
  //    A memo tx costs ~5 000 lamports (≈ $0.001). We check for 10 000 to be safe.
  const balance = await connection.getBalance(keypair.publicKey);
  if (balance < 10_000) {
    throw new Error(
      `Solana wallet balance too low (${balance} lamports). ` +
      `Refill with: solana airdrop 1 ${keypair.publicKey.toBase58()} --url devnet`
    );
  }

  // 3. Build the transaction
  //    Instruction A — zero-lamport self-transfer (makes the tx structurally
  //    valid on RPC nodes that reject memo-only transactions)
  //    Instruction B — SPL Memo carrying our hash string
  const transaction = new Transaction();

  transaction.add(
    SystemProgram.transfer({
      fromPubkey: keypair.publicKey,
      toPubkey: keypair.publicKey,
      lamports: 0,
    })
  );

  transaction.add(
    new TransactionInstruction({
      programId: MEMO_PROGRAM_ID,
      keys: [{ pubkey: keypair.publicKey, isSigner: true, isWritable: false }],
      data: Buffer.from(memoText, "utf8"),
    })
  );

  // 4. Submit and wait for on-chain confirmation
  const signature = await sendAndConfirmTransaction(connection, transaction, [keypair]);
  const explorerUrl = `https://explorer.solana.com/tx/${signature}?cluster=devnet`;

  logger.info(
    { deviceId: data.deviceId, signature, explorerUrl },
    "Telemetry anchored successfully"
  );

  return { signature, hash, anchoredAt, explorerUrl };
};

/**
 * verifyAnchor
 * ────────────
 * Re-hashes the original data and confirms the on-chain memo matches.
 * Used by GET /api/devices/:deviceId/anchors/:signature in httpServer.
 */
export const verifyAnchor = async (
  data: TelemetryWindow,
  signature: string,
  logger: Logger
): Promise<boolean> => {
  const connection = getConnection();

  const canonical = sortedStringify(data);
  const expectedHash = sha256(canonical);

  const tx = await connection.getParsedTransaction(signature, {
    maxSupportedTransactionVersion: 0,
  });

  if (!tx) {
    throw new Error(`Transaction not found on Solana: ${signature}`);
  }

  const logs: string[] = tx.meta?.logMessages ?? [];
  const memoLog = logs.find((l) => l.includes("smart-potsy:v1:"));
  const onChainHash = memoLog?.match(/smart-potsy:v1:[^:]+:([a-f0-9]{64})/)?.[1];

  const valid = onChainHash === expectedHash;
  logger.info(
    { signature, valid, expected: expectedHash.substring(0, 16), found: (onChainHash ?? "none").substring(0, 16) },
    "Anchor verification result"
  );

  return valid;
};

/**
 * requestAirdrop
 * ──────────────
 * One-time helper for first-time setup or CI environments.
 * Do NOT call this in the cron loop — Devnet faucet rate-limits heavily.
 */
export const requestAirdrop = async (logger: Logger): Promise<void> => {
  const connection = getConnection();
  const keypair = loadKeypair();

  logger.info({ pubkey: keypair.publicKey.toBase58() }, "Requesting Devnet airdrop");
  const sig = await connection.requestAirdrop(keypair.publicKey, 1 * LAMPORTS_PER_SOL);
  await connection.confirmTransaction(sig);
  logger.info("Airdrop confirmed — 1 SOL added to wallet");
};

/**
 * getWalletInfo
 * ─────────────
 * Returns the public key and current balance of the configured wallet.
 * Useful for a health-check endpoint or startup log.
 */
export const getWalletInfo = async (): Promise<{ pubkey: string; balanceLamports: number }> => {
  const connection = getConnection();
  const keypair = loadKeypair();
  const balanceLamports = await connection.getBalance(keypair.publicKey);
  return { pubkey: keypair.publicKey.toBase58(), balanceLamports };
};