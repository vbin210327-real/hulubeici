import Foundation

enum SupabaseConfig {
    // Replace the placeholder with your Supabase anon (public) key from Dashboard → Settings → API.
    private static let rawAnonKey = """
eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFmdHhreGRxcm1lZWJ3cmhzcGRuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjE2MzMxMTAsImV4cCI6MjA3NzIwOTExMH0.dnR6xy_8pG-5mA4arpdViavVjcSpu9OJ8hZKBg_3R0g
"""

    static let url: URL = {
        guard let url = URL(string: "https://qftxkxdqrmeebwrhspdn.supabase.co") else {
            fatalError("Invalid Supabase URL")
        }
        return url
    }()

    static var anonKey: String {
        if let envKey = ProcessInfo.processInfo.environment["SUPABASE_ANON_KEY"], !envKey.isEmpty {
            return envKey
        }
        let trimmed = rawAnonKey.trimmingCharacters(in: .whitespacesAndNewlines)
        precondition(!trimmed.isEmpty && trimmed != "YOUR_SUPABASE_ANON_KEY", "Please set Supabase anon key in SupabaseConfig.swift or SUPABASE_ANON_KEY environment variable.")
        return trimmed
    }
}
