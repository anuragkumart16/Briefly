import dotenv from "dotenv";
dotenv.config();
import { sendNotificationToUser } from "./services/fcm.service";

const userId = process.argv[2];
const title = process.argv[3] || "Test Notification ✨";
const body = process.argv[4] || "Hello, this is a test push notification from the Briefly backend!";

if (!userId) {
    console.error("Usage: npx ts-node src/test-push.ts <userId> [title] [body]");
    process.exit(1);
}

console.log(`Sending push notification to user ${userId}...`);
sendNotificationToUser(userId, title, body)
    .then(() => {
        console.log("Notification send command completed. Check console/logs above for results.");
        process.exit(0);
    })
    .catch((err) => {
        console.error("Error sending notification:", err);
        process.exit(1);
    });
