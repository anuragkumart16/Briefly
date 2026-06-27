import { Request, Response } from "express";
import ApiResponse from "../utils/response.util";
import prisma from "../config/prisma";
import { setupOrUpdateUserCron } from "../services/cron.service";

/**
 * Get User Settings.
 * 
 * Retrieves the settings for a user. If the settings record does not exist yet,
 * it will be created with default values.
 * 
 * @param req express request object
 * @param res express response object
 */
const getSettings = async (req: Request, res: Response) => {
    const userId = req.params.userId as string;

    if (!userId) {
        return ApiResponse(res, 400, "User ID is required");
    }

    try {
        let settings = await prisma.settings.findUnique({
            where: { userId }
        });

        // If settings do not exist yet, create default settings
        if (!settings) {
            settings = await prisma.settings.create({
                data: {
                    userId
                }
            });
        }

        return ApiResponse(res, 200, "User settings retrieved successfully", settings);
    } catch (error: any) {
        console.error("Error in getSettings:", error);
        return ApiResponse(res, 500, error.message || "Failed to retrieve settings");
    }
};

/**
 * Update User Settings.
 * 
 * Upserts or updates settings fields for a user.
 * 
 * @param req express request object
 * @param res express response object
 */
const updateSettings = async (req: Request, res: Response) => {
    const userId = req.params.userId as string;
    const updateData = req.body;

    if (!userId) {
        return ApiResponse(res, 400, "User ID is required");
    }

    try {
        const settings = await prisma.settings.upsert({
            where: { userId },
            update: updateData,
            create: {
                userId,
                ...updateData
            }
        });

        console.log(`Updated settings for user ${userId}:`, updateData);

        if (updateData.reportHour !== undefined || updateData.reportMinute !== undefined || updateData.timezone !== undefined) {
            const currentHour = updateData.reportHour !== undefined ? updateData.reportHour : settings.reportHour;
            const currentMinute = updateData.reportMinute !== undefined ? updateData.reportMinute : settings.reportMinute;
            const currentTimezone = updateData.timezone !== undefined ? updateData.timezone : settings.timezone;
            await setupOrUpdateUserCron(userId, currentHour, currentMinute, currentTimezone);
        }

        return ApiResponse(res, 200, "User settings updated successfully", settings);
    } catch (error: any) {
        console.error("Error in updateSettings:", error);
        return ApiResponse(res, 500, error.message || "Failed to update settings");
    }
};

/**
 * Delete User Account.
 * 
 * Deletes the User record from MongoDB using Prisma (settings cascade).
 * 
 * @param req express request object
 * @param res express response object
 */
export { getSettings, updateSettings };
