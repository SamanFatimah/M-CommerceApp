import 'package:supabase_flutter/supabase_flutter.dart';
import 'seller_service.dart';
import 'supabase_service.dart';

/// Talks to the buyer RPCs from 20261007000000_buyer_backend.sql.
///
/// Cart lines sent to the server must look like:
///   {'productId': uuid, 'size': 'M', 'colorHex': '#1B1B1F', 'qty': 2}
/// (BuyerCartState.addItem has to store these three extra fields.)
class BuyerService {
  static SupabaseClient get _db => SupabaseService.client;

  static String money(num v) => SellerService.money(v);

  static String errorMessage(Object e) {
    if (e is PostgrestException) {
      if (e.code == 'P0001' || e.code == '22023' || e.code == '22001') {
        return e.message;
      }
      if (e.code == '42501') return 'Your account is not allowed to do this.';
      return 'Server error. Please try again.';
    }
    if (e is AuthException) return e.message;
    return 'Something went wrong. Check your internet connection.';
  }

  // ---------- catalog ----------
  static Map<String, dynamic> _productFromRow(Map<String, dynamic> r) {
    final colors = (r['colors'] as List).cast<String>();
    final images = (r['image_urls'] as List).cast<String>();
    final discount = (r['discount_pct'] as num).toInt();
    final sold = (r['sold_count'] as num).toInt();
    final reviews = (r['reviews_count'] as num).toInt();
    final rating = (r['rating'] as num).toDouble();
    return {
      'id': r['id'] as String,
      'title': r['title'] as String,
      'description': (r['description'] as String?) ?? '',
      'brand': r['brand'] as String,
      'sellerId': r['seller_id'] as String,
      'category': r['category'] as String,
      'price': (r['price'] as num).toDouble(),
      'originalPrice': (r['original_price'] as num?)?.toDouble(),
      'discount': discount > 0 ? '-$discount%' : null,
      'rating': (r['rating'] as num).toDouble(),
      'reviewsCount': (r['reviews_count'] as num).toInt(),
      'sold': (r['sold_count'] as num).toInt(),
      'stock': (r['stock'] as num).toInt(),
      'sizes': (r['sizes'] as List).cast<String>(),
      'colors': colors.map(SellerService.hexToColor).toList(),
      'colorHexes': colors,
      'imageUrls': images,
      'inWishlist': r['in_wishlist'] as bool,
      // Extra keys the existing buyer widgets already read:
      'tag': r['category'] as String,
      'sales': '$sold sold | $reviews Reviews',
      'reviewSnippet': reviews > 0
          ? '${rating.toStringAsFixed(1)} stars from $reviews reviews'
          : 'New arrival',
      'isHot': sold >= 10,
    };
  }

  /// [sort]: 'Popularity' | 'Price: Low to High' | 'Price: High to Low' | 'Customer Rating'
  /// Page with [offset] += [limit] for infinite scroll.
  static Future<List<Map<String, dynamic>>> fetchProducts({
    String? category,
    String? search,
    double? minPrice,
    double? maxPrice,
    String? brand,
    double minRating = 0,
    String sort = 'Popularity',
    int limit = 20,
    int offset = 0,
    bool wishlistOnly = false,
    List<String>? ids,
  }) async {
    final rows = await _db.rpc('buyer_list_products', params: {
      'p_category': (category == null || category == 'All') ? null : category,
      'p_search': search,
      'p_min_price': minPrice,
      'p_max_price': maxPrice,
      'p_brand': (brand == null || brand == 'All') ? null : brand,
      'p_min_rating': minRating,
      'p_sort': sort,
      'p_limit': limit,
      'p_offset': offset,
      'p_wishlist_only': wishlistOnly,
      'p_ids': ids,
    }) as List;
    return rows
        .map<Map<String, dynamic>>(
            (r) => _productFromRow(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  static Future<Map<String, dynamic>?> fetchProduct(String id) async {
    final list = await fetchProducts(ids: [id], limit: 1);
    return list.isEmpty ? null : list.first;
  }

  /// Use on the cart screen to refresh prices / stock of what is in the cart.
  static Future<List<Map<String, dynamic>>> fetchProductsByIds(
          List<String> ids) =>
      ids.isEmpty
          ? Future.value([])
          : fetchProducts(ids: ids, limit: ids.length.clamp(1, 50));

  static Future<List<String>> fetchBrands() async {
    final rows = await _db.rpc('buyer_list_brands') as List;
    return ['All', ...rows.map((r) => (r as Map)['brand'] as String)];
  }

  static Future<List<String>> fetchCategories() async {
    final rows =
        await _db.from('categories').select('name').order('sort_order');
    return rows.map<String>((r) => r['name'] as String).toList();
  }

  /// Returns the new state (true = now in wishlist).
  static Future<bool> toggleWishlist(String productId) async {
    final res = await _db
        .rpc('buyer_toggle_wishlist', params: {'p_product': productId});
    return res as bool;
  }

  // ---------- reviews ----------
  static Future<List<Map<String, dynamic>>> fetchReviews(String productId,
      {int limit = 20, int offset = 0}) async {
    final rows = await _db
        .from('product_reviews')
        .select('reviewer_name,rating,comment,created_at')
        .eq('product_id', productId)
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);
    return rows
        .map<Map<String, dynamic>>((r) => {
              'name': r['reviewer_name'] as String,
              'rating': (r['rating'] as num).toInt(),
              'comment': (r['comment'] as String?) ?? '',
              'date': SellerService.formatDate(
                  DateTime.parse(r['created_at'] as String).toLocal()),
            })
        .toList();
  }

  /// Only works after the buyer's order for this product is Delivered.
  static Future<Map<String, dynamic>> addReview(
      String productId, int rating, String? comment) async {
    final res = await _db.rpc('buyer_add_review', params: {
      'p_product': productId,
      'p_rating': rating,
      'p_comment': comment,
    });
    return Map<String, dynamic>.from(res as Map);
  }

  // ---------- checkout ----------
  static List<Map<String, dynamic>> cartToJson(
          List<Map<String, dynamic>> cart) =>
      cart
          .map((i) => {
                'product_id': i['productId'],
                'size': i['size'],
                'color': i['colorHex'],
                'qty': i['qty'],
              })
          .toList();

  /// Server-side price breakdown. Throws a readable error for bad coupons,
  /// out-of-stock items, etc. Use this for the "Apply" coupon button and the
  /// totals on the cart screen.
  /// Result keys: subtotal, shipping, tax, discount, grand_total, coupon_code,
  /// sellers[] (one per parcel, each with its own shipping + tax).
  static Future<Map<String, dynamic>> quote(
    List<Map<String, dynamic>> cart, {
    String delivery = 'Standard',
    String? coupon,
  }) async {
    final res = await _db.rpc('buyer_quote_checkout', params: {
      'p_items': cartToJson(cart),
      'p_delivery': delivery,
      'p_coupon': (coupon == null || coupon.trim().isEmpty) ? null : coupon,
    });
    return Map<String, dynamic>.from(res as Map);
  }

  /// [payment]: 'Card' | 'JazzCash' | 'COD'.
  /// [payNow] false = reserve the stock and create an *Unpaid* order
  /// (what the app does when the buyer backs out of the payment step).
  /// NEVER send card numbers / CVC here.
  static Future<Map<String, dynamic>> placeOrder({
    required List<Map<String, dynamic>> cart,
    required String delivery,
    required String payment,
    String? coupon,
    required String name,
    required String phone,
    required String address,
    required String city,
    bool payNow = true,
  }) async {
    final res = await _db.rpc('buyer_place_order', params: {
      'p_items': cartToJson(cart),
      'p_delivery': delivery,
      'p_payment': payment,
      'p_coupon': (coupon == null || coupon.trim().isEmpty) ? null : coupon,
      'p_name': name,
      'p_phone': phone,
      'p_address': address,
      'p_city': city,
      'p_pay_now': payNow,
    });
    return Map<String, dynamic>.from(res as Map);
  }

  static Future<void> payOrder(String orderNumber, String method) async {
    await _db.rpc('buyer_pay_order',
        params: {'p_order_number': orderNumber, 'p_method': method});
  }

  static Future<void> cancelOrder(String orderNumber) async {
    await _db
        .rpc('buyer_cancel_order', params: {'p_order_number': orderNumber});
  }

  static Future<void> confirmDelivery(String orderNumber) async {
    await _db
        .rpc('buyer_confirm_delivery', params: {'p_order_number': orderNumber});
  }

  // ---------- orders ----------
  /// [bucket]: null (all) | 'unpaid' | 'processing' | 'shipped' | 'delivered' | 'cancelled'
  static Future<List<Map<String, dynamic>>> fetchOrders(
      {String? bucket}) async {
    final rows = await _db
        .rpc('buyer_list_orders', params: {'p_bucket': bucket}) as List;
    return rows.map<Map<String, dynamic>>((raw) {
      final r = Map<String, dynamic>.from(raw as Map);
      return {
        'orderId': r['order_number'] as String,
        'status': r['status'] as String,
        'bucket': r['bucket'] as String,
        'store': r['store'] as String,
        'subtotal': (r['subtotal'] as num).toDouble(),
        'discount': (r['discount'] as num).toDouble(),
        'shipping': (r['shipping_fee'] as num).toDouble(),
        'tax': (r['tax'] as num).toDouble(),
        'total': (r['total'] as num).toDouble(),
        'paymentMethod': r['payment_method'] as String?,
        'paymentStatus': r['payment_status'] as String,
        'deliveryMethod': r['delivery_method'] as String,
        'trackingId': (r['tracking_id'] as String?) ?? '',
        'shipName': r['ship_name'] as String?,
        'shipPhone': r['ship_phone'] as String?,
        'shipAddress': r['ship_address'] as String?,
        'shipCity': r['ship_city'] as String?,
        'date': SellerService.formatDate(
            DateTime.parse(r['created_at'] as String).toLocal()),
        'items': (r['items'] as List)
            .map((i) => {
                  'productId': (i as Map)['product_id'],
                  'title': i['title'],
                  'size': i['size'],
                  'color': i['color'] == null
                      ? null
                      : SellerService.hexToColor(i['color'] as String),
                  'qty': (i['quantity'] as num).toInt(),
                  'unitPrice': (i['unit_price'] as num).toDouble(),
                })
            .toList(),
      };
    }).toList();
  }
}