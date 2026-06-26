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

/**
 * Register FCM Token for a user.
 * 
 * Adds the FCM token to the user's fcmTokens list if not already present.
 */
const registerFcmToken = async (req: Request, res: Response) => {
    const userId = req.params.userId as string;
    const { token } = req.body;

    if (!userId) {
        return ApiResponse(res, 400, "User ID is required");
    }
    if (!token) {
        return ApiResponse(res, 400, "FCM Token is required");
    }

    try {
        const user = await prisma.user.findUnique({
            where: { id: userId },
            select: { fcmTokens: true }
        });

        if (!user) {
            return ApiResponse(res, 404, "User not found");
        }

        const currentTokens = user.fcmTokens || [];
        if (!currentTokens.includes(token)) {
            await prisma.user.update({
                where: { id: userId },
                data: {
                    fcmTokens: {
                        set: [...currentTokens, token]
                    }
                }
            });
        }

        console.log(`Registered FCM token for user: ${userId}`);
        return ApiResponse(res, 200, "FCM token registered successfully");
    } catch (error: any) {
        console.error("Error in registerFcmToken:", error);
        return ApiResponse(res, 500, error.message || "Failed to register FCM token");
    }
};

/**
 * Unregister FCM Token for a user.
 * 
 * Removes the FCM token from the user's fcmTokens list.
 */
const unregisterFcmToken = async (req: Request, res: Response) => {
    const userId = req.params.userId as string;
    const { token } = req.body;

    if (!userId) {
        return ApiResponse(res, 400, "User ID is required");
    }
    if (!token) {
        return ApiResponse(res, 400, "FCM Token is required");
    }

    try {
        const user = await prisma.user.findUnique({
            where: { id: userId },
            select: { fcmTokens: true }
        });

        if (!user) {
            return ApiResponse(res, 404, "User not found");
        }

        const currentTokens = user.fcmTokens || [];
        if (currentTokens.includes(token)) {
            await prisma.user.update({
                where: { id: userId },
                data: {
                    fcmTokens: {
                        set: currentTokens.filter(t => t !== token)
                    }
                }
            });
        }

        console.log(`Unregistered FCM token for user: ${userId}`);
        return ApiResponse(res, 200, "FCM token unregistered successfully");
    } catch (error: any) {
        console.error("Error in unregisterFcmToken:", error);
        return ApiResponse(res, 500, error.message || "Failed to unregister FCM token");
    }
};

export { deleteUser, registerFcmToken, unregisterFcmToken };
