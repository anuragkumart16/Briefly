import prisma from "./config/prisma";

async function main() {
    console.log("Fetching users from database...");
    const users = await prisma.user.findMany();
    console.log("Users:", JSON.stringify(users, null, 2));

    console.log("\nFetching reports from database...");
    const reports = await prisma.report.findMany({
        orderBy: { createdAt: "desc" },
        take: 5
    });
    console.log("Recent Reports:", JSON.stringify(reports, null, 2));

    console.log("\nFetching float schedules from database...");
    const schedules = await prisma.floatSchedule.findMany();
    console.log("Float Schedules:", JSON.stringify(schedules, null, 2));
}

main()
    .catch(err => console.error(err))
    .finally(() => prisma.$disconnect());
