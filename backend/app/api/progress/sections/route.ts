import { NextResponse } from "next/server";
import { supabase } from "@/lib/supabase";
import { requireAuth } from "@/lib/auth";
import { errorResponse, HttpError } from "@/lib/errors";
import { sectionProgressListSchema, uuidSchema } from "@/lib/validation";

export async function GET(request: Request) {
  try {
    const { user } = await requireAuth(request);
    const { searchParams } = new URL(request.url);
    const wordbookIdParam = searchParams.get("wordbookId");

    const query = supabase
      .from("section_progress")
      .select("wordbook_id, completed_pages, completed_passes, updated_at")
      .eq("user_id", user.id)
      .order("updated_at", { ascending: false });

    if (wordbookIdParam) {
      const wordbookId = uuidSchema.parse(wordbookIdParam);
      query.eq("wordbook_id", wordbookId);
    }

    const { data, error } = await query;
    if (error) {
      throw new HttpError(500, "读取学习进度失败", error.message);
    }

    return NextResponse.json({
      records: (data ?? []).map((row) => ({
        wordbookId: row.wordbook_id,
        completedPages: row.completed_pages,
        completedPasses: row.completed_passes,
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
    const payload = sectionProgressListSchema.parse(await request.json());

    const rows = payload.records.map((record) => ({
      user_id: user.id,
      wordbook_id: record.wordbookId,
      completed_pages: record.completedPages,
      completed_passes: record.completedPasses,
      updated_at: record.updatedAt ?? new Date().toISOString()
    }));

    const { error } = await supabase
      .from("section_progress")
      .upsert(rows, { onConflict: "user_id,wordbook_id" });

    if (error) {
      throw new HttpError(500, "保存学习进度失败", error.message);
    }

    return NextResponse.json({ success: true });
  } catch (error) {
    return errorResponse(error);
  }
}
