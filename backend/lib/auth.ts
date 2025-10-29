import type { User } from "@supabase/supabase-js";
import { supabase } from "@/lib/supabase";
import { HttpError } from "@/lib/errors";

export interface AuthContext {
  user: User;
  token: string;
}

function extractBearerToken(request: Request): string {
  const header = request.headers.get("Authorization") ?? request.headers.get("authorization");
  if (!header) {
    throw new HttpError(401, "缺少 Authorization 头");
  }
  const [scheme, token] = header.split(" ");
  if (!scheme || scheme.toLowerCase() !== "bearer" || !token) {
    throw new HttpError(401, "Authorization 头格式错误");
  }
  return token;
}

export async function requireAuth(request: Request): Promise<AuthContext> {
  const token = extractBearerToken(request);
  const { data, error } = await supabase.auth.getUser(token);
  if (error || !data?.user) {
    throw new HttpError(401, "无效或过期的登录状态", error?.message);
  }
  return { user: data.user, token };
}
