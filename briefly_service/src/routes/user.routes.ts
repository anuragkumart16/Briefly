import { Router } from "express";
import { deleteUser, registerFcmToken, unregisterFcmToken } from "../controllers/user.controller";

/**
 * User Account Routes.
 * 
 * Defines routing for account level actions (e.g. deletion).
 */
const router = Router();

router.route("/:userId")
    .delete(deleteUser);

router.route("/:userId/fcm-token")
    .post(registerFcmToken)
    .delete(unregisterFcmToken);

export default router;
