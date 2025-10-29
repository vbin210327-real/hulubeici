import type { Database } from "@/types/database";
import type { WordbookResponse, WordEntryResponse } from "@/lib/types";

type WordbookRow = Database["public"]["Tables"]["wordbooks"]["Row"];
type WordEntryRow = Database["public"]["Tables"]["word_entries"]["Row"];

export function mapWordEntry(row: WordEntryRow): WordEntryResponse {
  return {
    id: row.id,
    wordbookId: row.wordbook_id,
    word: row.lemma,
    meaning: row.definition,
    ordinal: row.ordinal,
    updatedAt: row.updated_at
  };
}

export function mapWordbook(
  row: WordbookRow,
  entries: WordEntryRow[]
): WordbookResponse {
  return {
    id: row.id,
    title: row.title,
    subtitle: row.subtitle,
    targetPasses: row.target_passes,
    isTemplate: row.is_template,
    templateVersion: row.template_version,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
    words: entries
      .sort((a, b) => a.ordinal - b.ordinal || a.created_at.localeCompare(b.created_at))
      .map(mapWordEntry)
  };
}
