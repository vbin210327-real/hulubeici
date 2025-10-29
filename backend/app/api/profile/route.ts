import { NextResponse } from "next/server";
import { supabase } from "@/lib/supabase";
import { requireAuth } from "@/lib/auth";
import { errorResponse, HttpError } from "@/lib/errors";
import { userProfileSchema } from "@/lib/validation";

const DEFAULT_NAME = "学习者";
const DEFAULT_EMOJI = "🎓";

export async function GET(request: Request) {
  try {
    const { user } = await requireAuth(request);

    const { data, error } = await supabase
      .from("user_profiles")
      .select("display_name, avatar_emoji, updated_at")
      .eq("user_id", user.id)
      .maybeSingle();

    if (error) {
      throw new HttpError(500, "读取用户信息失败", error.message);
    }

    return NextResponse.json({
      profile: {
        displayName: data?.display_name ?? DEFAULT_NAME,
        avatarEmoji: data?.avatar_emoji ?? DEFAULT_EMOJI,
        updatedAt: data?.updated_at ?? null
      }
    });
  } catch (error) {
    return errorResponse(error);
  }
}

export async function PATCH(request: Request) {
  try {
    const { user } = await requireAuth(request);
    const payload = userProfileSchema.parse(await request.json());

    const { data: existing, error: fetchError } = await supabase
      .from("user_profiles")
      .select("display_name, avatar_emoji")
      .eq("user_id", user.id)
      .maybeSingle();

    if (fetchError) {
      throw new HttpError(500, "读取用户信息失败", fetchError.message);
    }

    const { data, error } = await supabase
      .from("user_profiles")
      .upsert(
        {
          user_id: user.id,
          display_name: payload.displayName ?? existing?.display_name ?? DEFAULT_NAME,
          avatar_emoji: payload.avatarEmoji ?? existing?.avatar_emoji ?? DEFAULT_EMOJI
        },
        { onConflict: "user_id" }
      )
      .select()
      .maybeSingle();

    if (error) {
      throw new HttpError(500, "保存用户信息失败", error.message);
    }

    return NextResponse.json({
      profile: {
        displayName: data?.display_name ?? DEFAULT_NAME,
        avatarEmoji: data?.avatar_emoji ?? DEFAULT_EMOJI,
        updatedAt: data?.updated_at ?? new Date().toISOString()
      }
    });
  } catch (error) {
    return errorResponse(error);
  }
}
