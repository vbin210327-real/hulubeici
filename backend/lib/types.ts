export interface WordEntryPayload {
  id?: string;
  word: string;
  meaning: string;
  ordinal?: number;
}

export interface WordbookPayload {
  title: string;
  subtitle?: string | null;
  targetPasses?: number;
  words?: WordEntryPayload[];
}

export interface WordbookResponse {
  id: string;
  title: string;
  subtitle: string | null;
  targetPasses: number;
  isTemplate: boolean;
  templateVersion: number;
  words: WordEntryResponse[];
  updatedAt: string;
  createdAt: string;
}

export interface WordEntryResponse {
  id: string;
  wordbookId: string;
  word: string;
  meaning: string;
  ordinal: number;
  updatedAt: string;
}

export interface SectionProgressPayload {
  wordbookId: string;
  completedPages: number;
  completedPasses: number;
  updatedAt?: string;
}

export interface DailyProgressPayload {
  date: string; // yyyy-MM-dd
  wordsLearned: number;
  updatedAt?: string;
}

export interface WordVisibilityPayload {
  wordEntryId: string;
  showWord: boolean;
  showMeaning: boolean;
  updatedAt?: string;
}

export interface UserProfilePayload {
  displayName?: string;
  avatarEmoji?: string;
}

export interface PaginatedResult<T> {
  data: T[];
  nextCursor?: string;
}
