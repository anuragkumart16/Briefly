import dotenv from "dotenv";
dotenv.config();
import express from "express";
import cronRouter from "./routes/cron.routes";

const app = express();

app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Log requests
app.use((req, res, next) => {
    console.log(`[${new Date().toISOString()}] ${req.method} ${req.path}`);
    next();
});

// Health check endpoint for pre-warming / Render sleep bypass
app.get("/healthcheck", (req, res) => {
    res.status(200).json({ success: true, message: "Float Service is healthy and awake!" });
});

// Register routes
app.use("/api/v1/cron", cronRouter);

// Global error handler
app.use((err: any, req: express.Request, res: express.Response, next: express.NextFunction) => {
    console.error("Unhandled error:", err);
    res.status(500).json({ success: false, message: err.message || "Internal server error" });
});

const port = process.env.PORT || 3001;

app.listen(port, () => {
    console.log(`Briefly Float Service is up and running on port ${port}`);
});
