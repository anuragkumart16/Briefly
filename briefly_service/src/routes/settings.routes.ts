import { Router } from "express";
import { getSettings, updateSettings, deleteUser } from "../controllers/settings.controller";

/**
 * Settings Routes.
 * 
 * Defines routing for user settings retrieve and update.
 */
const router = Router();

router.route("/:userId/settings")
    .get(getSettings)
    .put(updateSettings);

router.route("/:userId")
    .delete(deleteUser);

export default router;
