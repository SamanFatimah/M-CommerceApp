-- ============================================================
-- 002: auth hardening
--  - phone_verified column (fixes the repeated SMS prompt on every login)
--  - is_admin() now requires completed 2FA (aal2) and a non-suspended account
--  - is_active() helper for write policies in later migrations
-- ============================================================

-- 1) phone_verified ------------------------------------------------
alter table public.profiles
  add column if not exists phone_verified boolean not null default false;

-- Backfill for users who already verified a phone
update public.profiles p
set phone_verified = true
from auth.users u
where u.id = p.id
  and u.phone is not null
  and u.phone_confirmed_at is not null;

-- Keep it in sync with Supabase Auth
create or replace function public.sync_phone_verified()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.profiles
  set phone_verified = (new.phone is not null and new.phone_confirmed_at is not null)
  where id = new.id;
  return new;
end;
$$;

drop trigger if exists on_auth_user_phone_updated on auth.users;
create trigger on_auth_user_phone_updated
  after update of phone, phone_confirmed_at on auth.users
  for each row
  when (old.phone_confirmed_at is distinct from new.phone_confirmed_at
        or old.phone is distinct from new.phone)
  execute function public.sync_phone_verified();

-- 2) is_admin(): require aal2 + active admin ------------------------
create or replace function public.is_admin()
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select coalesce((select auth.jwt() ->> 'aal'), '') = 'aal2'
     and exists (
       select 1 from public.profiles
       where id = auth.uid()
         and role = 'admin'
         and is_suspended = false
     );
$$;

-- 3) is_active(): signed-in and not suspended -----------------------
create or replace function public.is_active()
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and is_suspended = false
  );
$$;

-- 4) A suspended user can still READ their own profile (the app needs
--    it to show the message) but can no longer UPDATE it.
drop policy if exists "update own profile" on public.profiles;
create policy "update own profile" on public.profiles
  for update
  using (auth.uid() = id)
  with check (auth.uid() = id and public.is_active());

-- 5) Function privileges --------------------------------------------
revoke execute on function public.is_admin()           from public, anon;
revoke execute on function public.is_active()          from public, anon;
revoke execute on function public.sync_phone_verified() from public, anon, authenticated;
revoke execute on function public.handle_new_user()    from public, anon, authenticated;
grant  execute on function public.is_admin()  to authenticated;
grant  execute on function public.is_active() to authenticated;