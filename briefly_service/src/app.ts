import dotenv from "dotenv";
dotenv.config();
import express from "express";
import { errorHandler } from "./middlewares/error.middleware";
import { httpLogger } from "./middlewares/httpLogger.middleware";

/**
 * Express Application Instance.
 * 
 * Configures middleware, routes, and error handling.
 */
const app = express();

// app-level middleware config
app.use(httpLogger);
app.use(express.json());
app.use(express.urlencoded({ extended: true }));


// router imports
import healthCheckRouter from "./routes/healthcheck.routes"
import authRouter from "./routes/auth.routes"
import settingsRouter from "./routes/settings.routes"
import feedbackRouter from "./routes/feedback.routes"
import userRouter from "./routes/user.routes"
import floatRouter from "./routes/float.routes"
import reportRouter from "./routes/report.routes"
import taskRouter from "./routes/task.routes"
import calendarRouter from "./routes/calendar.routes"
import emailRouter from "./routes/email.routes"

// url mapping
app.use("/healthcheck", healthCheckRouter)
app.use("/api/v1/auth", authRouter)
app.use("/api/v1/users", settingsRouter)
app.use("/api/v1/users", userRouter)
app.use("/api/v1/users", floatRouter)
app.use("/api/v1/users", reportRouter)
app.use("/api/v1/users", taskRouter)
app.use("/api/v1/users", calendarRouter)
app.use("/api/v1/users", emailRouter)
app.use("/api/v1/feedback", feedbackRouter)


// global error handler
app.use(errorHandler);


export default app;