import winston from 'winston';
import { appConfig } from "../config/envConfig";


/**
 * Winston Logger Configuration.
 * 
 * Configures the application-wide logger.
 * 
 * Features:
 * - Log Level: Defaults to 'info', or 'LOG_LEVEL' env var.
 * - Format: JSON format with timestamp and error stack traces.
 * - Transports: Console transport.
 */
export const logger = winston.createLogger({
    level: appConfig.logLevel,
    format: winston.format.combine(
        winston.format.timestamp(),
        winston.format.errors(),
        winston.format.json()
    ),
    transports: [new winston.transports.Console()]
})

