import type { User } from "@supabase/supabase-js";
import { createClient } from "@supabase/supabase-js";
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

  // Create a Supabase client with the user's access token (not service role key)
  const url = process.env.SUPABASE_URL || process.env.NEXT_PUBLIC_SUPABASE_URL || "";
  const anonKey = process.env.SUPABASE_ANON_KEY || "";

  if (!url || !anonKey) {
    throw new HttpError(500, "服务器配置错误");
  }

  const supabaseClient = createClient(url, anonKey, {
    auth: {
      autoRefreshToken: false,
      persistSession: false
    },
    global: {
      headers: {
        Authorization: `Bearer ${token}`
      }
    }
  });

  const { data, error } = await supabaseClient.auth.getUser(token);
  if (error || !data?.user) {
    console.error("Auth error:", error?.message);
    throw new HttpError(401, "无效或过期的登录状态", error?.message);
  }
  return { user: data.user, token };
}
