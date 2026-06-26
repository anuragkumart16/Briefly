import { Router } from "express";
import { getLatestAppVersion, createAppVersion } from "../controllers/update.controller";

const router = Router();

router.route("/check").get(getLatestAppVersion);
router.route("/").post(createAppVersion);

export default router;
