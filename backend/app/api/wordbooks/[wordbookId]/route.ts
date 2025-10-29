import { NextResponse } from "next/server";
import { supabase } from "@/lib/supabase";
import { errorResponse, HttpError } from "@/lib/errors";
import { requireAuth } from "@/lib/auth";
import { mapWordbook } from "@/lib/mappers";
import {
  uuidSchema,
  wordbookSchema,
  wordEntrySchema
} from "@/lib/validation";
import type { Database } from "@/types/database";
import type { WordEntryPayload } from "@/lib/types";

const updateSchema = wordbookSchema.partial();

type WordbookWithEntries = Database["public"]["Tables"]["wordbooks"]["Row"] & {
  word_entries: Database["public"]["Tables"]["word_entries"]["Row"][];
};

type WordEntryInsert = Database["public"]["Tables"]["word_entries"]["Insert"];
type WordEntryUpdate = Database["public"]["Tables"]["word_entries"]["Update"];

type Params = {
  params: {
    wordbookId: string;
  };
};

function sanitizeEntries(
  bookId: string,
  entries: WordEntryPayload[]
): {
  inserts: WordEntryInsert[];
  updates: WordEntryUpdate[];
  keepIds: Set<string>;
} {
  const seen = new Set<string>();
  const inserts: WordEntryInsert[] = [];
  const updates: WordEntryUpdate[] = [];
  const keepIds = new Set<string>();

  entries.forEach((entry, index) => {
    const parsed = wordEntrySchema.parse(entry);
    const lemma = parsed.word.trim();
    if (!lemma) {
      return;
    }
    const normalized = lemma.toLowerCase();
    if (seen.has(normalized)) {
      return;
    }
    seen.add(normalized);

    const definition = parsed.meaning.trim() || "-";
    const ordinal = parsed.ordinal ?? index;

    if (parsed.id) {
      keepIds.add(parsed.id);
      updates.push({
        id: parsed.id,
        wordbook_id: bookId,
        lemma,
        definition,
        ordinal
      });
    } else {
      inserts.push({
        wordbook_id: bookId,
        lemma,
        definition,
        ordinal
      });
    }
  });

  return { inserts, updates, keepIds };
}

async function assertOwnership(row: WordbookWithEntries, userId: string) {
  if (row.owner_id !== userId) {
    throw new HttpError(403, "无权操作此词书");
  }
}

export async function GET(request: Request, { params }: Params) {
  try {
    const { user } = await requireAuth(request);
    const bookId = uuidSchema.parse(params.wordbookId);

    const { data, error } = await supabase
      .from("wordbooks")
      .select("*, word_entries(*)")
      .eq("id", bookId)
      .maybeSingle();

    if (error) {
      throw new HttpError(500, "读取词书失败", error.message);
    }
    if (!data) {
      throw new HttpError(404, "词书不存在");
    }
    if (!data.is_template && data.owner_id !== user.id) {
      throw new HttpError(403, "无权查看此词书");
    }

    return NextResponse.json({
      wordbook: mapWordbook(data, data.word_entries ?? [])
    });
  } catch (error) {
    return errorResponse(error);
  }
}

export async function PATCH(request: Request, { params }: Params) {
  try {
    const { user } = await requireAuth(request);
    const bookId = uuidSchema.parse(params.wordbookId);
    const payload = updateSchema.parse(await request.json());

    const { data: existing, error: fetchError } = await supabase
      .from("wordbooks")
      .select("*, word_entries(*)")
      .eq("id", bookId)
      .maybeSingle();

    if (fetchError) {
      throw new HttpError(500, "读取词书失败", fetchError.message);
    }
    if (!existing) {
      throw new HttpError(404, "词书不存在");
    }

    await assertOwnership(existing, user.id);

    if (payload.title || payload.subtitle !== undefined || payload.targetPasses) {
      const { error: updateError } = await supabase
        .from("wordbooks")
        .update({
          title: payload.title?.trim() ?? existing.title,
          subtitle:
            payload.subtitle === undefined
              ? existing.subtitle
              : payload.subtitle?.trim() || null,
          target_passes: payload.targetPasses ?? existing.target_passes
        })
        .eq("id", bookId);
      if (updateError) {
        throw new HttpError(500, "更新词书信息失败", updateError.message);
      }
    }

    if (payload.words) {
      const { inserts, updates, keepIds } = sanitizeEntries(bookId, payload.words);

      if (updates.length > 0) {
        const { error: upsertError } = await supabase
          .from("word_entries")
          .upsert(updates, { onConflict: "id" });
        if (upsertError) {
          throw new HttpError(500, "更新单词失败", upsertError.message);
        }
      }

      if (inserts.length > 0) {
        const { error: insertError } = await supabase
          .from("word_entries")
          .insert(inserts);
        if (insertError) {
          throw new HttpError(500, "添加单词失败", insertError.message);
        }
      }

      const existingIds = (existing.word_entries ?? []).map((entry) => entry.id);
      const toDelete = existingIds.filter((id) => !keepIds.has(id));
      if (toDelete.length > 0) {
        const { error: deleteError } = await supabase
          .from("word_entries")
          .delete()
          .in("id", toDelete);
        if (deleteError) {
          throw new HttpError(500, "删除单词失败", deleteError.message);
        }
      }
    }

    const { data: refreshed, error: reloadError } = await supabase
      .from("wordbooks")
      .select("*, word_entries(*)")
      .eq("id", bookId)
      .maybeSingle();

    if (reloadError) {
      throw new HttpError(500, "刷新词书失败", reloadError.message);
    }

    if (!refreshed) {
      throw new HttpError(404, "词书不存在");
    }

    return NextResponse.json({
      wordbook: mapWordbook(refreshed, refreshed.word_entries ?? [])
    });
  } catch (error) {
    return errorResponse(error);
  }
}

export async function DELETE(request: Request, { params }: Params) {
  try {
    const { user } = await requireAuth(request);
    const bookId = uuidSchema.parse(params.wordbookId);

    const { data: existing, error: fetchError } = await supabase
      .from("wordbooks")
      .select("*")
      .eq("id", bookId)
      .maybeSingle();

    if (fetchError) {
      throw new HttpError(500, "读取词书失败", fetchError.message);
    }
    if (!existing) {
      throw new HttpError(404, "词书不存在");
    }

    await assertOwnership(
      { ...existing, word_entries: [] },
      user.id
    );

    const { error: deleteError } = await supabase
      .from("wordbooks")
      .delete()
      .eq("id", bookId);

    if (deleteError) {
      throw new HttpError(500, "删除词书失败", deleteError.message);
    }

    return NextResponse.json({ success: true });
  } catch (error) {
    return errorResponse(error);
  }
}
