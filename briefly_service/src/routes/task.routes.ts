import { Router } from "express";
import { getTasks, createTask, updateTask, deleteTask } from "../controllers/task.controller";

/**
 * Task Routes.
 * 
 * Proxies CRUD requests to the Google Tasks API.
 */
const router = Router();

router.route("/:userId/tasks")
    .get(getTasks)
    .post(createTask);

router.route("/:userId/tasks/:taskId")
    .patch(updateTask)
    .delete(deleteTask);

export default router;
