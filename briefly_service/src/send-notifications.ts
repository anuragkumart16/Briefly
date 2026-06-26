import dotenv from "dotenv";
dotenv.config();
import prisma from "./config/prisma";
import { sendNotificationToUser } from "./services/fcm.service";

async function main() {
    const args = process.argv.slice(2);
    
    // Command validation
    const mode = args[0]; // "--all" or "--user"
    const target = args[1]; // User ID / Email (if --user mode)
    
    let titleIndex = 1;
    if (mode === "--user") {
        titleIndex = 2;
    }
    
    const title = args[titleIndex] || "Update from Briefly ✨";
    const body = args[titleIndex + 1] || "Check out what's new in the app!";

    if (mode === "--all") {
        console.log(`[Broadcast] Sending push notification to ALL users...`);
        console.log(`Title: "${title}"`);
        console.log(`Body: "${body}"\n`);

        const users = await prisma.user.findMany({
            select: { id: true, email: true, name: true }
        });

        console.log(`Found ${users.length} users in database. Starting dispatch...`);
        
        let successCount = 0;
        const promises = users.map(async (user) => {
            try {
                await sendNotificationToUser(user.id, title, body);
                console.log(`  ✓ Sent to ${user.name || user.email}`);
                successCount++;
            } catch (err: any) {
                console.error(`  ✗ Failed for ${user.email}:`, err.message || err);
            }
        });

        await Promise.all(promises);
        console.log(`\nBroadcast complete. Dispatched notifications successfully to ${successCount}/${users.length} users.`);

    } else if (mode === "--user" && target) {
        console.log(`[Targeted] Searching user by ID or Email: "${target}"...`);
        
        // Find user by ID first, then fallback to email search
        let user = await prisma.user.findFirst({
            where: {
                OR: [
                    { id: target },
                    { email: target }
                ]
            },
            select: { id: true, email: true, name: true }
        });

        if (!user) {
            console.error(`Error: User not found with ID or Email "${target}"`);
            process.exit(1);
        }

        console.log(`Found user: ${user.name || user.email} (ID: ${user.id})`);
        console.log(`Title: "${title}"`);
        console.log(`Body: "${body}"\n`);

        try {
            await sendNotificationToUser(user.id, title, body);
            console.log(`✓ Push notification sent successfully.`);
        } catch (err: any) {
            console.error(`✗ Failed to send notification:`, err.message || err);
            process.exit(1);
        }

    } else {
        console.log("Usage Guide:");
        console.log("  1. Broadcast to all users:");
        console.log('     npx ts-node src/send-notifications.ts --all "Title text" "Body text"');
        console.log("\n  2. Send to a specific user (by ID or Email):");
        console.log('     npx ts-node src/send-notifications.ts --user "user-id-or-email" "Title text" "Body text"');
        process.exit(1);
    }
}

main()
    .catch((e) => {
        console.error("Fatal execution error:", e);
        process.exit(1);
    })
    .finally(() => {
        prisma.$disconnect();
    });
