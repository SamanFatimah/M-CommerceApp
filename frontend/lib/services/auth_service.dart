import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/app_profile.dart';
import 'supabase_service.dart';

class AuthFailure implements Exception {
  final String message;
  AuthFailure(this.message);
}

class TotpEnrollment {
  final String factorId;
  final String secret;
  TotpEnrollment(this.factorId, this.secret);
}

/// Where the one-time code is sent. The user picks this once, at sign-up.
enum VerifyChannel { email, phone }

/// A pending verification: which channel + where the code went.
class VerifyTarget {
  final VerifyChannel channel;
  final String destination; // email address, or +E.164 phone number
  const VerifyTarget(this.channel, this.destination);
}

/// Thrown at login when the account exists but its first-time code was
/// never entered (e.g. app closed during sign-up). Happens at most once.
class VerificationRequired implements Exception {
  final VerifyTarget target;
  VerificationRequired(this.target);
}

class AuthService {
  static SupabaseClient get _db => SupabaseService.client;

  static Future<AppProfile> currentProfile() async {
    final user = _db.auth.currentUser;
    if (user == null) throw AuthFailure('You are not signed in.');
    final data = await _db.from('profiles').select().eq('id', user.id).single();
    return AppProfile.fromMap(data);
  }

  static Future<AppProfile> _requireRole(String expectedRole) async {
    final profile = await currentProfile();
    if (profile.role != expectedRole) {
      await _db.auth.signOut();
      throw AuthFailure('This account is not a $expectedRole account.');
    }
    if (profile.isSuspended) {
      await _db.auth.signOut();
      throw AuthFailure('This account has been suspended.');
    }
    return profile;
  }

    /// Call after a successful confirmVerificationCode on the login path.
  static Future<AppProfile> finishLogin(String expectedRole) =>
      _requireRole(expectedRole);

  /// "0300 1234567" -> "+923001234567"
  static String normalizePhone(String raw) {
    final p = raw.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    if (p.startsWith('+')) return p;
    if (p.startsWith('00')) return '+${p.substring(2)}';
    if (p.startsWith('0')) return '+92${p.substring(1)}';
    return '+$p';
  }

  // ---------------- Sign up (one-time verification) ----------------

  /// Email channel: account keyed by email, code sent by email.
  /// Phone channel: account keyed by phone, code sent by SMS.
  /// Returns the target to show in the OTP dialog (null if already signed in).
  static Future<VerifyTarget?> signUp({
    required VerifyChannel channel,
    required String email,
    required String phone,
    required String password,
    required String role,
    Map<String, dynamic> details = const {},
  }) async {
    final cleanPhone = phone.trim().isEmpty ? '' : normalizePhone(phone);
    final meta = <String, dynamic>{
      'role': role,
      ...details,
      'phone': cleanPhone,
      'email': email,
    };

    if (channel == VerifyChannel.email) {
      final res =
          await _db.auth.signUp(email: email, password: password, data: meta);
      return res.session != null ? null : VerifyTarget(channel, email);
    }
    final res = await _db.auth
        .signUp(phone: cleanPhone, password: password, data: meta);
    return res.session != null ? null : VerifyTarget(channel, cleanPhone);
  }

  static Future<void> sendVerificationCode(VerifyTarget t) async {
    if (t.channel == VerifyChannel.email) {
      await _db.auth.resend(type: OtpType.signup, email: t.destination);
    } else {
      await _db.auth.resend(type: OtpType.sms, phone: t.destination);
    }
  }

  /// On success Supabase marks the email/phone confirmed AND opens a session.
  static Future<void> confirmVerificationCode(
      VerifyTarget t, String code) async {
    if (t.channel == VerifyChannel.email) {
      await _db.auth
          .verifyOTP(email: t.destination, token: code, type: OtpType.signup);
    } else {
      await _db.auth
          .verifyOTP(phone: t.destination, token: code, type: OtpType.sms);
    }
  }

  // ---------------- Log in (password only, never a code) ----------------

  /// [identifier] is an email or a phone number.
  static Future<AppProfile> signInWithIdentifier({
    required String identifier,
    required String password,
    required String expectedRole,
  }) async {
    final id = identifier.trim();
    final isEmail = id.contains('@');
    final phone = isEmail ? '' : normalizePhone(id);
    try {
      if (isEmail) {
        await _db.auth.signInWithPassword(email: id, password: password);
      } else {
        await _db.auth.signInWithPassword(phone: phone, password: password);
      }
    } on AuthException catch (e) {
      final m = e.message.toLowerCase();
      if (m.contains('email not confirmed')) {
        throw VerificationRequired(VerifyTarget(VerifyChannel.email, id));
      }
      if (m.contains('phone not confirmed')) {
        throw VerificationRequired(VerifyTarget(VerifyChannel.phone, phone));
      }
      if (!isEmail && m.contains('invalid login credentials')) {
        throw AuthFailure('No account found for this phone number and '
            'password. If you verified with your email, log in with your '
            'email instead.');
      }
      rethrow;
    }
    return _requireRole(expectedRole);
  }

  /// Used by the admin screen (unchanged call site).
  static Future<AppProfile> signIn({
    required String email,
    required String password,
    required String expectedRole,
  }) =>
      signInWithIdentifier(
          identifier: email, password: password, expectedRole: expectedRole);

  static Future<void> signOut() => _db.auth.signOut();

  static Future<void> signOutQuietly() async {
    try {
      await _db.auth.signOut();
    } catch (_) {}
  }
  // ---------------- Admin authenticator (TOTP) ----------------

  static Future<String?> verifiedTotpFactorId() async {
    final factors = await _db.auth.mfa.listFactors();
    return factors.totp.isEmpty ? null : factors.totp.first.id;
  }

  static Future<TotpEnrollment> beginTotpEnrollment() async {
    final factors = await _db.auth.mfa.listFactors();
    for (final f in factors.all) {
      if (f.status == FactorStatus.unverified) {
        await _db.auth.mfa.unenroll(f.id);
      }
    }
    final res = await _db.auth.mfa.enroll(
      factorType: FactorType.totp,
      issuer: 'LoopLab',
      friendlyName: 'LoopLab Admin',
    );
    return TotpEnrollment(res.id, res.totp!.secret);
  }

  static Future<void> verifyTotp({
    required String factorId,
    required String code,
  }) async {
    await _db.auth.mfa.challengeAndVerify(factorId: factorId, code: code);
  }

  static Future<bool> isAal2() async {
    final aal = _db.auth.mfa.getAuthenticatorAssuranceLevel();
    return aal.currentLevel == AuthenticatorAssuranceLevels.aal2;
  }

    static String errorMessage(Object e) {
    if (e is AuthFailure) return e.message;
    if (e is AuthException) {
      final m = e.message.toLowerCase();
      if (m.contains('already registered') || m.contains('already exists')) {
        return 'This email or phone is already registered. Log in instead.';
      }
      if (m.contains('signups not allowed') ||
          m.contains('unsupported phone provider')) {
        return 'Phone verification is not enabled on the server yet. '
            'Choose email instead.';
      }
      if (m.contains('invalid login credentials')) {
        return 'Wrong email/phone or password.';
      }
      return e.message;
    }
    if (e is PostgrestException) {
      return 'Could not load your profile. Try again.';
    }
    return 'Something went wrong. Check your internet connection.';
  }
}
