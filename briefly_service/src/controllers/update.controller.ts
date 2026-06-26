import { Request, Response } from "express";
import ApiResponse from "../utils/response.util";
import prisma from "../config/prisma";

/**
 * Get the latest app version details for update checking.
 * 
 * Query parameters:
 *  - platform: "android" | "ios" (default: "android")
 */
const getLatestAppVersion = async (req: Request, res: Response) => {
    const platform = (req.query.platform as string) || "android";

    try {
        const latest = await prisma.appVersion.findFirst({
            where: { platform },
            orderBy: { createdAt: "desc" }
        });

        if (!latest) {
            return ApiResponse(res, 404, "No version information found for platform: " + platform);
        }

        return ApiResponse(res, 200, "Latest version fetched successfully", {
            id: latest.id,
            platform: latest.platform,
            version: latest.version,
            buildNumber: latest.buildNumber,
            url: latest.url,
            releaseNotes: latest.releaseNotes,
            mandatory: latest.mandatory,
            createdAt: latest.createdAt
        });
    } catch (error: any) {
        console.error("Error in getLatestAppVersion:", error);
        return ApiResponse(res, 500, error.message || "Failed to fetch version information");
    }
};

export { getLatestAppVersion };
