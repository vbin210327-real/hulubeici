import { NextResponse } from "next/server";
import { supabase } from "@/lib/supabase";
import { requireAuth } from "@/lib/auth";
import { errorResponse, HttpError } from "@/lib/errors";
import { dailyProgressListSchema } from "@/lib/validation";

function assertDate(value: string | null, label: string): string | null {
  if (!value) {
    return null;
  }
  const valid = /^\d{4}-\d{2}-\d{2}$/.test(value);
  if (!valid) {
    throw new HttpError(400, `${label} 格式应为 yyyy-MM-dd`);
  }
  return value;
}

export async function GET(request: Request) {
  try {
    const { user } = await requireAuth(request);
    const { searchParams } = new URL(request.url);
    const start = assertDate(searchParams.get("startDate"), "startDate");
    const end = assertDate(searchParams.get("endDate"), "endDate");

    const query = supabase
      .from("daily_progress")
      .select("progress_date, words_learned, updated_at")
      .eq("user_id", user.id)
      .order("progress_date", { ascending: true });

    if (start) {
      query.gte("progress_date", start);
    }
    if (end) {
      query.lte("progress_date", end);
    }

    const { data, error } = await query;
    if (error) {
      throw new HttpError(500, "读取每日进度失败", error.message);
    }

    return NextResponse.json({
      records: (data ?? []).map((row) => ({
        date: row.progress_date,
        wordsLearned: row.words_learned,
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
    const payload = dailyProgressListSchema.parse(await request.json());

    const rows = payload.records.map((record) => ({
      user_id: user.id,
      progress_date: record.date,
      words_learned: record.wordsLearned,
      updated_at: record.updatedAt ?? new Date().toISOString()
    }));

    const { error } = await supabase
      .from("daily_progress")
      .upsert(rows, { onConflict: "user_id,progress_date" });

    if (error) {
      throw new HttpError(500, "保存每日进度失败", error.message);
    }

    return NextResponse.json({ success: true });
  } catch (error) {
    return errorResponse(error);
  }
}
