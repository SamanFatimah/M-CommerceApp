import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Session is kept in memory only, never saved on the device,
/// so the user must log in again every time the app is opened.
class SecureSessionStorage extends LocalStorage {
  SecureSessionStorage();

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> hasAccessToken() async => false;

  @override
  Future<String?> accessToken() async => null;

  @override
  Future<void> removePersistedSession() async {}

  @override
  Future<void> persistSession(String persistSessionString) async {}
}

class SupabaseService {
  static Future<void> init() async {
    await dotenv.load(fileName: '.env');
    await Supabase.initialize(
      url: dotenv.env['SUPABASE_URL']!,
      publishableKey: dotenv.env['SUPABASE_PUBLISHABLE_KEY']!,
      authOptions: FlutterAuthClientOptions(
        localStorage: SecureSessionStorage(),
      ),
    );
  }

  static SupabaseClient get client => Supabase.instance.client;
}
