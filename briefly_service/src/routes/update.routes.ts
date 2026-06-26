import { Router } from "express";
import { getLatestAppVersion } from "../controllers/update.controller";

const router = Router();

router.route("/check").get(getLatestAppVersion);

export default router;
