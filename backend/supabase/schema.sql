-- Enable required extensions
create extension if not exists "pgcrypto";

-- Utility function to auto-update updated_at columns
create or replace function public.set_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

-- Wordbooks
create table if not exists public.wordbooks (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid references auth.users (id) on delete cascade,
  title text not null,
  subtitle text,
  target_passes smallint not null default 1 check (target_passes > 0),
  is_template boolean not null default false,
  template_version integer not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger set_wordbooks_updated_at
before update on public.wordbooks
for each row execute function public.set_updated_at();

-- Word entries
create table if not exists public.word_entries (
  id uuid primary key default gen_random_uuid(),
  wordbook_id uuid not null references public.wordbooks (id) on delete cascade,
  lemma text not null,
  definition text not null,
  ordinal integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint non_empty_definition check (length(trim(definition)) > 0)
);

create trigger set_word_entries_updated_at
before update on public.word_entries
for each row execute function public.set_updated_at();

create unique index if not exists word_entries_unique_lemma
on public.word_entries (wordbook_id, lower(lemma));

create index if not exists word_entries_wordbook_ordinal_idx
on public.word_entries (wordbook_id, ordinal);

-- Section progress
create table if not exists public.section_progress (
  user_id uuid not null references auth.users (id) on delete cascade,
  wordbook_id uuid not null references public.wordbooks (id) on delete cascade,
  completed_pages integer not null default 0,
  completed_passes integer not null default 0,
  updated_at timestamptz not null default now(),
  primary key (user_id, wordbook_id)
);

create trigger set_section_progress_updated_at
before update on public.section_progress
for each row execute function public.set_updated_at();

-- Daily progress
create table if not exists public.daily_progress (
  user_id uuid not null references auth.users (id) on delete cascade,
  progress_date date not null,
  words_learned integer not null default 0,
  updated_at timestamptz not null default now(),
  primary key (user_id, progress_date)
);

create trigger set_daily_progress_updated_at
before update on public.daily_progress
for each row execute function public.set_updated_at();

-- Word visibility preferences
create table if not exists public.word_visibility (
  user_id uuid not null references auth.users (id) on delete cascade,
  word_entry_id uuid not null references public.word_entries (id) on delete cascade,
  show_word boolean not null default true,
  show_meaning boolean not null default true,
  updated_at timestamptz not null default now(),
  primary key (user_id, word_entry_id)
);

create trigger set_word_visibility_updated_at
before update on public.word_visibility
for each row execute function public.set_updated_at();

-- User profile data
create table if not exists public.user_profiles (
  user_id uuid primary key references auth.users (id) on delete cascade,
  display_name text not null default '学习者',
  avatar_emoji text not null default '🎓',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger set_user_profiles_updated_at
before update on public.user_profiles
for each row execute function public.set_updated_at();

-- Row Level Security policies
alter table public.wordbooks enable row level security;
alter table public.word_entries enable row level security;
alter table public.section_progress enable row level security;
alter table public.daily_progress enable row level security;
alter table public.word_visibility enable row level security;
alter table public.user_profiles enable row level security;

create policy "Users can read their wordbooks or templates"
on public.wordbooks
for select
using (owner_id = auth.uid() or is_template);

create policy "Users can manage their own wordbooks"
on public.wordbooks
for all
using (owner_id = auth.uid())
with check (owner_id = auth.uid());

create policy "Entries are visible to owners or template access"
on public.word_entries
for select
using (
  exists (
    select 1 from public.wordbooks wb
    where wb.id = word_entries.wordbook_id
      and (wb.owner_id = auth.uid() or wb.is_template)
  )
);

create policy "Entries can be managed by owners"
on public.word_entries
for all
using (
  exists (
    select 1 from public.wordbooks wb
    where wb.id = word_entries.wordbook_id
      and wb.owner_id = auth.uid()
  )
)
with check (
  exists (
    select 1 from public.wordbooks wb
    where wb.id = word_entries.wordbook_id
      and wb.owner_id = auth.uid()
  )
);

create policy "Users manage their section progress"
on public.section_progress
for all
using (user_id = auth.uid())
with check (user_id = auth.uid());

create policy "Users manage their daily progress"
on public.daily_progress
for all
using (user_id = auth.uid())
with check (user_id = auth.uid());

create policy "Users manage their visibility settings"
on public.word_visibility
for all
using (user_id = auth.uid())
with check (user_id = auth.uid());

create policy "Users manage their profile"
on public.user_profiles
for all
using (user_id = auth.uid())
with check (user_id = auth.uid());
