import prisma from "../config/prisma";

/**
 * Resolves a valid, non-expired Google Access Token for a user.
 * Refreshes it using the stored refreshToken if expired.
 * 
 * @param userId The ID of the user in the database
 */
export async function getValidGoogleToken(userId: string): Promise<string> {
    const user = await prisma.user.findUnique({ where: { id: userId } });
    if (!user) {
        throw new Error("User not found");
    }

    let accessToken = user.accessToken;
    const now = new Date();

    // If token is missing, expired, or expiring in the next 30 seconds, refresh it
    if (!user.tokenExpiry || user.tokenExpiry.getTime() - now.getTime() <= 30000) {
        if (!user.refreshToken) {
            throw new Error("Google refresh token is missing. Please sign in again.");
        }

        const clientId = process.env.GOOGLE_CLIENT_ID || "";
        const clientSecret = process.env.GOOGLE_CLIENT_SECRET || "";

        if (!clientId || !clientSecret) {
            throw new Error("Server OAuth configuration error: GOOGLE_CLIENT_ID or GOOGLE_CLIENT_SECRET is missing in environment variables.");
        }

        console.log(`Refreshing Google access token for user ${user.email}...`);

        const tokenResponse = await fetch("https://oauth2.googleapis.com/token", {
            method: "POST",
            headers: {
                "Content-Type": "application/x-www-form-urlencoded",
            },
            body: new URLSearchParams({
                client_id: clientId,
                client_secret: clientSecret,
                refresh_token: user.refreshToken,
                grant_type: "refresh_token",
            }),
        });

        const tokenData = await tokenResponse.json();

        if (!tokenResponse.ok) {
            console.error("Failed to refresh Google token:", tokenData);
            throw new Error("Failed to refresh Google token. Please sign in again.");
        }

        accessToken = tokenData.access_token;
        const expires_in = tokenData.expires_in;
        const tokenExpiry = expires_in ? new Date(Date.now() + expires_in * 1000) : new Date(Date.now() + 3600 * 1000);

        await prisma.user.update({
            where: { id: userId },
            data: {
                accessToken,
                tokenExpiry,
            },
        });

        console.log(`Google access token refreshed successfully for user ${user.email}.`);
    }

    return accessToken;
}
