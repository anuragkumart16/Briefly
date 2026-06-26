import { Router } from "express";
import { getTodayLeftEvents } from "../controllers/calendar.controller";

/**
 * Calendar Routes.
 */
const router = Router();

router.route("/:userId/calendar/today-left")
    .get(getTodayLeftEvents);

export default router;
