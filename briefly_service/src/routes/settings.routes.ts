import { Router } from "express";
import { getSettings, updateSettings } from "../controllers/settings.controller";

/**
 * Settings Routes.
 * 
 * Defines routing for user settings retrieve and update.
 */
const router = Router();

router.route("/:userId/settings")
    .get(getSettings)
    .put(updateSettings);



export default router;
