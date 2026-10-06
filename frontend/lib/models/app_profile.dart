class AppProfile {
  final String id;
  final String role;
  final String? fullName;
  final String? storeName;
  final String? phone;
  final bool phoneVerified;
  final bool isSuspended;

  AppProfile({
    required this.id,
    required this.role,
    this.fullName,
    this.storeName,
    this.phone,
    this.phoneVerified = false,
    this.isSuspended = false,
  });

  factory AppProfile.fromMap(Map<String, dynamic> m) => AppProfile(
        id: m['id'] as String,
        role: m['role'] as String,
        fullName: m['full_name'] as String?,
        storeName: m['store_name'] as String?,
        phone: m['phone'] as String?,
        phoneVerified: (m['phone_verified'] as bool?) ?? false,
        isSuspended: (m['is_suspended'] as bool?) ?? false,
      );
}
