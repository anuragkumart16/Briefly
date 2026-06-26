import { PrismaClient } from "@prisma/client";

/**
 * Global Prisma Client Instance.
 * 
 * Used to perform CRUD operations on the database.
 */
const prisma = new PrismaClient();

export default prisma;
