do $$
begin
  if to_regclass('public.profiles') is null then
    raise exception 'public.profiles not found. Run your auth/profile migration first.';
  end if;
end $$;

alter table public.profiles add column if not exists owner_name text;
alter table public.profiles add column if not exists address    text;

-- ---------- helpers ----------
create or replace function public.touch_updated_at()
returns trigger language plpgsql as $$
begin new.updated_at := now(); return new; end $$;

create or replace function public.is_admin()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.profiles p
    where p.id = auth.uid() and p.role = 'admin' and not coalesce(p.is_suspended, false));
$$;

create or replace function public.is_active_seller()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.profiles p
    where p.id = auth.uid() and p.role = 'seller' and not coalesce(p.is_suspended, false));
$$;

create or replace function public.valid_hex_colors(c text[])
returns boolean language sql immutable as $$
  select c is not null
     and coalesce(array_length(c, 1), 0) between 1 and 12
     and not exists (select 1 from unnest(c) x where x !~ '^#[0-9A-F]{6}$');
$$;

-- ---------- categories ----------
create table if not exists public.categories (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  sort_order int not null default 0,
  created_at timestamptz not null default now()
);
insert into public.categories (name, sort_order) values
  ('Bags',1),('Shoes',2),('Apparel',3),('Accessories',4)
on conflict (name) do nothing;

alter table public.categories enable row level security;
drop policy if exists categories_read on public.categories;
create policy categories_read on public.categories for select to authenticated using (true);
drop policy if exists categories_admin_write on public.categories;
create policy categories_admin_write on public.categories for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

-- ---------- products ----------
create table if not exists public.products (
  id uuid primary key default gen_random_uuid(),
  seller_id uuid not null references auth.users(id) on delete cascade,
  category_id uuid not null references public.categories(id),
  title text not null check (char_length(btrim(title)) between 1 and 150),
  sku text not null check (char_length(sku) between 1 and 40),
  description text,
  price numeric(12,2) not null check (price >= 0),
  stock integer not null default 0 check (stock >= 0),
  low_threshold integer not null default 5 check (low_threshold >= 0),
  sizes text[] not null default array['Standard'],
  colors text[] not null default array['#1B1B1F'],
  -- change 'pending' to 'approved' if you want products live instantly
  moderation_status text not null default 'pending'
    check (moderation_status in ('pending','approved','rejected')),
  moderation_note text,
  deleted_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint products_colors_hex check (public.valid_hex_colors(colors)),
  constraint products_sizes_nonempty check (coalesce(array_length(sizes,1),0) between 1 and 20)
);
create unique index if not exists products_seller_sku_uniq
  on public.products (seller_id, sku) where deleted_at is null;
create index if not exists products_seller_idx on public.products (seller_id, created_at desc);
create index if not exists products_public_idx on public.products (category_id)
  where moderation_status = 'approved' and deleted_at is null;

-- SECURITY INVOKER on purpose: locks bind only direct API writes, not our RPCs.
create or replace function public.products_before_write()
returns trigger language plpgsql set search_path = public as $$
begin
  new.sku    := upper(btrim(new.sku));
  new.title  := btrim(new.title);
  new.colors := (select coalesce(array_agg(upper(c)), '{}') from unnest(new.colors) c);
  new.updated_at := now();
  if current_user = 'authenticated' and not public.is_admin() then
    if tg_op = 'INSERT' then
      new.seller_id := auth.uid();
      new.moderation_status := 'pending';
      new.moderation_note := null;
      new.deleted_at := null;
    else
      new.seller_id := old.seller_id;
      new.moderation_status := old.moderation_status;
      new.moderation_note := old.moderation_note;
      new.deleted_at := old.deleted_at;
    end if;
  end if;
  return new;
end $$;

drop trigger if exists trg_products_before_write on public.products;
create trigger trg_products_before_write before insert or update on public.products
  for each row execute function public.products_before_write();

alter table public.products enable row level security;
drop policy if exists products_select on public.products;
create policy products_select on public.products for select to authenticated
  using (seller_id = auth.uid() or public.is_admin()
         or (moderation_status = 'approved' and deleted_at is null));
drop policy if exists products_seller_insert on public.products;
create policy products_seller_insert on public.products for insert to authenticated
  with check (seller_id = auth.uid() and public.is_active_seller());
drop policy if exists products_seller_update on public.products;
create policy products_seller_update on public.products for update to authenticated
  using (seller_id = auth.uid() and public.is_active_seller() and deleted_at is null)
  with check (seller_id = auth.uid() and public.is_active_seller());
drop policy if exists products_admin_update on public.products;
create policy products_admin_update on public.products for update to authenticated
  using (public.is_admin()) with check (public.is_admin());

-- ---------- product images ----------
create table if not exists public.product_images (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.products(id) on delete cascade,
  url text not null,
  sort_order int not null default 0,
  created_at timestamptz not null default now()
);
create index if not exists product_images_product_idx on public.product_images (product_id, sort_order);
alter table public.product_images enable row level security;

drop policy if exists product_images_select on public.product_images;
create policy product_images_select on public.product_images for select to authenticated
  using (exists (select 1 from public.products p where p.id = product_id
    and (p.seller_id = auth.uid() or public.is_admin()
         or (p.moderation_status = 'approved' and p.deleted_at is null))));
drop policy if exists product_images_seller_write on public.product_images;
create policy product_images_seller_write on public.product_images for all to authenticated
  using (exists (select 1 from public.products p where p.id = product_id
         and p.seller_id = auth.uid() and public.is_active_seller()))
  with check (exists (select 1 from public.products p where p.id = product_id
         and p.seller_id = auth.uid() and public.is_active_seller()));

-- ---------- catalog RPCs ----------
create or replace function public.seller_adjust_stock(p_id uuid, p_delta integer)
returns integer language plpgsql security definer set search_path = public as $$
declare v_stock integer;
begin
  if not public.is_active_seller() then
    raise exception 'Your seller account is not allowed to do this.' using errcode = '42501';
  end if;
  if p_delta is null or p_delta = 0 or abs(p_delta) > 100000 then
    raise exception 'Invalid stock change.' using errcode = '22023';
  end if;
  update public.products set stock = stock + p_delta
   where id = p_id and seller_id = auth.uid() and deleted_at is null and stock + p_delta >= 0
  returning stock into v_stock;
  if not found then
    raise exception 'Stock cannot go below 0 (or the product no longer exists).' using errcode = 'P0001';
  end if;
  return v_stock;
end $$;

create or replace function public.seller_delete_product(p_id uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.is_active_seller() then
    raise exception 'Your seller account is not allowed to do this.' using errcode = '42501';
  end if;
  update public.products set deleted_at = now()
   where id = p_id and seller_id = auth.uid() and deleted_at is null;
  if not found then
    raise exception 'Product not found.' using errcode = 'P0001';
  end if;
end $$;

-- ---------- coupons ----------
create table if not exists public.coupons (
  id uuid primary key default gen_random_uuid(),
  seller_id uuid not null references auth.users(id) on delete cascade,
  code text not null check (code ~ '^[A-Z0-9_-]{3,30}$'),
  discount_type text not null check (discount_type in ('Percentage','Flat')),
  discount_value numeric(12,2) not null check (discount_value > 0),
  min_spend numeric(12,2) not null default 0 check (min_spend >= 0),
  is_active boolean not null default true,
  expires_at timestamptz not null default (now() + interval '30 days'),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint coupons_percent_max check (discount_type <> 'Percentage' or discount_value <= 100)
);
create unique index if not exists coupons_code_uniq on public.coupons (code);
create index if not exists coupons_seller_idx on public.coupons (seller_id, created_at desc);

create or replace function public.coupons_before_write()
returns trigger language plpgsql set search_path = public as $$
begin
  new.code := upper(btrim(new.code));
  new.updated_at := now();
  if current_user = 'authenticated' and not public.is_admin() then
    if tg_op = 'INSERT' then new.seller_id := auth.uid();
    else new.seller_id := old.seller_id; end if;
  end if;
  return new;
end $$;

drop trigger if exists trg_coupons_before_write on public.coupons;
create trigger trg_coupons_before_write before insert or update on public.coupons
  for each row execute function public.coupons_before_write();

alter table public.coupons enable row level security;
drop policy if exists coupons_seller_select on public.coupons;
create policy coupons_seller_select on public.coupons for select to authenticated
  using (seller_id = auth.uid() or public.is_admin());
drop policy if exists coupons_seller_insert on public.coupons;
create policy coupons_seller_insert on public.coupons for insert to authenticated
  with check (seller_id = auth.uid() and public.is_active_seller());
drop policy if exists coupons_seller_update on public.coupons;
create policy coupons_seller_update on public.coupons for update to authenticated
  using (seller_id = auth.uid() and public.is_active_seller())
  with check (seller_id = auth.uid() and public.is_active_seller());
drop policy if exists coupons_seller_delete on public.coupons;
create policy coupons_seller_delete on public.coupons for delete to authenticated
  using (seller_id = auth.uid() and public.is_active_seller());

create or replace function public.validate_coupon(p_code text, p_subtotal numeric)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare c public.coupons%rowtype; v_amount numeric;
begin
  if auth.uid() is null then
    raise exception 'Not signed in.' using errcode = '42501';
  end if;
  select * into c from public.coupons
   where code = upper(btrim(p_code)) and is_active and expires_at > now();
  if not found then
    return jsonb_build_object('valid', false, 'message', 'This coupon is invalid or has expired.');
  end if;
  if coalesce(p_subtotal, 0) < c.min_spend then
    return jsonb_build_object('valid', false,
      'message', 'Minimum spend for this coupon is Rs. ' || to_char(c.min_spend, 'FM999,999,999'));
  end if;
  v_amount := case c.discount_type
    when 'Percentage' then round(p_subtotal * c.discount_value / 100, 2)
    else least(c.discount_value, p_subtotal) end;
  return jsonb_build_object('valid', true, 'coupon_id', c.id, 'seller_id', c.seller_id,
    'discount_type', c.discount_type, 'discount_value', c.discount_value, 'discount', v_amount);
end $$;

-- ---------- orders ----------
create sequence if not exists public.order_number_seq start 10000;

create table if not exists public.orders (
  id uuid primary key default gen_random_uuid(),
  order_number text not null unique default ('LL-ORD-' || nextval('public.order_number_seq')::text),
  seller_id uuid not null references auth.users(id) on delete restrict,
  buyer_id uuid references auth.users(id) on delete set null,
  buyer_name text not null,   -- snapshot, sellers cannot read buyer profiles
  status text not null default 'Pending'
    check (status in ('Pending','Confirmed','Packed','Shipped','Delivered','Cancelled','In Review')),
  subtotal numeric(12,2) not null default 0 check (subtotal >= 0),
  discount numeric(12,2) not null default 0 check (discount >= 0),
  total numeric(12,2) not null check (total >= 0),
  coupon_id uuid references public.coupons(id) on delete set null,
  tracking_id text not null default '' check (char_length(tracking_id) <= 40),
  shipped_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists orders_seller_idx on public.orders (seller_id, created_at desc);
create index if not exists orders_seller_status_idx on public.orders (seller_id, status);
create index if not exists orders_buyer_idx on public.orders (buyer_id, created_at desc);

drop trigger if exists trg_orders_touch on public.orders;
create trigger trg_orders_touch before update on public.orders
  for each row execute function public.touch_updated_at();

create table if not exists public.order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  product_id uuid references public.products(id) on delete set null,
  title text not null,
  size text,
  color text,
  quantity integer not null check (quantity > 0),
  unit_price numeric(12,2) not null check (unit_price >= 0),
  created_at timestamptz not null default now()
);
create index if not exists order_items_order_idx on public.order_items (order_id, created_at, id);

alter table public.orders enable row level security;
alter table public.order_items enable row level security;

drop policy if exists orders_select on public.orders;
create policy orders_select on public.orders for select to authenticated
  using (seller_id = auth.uid() or buyer_id = auth.uid() or public.is_admin());
drop policy if exists order_items_select on public.order_items;
create policy order_items_select on public.order_items for select to authenticated
  using (exists (select 1 from public.orders o where o.id = order_id
    and (o.seller_id = auth.uid() or o.buyer_id = auth.uid() or public.is_admin())));

create or replace function public.seller_list_orders()
returns table (order_id text, buyer text, items text, total numeric,
               created_at timestamptz, status text, tracking_id text)
language sql stable security invoker set search_path = public as $$
  select o.order_number, o.buyer_name,
    coalesce((select string_agg(
        oi.title
        || case when coalesce(oi.size,'') not in ('','Standard','One Size')
                then ' (' || oi.size || ')' else '' end
        || ' × ' || oi.quantity::text, ', ' order by oi.created_at, oi.id)
      from public.order_items oi where oi.order_id = o.id), ''),
    o.total, o.created_at, o.status, o.tracking_id
  from public.orders o
  where o.seller_id = auth.uid() and o.status in ('Confirmed','Packed','Shipped')
  order by o.created_at desc;
$$;

create or replace function public.seller_advance_order(p_order_number text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare o public.orders%rowtype;
begin
  if not public.is_active_seller() then
    raise exception 'Your seller account is not allowed to do this.' using errcode = '42501';
  end if;
  select * into o from public.orders
   where order_number = p_order_number and seller_id = auth.uid() for update;
  if not found then raise exception 'Order not found.' using errcode = 'P0001'; end if;

  if o.status = 'Confirmed' then
    update public.orders set status = 'Packed' where id = o.id returning * into o;
  elsif o.status = 'Packed' then
    update public.orders set status = 'Shipped', shipped_at = now(),
      tracking_id = case when btrim(tracking_id) = ''
        then 'TRK-' || (floor(random() * 89999) + 10000)::int::text else tracking_id end
     where id = o.id returning * into o;
  else
    raise exception 'An order in status "%" cannot be advanced.', o.status using errcode = 'P0001';
  end if;
  return jsonb_build_object('status', o.status, 'tracking_id', o.tracking_id);
end $$;

create or replace function public.seller_set_tracking(p_order_number text, p_tracking text)
returns text language plpgsql security definer set search_path = public as $$
declare v_track text := btrim(coalesce(p_tracking, '')); v_saved text;
begin
  if not public.is_active_seller() then
    raise exception 'Your seller account is not allowed to do this.' using errcode = '42501';
  end if;
  if char_length(v_track) > 40 then
    raise exception 'Tracking ID is too long (max 40 characters).' using errcode = '22001';
  end if;
  update public.orders set tracking_id = v_track
   where order_number = p_order_number and seller_id = auth.uid()
     and status in ('Confirmed','Packed','Shipped')
  returning tracking_id into v_saved;
  if not found then raise exception 'Order not found.' using errcode = 'P0001'; end if;
  return v_saved;
end $$;

-- ---------- overview ----------
create or replace function public.seller_overview_metrics(p_period text default 'week')
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare
  v_seller uuid := auth.uid();
  v_tz constant text := 'Asia/Karachi';
  v_counted constant text[] := array['Confirmed','Packed','Shipped','Delivered'];
  v_today date := (now() at time zone 'Asia/Karachi')::date;
  v_days int; v_start date; v_prev_start date;
  v_rev numeric; v_cnt int; v_prev_rev numeric; v_change numeric; v_series jsonb;
begin
  if not public.is_active_seller() then
    raise exception 'Your seller account is not allowed to do this.' using errcode = '42501';
  end if;
  if p_period not in ('week','month') then
    raise exception 'period must be week or month.' using errcode = '22023';
  end if;

  v_days := case when p_period = 'week' then 7 else 28 end;
  v_start := v_today - (v_days - 1);
  v_prev_start := v_start - v_days;

  select coalesce(sum(total),0), count(*) into v_rev, v_cnt from public.orders
   where seller_id = v_seller and status = any (v_counted)
     and (created_at at time zone v_tz)::date between v_start and v_today;

  select coalesce(sum(total),0) into v_prev_rev from public.orders
   where seller_id = v_seller and status = any (v_counted)
     and (created_at at time zone v_tz)::date between v_prev_start and v_start - 1;

  v_change := case when v_prev_rev > 0
                   then round((v_rev - v_prev_rev) / v_prev_rev * 100, 1) else null end;

  if p_period = 'week' then
    select jsonb_agg(jsonb_build_object('label', to_char(d.day,'Dy'),
             'amount', coalesce(s.rev,0), 'value', round(coalesce(s.rev,0)/1000.0,1)) order by d.day)
      into v_series
      from (select generate_series(v_start, v_today, interval '1 day')::date as day) d
      left join (select (created_at at time zone v_tz)::date as day, sum(total) as rev
                   from public.orders
                  where seller_id = v_seller and status = any (v_counted)
                    and (created_at at time zone v_tz)::date between v_start and v_today
                  group by 1) s on s.day = d.day;
  else
    select jsonb_agg(jsonb_build_object('label', 'Wk ' || b.n,
             'amount', coalesce(s.rev,0), 'value', round(coalesce(s.rev,0)/1000.0,1)) order by b.n)
      into v_series
      from generate_series(1,4) as b(n)
      left join (select ((created_at at time zone v_tz)::date - v_start) / 7 + 1 as n, sum(total) as rev
                   from public.orders
                  where seller_id = v_seller and status = any (v_counted)
                    and (created_at at time zone v_tz)::date between v_start and v_today
                  group by 1) s on s.n = b.n;
  end if;

  return jsonb_build_object(
    'period', p_period, 'revenue', v_rev, 'change_pct', v_change, 'orders', v_cnt,
    'avg_ticket', case when v_cnt > 0 then round(v_rev / v_cnt) else 0 end,
    'products', (select count(*) from public.products where seller_id = v_seller and deleted_at is null),
    'series', coalesce(v_series, '[]'::jsonb),
    'pipeline', jsonb_build_object(
      'unconfirmed', (select count(*) from public.orders where seller_id = v_seller and status = 'Pending'),
      'shipping',    (select count(*) from public.orders where seller_id = v_seller and status in ('Confirmed','Packed','Shipped')),
      'in_review',   (select count(*) from public.orders where seller_id = v_seller and status = 'In Review')),
    'pending_dispatch', (select count(*) from public.orders where seller_id = v_seller and status in ('Confirmed','Packed'))
  );
end $$;

-- ---------- permissions ----------
revoke all on public.categories, public.products, public.product_images,
              public.coupons, public.orders, public.order_items from anon;
revoke all on public.categories, public.products, public.product_images,
              public.coupons, public.orders, public.order_items from authenticated;
grant select, insert, update, delete on public.categories     to authenticated;
grant select, insert, update         on public.products       to authenticated;
grant select, insert, update, delete on public.product_images to authenticated;
grant select, insert, update, delete on public.coupons        to authenticated;
grant select                         on public.orders         to authenticated;
grant select                         on public.order_items    to authenticated;

revoke all on function
  public.seller_adjust_stock(uuid, integer), public.seller_delete_product(uuid),
  public.seller_list_orders(), public.seller_advance_order(text),
  public.seller_set_tracking(text, text), public.seller_overview_metrics(text),
  public.validate_coupon(text, numeric)
from public, anon;
grant execute on function
  public.seller_adjust_stock(uuid, integer), public.seller_delete_product(uuid),
  public.seller_list_orders(), public.seller_advance_order(text),
  public.seller_set_tracking(text, text), public.seller_overview_metrics(text),
  public.validate_coupon(text, numeric)
to authenticated;