import * as admin from "firebase-admin";
import * as fs from "fs";
import * as path from "path";
import prisma from "../config/prisma";

let isInitialized = false;

export function initFirebase() {
    if (isInitialized) return;

    try {
        if (admin.apps.length > 0) {
            isInitialized = true;
            return;
        }

        const serviceAccountVar = process.env.FIREBASE_SERVICE_ACCOUNT;
        if (serviceAccountVar) {
            let parsedCreds;
            try {
                parsedCreds = JSON.parse(serviceAccountVar);
            } catch (err) {
                // If it is not JSON, it might be a file path
                if (fs.existsSync(serviceAccountVar)) {
                    parsedCreds = JSON.parse(fs.readFileSync(serviceAccountVar, "utf8"));
                } else {
                    throw err;
                }
            }
            admin.initializeApp({
                credential: admin.credential.cert(parsedCreds),
            });
            console.log("Firebase Admin initialized successfully using process.env.FIREBASE_SERVICE_ACCOUNT.");
            isInitialized = true;
            return;
        }

        // Try checking local file
        const serviceAccountFilePath = path.join(__dirname, "../config/firebase-service-account.json");
        if (fs.existsSync(serviceAccountFilePath)) {
            const serviceAccount = JSON.parse(fs.readFileSync(serviceAccountFilePath, "utf8"));
            admin.initializeApp({
                credential: admin.credential.cert(serviceAccount),
            });
            console.log("Firebase Admin initialized successfully using firebase-service-account.json.");
            isInitialized = true;
            return;
        }

        // Fallback to default credentials
        admin.initializeApp();
        console.log("Firebase Admin initialized using applicationDefault / default credentials.");
        isInitialized = true;
    } catch (error) {
        console.error("Firebase Admin failed to initialize:", error);
    }
}

/**
 * Sends a push notification to all registered tokens of a user.
 * Stale or invalid tokens are automatically cleaned up from the database.
 */
export async function sendNotificationToUser(
    userId: string,
    title: string,
    body: string,
    data?: Record<string, string>
): Promise<void> {
    initFirebase();

    if (!isInitialized) {
        console.error("Cannot send notification: Firebase Admin SDK is not initialized.");
        return;
    }

    try {
        const user = await prisma.user.findUnique({
            where: { id: userId },
            select: { fcmTokens: true, email: true },
        });

        if (!user || !user.fcmTokens || user.fcmTokens.length === 0) {
            console.log(`No registered FCM tokens found for user ${userId}. Skipping push notification.`);
            return;
        }

        const tokensToRemove: string[] = [];
        const sendPromises = user.fcmTokens.map(async (token) => {
            const message: admin.messaging.Message = {
                token,
                notification: {
                    title,
                    body,
                },
                data: data || {},
                android: {
                    priority: "high",
                    notification: {
                        sound: "default",
                        clickAction: "FLUTTER_NOTIFICATION_CLICK",
                    },
                },
                apns: {
                    payload: {
                        aps: {
                            sound: "default",
                            badge: 1,
                        },
                    },
                },
            };

            try {
                await admin.messaging().send(message);
                console.log(`Notification sent successfully to token (user: ${user.email})`);
            } catch (err: any) {
                console.error(`Failed to send notification to token:`, err.message);
                // Stale/Invalid tokens usually return code "messaging/registration-token-not-registered" or "messaging/invalid-registration-token"
                if (
                    err.code === "messaging/registration-token-not-registered" ||
                    err.code === "messaging/invalid-registration-token"
                ) {
                    tokensToRemove.push(token);
                }
            }
        });

        await Promise.all(sendPromises);

        // Remove stale/invalid tokens from DB if any were found
        if (tokensToRemove.length > 0) {
            console.log(`Cleaning up ${tokensToRemove.length} invalid/stale FCM tokens for user ${user.email}.`);
            await prisma.user.update({
                where: { id: userId },
                data: {
                    fcmTokens: {
                        set: user.fcmTokens.filter((t) => !tokensToRemove.includes(t)),
                    },
                },
            });
        }
    } catch (error) {
        console.error("Error in sendNotificationToUser service:", error);
    }
}
