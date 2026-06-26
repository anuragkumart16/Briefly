import { Router } from "express";
import { getTodayEmails } from "../controllers/email.controller";

/**
 * Gmail Email Routes.
 */
const router = Router();

router.route("/:userId/emails/today")
    .get(getTodayEmails);

export default router;
