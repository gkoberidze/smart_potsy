import nodemailer from "nodemailer";
import { logger } from "./logger";

const transporter = nodemailer.createTransport({
  host: process.env.SMTP_HOST || "smtp.gmail.com",
  port: parseInt(process.env.SMTP_PORT || "587", 10),
  secure: process.env.SMTP_SECURE === "true",
  auth: {
    user: process.env.SMTP_USER,
    pass: process.env.SMTP_PASS,
  },
});

const FROM_EMAIL = process.env.SMTP_FROM || process.env.SMTP_USER || "noreply@greenhouse.local";
const APP_NAME = "Greenhouse IoT";

export const sendPasswordResetEmail = async (
  to: string,
  resetCode: string
): Promise<boolean> => {
  if (!process.env.SMTP_USER || !process.env.SMTP_PASS) {
    logger.warn({ to, resetCode }, "SMTP not configured - logging reset code instead");
    return false;
  }

  try {
    await transporter.sendMail({
      from: `"${APP_NAME}" <${FROM_EMAIL}>`,
      to,
      subject: "პაროლის აღდგენის კოდი - Greenhouse IoT",
      text: `
გამარჯობა,

თქვენ მოითხოვეთ პაროლის აღდგენა ${APP_NAME}-ისთვის.

თქვენი კოდი: ${resetCode}

კოდი მოქმედებს 1 საათის განმავლობაში.

თუ თქვენ არ მოითხოვეთ ეს, იგნორირება გაუკეთეთ ამ შეტყობინებას.

- ${APP_NAME} გუნდი
      `.trim(),
      html: `
<!DOCTYPE html>
<html>
<head>
  <style>
    body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
    .container { max-width: 600px; margin: 0 auto; padding: 20px; text-align: center; }
    .code { font-size: 36px; font-weight: bold; color: #22c55e; letter-spacing: 8px; margin: 30px 0; padding: 20px; background: #f0fdf4; border-radius: 12px; }
    .footer { margin-top: 30px; font-size: 12px; color: #666; }
  </style>
</head>
<body>
  <div class="container">
    <h2>პაროლის აღდგენა</h2>
    <p>გამარჯობა,</p>
    <p>თქვენ მოითხოვეთ პაროლის აღდგენა <strong>${APP_NAME}</strong>-ისთვის.</p>
    <p>თქვენი კოდი:</p>
    <div class="code">${resetCode}</div>
    <p>კოდი მოქმედებს <strong>1 საათის</strong> განმავლობაში.</p>
    <p>თუ თქვენ არ მოითხოვეთ ეს, იგნორირება გაუკეთეთ ამ შეტყობინებას.</p>
    <div class="footer">
      <p>- ${APP_NAME} გუნდი</p>
    </div>
  </div>
</body>
</html>
      `.trim(),
    });

    logger.info({ to }, "Password reset email sent");
    return true;
  } catch (err) {
    logger.error({ err, to }, "Failed to send password reset email");
    return false;
  }
};

export const verifyEmailConnection = async (): Promise<boolean> => {
  if (!process.env.SMTP_USER || !process.env.SMTP_PASS) {
    logger.warn("SMTP not configured - email sending disabled");
    return false;
  }

  try {
    await transporter.verify();
    logger.info("SMTP connection verified");
    return true;
  } catch (err) {
    logger.error({ err }, "SMTP connection failed");
    return false;
  }
};
