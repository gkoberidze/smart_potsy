import { config } from "./config";
import { closePool, pool } from "./db";
import { createHttpServer } from "./httpServer";
import { logger } from "./logger";
import { runMigrations } from "./migrations";
import { startMqttIngestion } from "./mqttService";

const start = async () => {
  logger.info("Starting greenhouse backend...");
  
  try {
    await pool.query("SELECT 1");
    logger.info("Database connection established");
  } catch (err) {
    logger.fatal({ err }, "Failed to connect to database");
    throw new Error("Database connection failed");
  }
  
  await runMigrations(pool, logger);

  const mqttClient = startMqttIngestion(pool, logger);
  const app = createHttpServer(pool, logger);

  const server = app.listen(config.port, () => {
    logger.info({ port: config.port, env: config.env }, "HTTP server listening");
  });

  const shutdown = async (signal: NodeJS.Signals) => {
    logger.info({ signal }, "Shutting down");
    server.close();
    mqttClient.end(true);
    await closePool();
    process.exit(0);
  };

  process.on("SIGINT", shutdown);
  process.on("SIGTERM", shutdown);
};

start().catch((err) => {
  logger.fatal({ err }, "Failed to start backend");
  process.exit(1);
});
