import { Request, Response } from "express";
import ApiResponse from "../utils/response.util";
import prisma from "../config/prisma";
import { setupOrUpdateUserCron } from "../services/cron.service";

/**
 * Google Authentication Controller.
 * 
 * Exchanges the authorization code for tokens, extracts the user profile,
 * saves it to the database, and returns the user credentials.
 * 
 * @param req express request object
 * @param res express response object
 */
const googleAuth = async (req: Request, res: Response) => {
    const { code } = req.body;

    if (!code) {
        return ApiResponse(res, 400, "Authorization code is required");
    }

    try {
        const clientId = process.env.GOOGLE_CLIENT_ID || "";
        const clientSecret = process.env.GOOGLE_CLIENT_SECRET || "";

        if (!clientId || !clientSecret) {
            console.error("Missing GOOGLE_CLIENT_ID or GOOGLE_CLIENT_SECRET in .env");
            return ApiResponse(res, 500, "Server configuration error: OAuth credentials missing");
        }

        // Exchange authorization code for access and refresh tokens
        const tokenResponse = await fetch("https://oauth2.googleapis.com/token", {
            method: "POST",
            headers: {
                "Content-Type": "application/x-www-form-urlencoded",
            },
            body: new URLSearchParams({
                code,
                client_id: clientId,
                client_secret: clientSecret,
                grant_type: "authorization_code",
                redirect_uri: "",
                access_type: "offline",
                prompt: "consent",
            }),
        });

        const tokenData = await tokenResponse.json();

        if (!tokenResponse.ok) {
            console.error("Google token exchange error:", tokenData);
            return ApiResponse(
                res,
                tokenResponse.status,
                tokenData.error_description || tokenData.error || "Failed to exchange authorization code"
            );
        }

        const { access_token, refresh_token, expires_in, id_token } = tokenData;

        if (!id_token) {
            return ApiResponse(res, 400, "Google did not return ID token");
        }

        // Decode JWT ID token without external library
        const payloadBase64 = id_token.split(".")[1];
        if (!payloadBase64) {
            return ApiResponse(res, 400, "Invalid ID token format");
        }
        
        const payloadJson = Buffer.from(payloadBase64, "base64").toString("utf-8");
        const payload = JSON.parse(payloadJson);
        
        const { email, name } = payload;
        let picture = payload.picture;

        if (!email) {
            return ApiResponse(res, 400, "Google ID token did not contain email address");
        }

        if (!picture && access_token) {
            try {
                const userInfoResponse = await fetch("https://www.googleapis.com/oauth2/v3/userinfo", {
                    headers: {
                        Authorization: `Bearer ${access_token}`,
                    },
                });
                if (userInfoResponse.ok) {
                    const userInfo = await userInfoResponse.json();
                    picture = userInfo.picture;
                }
            } catch (err) {
                console.error("Failed to fetch userinfo from Google:", err);
            }
        }

        const tokenExpiry = expires_in ? new Date(Date.now() + expires_in * 1000) : null;

        // Upsert User profile and credentials into MongoDB database
        const user = await prisma.user.upsert({
            where: { email },
            update: {
                name,
                picture,
                accessToken: access_token,
                ...(refresh_token && { refreshToken: refresh_token }),
                tokenExpiry,
            },
            create: {
                email,
                name,
                picture,
                accessToken: access_token,
                refreshToken: refresh_token,
                tokenExpiry,
            },
        });

        // Ensure default settings exist for the user
        const existingSettings = await prisma.settings.findUnique({
            where: { userId: user.id }
        });
        if (!existingSettings) {
            const defaultSettings = await prisma.settings.create({
                data: {
                    userId: user.id
                }
            });
            await setupOrUpdateUserCron(user.id, defaultSettings.reportHour, defaultSettings.reportMinute, defaultSettings.timezone);
        } else if (!existingSettings.cronJobId) {
            await setupOrUpdateUserCron(user.id, existingSettings.reportHour, existingSettings.reportMinute, existingSettings.timezone);
        }

        console.log(`User ${email} authenticated successfully.`);

        return ApiResponse(res, 200, "Google authentication successful", {
            user: {
                id: user.id,
                email: user.email,
                name: user.name,
                picture: user.picture
            }
        });
    } catch (error: any) {
        console.error("Error in googleAuth controller:", error);
        return ApiResponse(res, 500, error.message || "An unexpected error occurred during authentication");
    }
}

export { googleAuth };
