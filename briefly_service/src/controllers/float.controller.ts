import { Request, Response } from "express";
import ApiResponse from "../utils/response.util";
import prisma from "../config/prisma";

/**
 * Get All Floats for a User.
 * 
 * Retrieves all float items belonging to the user.
 */
const getFloats = async (req: Request, res: Response) => {
    const userId = req.params.userId as string;

    if (!userId) {
        return ApiResponse(res, 400, "User ID is required");
    }

    try {
        const floats = await prisma.floatItem.findMany({
            where: { userId },
            orderBy: { createdAt: "desc" },
        });

        return ApiResponse(res, 200, "Floats retrieved successfully", floats);
    } catch (error: any) {
        console.error("Error in getFloats:", error);
        return ApiResponse(res, 500, error.message || "Failed to retrieve floats");
    }
};

/**
 * Create a Float for a User.
 * 
 * Creates a new float item for the given user.
 */
const createFloat = async (req: Request, res: Response) => {
    const userId = req.params.userId as string;
    const { text } = req.body;

    if (!userId) {
        return ApiResponse(res, 400, "User ID is required");
    }
    if (!text || !text.trim()) {
        return ApiResponse(res, 400, "Float text is required");
    }

    try {
        const float = await prisma.floatItem.create({
            data: {
                userId,
                text: text.trim(),
                isActive: true,
            },
        });

        return ApiResponse(res, 201, "Float created successfully", float);
    } catch (error: any) {
        console.error("Error in createFloat:", error);
        return ApiResponse(res, 500, error.message || "Failed to create float");
    }
};

/**
 * Update a Float.
 * 
 * Updates fields of a single float item (text and/or isActive).
 */
const updateFloat = async (req: Request, res: Response) => {
    const userId = req.params.userId as string;
    const floatId = req.params.floatId as string;
    const { text, isActive } = req.body;

    if (!floatId) {
        return ApiResponse(res, 400, "Float ID is required");
    }

    try {
        // Optional verification to ensure the float belongs to the user
        const existing = await prisma.floatItem.findUnique({
            where: { id: floatId }
        });

        if (!existing) {
            return ApiResponse(res, 404, "Float not found");
        }

        if (existing.userId !== userId) {
            return ApiResponse(res, 403, "Access denied: Float does not belong to this user");
        }

        const updateData: any = {};
        if (text !== undefined) updateData.text = text.trim();
        if (isActive !== undefined) updateData.isActive = isActive;

        const float = await prisma.floatItem.update({
            where: { id: floatId },
            data: updateData,
        });

        return ApiResponse(res, 200, "Float updated successfully", float);
    } catch (error: any) {
        console.error("Error in updateFloat:", error);
        return ApiResponse(res, 500, error.message || "Failed to update float");
    }
};

/**
 * Delete a Float.
 * 
 * Deletes a single float item by ID.
 */
const deleteFloat = async (req: Request, res: Response) => {
    const userId = req.params.userId as string;
    const floatId = req.params.floatId as string;

    if (!floatId) {
        return ApiResponse(res, 400, "Float ID is required");
    }

    try {
        const existing = await prisma.floatItem.findUnique({
            where: { id: floatId }
        });

        if (!existing) {
            return ApiResponse(res, 404, "Float not found");
        }

        if (existing.userId !== userId) {
            return ApiResponse(res, 403, "Access denied: Float does not belong to this user");
        }

        await prisma.floatItem.delete({
            where: { id: floatId },
        });

        return ApiResponse(res, 200, "Float deleted successfully");
    } catch (error: any) {
        console.error("Error in deleteFloat:", error);
        return ApiResponse(res, 500, error.message || "Failed to delete float");
    }
};

/**
 * Batch Update Floats.
 * 
 * Updates multiple floats (e.g. marking them active/inactive) for a user.
 */
const batchUpdateFloats = async (req: Request, res: Response) => {
    const userId = req.params.userId as string;
    const { ids, isActive } = req.body;

    if (!userId) {
        return ApiResponse(res, 400, "User ID is required");
    }
    if (!Array.isArray(ids) || ids.length === 0) {
        return ApiResponse(res, 400, "List of float IDs is required");
    }
    if (isActive === undefined) {
        return ApiResponse(res, 400, "isActive status is required");
    }

    try {
        const updateResult = await prisma.floatItem.updateMany({
            where: {
                id: { in: ids },
                userId: userId,
            },
            data: {
                isActive: isActive,
            },
        });

        return ApiResponse(res, 200, `${updateResult.count} floats updated successfully`, { count: updateResult.count });
    } catch (error: any) {
        console.error("Error in batchUpdateFloats:", error);
        return ApiResponse(res, 500, error.message || "Failed to batch update floats");
    }
};

/**
 * Batch Delete Floats.
 * 
 * Deletes multiple floats in bulk.
 */
const batchDeleteFloats = async (req: Request, res: Response) => {
    const userId = req.params.userId as string;
    const { ids } = req.body;

    if (!userId) {
        return ApiResponse(res, 400, "User ID is required");
    }
    if (!Array.isArray(ids) || ids.length === 0) {
        return ApiResponse(res, 400, "List of float IDs is required");
    }

    try {
        const deleteResult = await prisma.floatItem.deleteMany({
            where: {
                id: { in: ids },
                userId: userId,
            },
        });

        return ApiResponse(res, 200, `${deleteResult.count} floats deleted successfully`, { count: deleteResult.count });
    } catch (error: any) {
        console.error("Error in batchDeleteFloats:", error);
        return ApiResponse(res, 500, error.message || "Failed to batch delete floats");
    }
};

export {
    getFloats,
    createFloat,
    updateFloat,
    deleteFloat,
    batchUpdateFloats,
    batchDeleteFloats,
};
