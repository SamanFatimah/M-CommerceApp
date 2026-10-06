import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

class SellerService {
  static SupabaseClient get _db => SupabaseService.client;

  static String get _uid {
    final u = _db.auth.currentUser;
    if (u == null) throw Exception('You are not signed in.');
    return u.id;
  }

  static String sellerCode() => 'LL-${_uid.substring(0, 8).toUpperCase()}';

  // ---------- helpers ----------
  static String colorToHex(Color c) =>
      '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

  static Color hexToColor(String hex) =>
      Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));

  static String money(num v) {
    final whole = v.round() == v;
    final s = whole ? v.round().toString() : v.toStringAsFixed(2);
    final parts = s.split('.');
    final intPart =
        parts[0].replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');
    return parts.length > 1 ? '$intPart.${parts[1]}' : intPart;
  }

  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec'
  ];

  static String formatDate(DateTime d) =>
      '${_months[d.month - 1]} ${d.day}, ${d.year}';

  static String errorMessage(Object e) {
    if (e is PostgrestException) {
      final msg = e.message;
      switch (e.code) {
        case '23505':
          if (msg.contains('products_seller_sku_uniq')) {
            return 'That SKU is already used in your catalog. Pick another.';
          }
          if (msg.contains('coupons_code_uniq')) {
            return 'That coupon code is already taken. Try another.';
          }
          return 'That value already exists.';
        case '23514':
          if (msg.contains('coupons_percent_max')) {
            return 'A percentage coupon cannot exceed 100%.';
          }
          if (msg.contains('code_check')) {
            return 'Coupon code: 3-30 letters, numbers, - or _.';
          }
          if (msg.contains('products_price'))
            return 'Price cannot be negative.';
          if (msg.contains('products_stock'))
            return 'Stock cannot be negative.';
          return 'Some values are not valid. Please check the form.';
        case '42501':
          return 'Your seller account is not allowed to do this.';
        case 'PGRST116':
          return 'That item could not be saved. It may have been removed.';
        default:
          if (e.code == 'P0001' || e.code == '22023' || e.code == '22001') {
            return msg;
          }
          if (msg.contains('row-level security')) {
            return 'Your seller account is not allowed to do this.';
          }
          return 'Server error. Please try again.';
      }
    }
    if (e is AuthException) return e.message;
    return 'Something went wrong. Check your internet connection.';
  }

  // ---------- catalog ----------
  static Map<String, String>? _categoryIds;

  static Future<String> _categoryId(String name) async {
    _categoryIds ??= {
      for (final r in await _db.from('categories').select('id,name'))
        r['name'] as String: r['id'] as String
    };
    final id = _categoryIds![name];
    if (id == null) throw Exception('Unknown category "$name".');
    return id;
  }

  static Map<String, dynamic> _productFromRow(Map<String, dynamic> r) {
    final cat = r['categories'];
    return {
      'id': r['id'] as String,
      'title': r['title'] as String,
      'sku': r['sku'] as String,
      'category': cat is Map ? cat['name'] as String : 'Bags',
      'price': (r['price'] as num).toDouble(),
      'stock': (r['stock'] as num).toInt(),
      'lowThreshold': (r['low_threshold'] as num).toInt(),
      'sizes': (r['sizes'] as List).map<String>((e) => e as String).toList(),
      'colors': (r['colors'] as List)
          .map<Color>((e) => hexToColor(e as String))
          .toList(),
      'status': r['moderation_status'] as String,
    };
  }

  static Future<List<Map<String, dynamic>>> fetchProducts() async {
    final rows = await _db
        .from('products')
        .select('*, categories(name)')
        .eq('seller_id', _uid)
        .isFilter('deleted_at', null)
        .order('created_at', ascending: false);
    return rows.map<Map<String, dynamic>>(_productFromRow).toList();
  }

  static Future<Map<String, dynamic>> addProduct(Map<String, dynamic> p) async {
    final row = await _db
        .from('products')
        .insert({
          'seller_id': _uid,
          'category_id': await _categoryId(p['category'] as String),
          'title': p['title'],
          'sku': p['sku'],
          'price': p['price'],
          'stock': p['stock'],
          'low_threshold': p['lowThreshold'],
          'sizes': p['sizes'],
          'colors': (p['colors'] as List<Color>).map(colorToHex).toList(),
        })
        .select('*, categories(name)')
        .single();
    return _productFromRow(row);
  }

  static Future<Map<String, dynamic>> updateProduct(
      Map<String, dynamic> p) async {
    final row = await _db
        .from('products')
        .update({
          'category_id': await _categoryId(p['category'] as String),
          'title': p['title'],
          'sku': p['sku'],
          'price': p['price'],
          'stock': p['stock'],
          'low_threshold': p['lowThreshold'],
          'sizes': p['sizes'],
          'colors': (p['colors'] as List<Color>).map(colorToHex).toList(),
        })
        .eq('id', p['id'] as String)
        .select('*, categories(name)')
        .single();
    return _productFromRow(row);
  }

  static Future<int> adjustStock(String id, int delta) async {
    final res = await _db
        .rpc('seller_adjust_stock', params: {'p_id': id, 'p_delta': delta});
    return (res as num).toInt();
  }

  static Future<void> deleteProduct(String id) async {
    await _db.rpc('seller_delete_product', params: {'p_id': id});
  }

  // ---------- overview ----------
  static Future<Map<String, dynamic>> overview(String period) async {
    final res =
        await _db.rpc('seller_overview_metrics', params: {'p_period': period});
    return Map<String, dynamic>.from(res as Map);
  }

  // ---------- orders ----------
  static Future<List<Map<String, dynamic>>> fetchOrders() async {
    final rows = await _db.rpc('seller_list_orders') as List;
    return rows.map<Map<String, dynamic>>((raw) {
      final r = Map<String, dynamic>.from(raw as Map);
      return {
        'orderId': r['order_id'] as String,
        'buyer': r['buyer'] as String,
        'items': r['items'] as String,
        'total': 'Rs. ${money(r['total'] as num)}',
        'date': formatDate(DateTime.parse(r['created_at'] as String).toLocal()),
        'status': r['status'] as String,
        'trackingId': (r['tracking_id'] as String?) ?? '',
      };
    }).toList();
  }

  static Future<Map<String, dynamic>> advanceOrder(String orderId) async {
    final res = await _db
        .rpc('seller_advance_order', params: {'p_order_number': orderId});
    return Map<String, dynamic>.from(res as Map);
  }

  static Future<String> setTracking(String orderId, String tracking) async {
    final res = await _db.rpc('seller_set_tracking',
        params: {'p_order_number': orderId, 'p_tracking': tracking});
    return (res as String?) ?? '';
  }

  // ---------- coupons ----------
  static Map<String, dynamic> _couponFromRow(Map<String, dynamic> r) {
    final type = r['discount_type'] as String;
    final value = r['discount_value'] as num;
    final min = r['min_spend'] as num;
    final expiresAt = DateTime.parse(r['expires_at'] as String).toLocal();
    final expired = expiresAt.isBefore(DateTime.now());
    return {
      'id': r['id'] as String,
      'code': r['code'] as String,
      'discount': type == 'Percentage'
          ? '${money(value)}% OFF'
          : 'Rs. ${money(value)} FLAT',
      'type': type,
      'minSpend': min == 0 ? 'None' : 'Rs. ${money(min)}',
      'isActive': (r['is_active'] as bool) && !expired,
      'expires': expired ? 'Expired' : formatDate(expiresAt),
    };
  }

  static Future<List<Map<String, dynamic>>> fetchCoupons() async {
    final rows = await _db
        .from('coupons')
        .select()
        .eq('seller_id', _uid)
        .order('created_at', ascending: false);
    return rows.map<Map<String, dynamic>>(_couponFromRow).toList();
  }

  static Future<Map<String, dynamic>> createCoupon({
    required String code,
    required String type,
    required double value,
    required double minSpend,
  }) async {
    final row = await _db
        .from('coupons')
        .insert({
          'seller_id': _uid,
          'code': code.trim().toUpperCase(),
          'discount_type': type,
          'discount_value': value,
          'min_spend': minSpend,
        })
        .select()
        .single();
    return _couponFromRow(row);
  }

  static Future<void> setCouponActive(String id, bool active) async {
    await _db.from('coupons').update({'is_active': active}).eq('id', id);
  }
}
