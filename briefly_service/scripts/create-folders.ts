import dotenv from "dotenv";
dotenv.config();

import { createFolder, listFolders } from "../src/services/cron.service";
import prisma from "../src/config/prisma";

async function main() {
    console.log("Checking existing folders...");
    try {
        const existingFolders = await listFolders();
        console.log("Existing folders on cron-job.org:", existingFolders.map(f => f.title));

        const targetFolders = ["Briefly Floats", "Briefly Reports"];
        const sleep = (ms: number) => new Promise((resolve) => setTimeout(resolve, ms));

        for (const title of targetFolders) {
            let folderId: number;
            const existingFolder = existingFolders.find(f => f.title.toLowerCase() === title.toLowerCase());

            if (existingFolder) {
                console.log(`Folder "${title}" already exists on cron-job.org with ID: ${existingFolder.folderId}`);
                folderId = existingFolder.folderId!;
            } else {
                console.log(`Creating folder "${title}" on cron-job.org...`);
                folderId = await createFolder(title);
                console.log(`✓ Folder "${title}" created successfully with ID: ${folderId}`);
                console.log("Waiting 1.5s to respect rate limits...");
                await sleep(1500);
            }

            // Save/Upsert in AppConstants database table
            const dbKey = title.toUpperCase().replace(" ", "_") + "_FOLDER_ID";
            console.log(`Saving ${dbKey} = ${folderId} to AppConstants...`);
            await prisma.appConstants.upsert({
                where: { key: dbKey },
                update: { value: String(folderId) },
                create: { key: dbKey, value: String(folderId) }
            });
            console.log(`✓ Saved ${dbKey} to database.`);
        }
    } catch (error: any) {
        console.error("Error creating folders:", error.message || error);
        process.exit(1);
    } finally {
        await prisma.$disconnect();
    }
}

main();
