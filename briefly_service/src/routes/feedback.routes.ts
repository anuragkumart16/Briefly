import { Router } from "express";
import { submitFeedback } from "../controllers/feedback.controller";

/**
 * Feedback Routes.
 * 
 * Defines routing for submitting feedback.
 */
const router = Router();

router.route("/")
    .post(submitFeedback);

export default router;
