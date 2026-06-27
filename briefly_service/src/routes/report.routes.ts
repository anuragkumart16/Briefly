import { Router } from "express";
import { getDailyReport, triggerDailyReport } from "../controllers/report.controller";

/**
 * Report Routes.
 * 
 * Defines routing for generating and fetching daily report.
 */
const router = Router();

router.route("/:userId/report")
    .get(getDailyReport);

router.route("/:userId/trigger-report")
    .post(triggerDailyReport);

export default router;
