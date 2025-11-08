import { createClient } from "@supabase/supabase-js";
import type { Database } from "@/types/database";

const url = process.env.SUPABASE_URL || process.env.NEXT_PUBLIC_SUPABASE_URL || "";
const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY || "";

// Only create the client if we have the required environment variables
// This allows the build to succeed even without env vars
export const supabase = url && serviceRoleKey
  ? createClient<Database>(url, serviceRoleKey, {
      auth: {
        autoRefreshToken: false,
        persistSession: false
      }
    })
  : null as any;
