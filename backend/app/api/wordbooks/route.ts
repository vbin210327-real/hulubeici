import { NextResponse } from "next/server";
import { supabase } from "@/lib/supabase";
import { errorResponse, HttpError } from "@/lib/errors";
import { requireAuth } from "@/lib/auth";
import { mapWordbook } from "@/lib/mappers";
import { wordbookSchema } from "@/lib/validation";
import type { Database } from "@/types/database";
import type { WordEntryPayload } from "@/lib/types";

const DEFAULT_PAGE_SIZE = Number(process.env.API_PAGE_SIZE ?? 100);

type WordbookWithEntries = Database["public"]["Tables"]["wordbooks"]["Row"] & {
  word_entries: Database["public"]["Tables"]["word_entries"]["Row"][];
};

function toInsertEntries(
  bookId: string,
  words: WordEntryPayload[]
): Database["public"]["Tables"]["word_entries"]["Insert"][] {
  const seen = new Set<string>();
  return words
    .map((entry, index) => {
      const lemma = entry.word.trim();
      const meaning = entry.meaning.trim();
      if (!lemma) {
        return null;
      }
      const normalized = lemma.toLowerCase();
      if (seen.has(normalized)) {
        return null;
      }
      seen.add(normalized);
      return {
        wordbook_id: bookId,
        lemma,
        definition: meaning || "-",
        ordinal: entry.ordinal ?? index
      };
    })
    .filter(Boolean) as Database["public"]["Tables"]["word_entries"]["Insert"][];
}

export async function GET(request: Request) {
  try {
    const { user } = await requireAuth(request);
    const { searchParams } = new URL(request.url);
    const includeTemplates = searchParams.get("includeTemplates") !== "false";
    const limit = Math.min(Number(searchParams.get("limit") ?? DEFAULT_PAGE_SIZE), 500);

    const ownQuery = supabase
      .from("wordbooks")
      .select("*, word_entries(*)")
      .eq("owner_id", user.id)
      .order("updated_at", { ascending: false })
      .limit(limit);

    const [ownResult, templateResult] = await Promise.all([
      ownQuery,
      includeTemplates
        ? supabase
            .from("wordbooks")
            .select("*, word_entries(*)")
            .eq("is_template", true)
            .order("title", { ascending: true })
            .limit(limit)
        : Promise.resolve({ data: [] as WordbookWithEntries[], error: null })
    ]);

    if (ownResult.error) {
      throw new HttpError(500, "无法读取自定义词书", ownResult.error.message);
    }
    if (templateResult.error) {
      throw new HttpError(500, "无法读取模板词书", templateResult.error.message);
    }

    const merged = new Map<string, WordbookWithEntries>();
    for (const list of [ownResult.data ?? [], templateResult.data ?? []]) {
      for (const item of list) {
        merged.set(item.id, item as WordbookWithEntries);
      }
    }

    const payload = Array.from(merged.values()).map((row) =>
      mapWordbook(row, row.word_entries ?? [])
    );

    return NextResponse.json({ wordbooks: payload });
  } catch (error) {
    return errorResponse(error);
  }
}

export async function POST(request: Request) {
  try {
    const { user } = await requireAuth(request);
    const json = await request.json();
    const payload = wordbookSchema.parse(json);

    const { data: inserted, error: insertError } = await supabase
      .from("wordbooks")
      .insert({
        owner_id: user.id,
        title: payload.title.trim(),
        subtitle: payload.subtitle?.trim() || null,
        target_passes: payload.targetPasses ?? 1,
        is_template: false
      })
      .select()
      .single();

    if (insertError || !inserted) {
      throw new HttpError(500, "创建词书失败", insertError?.message);
    }

    let entries = [] as Database["public"]["Tables"]["word_entries"]["Row"][];
    if (payload.words && payload.words.length > 0) {
      const toInsert = toInsertEntries(inserted.id, payload.words);
      if (toInsert.length > 0) {
        const { data: insertedEntries, error: entryError } = await supabase
          .from("word_entries")
          .insert(toInsert)
          .select();
        if (entryError) {
          throw new HttpError(500, "保存单词失败", entryError.message);
        }
        entries = insertedEntries ?? [];
      }
    }

    return NextResponse.json(
      {
        wordbook: mapWordbook(inserted, entries)
      },
      { status: 201 }
    );
  } catch (error) {
    return errorResponse(error);
  }
}
