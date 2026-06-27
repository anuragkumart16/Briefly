import { Request, Response } from "express";
import prisma from "../config/prisma";
import { sendNotificationToUser } from "../services/fcm.service";

/**
 * Checks if the current local time in the user's timezone is within their configured silent hours.
 */
function isSilentHours(
    timezone: string,
    startHour: number,
    startMinute: number,
    endHour: number,
    endMinute: number
): boolean {
    try {
        // Resolve current local time in the target timezone
        const localTimeString = new Date().toLocaleString("en-US", { timeZone: timezone });
        const localDate = new Date(localTimeString);

        const currentMinutes = localDate.getHours() * 60 + localDate.getMinutes();
        const startMinutes = startHour * 60 + startMinute;
        const endMinutes = endHour * 60 + endMinute;

        if (startMinutes < endMinutes) {
            return currentMinutes >= startMinutes && currentMinutes <= endMinutes;
        } else {
            return currentMinutes >= startMinutes || currentMinutes <= endMinutes;
        }
    } catch (err) {
        console.error(`Error calculating silent hours for timezone ${timezone}:`, err);
        return false; // Default to not silent if timezone parsing fails
    }
}

/**
 * Endpoint triggered by the hourly cron job to batch process and dispatch Floats via FCM.
 */
export const processFloats = async (req: Request, res: Response) => {
    // Basic verification of CRON_JOB_TOKEN header if configured
    const cronToken = req.headers["authorization"] || req.headers["x-cron-token"];
    const expectedToken = process.env.CRON_JOB_TOKEN;

    if (expectedToken && cronToken !== expectedToken && cronToken !== `Bearer ${expectedToken}`) {
        res.status(401).json({ success: false, message: "Unauthorized cron trigger request." });
        return;
    }

    try {
        console.log(`[${new Date().toISOString()}] Starting Float dispatch cron run...`);

        // 1. Fetch all user settings where floats are enabled
        const activeSettings = await prisma.settings.findMany({
            where: { floatsEnabled: true }
        });

        console.log(`Found ${activeSettings.length} users with Floats enabled.`);
        let processedCount = 0;
        let sentCount = 0;

        // 2. Process each user setting record in parallel
        await Promise.all(
            activeSettings.map(async (setting) => {
                try {
                    const userId = setting.userId;

                    // A. Check silent hours
                    const isSilent = isSilentHours(
                        setting.timezone,
                        setting.silentStartHour,
                        setting.silentStartMinute,
                        setting.silentEndHour,
                        setting.silentEndMinute
                    );

                    if (isSilent && !setting.sendFloatsSilent) {
                        console.log(`User ${userId} is currently in silent hours. Skipping.`);
                        return;
                    }

                    // B. Check float send schedule / frequency interval
                    const schedule = await prisma.floatSchedule.findUnique({
                        where: { userId }
                    });

                    if (schedule && schedule.lastFloatSentAt) {
                        const elapsedMs = Date.now() - schedule.lastFloatSentAt.getTime();
                        const elapsedHours = elapsedMs / (1000 * 60 * 60);

                        if (elapsedHours < setting.floatsFrequencyHours) {
                            console.log(`User ${userId} not eligible yet. Hours since last float: ${elapsedHours.toFixed(2)} (requires ${setting.floatsFrequencyHours}h). Skipping.`);
                            return;
                        }
                    }

                    // C. Retrieve active floats
                    const activeFloats = await prisma.floatItem.findMany({
                        where: { userId, isActive: true },
                        select: { text: true }
                    });

                    let selectedFloat = "";
                    let notificationTitle = "Briefly Floats 💡";

                    if (activeFloats.length === 0) {
                        notificationTitle = "Add your first Float! 💡";
                        selectedFloat = "Tap here to add quotes, affirmations, or wisdom reminders to your daily Floats.";
                    } else {
                        // D. Pick a random float
                        const randomIndex = Math.floor(Math.random() * activeFloats.length);
                        selectedFloat = activeFloats[randomIndex].text;
                    }

                    processedCount++;

                    // E. Send FCM notification
                    console.log(`Sending float notification to user ${userId}: "${selectedFloat}"`);
                    const payload = {
                        type: "floats"
                    };
                    await sendNotificationToUser(userId, notificationTitle, selectedFloat, payload);
                    sentCount++;

                    // F. Update float schedule timestamp
                    await prisma.floatSchedule.upsert({
                        where: { userId },
                        update: { lastFloatSentAt: new Date() },
                        create: { userId, lastFloatSentAt: new Date() }
                    });

                } catch (userErr) {
                    console.error(`Error processing floats for user ${setting.userId}:`, userErr);
                }
            })
        );

        console.log(`[${new Date().toISOString()}] Float cron run completed. Processed: ${processedCount}, Sent: ${sentCount}.`);
        res.status(200).json({
            success: true,
            message: `Processed ${processedCount} users, successfully sent ${sentCount} notifications.`
        });
    } catch (error: any) {
        console.error("Error in processFloats cron handler:", error);
        res.status(500).json({ success: false, message: error.message || "Failed to process float cron jobs." });
    }
};
