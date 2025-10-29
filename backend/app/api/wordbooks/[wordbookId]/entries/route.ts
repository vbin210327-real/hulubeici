import { NextResponse } from "next/server";
import { supabase } from "@/lib/supabase";
import { errorResponse, HttpError } from "@/lib/errors";
import { requireAuth } from "@/lib/auth";
import { bulkWordImportSchema, uuidSchema } from "@/lib/validation";
import type { Database } from "@/types/database";

type ExistingEntry = Pick<Database["public"]["Tables"]["word_entries"]["Row"], "lemma">;

type Params = {
  params: {
    wordbookId: string;
  };
};

export async function POST(request: Request, { params }: Params) {
  try {
    const { user } = await requireAuth(request);
    const bookId = uuidSchema.parse(params.wordbookId);
    const payload = bulkWordImportSchema.parse(await request.json());

    const { data: wordbook, error: bookError } = await supabase
      .from("wordbooks")
      .select("owner_id")
      .eq("id", bookId)
      .maybeSingle();

    if (bookError) {
      throw new HttpError(500, "读取词书失败", bookError.message);
    }
    if (!wordbook) {
      throw new HttpError(404, "词书不存在");
    }
    if (wordbook.owner_id !== user.id) {
      throw new HttpError(403, "无权导入到此词书");
    }

    const { data: existingRows, error: existingError } = await supabase
      .from("word_entries")
      .select("lemma")
      .eq("wordbook_id", bookId);
    if (existingError) {
      throw new HttpError(500, "读取现有单词失败", existingError.message);
    }

    const existingRowList = existingRows ?? [];
    const existing = new Set<string>(
      existingRowList.map((row: ExistingEntry) => row.lemma.trim().toLowerCase())
    );
    const baseOrdinal = existingRowList.length;
    const seen = new Set<string>();
    const duplicates: string[] = [];

    const inserts: Database["public"]["Tables"]["word_entries"]["Insert"][] = [];
    payload.entries.forEach((entry, index) => {
      const lemma = entry.word.trim();
      if (!lemma) {
        return;
      }
      const normalized = lemma.toLowerCase();
      if (existing.has(normalized) || seen.has(normalized)) {
        duplicates.push(lemma);
        return;
      }
      seen.add(normalized);
      inserts.push({
        wordbook_id: bookId,
        lemma,
        definition: entry.meaning.trim() || "-",
        ordinal: entry.ordinal ?? baseOrdinal + inserts.length
      });
    });

    if (inserts.length > 0) {
      const { error: insertError } = await supabase.from("word_entries").insert(inserts);
      if (insertError) {
        throw new HttpError(500, "导入新单词失败", insertError.message);
      }
    }

    return NextResponse.json(
      {
        addedCount: inserts.length,
        duplicateWords: duplicates
      },
      { status: 201 }
    );
  } catch (error) {
    return errorResponse(error);
  }
}
