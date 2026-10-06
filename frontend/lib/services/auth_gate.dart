import 'package:flutter/material.dart';
import 'package:firstApp/main.dart';
import 'package:firstApp/services/auth_service.dart';

/// Use this on any "Log out" button.
Future<void> logout(BuildContext context) async {
  await AuthService.signOutQuietly();
  if (!context.mounted) return;
  Navigator.pushAndRemoveUntil(
    context,
    MaterialPageRoute(builder: (_) => const AuthGate()),
    (_) => false,
  );
}

/// Every app launch starts logged out and shows Welcome -> Login/Register.
/// (The verification code is only used during registration.)
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});
  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final Future<Widget> _destination = _decide();

  Future<Widget> _decide() async {
    await AuthService.signOutQuietly();
    return const WelcomeScreen();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _destination,
      builder: (context, snap) => snap.hasData
          ? snap.data!
          : const Scaffold(body: Center(child: CircularProgressIndicator())),
    );
  }
}
