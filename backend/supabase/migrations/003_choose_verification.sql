-- 1) new columns
alter table public.profiles
  add column if not exists is_verified   boolean not null default false,
  add column if not exists verified_via  text check (verified_via in ('email','phone')),
  add column if not exists contact_email text;

-- 2) profile creation: works for email-keyed AND phone-keyed sign-ups
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
declare r text := coalesce(new.raw_user_meta_data->>'role', 'buyer');
begin
  if r not in ('buyer','seller') then r := 'buyer'; end if;
  insert into public.profiles
    (id, role, full_name, phone, store_name, address,
     contact_email, is_verified, verified_via, phone_verified)
  values (
    new.id, r,
    coalesce(new.raw_user_meta_data->>'full_name', new.raw_user_meta_data->>'owner_name'),
    coalesce(nullif(new.raw_user_meta_data->>'phone',''),
             case when coalesce(new.phone,'') <> '' then '+' || new.phone end),
    new.raw_user_meta_data->>'store_name',
    new.raw_user_meta_data->>'address',
    coalesce(new.email, nullif(new.raw_user_meta_data->>'email','')),
    (new.email_confirmed_at is not null or new.phone_confirmed_at is not null),
    case when new.phone_confirmed_at is not null then 'phone'
         when new.email_confirmed_at is not null then 'email' end,
    (new.phone is not null and new.phone_confirmed_at is not null)
  );
  return new;
end; $$;

-- 3) keep flags in sync when the user enters the code
create or replace function public.sync_verified()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  update public.profiles
  set is_verified    = (new.email_confirmed_at is not null or new.phone_confirmed_at is not null),
      verified_via   = coalesce(verified_via,
                         case when new.phone_confirmed_at is not null then 'phone'
                              when new.email_confirmed_at is not null then 'email' end),
      phone_verified = (new.phone is not null and new.phone_confirmed_at is not null)
  where id = new.id;
  return new;
end; $$;

drop trigger if exists on_auth_user_phone_updated    on auth.users;
drop trigger if exists on_auth_user_verified_updated on auth.users;
create trigger on_auth_user_verified_updated
  after update of email_confirmed_at, phone_confirmed_at, phone on auth.users
  for each row
  when (old.email_confirmed_at is distinct from new.email_confirmed_at
        or old.phone_confirmed_at is distinct from new.phone_confirmed_at
        or old.phone is distinct from new.phone)
  execute function public.sync_verified();

drop function if exists public.sync_phone_verified();

-- 4) existing users count as verified, so nobody gets prompted
update public.profiles p
set is_verified   = true,
    contact_email = coalesce(p.contact_email, u.email),
    verified_via  = coalesce(p.verified_via,
                      case when u.phone_confirmed_at is not null then 'phone' else 'email' end)
from auth.users u
where u.id = p.id
  and (u.email_confirmed_at is not null or u.phone_confirmed_at is not null);

-- 5) lock the functions down
revoke execute on function public.sync_verified()   from public, anon, authenticated;
revoke execute on function public.handle_new_user() from public, anon, authenticated;