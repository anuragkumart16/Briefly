import { Router } from "express";
import { deleteUser } from "../controllers/user.controller";

/**
 * User Account Routes.
 * 
 * Defines routing for account level actions (e.g. deletion).
 */
const router = Router();

router.route("/:userId")
    .delete(deleteUser);

export default router;
