import { Request, Response } from "express";
import ApiResponse from "../utils/response.util";
import prisma from "../config/prisma";

/**
 * Delete User Account.
 * 
 * Deletes the User record from MongoDB using Prisma (settings cascade).
 * 
 * @param req express request object
 * @param res express response object
 */
const deleteUser = async (req: Request, res: Response) => {
    const userId = req.params.userId as string;

    if (!userId) {
        return ApiResponse(res, 400, "User ID is required");
    }

    try {
        await prisma.user.delete({
            where: { id: userId }
        });

        console.log(`Deleted user account: ${userId}`);

        return ApiResponse(res, 200, "Account deleted successfully");
    } catch (error: any) {
        console.error("Error in deleteUser:", error);
        return ApiResponse(res, 500, error.message || "Failed to delete account");
    }
};

export { deleteUser };
