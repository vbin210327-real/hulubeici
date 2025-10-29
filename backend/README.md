# Hulu Beici Backend (Next.js + Supabase)

This Next.js project exposes the REST API required to persist the "葫芦背词" iOS app data in Supabase. It manages custom wordbooks, word entries, learning progress, daily statistics, visibility preferences, and user profile data.

## Prerequisites

- Node.js 18+
- pnpm / npm / yarn (examples use `pnpm`)
- Supabase project (URL: `https://qftxkxdqrmeebwrhspdn.supabase.co`)
- Supabase CLI (`brew install supabase/tap/supabase`) – optional but recommended

## 1. Configure Supabase Schema

1. Sign in to the Supabase dashboard for your project.
2. Open the SQL Editor and run the contents of [`supabase/schema.sql`](./supabase/schema.sql).
   - This creates the tables, triggers, and row-level security policies required by the app.
3. (Optional) Seed shared template wordbooks by inserting them into `wordbooks` with `is_template = true` and `owner_id = NULL`.

If you prefer using the CLI:

```bash
cd backend
supabase login               # once
supabase link --project-ref qftxkxdqrmeebwrhspdn
supabase db push --file supabase/schema.sql
```

## 2. Environment Variables

Copy `.env.example` to `.env.local` (or `.env`) and fill in your project keys:

```bash
SUPABASE_URL=https://qftxkxdqrmeebwrhspdn.supabase.co
SUPABASE_SERVICE_ROLE_KEY=... # Settings → API → Service role key
SUPABASE_ANON_KEY=...         # Settings → API → anon key (optional for future use)
API_PAGE_SIZE=100             # optional override
```

> ⚠️ Keep the **service role** key on the server only. Do not ship it with the iOS app.

## 3. Install & Run

```bash
cd backend
pnpm install   # or npm install / yarn
touch .env.local # populate as described above
pnpm dev       # starts Next.js on http://localhost:3000
```

## 4. Available API Routes

All routes expect a Supabase session access token in the `Authorization: Bearer <token>` header. You can obtain this token by signing in from the iOS app via Supabase Auth (email OTP, Sign in with Apple, etc.).

### Wordbooks

| Method | Path                                      | Description |
| ------ | ----------------------------------------- | ----------- |
| GET    | `/api/wordbooks?includeTemplates=true`    | List user wordbooks and optional shared templates |
| POST   | `/api/wordbooks`                          | Create a new wordbook with optional initial entries |
| GET    | `/api/wordbooks/:id`                      | Fetch a single wordbook (entries included) |
| PATCH  | `/api/wordbooks/:id`                      | Update metadata and replace entries |
| DELETE | `/api/wordbooks/:id`                      | Delete the wordbook and cascade entries |
| POST   | `/api/wordbooks/:id/entries`              | Bulk import words into an existing wordbook |

### Progress & Statistics

| Method | Path                         | Description |
| ------ | ---------------------------- | ----------- |
| GET    | `/api/progress/sections`     | Fetch per-wordbook progress; filter with `wordbookId` |
| POST   | `/api/progress/sections`     | Upsert a batch of section progress records |
| GET    | `/api/progress/daily`        | Fetch daily stats; optional `startDate`, `endDate` |
| POST   | `/api/progress/daily`        | Upsert a batch of daily statistics |

### Visibility & Profile

| Method | Path                | Description |
| ------ | ------------------- | ----------- |
| GET    | `/api/visibility`   | Fetch all visibility overrides (optionally filter by `wordbookId`) |
| POST   | `/api/visibility`   | Upsert visibility overrides for entries |
| GET    | `/api/profile`      | Read the user's display name & avatar emoji |
| PATCH  | `/api/profile`      | Update profile data |

### Utilities

| Method | Path           | Description |
| ------ | -------------- | ----------- |
| GET    | `/api/health`  | Simple status check |

## 5. iOS Integration Cheatsheet

1. **Auth**: Sign in via Supabase Auth (email OTP or Apple). Store the returned session token for API calls.
2. **Wordbooks**:
   - Use `GET /api/wordbooks` on launch to sync.
   - For create/edit/delete/import, call the corresponding endpoints; update local caches with the JSON response.
3. **Progress**:
   - Periodically batch-update progress with `POST /api/progress/sections` and `POST /api/progress/daily`.
   - Before showing analytics, refresh with `GET` to stay in sync across devices.
4. **Visibility**: When toggles change, push them via `POST /api/visibility`. Fetch on section load if you need the latest server state.
5. **Profile**: Mirror `UserProfileStore` with the `/api/profile` endpoints.

## 6. Folder Structure

```
backend/
├─ app/
│  ├─ api/...
│  ├─ layout.tsx
│  ├─ page.tsx
│  └─ globals.css
├─ lib/     # shared helpers (auth, validation, mappers)
├─ supabase/
│  └─ schema.sql
├─ types/
│  └─ database.ts
├─ package.json
└─ README.md
```

## 7. Production Deployment

- Deploy the Next.js app to Vercel, Fly.io, or your preferred host.
- Set the environment variables in the hosting provider (never commit credentials).
- Configure HTTPS and point your app's API base URL to the deployed host.

Once deployed, update the iOS app's networking layer to point to the hosted API, and start creating remote backups of your wordbooks 🙂
