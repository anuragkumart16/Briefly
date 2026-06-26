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

/**
 * Create a new app version.
 * 
 * Request body:
 *  - platform: "android" | "ios" (default: "android")
 *  - version: string (required)
 *  - buildNumber: number (required)
 *  - url: string (required)
 *  - releaseNotes: string (optional)
 *  - mandatory: boolean (default: false)
 */
const createAppVersion = async (req: Request, res: Response) => {
    const { platform, version, buildNumber, url, releaseNotes, mandatory } = req.body;

    if (!version || buildNumber === undefined || !url) {
        return ApiResponse(res, 400, "Missing required fields: version, buildNumber, and url are required.");
    }

    try {
        const newVersion = await prisma.appVersion.create({
            data: {
                platform: platform || "android",
                version,
                buildNumber: Number(buildNumber),
                url,
                releaseNotes: releaseNotes || "",
                mandatory: mandatory ?? false
            }
        });

        return ApiResponse(res, 201, "App version created successfully", newVersion);
    } catch (error: any) {
        console.error("Error in createAppVersion:", error);
        return ApiResponse(res, 500, error.message || "Failed to create app version");
    }
};

export { getLatestAppVersion, createAppVersion };
