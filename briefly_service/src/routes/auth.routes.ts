import { Router } from "express";
import { googleAuth } from "../controllers/auth.controller";

/**
 * Google Authentication Routes.
 * 
 * Defines routing for google auth endpoints.
 */
const router = Router();

router.route("/google").post(googleAuth);

export default router;
