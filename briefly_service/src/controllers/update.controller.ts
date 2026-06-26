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
        let latest = await prisma.appVersion.findFirst({
            where: { platform },
            orderBy: { createdAt: "desc" }
        });

        if (!latest) {
            latest = {
                id: "default",
                platform: platform,
                version: "1.0.0",
                buildNumber: 1,
                url: "",
                releaseNotes: "Initial release version",
                mandatory: false,
                createdAt: new Date(),
                updatedAt: new Date()
            };
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
