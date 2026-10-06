-- One profile row per user, created automatically at sign-up
create table public.profiles (
  id          uuid primary key references auth.users(id) on delete cascade,
  role        text not null default 'buyer' check (role in ('buyer','seller','admin')),
  full_name   text,
  phone       text,
  store_name  text,
  address     text,
  is_suspended boolean not null default false,
  created_at  timestamptz not null default now()
);

-- Trigger: build the profile from sign-up data.
-- Only 'buyer' or 'seller' is accepted from the app; admins are made by hand.
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
declare r text := coalesce(new.raw_user_meta_data->>'role', 'buyer');
begin
  if r not in ('buyer','seller') then r := 'buyer'; end if;
  insert into public.profiles (id, role, full_name, phone, store_name, address)
  values (
    new.id, r,
    coalesce(new.raw_user_meta_data->>'full_name', new.raw_user_meta_data->>'owner_name'),
    new.raw_user_meta_data->>'phone',
    new.raw_user_meta_data->>'store_name',
    new.raw_user_meta_data->>'address'
  );
  return new;
end; $$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Helper used by security rules
create or replace function public.is_admin()
returns boolean language sql security definer set search_path = public stable as $$
  select exists (select 1 from public.profiles where id = auth.uid() and role = 'admin');
$$;

-- Row Level Security: who can see what
alter table public.profiles enable row level security;

create policy "read own profile"  on public.profiles for select using (auth.uid() = id);
create policy "admin reads all"   on public.profiles for select using (public.is_admin());
create policy "update own profile" on public.profiles for update
  using (auth.uid() = id) with check (auth.uid() = id);

-- Users may edit only these columns (never role or is_suspended)
revoke update on public.profiles from authenticated, anon;
grant update (full_name, phone, store_name, address) on public.profiles to authenticated;