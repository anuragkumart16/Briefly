/**
 * Application Configuration.
 * 
 * Centralized configuration object populated and validated from environment variables.
 */

const requiredEnvVars = [
    "DATABASE_URL",
    "GOOGLE_CLIENT_ID",
    "GOOGLE_CLIENT_SECRET",
    "GROQ_API_KEY",
    "CRON_JOB_TOKEN",
    "FIREBASE_SERVICE_ACCOUNT",
    "SERVER_BASE_URL"
];

const missingEnvVars: string[] = [];

for (const envVar of requiredEnvVars) {
    if (!process.env[envVar]) {
        missingEnvVars.push(envVar);
    }
}

if (missingEnvVars.length > 0) {
    throw new Error(
        `Configuration error: Required environment variables are missing: ${missingEnvVars.join(", ")}`
    );
}

export const appConfig = {
    port: process.env.PORT || 5001,
    nodeEnv: process.env.NODE_ENV || "dev",
    microserviceName: process.env.MICROSERVICE_NAME ? process.env.MICROSERVICE_NAME + "microservice" : "server",
    databaseUrl: process.env.DATABASE_URL!,
    googleClientId: process.env.GOOGLE_CLIENT_ID!,
    googleClientSecret: process.env.GOOGLE_CLIENT_SECRET!,
    groqApiKey: process.env.GROQ_API_KEY!,
    cronJobToken: process.env.CRON_JOB_TOKEN!,
    firebaseServiceAccount: process.env.FIREBASE_SERVICE_ACCOUNT!,
    serverBaseUrl: process.env.SERVER_BASE_URL!,
    logLevel: process.env.LOG_LEVEL || "info"
};
