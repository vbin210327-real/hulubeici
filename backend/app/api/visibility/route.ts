import { NextResponse } from "next/server";
import { supabase } from "@/lib/supabase";
import { requireAuth } from "@/lib/auth";
import { errorResponse, HttpError } from "@/lib/errors";
import { uuidSchema, visibilityListSchema } from "@/lib/validation";

export async function GET(request: Request) {
  try {
    const { user } = await requireAuth(request);
    const { searchParams } = new URL(request.url);
    const wordbookIdParam = searchParams.get("wordbookId");

    if (wordbookIdParam) {
      const wordbookId = uuidSchema.parse(wordbookIdParam);
      const { data, error } = await supabase
        .from("word_visibility")
        .select(
          "word_entry_id, show_word, show_meaning, updated_at, word_entries!inner(wordbook_id)"
        )
        .eq("user_id", user.id)
        .eq("word_entries.wordbook_id", wordbookId);

      if (error) {
        throw new HttpError(500, "读取遮挡设置失败", error.message);
      }

      return NextResponse.json({
        records: (data ?? []).map((row) => ({
          wordEntryId: row.word_entry_id,
          showWord: row.show_word,
          showMeaning: row.show_meaning,
          updatedAt: row.updated_at
        }))
      });
    }

    const { data, error } = await supabase
      .from("word_visibility")
      .select("word_entry_id, show_word, show_meaning, updated_at")
      .eq("user_id", user.id);

    if (error) {
      throw new HttpError(500, "读取遮挡设置失败", error.message);
    }

    return NextResponse.json({
      records: (data ?? []).map((row) => ({
        wordEntryId: row.word_entry_id,
        showWord: row.show_word,
        showMeaning: row.show_meaning,
        updatedAt: row.updated_at
      }))
    });
  } catch (error) {
    return errorResponse(error);
  }
}

export async function POST(request: Request) {
  try {
    const { user } = await requireAuth(request);
    const payload = visibilityListSchema.parse(await request.json());

    const entryIds = Array.from(new Set(payload.records.map((record) => record.wordEntryId)));
    if (entryIds.length === 0) {
      return NextResponse.json({ success: true });
    }

    const { data: accessibleEntries, error: accessError } = await supabase
      .from("word_entries")
      .select("id, wordbooks(owner_id, is_template)")
      .in("id", entryIds);

    if (accessError) {
      throw new HttpError(500, "校验单词归属失败", accessError.message);
    }

    const allowed = new Set(
      (accessibleEntries ?? [])
        .filter((row) => {
          const book = row.wordbooks;
          if (!book) {
            return false;
          }
          return book.owner_id === user.id || book.is_template;
        })
        .map((row) => row.id)
    );

    if (allowed.size !== entryIds.length) {
      throw new HttpError(403, "包含无权访问的单词，已终止保存");
    }

    const rows = payload.records.map((record) => ({
      user_id: user.id,
      word_entry_id: record.wordEntryId,
      show_word: record.showWord,
      show_meaning: record.showMeaning,
      updated_at: record.updatedAt ?? new Date().toISOString()
    }));

    const { error } = await supabase
      .from("word_visibility")
      .upsert(rows, { onConflict: "user_id,word_entry_id" });

    if (error) {
      throw new HttpError(500, "保存遮挡设置失败", error.message);
    }

    return NextResponse.json({ success: true });
  } catch (error) {
    return errorResponse(error);
  }
}
