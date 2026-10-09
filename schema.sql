-- Attendly Campus schema for Supabase PostgreSQL
-- Run this entire file in Supabase Dashboard > SQL Editor.
-- Then create an account in the app and promote trusted staff using the admin SQL in README.md.

create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text not null,
  full_name text not null default '',
  role text not null default 'student' check (role in ('student','admin')),
  roll_number text,
  created_at timestamptz not null default now()
);

create table if not exists public.subjects (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  code text,
  target_percent integer not null default 75 check (target_percent between 1 and 100),
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now()
);

create table if not exists public.attendance_records (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null references public.profiles(id) on delete cascade,
  subject_id uuid not null references public.subjects(id) on delete cascade,
  attendance_date date not null,
  status text not null check (status in ('Present','Absent','Leave')),
  periods integer not null default 1 check (periods between 1 and 12),
  note text,
  marked_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now()
);

create index if not exists attendance_student_date_idx on public.attendance_records(student_id, attendance_date desc);
create index if not exists attendance_subject_idx on public.attendance_records(subject_id);

-- Create profile on auth signup. Public signups are always students.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, email, full_name, role)
  values (
    new.id,
    new.email,
    coalesce(new.raw_user_meta_data ->> 'full_name', ''),
    'student'
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created_attendly on auth.users;
create trigger on_auth_user_created_attendly
after insert on auth.users
for each row execute procedure public.handle_new_user();

-- Security-definer helper avoids recursive profile-policy lookups.
create or replace function public.is_attendly_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.profiles p
    where p.id = (select auth.uid()) and p.role = 'admin'
  );
$$;

alter table public.profiles enable row level security;
alter table public.subjects enable row level security;
alter table public.attendance_records enable row level security;

-- Remove broad default grants and grant only the operations used by this app.
revoke all on public.profiles from anon, authenticated;
revoke all on public.subjects from anon, authenticated;
revoke all on public.attendance_records from anon, authenticated;

grant select on public.profiles to authenticated;
grant update (full_name, roll_number) on public.profiles to authenticated;
grant select on public.subjects to authenticated;
grant insert, update, delete on public.subjects to authenticated;
grant select, insert, update, delete on public.attendance_records to authenticated;

-- Profiles: student sees own profile; admins can view all.
drop policy if exists "profile read own or admin" on public.profiles;
create policy "profile read own or admin" on public.profiles
for select to authenticated
using (id = (select auth.uid()) or (select public.is_attendly_admin()));

-- Users can update only their own permitted columns; role/email are not granted for update.
drop policy if exists "profile update own" on public.profiles;
create policy "profile update own" on public.profiles
for update to authenticated
using (id = (select auth.uid()))
with check (id = (select auth.uid()));

-- Subjects are visible to signed-in users; only admins may change them.
drop policy if exists "subjects read authenticated" on public.subjects;
create policy "subjects read authenticated" on public.subjects
for select to authenticated using (true);
drop policy if exists "subjects admin insert" on public.subjects;
create policy "subjects admin insert" on public.subjects
for insert to authenticated with check ((select public.is_attendly_admin()));
drop policy if exists "subjects admin update" on public.subjects;
create policy "subjects admin update" on public.subjects
for update to authenticated using ((select public.is_attendly_admin()))
with check ((select public.is_attendly_admin()));
drop policy if exists "subjects admin delete" on public.subjects;
create policy "subjects admin delete" on public.subjects
for delete to authenticated using ((select public.is_attendly_admin()));

-- Students can read only their own records. Admins can manage all records.
drop policy if exists "attendance read own or admin" on public.attendance_records;
create policy "attendance read own or admin" on public.attendance_records
for select to authenticated
using (student_id = (select auth.uid()) or (select public.is_attendly_admin()));
drop policy if exists "attendance admin insert" on public.attendance_records;
create policy "attendance admin insert" on public.attendance_records
for insert to authenticated
with check ((select public.is_attendly_admin()) and marked_by = (select auth.uid()));
drop policy if exists "attendance admin update" on public.attendance_records;
create policy "attendance admin update" on public.attendance_records
for update to authenticated
using ((select public.is_attendly_admin()))
with check ((select public.is_attendly_admin()) and marked_by = (select auth.uid()));
drop policy if exists "attendance admin delete" on public.attendance_records;
create policy "attendance admin delete" on public.attendance_records
for delete to authenticated using ((select public.is_attendly_admin()));

-- Important: no client-side policy permits a user to promote themselves to admin.
