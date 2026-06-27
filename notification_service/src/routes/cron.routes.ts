import { Router } from "express";
import { processFloats } from "../controllers/cron.controller";

const router = Router();

router.post("/process-floats", processFloats);

export default router;
