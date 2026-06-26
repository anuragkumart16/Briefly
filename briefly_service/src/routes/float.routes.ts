import { Router } from "express";
import {
    getFloats,
    createFloat,
    updateFloat,
    deleteFloat,
    batchUpdateFloats,
    batchDeleteFloats,
} from "../controllers/float.controller";

/**
 * Float Item Routes.
 * 
 * Defines routing for float items (creation, retrieval, update, deletion, and batch actions).
 */
const router = Router();

// Batch operations
router.route("/:userId/floats/batch-update")
    .post(batchUpdateFloats);

router.route("/:userId/floats/batch-delete")
    .post(batchDeleteFloats);

// Standard CRUD operations
router.route("/:userId/floats")
    .get(getFloats)
    .post(createFloat);

router.route("/:userId/floats/:floatId")
    .put(updateFloat)
    .delete(deleteFloat);

export default router;
