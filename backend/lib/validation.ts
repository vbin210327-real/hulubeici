import { z } from "zod";

export const uuidSchema = z
  .string()
  .uuid({ message: "Expected a valid UUID" });

export const wordEntrySchema = z.object({
  id: uuidSchema.optional(),
  word: z
    .string()
    .trim()
    .min(1, "单词不能为空"),
  meaning: z
    .string()
    .trim()
    .min(1, "释义不能为空"),
  ordinal: z.number().int().min(0).optional()
});

export const wordbookSchema = z.object({
  title: z
    .string()
    .trim()
    .min(1, "词书名称不能为空"),
  subtitle: z
    .string()
    .trim()
    .min(1)
    .nullable()
    .optional(),
  targetPasses: z
    .number()
    .int()
    .min(1)
    .max(50)
    .optional(),
  words: z.array(wordEntrySchema).max(2000).optional()
});

export const bulkWordImportSchema = z.object({
  entries: z.array(wordEntrySchema).min(1).max(500)
});

export const sectionProgressSchema = z.object({
  wordbookId: uuidSchema,
  completedPages: z.number().int().min(0),
  completedPasses: z.number().int().min(0),
  updatedAt: z.string().datetime().optional()
});

export const sectionProgressListSchema = z.object({
  records: z.array(sectionProgressSchema).min(1).max(200)
});

export const dailyProgressSchema = z.object({
  date: z
    .string()
    .regex(/\d{4}-\d{2}-\d{2}/, "日期格式应为 yyyy-MM-dd"),
  wordsLearned: z.number().int().min(0),
  updatedAt: z.string().datetime().optional()
});

export const dailyProgressListSchema = z.object({
  records: z.array(dailyProgressSchema).min(1).max(200)
});

export const visibilitySchema = z.object({
  wordEntryId: uuidSchema,
  showWord: z.boolean(),
  showMeaning: z.boolean(),
  updatedAt: z.string().datetime().optional()
});

export const visibilityListSchema = z.object({
  records: z.array(visibilitySchema).min(1).max(500)
});

export const userProfileSchema = z.object({
  displayName: z
    .string()
    .trim()
    .min(1)
    .max(60)
    .optional(),
  avatarEmoji: z
    .string()
    .trim()
    .max(8)
    .optional()
});

export type WordbookInput = z.infer<typeof wordbookSchema>;
export type WordEntryInput = z.infer<typeof wordEntrySchema>;
export type SectionProgressInput = z.infer<typeof sectionProgressSchema>;
export type DailyProgressInput = z.infer<typeof dailyProgressSchema>;
export type VisibilityInput = z.infer<typeof visibilitySchema>;
export type UserProfileInput = z.infer<typeof userProfileSchema>;
