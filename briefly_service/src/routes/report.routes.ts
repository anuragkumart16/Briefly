import { Router } from "express";
import { getDailyReport } from "../controllers/report.controller";

/**
 * Report Routes.
 * 
 * Defines routing for generating and fetching daily report.
 */
const router = Router();

router.route("/:userId/report")
    .get(getDailyReport);

export default router;
