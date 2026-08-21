import { PrismaClient } from "@prisma/client";

// Single pooled Prisma client shared across the process.
// In production, DATABASE_URL points at PgBouncer (transaction pooling mode)
// in front of RDS, not directly at RDS - see docs/14-scaling-to-1m-users.md.
export const prisma = new PrismaClient();
