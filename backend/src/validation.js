import { z } from 'zod';

const optionalText = z.string().trim().max(120).optional().nullable();

export const registerSchema = z.object({
  displayName: z.string().trim().min(2).max(120),
  email: z.string().trim().email().max(254),
  password: z.string().min(8).max(128),
});

export const loginSchema = z.object({
  email: z.string().trim().email().max(254),
  password: z.string().min(1).max(128),
});

export const profileSchema = z.object({
  displayName: z.string().trim().min(2).max(120),
});

export const customerSchema = z.object({
  name: z.string().trim().min(1).max(160),
  contactName: optionalText,
  email: z.string().trim().email().max(254).optional().nullable().or(z.literal('')),
  phone: z.string().trim().max(40).optional().nullable(),
  archived: z.boolean().optional(),
});

export const customerListSchema = z.object({
  query: z.string().trim().max(160).optional(),
  archiveScope: z.enum(['WORKING', 'ARCHIVED']).default('WORKING'),
  limit: z.coerce.number().int().min(1).max(50).default(10),
});
