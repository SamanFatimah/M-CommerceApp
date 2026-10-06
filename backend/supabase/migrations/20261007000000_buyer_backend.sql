-- ============================================================
-- Buyer backend
--   * restores is_admin() aal2 requirement (see section 0)
--   * catalog: search / filter / sort / pagination, brands, wishlist
--   * checkout: server-side pricing, coupons, stock reservation,
--     one order per seller, unpaid -> pay / cancel / expire
--   * buyer orders, delivery confirmation, verified reviews
--   * seller_list_orders now returns the shipping address + payment info
--   * storage bucket for product images
-- ============================================================

do $$
begin
  if to_regclass('public.orders') is null or to_regclass('public.products') is null then
    raise exception 'Run the seller migration first (orders/products not found).';
  end if;
end $$;

-- ---------- 0. regression fix ----------
-- The seller migration redefined is_admin() WITHOUT the aal2 (2FA) check that
-- 002_auth_hardening added. Put it back.
create or replace function public.is_admin()
returns boolean language sql security definer set search_path = public stable as $$
  select coalesce((select auth.jwt() ->> 'aal'), '') = 'aal2'
     and exists (select 1 from public.profiles
                 where id = auth.uid() and role = 'admin' and is_suspended = false);
$$;

create or replace function public.is_active_buyer()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.profiles p
    where p.id = auth.uid() and p.role = 'buyer' and not coalesce(p.is_suspended, false));
$$;

-- ---------- 1. settings (server-only) ----------
create table if not exists public.app_settings (
  key text primary key,
  value text not null
);
alter table public.app_settings enable row level security;   -- no policies: server only
-- While true, the client may mark Card/JazzCash orders as paid (no real gateway yet).
-- Set to 'false' before going live; only COD will work until a payment webhook exists.
insert into public.app_settings (key, value) values ('sandbox_payments', 'true')
on conflict (key) do nothing;

create or replace function public._sandbox_payments()
returns boolean language sql stable security definer set search_path = public as $$
  select coalesce((select value from public.app_settings where key = 'sandbox_payments'), 'false') = 'true';
$$;

-- ---------- 2. products: public stats ----------
alter table public.products
  add column if not exists original_price numeric(12,2) check (original_price is null or original_price > 0),
  add column if not exists rating_avg   numeric(3,2) not null default 0,
  add column if not exists review_count integer      not null default 0,
  add column if not exists sold_count   integer      not null default 0;

-- Sellers must not be able to fake ratings / sales through the API.
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
      new.rating_avg := 0; new.review_count := 0; new.sold_count := 0;
    else
      new.seller_id := old.seller_id;
      new.moderation_status := old.moderation_status;
      new.moderation_note := old.moderation_note;
      new.deleted_at := old.deleted_at;
      new.rating_avg := old.rating_avg;
      new.review_count := old.review_count;
      new.sold_count := old.sold_count;
    end if;
  end if;
  return new;
end $$;

create extension if not exists pg_trgm with schema extensions;
create index if not exists products_title_trgm on public.products
  using gin (title extensions.gin_trgm_ops) where moderation_status = 'approved' and deleted_at is null;
create index if not exists products_popularity_idx on public.products (sold_count desc)
  where moderation_status = 'approved' and deleted_at is null;

-- ---------- 3. orders: checkout columns ----------
alter table public.orders drop constraint if exists orders_status_check;
alter table public.orders add constraint orders_status_check check (status in
  ('Unpaid','Pending','Confirmed','Packed','Shipped','Delivered','Cancelled','In Review'));

alter table public.orders
  add column if not exists checkout_id     uuid,
  add column if not exists shipping_fee    numeric(12,2) not null default 0 check (shipping_fee >= 0),
  add column if not exists tax             numeric(12,2) not null default 0 check (tax >= 0),
  add column if not exists delivery_method text not null default 'Standard'
        check (delivery_method in ('Standard','Express')),
  add column if not exists payment_method  text check (payment_method in ('Card','JazzCash','COD')),
  add column if not exists payment_status  text not null default 'unpaid'
        check (payment_status in ('unpaid','paid','cod','refund_due')),
  add column if not exists ship_name    text,
  add column if not exists ship_phone   text,
  add column if not exists ship_address text,
  add column if not exists ship_city    text,
  add column if not exists paid_at      timestamptz,
  add column if not exists delivered_at timestamptz,
  add column if not exists cancelled_at timestamptz;

create index if not exists orders_unpaid_idx on public.orders (created_at) where status = 'Unpaid';
create index if not exists orders_checkout_idx on public.orders (checkout_id);
create index if not exists order_items_product_idx on public.order_items (product_id);

-- ---------- 4. wishlist ----------
create table if not exists public.wishlist (
  user_id    uuid not null references auth.users(id) on delete cascade,
  product_id uuid not null references public.products(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, product_id)
);
alter table public.wishlist enable row level security;
drop policy if exists wishlist_own_select on public.wishlist;
create policy wishlist_own_select on public.wishlist for select to authenticated
  using (user_id = auth.uid());

-- ---------- 5. reviews ----------
create table if not exists public.product_reviews (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.products(id) on delete cascade,
  buyer_id   uuid not null references auth.users(id) on delete cascade,
  reviewer_name text not null,
  rating  integer not null check (rating between 1 and 5),
  comment text check (comment is null or char_length(comment) <= 1000),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (product_id, buyer_id)
);
create index if not exists product_reviews_product_idx on public.product_reviews (product_id, created_at desc);
alter table public.product_reviews enable row level security;
drop policy if exists product_reviews_select on public.product_reviews;
create policy product_reviews_select on public.product_reviews for select to authenticated
  using (buyer_id = auth.uid() or public.is_admin()
         or exists (select 1 from public.products p where p.id = product_id
                    and p.moderation_status = 'approved' and p.deleted_at is null));

-- ---------- 6. internal helpers ----------
create or replace function public._parse_cart_lines(p_items jsonb)
returns table (pid uuid, size text, color text, qty integer)
language sql immutable set search_path = public as $$
  select (x->>'product_id')::uuid,
         nullif(btrim(x->>'size'), ''),
         upper(nullif(btrim(x->>'color'), '')),
         (x->>'qty')::integer
  from jsonb_array_elements(p_items) x;
$$;

create or replace function public._recompute_rating(p_product uuid)
returns void language sql security definer set search_path = public as $$
  update public.products set
    rating_avg   = coalesce((select round(avg(rating)::numeric, 2) from public.product_reviews where product_id = p_product), 0),
    review_count = (select count(*) from public.product_reviews where product_id = p_product)
  where id = p_product;
$$;

-- Adds (sign = 1) or removes (sign = -1) an order's quantities from sold_count.
create or replace function public._apply_sold(p_order uuid, p_sign integer)
returns void language sql security definer set search_path = public as $$
  update public.products p
     set sold_count = greatest(p.sold_count + p_sign * t.q, 0)
    from (select product_id, sum(quantity)::int as q from public.order_items
           where order_id = p_order and product_id is not null group by product_id) t
   where p.id = t.product_id;
$$;

-- Cancels an order and gives the stock back. Caller has already checked ownership/status.
create or replace function public._cancel_order(p_order uuid)
returns void language plpgsql security definer set search_path = public as $$
declare o public.orders%rowtype;
begin
  select * into o from public.orders where id = p_order for update;
  if not found or o.status not in ('Unpaid','Pending','Confirmed') then return; end if;

  update public.products p
     set stock = p.stock + t.q
    from (select product_id, sum(quantity)::int as q from public.order_items
           where order_id = p_order and product_id is not null group by product_id) t
   where p.id = t.product_id;

  if o.status = 'Confirmed' then perform public._apply_sold(p_order, -1); end if;

  update public.orders
     set status = 'Cancelled', cancelled_at = now(),
         payment_status = case when payment_status = 'paid' then 'refund_due' else payment_status end
   where id = p_order;
end $$;

create or replace function public._expire_unpaid_orders()
returns integer language plpgsql security definer set search_path = public as $$
declare r record; n integer := 0;
begin
  for r in select id from public.orders
            where status = 'Unpaid' and created_at < now() - interval '24 hours'
            order by id for update skip locked
  loop
    perform public._cancel_order(r.id); n := n + 1;
  end loop;
  return n;
end $$;

-- Prices a cart on the server. Used by both the quote and the real order.
-- p_items: [{product_id, size, color(hex), qty}]
create or replace function public._checkout_compute(
  p_items jsonb, p_delivery text, p_coupon text, p_lock boolean)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_ship   numeric;
  v_bad    record;
  v_code   text := upper(btrim(coalesce(p_coupon, '')));
  v_c      public.coupons%rowtype;
  v_sub    numeric;
  v_result jsonb;
begin
  v_ship := case p_delivery when 'Standard' then 250 when 'Express' then 600 end;
  if v_ship is null then
    raise exception 'Choose Standard or Express delivery.' using errcode = '22023';
  end if;

  if p_items is null or jsonb_typeof(p_items) <> 'array'
     or jsonb_array_length(p_items) not between 1 and 50 then
    raise exception 'Your cart is empty or too large.' using errcode = '22023';
  end if;

  begin
    perform 1 from public._parse_cart_lines(p_items);
  exception when others then
    raise exception 'Your cart has an invalid item.' using errcode = '22023';
  end;

  if exists (select 1 from public._parse_cart_lines(p_items)
              where pid is null or qty is null or qty < 1 or qty > 50) then
    raise exception 'Item quantities must be between 1 and 50.' using errcode = '22023';
  end if;

  -- lock products in id order (stops two checkouts overselling the last item)
  if p_lock then
    perform 1 from public.products
     where id in (select pid from public._parse_cart_lines(p_items))
     order by id for update;
  end if;

  if exists (
    select 1 from public._parse_cart_lines(p_items) l
      left join public.products p on p.id = l.pid
           and p.moderation_status = 'approved' and p.deleted_at is null
      left join public.profiles s on s.id = p.seller_id
     where p.id is null or s.id is null or s.is_suspended) then
    raise exception 'An item in your cart is no longer available. Please remove it and try again.'
      using errcode = 'P0001';
  end if;

  select p.title into v_bad
    from public._parse_cart_lines(p_items) l join public.products p on p.id = l.pid
   where (l.size  is null and array_length(p.sizes, 1)  > 1)
      or (l.color is null and array_length(p.colors, 1) > 1)
   limit 1;
  if found then
    raise exception 'Please choose a size and color for "%".', v_bad.title using errcode = 'P0001';
  end if;

  select p.title into v_bad
    from public._parse_cart_lines(p_items) l join public.products p on p.id = l.pid
   where (l.size  is not null and not (l.size  = any (p.sizes)))
      or (l.color is not null and not (l.color = any (p.colors)))
   limit 1;
  if found then
    raise exception 'The selected size or color for "%" is no longer available.', v_bad.title
      using errcode = 'P0001';
  end if;

  select p.title, p.stock into v_bad
    from (select pid, sum(qty) as q from public._parse_cart_lines(p_items) group by pid) t
    join public.products p on p.id = t.pid
   where t.q > p.stock
   limit 1;
  if found then
    if v_bad.stock <= 0 then
      raise exception '"%" is out of stock.', v_bad.title using errcode = 'P0001';
    end if;
    raise exception 'Only % left of "%".', v_bad.stock, v_bad.title using errcode = 'P0001';
  end if;

  if v_code <> '' then
    select * into v_c from public.coupons
     where code = v_code and is_active and expires_at > now();
    if not found then
      raise exception 'This coupon is invalid or has expired.' using errcode = 'P0001';
    end if;
    select coalesce(sum(p.price * l.qty), 0) into v_sub
      from public._parse_cart_lines(p_items) l join public.products p on p.id = l.pid
     where p.seller_id = v_c.seller_id;
    if v_sub = 0 then
      raise exception 'This coupon only applies to products from the store that issued it.'
        using errcode = 'P0001';
    end if;
    if v_sub < v_c.min_spend then
      raise exception 'Minimum spend for this coupon is Rs. % (on that store''s items).',
        to_char(v_c.min_spend, 'FM999,999,999') using errcode = 'P0001';
    end if;
  end if;

  with eff as (
    select l.pid,
           coalesce(l.size,  p.sizes[1])  as size,
           coalesce(l.color, p.colors[1]) as color,
           l.qty, p.seller_id, p.title, p.price
      from public._parse_cart_lines(p_items) l join public.products p on p.id = l.pid
  ), per as (
    select seller_id,
           sum(price * qty)::numeric(12,2) as subtotal,
           jsonb_agg(jsonb_build_object('product_id', pid, 'title', title, 'size', size,
                     'color', color, 'qty', qty, 'unit_price', price) order by title, size) as items
      from eff group by seller_id
  ), calc as (
    select per.seller_id, per.subtotal, per.items,
           coalesce(nullif(btrim(s.store_name), ''), 'LoopLab Seller') as store,
           v_ship as shipping,
           round(per.subtotal * 0.05, 2) as tax,
           case when v_c.id is not null and v_c.seller_id = per.seller_id then
                  case v_c.discount_type
                    when 'Percentage' then round(per.subtotal * v_c.discount_value / 100, 2)
                    else least(v_c.discount_value, per.subtotal) end
                else 0 end as discount
      from per join public.profiles s on s.id = per.seller_id
  )
  select jsonb_build_object(
           'sellers', jsonb_agg(jsonb_build_object(
               'seller_id', seller_id, 'store', store, 'subtotal', subtotal,
               'shipping', shipping, 'tax', tax, 'discount', discount,
               'total', greatest(subtotal + shipping + tax - discount, 0),
               'items', items) order by store),
           'subtotal', sum(subtotal), 'shipping', sum(shipping), 'tax', sum(tax),
           'discount', sum(discount),
           'grand_total', sum(greatest(subtotal + shipping + tax - discount, 0)),
           'coupon_id', v_c.id, 'coupon_code', v_c.code)
    into v_result from calc;

  return v_result;
end $$;

-- ---------- 7. catalog ----------
create or replace function public.buyer_list_products(
  p_category      text    default null,
  p_search        text    default null,
  p_min_price     numeric default null,
  p_max_price     numeric default null,
  p_brand         text    default null,
  p_min_rating    numeric default 0,
  p_sort          text    default 'Popularity',
  p_limit         integer default 20,
  p_offset        integer default 0,
  p_wishlist_only boolean default false,
  p_ids           uuid[]  default null)
returns table (
  id uuid, title text, description text, price numeric, original_price numeric,
  discount_pct integer, category text, brand text, seller_id uuid,
  sizes text[], colors text[], image_urls text[], stock integer,
  rating numeric, reviews_count integer, sold_count integer,
  in_wishlist boolean, created_at timestamptz)
language sql stable security definer set search_path = public as $$
  select pr.id, pr.title, pr.description, pr.price, pr.original_price,
         case when pr.original_price is not null and pr.original_price > pr.price
              then round((pr.original_price - pr.price) / pr.original_price * 100)::int else 0 end,
         c.name,
         coalesce(nullif(btrim(s.store_name), ''), 'LoopLab Seller'),
         pr.seller_id, pr.sizes, pr.colors,
         coalesce((select array_agg(i.url order by i.sort_order, i.created_at)
                     from public.product_images i where i.product_id = pr.id), '{}'),
         pr.stock, pr.rating_avg, pr.review_count, pr.sold_count,
         exists (select 1 from public.wishlist w where w.user_id = auth.uid() and w.product_id = pr.id),
         pr.created_at
    from public.products pr
    join public.categories c on c.id = pr.category_id
    join public.profiles   s on s.id = pr.seller_id
   where auth.uid() is not null
     and pr.moderation_status = 'approved' and pr.deleted_at is null
     and not coalesce(s.is_suspended, false)
     and (p_ids is null or pr.id = any (p_ids))
     and (p_category is null or c.name = p_category)
     and (p_min_price is null or pr.price >= p_min_price)
     and (p_max_price is null or pr.price <= p_max_price)
     and (p_brand is null or p_brand = 'All'
          or coalesce(nullif(btrim(s.store_name), ''), 'LoopLab Seller') = p_brand)
     and pr.rating_avg >= coalesce(p_min_rating, 0)
     and (not coalesce(p_wishlist_only, false)
          or exists (select 1 from public.wishlist w where w.user_id = auth.uid() and w.product_id = pr.id))
     and (p_search is null or btrim(p_search) = ''
          or pr.title ilike '%' || replace(replace(replace(btrim(p_search), '\', '\\'), '%', '\%'), '_', '\_') || '%'
          or coalesce(pr.description, '') ilike '%' || replace(replace(replace(btrim(p_search), '\', '\\'), '%', '\%'), '_', '\_') || '%'
          or coalesce(s.store_name, '') ilike '%' || replace(replace(replace(btrim(p_search), '\', '\\'), '%', '\%'), '_', '\_') || '%')
   order by
     case when p_sort = 'Price: Low to High'  then pr.price end asc,
     case when p_sort = 'Price: High to Low'  then pr.price end desc,
     case when p_sort = 'Customer Rating'     then pr.rating_avg end desc,
     case when p_sort = 'Customer Rating'     then pr.review_count end desc,
     case when p_sort = 'Popularity'          then pr.sold_count end desc,
     case when p_sort = 'Popularity'          then pr.review_count end desc,
     pr.created_at desc, pr.id
   limit least(greatest(coalesce(p_limit, 20), 1), 50)
  offset greatest(coalesce(p_offset, 0), 0);
$$;

create or replace function public.buyer_list_brands()
returns table (brand text, product_count integer)
language sql stable security definer set search_path = public as $$
  select coalesce(nullif(btrim(s.store_name), ''), 'LoopLab Seller') as brand, count(*)::int
    from public.products pr join public.profiles s on s.id = pr.seller_id
   where auth.uid() is not null
     and pr.moderation_status = 'approved' and pr.deleted_at is null
     and not coalesce(s.is_suspended, false)
   group by 1 order by 2 desc, 1;
$$;

create or replace function public.buyer_toggle_wishlist(p_product uuid)
returns boolean language plpgsql security definer set search_path = public as $$
begin
  if not public.is_active_buyer() then
    raise exception 'Only buyer accounts can use the wishlist.' using errcode = '42501';
  end if;
  if exists (select 1 from public.wishlist where user_id = auth.uid() and product_id = p_product) then
    delete from public.wishlist where user_id = auth.uid() and product_id = p_product;
    return false;
  end if;
  if not exists (select 1 from public.products
                  where id = p_product and moderation_status = 'approved' and deleted_at is null) then
    raise exception 'That product is no longer available.' using errcode = 'P0001';
  end if;
  insert into public.wishlist (user_id, product_id) values (auth.uid(), p_product)
  on conflict do nothing;
  return true;
end $$;

-- ---------- 8. checkout ----------
create or replace function public.buyer_quote_checkout(
  p_items jsonb, p_delivery text default 'Standard', p_coupon text default null)
returns jsonb language plpgsql security definer set search_path = public as $$
begin
  if not public.is_active_buyer() then
    raise exception 'Only buyer accounts can check out.' using errcode = '42501';
  end if;
  return public._checkout_compute(p_items, p_delivery, p_coupon, false);
end $$;

create or replace function public.buyer_place_order(
  p_items jsonb, p_delivery text, p_payment text, p_coupon text,
  p_name text, p_phone text, p_address text, p_city text,
  p_pay_now boolean default true)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_calc jsonb; v_checkout uuid := gen_random_uuid();
  v_name text := btrim(coalesce(p_name, '')); v_phone text := btrim(coalesce(p_phone, ''));
  v_addr text := btrim(coalesce(p_address, '')); v_city text := btrim(coalesce(p_city, ''));
  v_confirmed boolean; v_pstatus text;
  s jsonb; i jsonb; v_oid uuid; v_onum text; v_orders jsonb := '[]'::jsonb;
begin
  if not public.is_active_buyer() then
    raise exception 'Only buyer accounts can place orders.' using errcode = '42501';
  end if;
  if p_payment is null or p_payment not in ('Card','JazzCash','COD') then
    raise exception 'Choose a payment method.' using errcode = '22023';
  end if;
  if v_name = '' or v_addr = '' or v_city = '' or char_length(v_name) > 100
     or char_length(v_addr) > 300 or char_length(v_city) > 80 then
    raise exception 'Please enter your name, address and city.' using errcode = '22023';
  end if;
  if v_phone !~ '^\+?[0-9 ()-]{7,20}$' then
    raise exception 'Please enter a valid phone number.' using errcode = '22023';
  end if;

  -- COD is confirmed immediately. Card/JazzCash are confirmed only when paid.
  v_confirmed := (p_payment = 'COD') or coalesce(p_pay_now, true);
  if v_confirmed and p_payment <> 'COD' and not public._sandbox_payments() then
    raise exception 'Online payments are not enabled yet. Please choose Cash on Delivery.'
      using errcode = 'P0001';
  end if;
  v_pstatus := case when p_payment = 'COD' then 'cod' when v_confirmed then 'paid' else 'unpaid' end;

  perform public._expire_unpaid_orders();
  if (select count(*) from public.orders where buyer_id = auth.uid() and status = 'Unpaid') >= 10
     and not v_confirmed then
    raise exception 'You have too many unpaid orders. Pay or cancel some first.' using errcode = 'P0001';
  end if;

  v_calc := public._checkout_compute(p_items, p_delivery, p_coupon, true);

  for s in select * from jsonb_array_elements(v_calc->'sellers') loop
    insert into public.orders
      (seller_id, buyer_id, buyer_name, status, subtotal, discount, total, coupon_id,
       checkout_id, shipping_fee, tax, delivery_method, payment_method, payment_status,
       ship_name, ship_phone, ship_address, ship_city, paid_at)
    values
      ((s->>'seller_id')::uuid, auth.uid(), v_name,
       case when v_confirmed then 'Confirmed' else 'Unpaid' end,
       (s->>'subtotal')::numeric, (s->>'discount')::numeric, (s->>'total')::numeric,
       case when (s->>'discount')::numeric > 0 then (v_calc->>'coupon_id')::uuid end,
       v_checkout, (s->>'shipping')::numeric, (s->>'tax')::numeric, p_delivery, p_payment, v_pstatus,
       v_name, v_phone, v_addr, v_city,
       case when v_pstatus = 'paid' then now() end)
    returning id, order_number into v_oid, v_onum;

    for i in select * from jsonb_array_elements(s->'items') loop
      insert into public.order_items (order_id, product_id, title, size, color, quantity, unit_price)
      values (v_oid, (i->>'product_id')::uuid, i->>'title', i->>'size', i->>'color',
              (i->>'qty')::int, (i->>'unit_price')::numeric);
      update public.products set stock = stock - (i->>'qty')::int
       where id = (i->>'product_id')::uuid;
    end loop;

    if v_confirmed then perform public._apply_sold(v_oid, 1); end if;

    v_orders := v_orders || jsonb_build_object(
      'order_number', v_onum, 'store', s->>'store',
      'total', (s->>'total')::numeric, 'status', case when v_confirmed then 'Confirmed' else 'Unpaid' end);
  end loop;

  return jsonb_build_object('checkout_id', v_checkout, 'orders', v_orders,
    'grand_total', (v_calc->>'grand_total')::numeric, 'payment_status', v_pstatus);
end $$;

-- SANDBOX payment: the client says "I paid". Gated by app_settings.sandbox_payments.
-- Replace with a webhook-driven update when a real gateway is added.
create or replace function public.buyer_pay_order(p_order_number text, p_method text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare o public.orders%rowtype;
begin
  if not public.is_active_buyer() then
    raise exception 'Only buyer accounts can pay for orders.' using errcode = '42501';
  end if;
  if p_method is null or p_method not in ('Card','JazzCash','COD') then
    raise exception 'Choose a payment method.' using errcode = '22023';
  end if;
  if p_method <> 'COD' and not public._sandbox_payments() then
    raise exception 'Online payments are not enabled yet. Please choose Cash on Delivery.'
      using errcode = 'P0001';
  end if;

  select * into o from public.orders
   where order_number = p_order_number and buyer_id = auth.uid() and status = 'Unpaid' for update;
  if not found then
    raise exception 'This order is not waiting for payment (it may have expired).' using errcode = 'P0001';
  end if;

  update public.orders
     set status = 'Confirmed', payment_method = p_method,
         payment_status = case when p_method = 'COD' then 'cod' else 'paid' end,
         paid_at = case when p_method = 'COD' then null else now() end
   where id = o.id;
  perform public._apply_sold(o.id, 1);
  return jsonb_build_object('order_number', o.order_number, 'status', 'Confirmed');
end $$;

create or replace function public.buyer_cancel_order(p_order_number text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare o public.orders%rowtype;
begin
  if not public.is_active_buyer() then
    raise exception 'Only buyer accounts can cancel orders.' using errcode = '42501';
  end if;
  select * into o from public.orders
   where order_number = p_order_number and buyer_id = auth.uid() for update;
  if not found then raise exception 'Order not found.' using errcode = 'P0001'; end if;
  if o.status not in ('Unpaid','Pending','Confirmed') then
    raise exception 'An order that is "%" can no longer be cancelled.', o.status using errcode = 'P0001';
  end if;
  perform public._cancel_order(o.id);
  return jsonb_build_object('order_number', o.order_number, 'status', 'Cancelled');
end $$;

create or replace function public.buyer_confirm_delivery(p_order_number text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare o public.orders%rowtype;
begin
  if not public.is_active_buyer() then
    raise exception 'Only buyer accounts can do this.' using errcode = '42501';
  end if;
  select * into o from public.orders
   where order_number = p_order_number and buyer_id = auth.uid() for update;
  if not found then raise exception 'Order not found.' using errcode = 'P0001'; end if;
  if o.status <> 'Shipped' then
    raise exception 'Only shipped orders can be marked as received.' using errcode = 'P0001';
  end if;
  update public.orders
     set status = 'Delivered', delivered_at = now(),
         payment_status = case when payment_status = 'cod' then 'paid' else payment_status end,
         paid_at = coalesce(paid_at, case when payment_status = 'cod' then now() end)
   where id = o.id;
  return jsonb_build_object('order_number', o.order_number, 'status', 'Delivered');
end $$;

create or replace function public.buyer_list_orders(p_bucket text default null)
returns table (
  order_number text, status text, bucket text, store text,
  subtotal numeric, discount numeric, shipping_fee numeric, tax numeric, total numeric,
  payment_method text, payment_status text, delivery_method text, tracking_id text,
  ship_name text, ship_phone text, ship_address text, ship_city text,
  created_at timestamptz, items jsonb)
language sql stable security definer set search_path = public as $$
  select * from (
    select o.order_number, o.status,
           case when o.status = 'Unpaid' then 'unpaid'
                when o.status in ('Pending','Confirmed','Packed','In Review') then 'processing'
                when o.status = 'Shipped' then 'shipped'
                when o.status = 'Delivered' then 'delivered'
                else 'cancelled' end as bucket,
           coalesce(nullif(btrim(s.store_name), ''), 'LoopLab Seller') as store,
           o.subtotal, o.discount, o.shipping_fee, o.tax, o.total,
           o.payment_method, o.payment_status, o.delivery_method, o.tracking_id,
           o.ship_name, o.ship_phone, o.ship_address, o.ship_city, o.created_at,
           coalesce((select jsonb_agg(jsonb_build_object(
                'product_id', oi.product_id, 'title', oi.title, 'size', oi.size, 'color', oi.color,
                'quantity', oi.quantity, 'unit_price', oi.unit_price) order by oi.created_at, oi.id)
              from public.order_items oi where oi.order_id = o.id), '[]'::jsonb) as items
      from public.orders o left join public.profiles s on s.id = o.seller_id
     where o.buyer_id = auth.uid()
  ) x
  where p_bucket is null or x.bucket = p_bucket
  order by x.created_at desc
  limit 100;
$$;

-- ---------- 9. reviews ----------
create or replace function public.buyer_add_review(p_product uuid, p_rating integer, p_comment text default null)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_full text; v_name text; v_parts text[]; v_comment text := nullif(btrim(coalesce(p_comment, '')), '');
begin
  if not public.is_active_buyer() then
    raise exception 'Only buyer accounts can write reviews.' using errcode = '42501';
  end if;
  if p_rating is null or p_rating not between 1 and 5 then
    raise exception 'Rating must be between 1 and 5.' using errcode = '22023';
  end if;
  if v_comment is not null and char_length(v_comment) > 1000 then
    raise exception 'Review is too long (max 1000 characters).' using errcode = '22001';
  end if;
  if not exists (select 1 from public.order_items oi join public.orders o on o.id = oi.order_id
                  where oi.product_id = p_product and o.buyer_id = auth.uid() and o.status = 'Delivered') then
    raise exception 'You can review a product after it has been delivered to you.' using errcode = 'P0001';
  end if;

  select full_name into v_full from public.profiles where id = auth.uid();
  v_parts := regexp_split_to_array(btrim(coalesce(v_full, '')), '\s+');
  v_name := case
    when coalesce(v_full, '') = '' then 'Verified buyer'
    when array_length(v_parts, 1) = 1 then v_parts[1]
    else v_parts[1] || ' ' || upper(left(v_parts[array_length(v_parts, 1)], 1)) || '.' end;

  insert into public.product_reviews (product_id, buyer_id, reviewer_name, rating, comment)
  values (p_product, auth.uid(), v_name, p_rating, v_comment)
  on conflict (product_id, buyer_id)
  do update set rating = excluded.rating, comment = excluded.comment, updated_at = now();

  perform public._recompute_rating(p_product);
  return (select jsonb_build_object('rating', rating_avg, 'reviews_count', review_count)
            from public.products where id = p_product);
end $$;

-- ---------- 10. seller_list_orders: add what the seller needs to ship ----------
drop function if exists public.seller_list_orders();
create function public.seller_list_orders()
returns table (order_id text, buyer text, items text, total numeric,
               created_at timestamptz, status text, tracking_id text,
               ship_phone text, ship_address text, ship_city text,
               payment_method text, payment_status text)
language sql stable security invoker set search_path = public as $$
  select o.order_number, o.buyer_name,
    coalesce((select string_agg(
        oi.title
        || case when coalesce(oi.size,'') not in ('','Standard','One Size')
                then ' (' || oi.size || ')' else '' end
        || ' × ' || oi.quantity::text, ', ' order by oi.created_at, oi.id)
      from public.order_items oi where oi.order_id = o.id), ''),
    o.total, o.created_at, o.status, o.tracking_id,
    o.ship_phone, o.ship_address, o.ship_city, o.payment_method, o.payment_status
  from public.orders o
  where o.seller_id = auth.uid() and o.status in ('Confirmed','Packed','Shipped')
  order by o.created_at desc;
$$;

-- ---------- 11. product image storage ----------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('product-images', 'product-images', true, 5242880,
        array['image/jpeg','image/png','image/webp'])
on conflict (id) do nothing;

drop policy if exists product_images_public_read on storage.objects;
create policy product_images_public_read on storage.objects for select
  using (bucket_id = 'product-images');

-- sellers upload into their own folder:  product-images/<seller uuid>/<file>
drop policy if exists product_images_seller_insert on storage.objects;
create policy product_images_seller_insert on storage.objects for insert to authenticated
  with check (bucket_id = 'product-images'
              and (storage.foldername(name))[1] = auth.uid()::text
              and public.is_active_seller());
drop policy if exists product_images_seller_update on storage.objects;
create policy product_images_seller_update on storage.objects for update to authenticated
  using (bucket_id = 'product-images' and (storage.foldername(name))[1] = auth.uid()::text
         and public.is_active_seller());
drop policy if exists product_images_seller_delete on storage.objects;
create policy product_images_seller_delete on storage.objects for delete to authenticated
  using (bucket_id = 'product-images' and (storage.foldername(name))[1] = auth.uid()::text
         and public.is_active_seller());

-- ---------- 12. permissions ----------
revoke all on public.app_settings, public.wishlist, public.product_reviews from anon, authenticated;
grant select on public.wishlist, public.product_reviews to authenticated;

revoke all on function
  public.is_active_buyer(), public._sandbox_payments(),
  public._parse_cart_lines(jsonb), public._recompute_rating(uuid),
  public._apply_sold(uuid, integer), public._cancel_order(uuid),
  public._expire_unpaid_orders(), public._checkout_compute(jsonb, text, text, boolean)
from public, anon, authenticated;

revoke all on function
  public.buyer_list_products(text, text, numeric, numeric, text, numeric, text, integer, integer, boolean, uuid[]),
  public.buyer_list_brands(), public.buyer_toggle_wishlist(uuid),
  public.buyer_quote_checkout(jsonb, text, text),
  public.buyer_place_order(jsonb, text, text, text, text, text, text, text, boolean),
  public.buyer_pay_order(text, text), public.buyer_cancel_order(text),
  public.buyer_confirm_delivery(text), public.buyer_list_orders(text),
  public.buyer_add_review(uuid, integer, text), public.seller_list_orders()
from public, anon;

grant execute on function
  public.buyer_list_products(text, text, numeric, numeric, text, numeric, text, integer, integer, boolean, uuid[]),
  public.buyer_list_brands(), public.buyer_toggle_wishlist(uuid),
  public.buyer_quote_checkout(jsonb, text, text),
  public.buyer_place_order(jsonb, text, text, text, text, text, text, text, boolean),
  public.buyer_pay_order(text, text), public.buyer_cancel_order(text),
  public.buyer_confirm_delivery(text), public.buyer_list_orders(text),
  public.buyer_add_review(uuid, integer, text), public.seller_list_orders()
to authenticated;

-- Optional: expire unpaid orders on a schedule too (needs the pg_cron extension).
-- select cron.schedule('expire-unpaid-orders', '*/30 * * * *', $$select public._expire_unpaid_orders()$$);