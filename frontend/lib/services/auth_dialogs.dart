import 'dart:async';
import 'package:flutter/material.dart';
import 'auth_service.dart';

void _snack(BuildContext context, String msg) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(msg),
    behavior: SnackBarBehavior.floating,
    backgroundColor: const Color(0xFF1E1E24),
  ));
}

/// "Where should we send your code?" Shown on the sign-up forms.
class VerifyChannelPicker extends StatelessWidget {
  final VerifyChannel value;
  final ValueChanged<VerifyChannel> onChanged;
  const VerifyChannelPicker(
      {super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Verify my account with',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<VerifyChannel>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                  value: VerifyChannel.email,
                  icon: Icon(Icons.mail_outline_rounded),
                  label: Text('Email')),
              ButtonSegment(
                  value: VerifyChannel.phone,
                  icon: Icon(Icons.sms_outlined),
                  label: Text('Phone (SMS)')),
            ],
            selected: {value},
            onSelectionChanged: (s) => onChanged(s.first),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value == VerifyChannel.email
              ? 'We will email you a 6-digit code. One time only. You will log in with your email + password.'
              : 'We will text you a 6-digit code. One time only. You will log in with your phone + password.',
          style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
        ),
      ],
    );
  }
}

/// 6-digit code dialog with resend (30s cooldown). Returns code or null.
Future<String?> showOtpDialog(BuildContext context,
    {required VerifyTarget target}) {
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _OtpDialog(target: target),
  );
}

class _OtpDialog extends StatefulWidget {
  final VerifyTarget target;
  const _OtpDialog({required this.target});
  @override
  State<_OtpDialog> createState() => _OtpDialogState();
}

class _OtpDialogState extends State<_OtpDialog> {
  final _ctrl = TextEditingController();
  Timer? _timer;
  int _cooldown = 30;
  bool _resending = false;

  @override
  void initState() {
    super.initState();
    _startCooldown();
  }

  void _startCooldown() {
    _timer?.cancel();
    setState(() => _cooldown = 30);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _cooldown--);
      if (_cooldown <= 0) t.cancel();
    });
  }

  Future<void> _resend() async {
    setState(() => _resending = true);
    try {
      await AuthService.sendVerificationCode(widget.target);
      if (mounted) _snack(context, 'New code sent.');
      _startCooldown();
    } catch (e) {
      if (mounted) _snack(context, AuthService.errorMessage(e));
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEmail = widget.target.channel == VerifyChannel.email;
    return AlertDialog(
      title: Text(isEmail ? 'Enter the email code' : 'Enter the SMS code'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('We sent a 6-digit code to ${widget.target.destination}.'),
          const SizedBox(height: 12),
          TextField(
            controller: _ctrl,
            keyboardType: TextInputType.number,
            maxLength: 6,
            autofocus: true,
            decoration: const InputDecoration(counterText: ''),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: (_cooldown > 0 || _resending) ? null : _resend,
              child: Text(_cooldown > 0
                  ? 'Resend code in ${_cooldown}s'
                  : 'Resend code'),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            final code = _ctrl.text.trim();
            if (RegExp(r'^\d{6}$').hasMatch(code)) Navigator.pop(context, code);
          },
          child: const Text('Verify'),
        ),
      ],
    );
  }
}

/// Asks for the code until it is right (or the user cancels).
/// Pass codeAlreadySent:false on the login path (no code was just sent).
/// Returns true only when verified; a session is open after true.
Future<bool> verifyAccount(BuildContext context, VerifyTarget target,
    {bool codeAlreadySent = true}) async {
  if (!codeAlreadySent) {
    try {
      await AuthService.sendVerificationCode(target);
    } catch (e) {
      if (context.mounted) {
        _snack(context,
            'Could not send the code. (${AuthService.errorMessage(e)})');
      }
      return false;
    }
  }
  while (context.mounted) {
    final code = await showOtpDialog(context, target: target);
    if (code == null) return false; // cancelled
    try {
      await AuthService.confirmVerificationCode(target, code);
      if (context.mounted) _snack(context, 'Verified. You are all set.');
      return true;
    } catch (_) {
      if (context.mounted) {
        _snack(context, 'Wrong or expired code. Try again.');
      }
    }
  }
  return false;
}


Future<bool> showTotpEnrollDialog(BuildContext context) async {
  final ok = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _TotpEnrollDialog(),
  );
  return ok ?? false;
}

class _TotpEnrollDialog extends StatefulWidget {
  const _TotpEnrollDialog();
  @override
  State<_TotpEnrollDialog> createState() => _TotpEnrollDialogState();
}

class _TotpEnrollDialogState extends State<_TotpEnrollDialog> {
  final _code = TextEditingController();
  TotpEnrollment? _enrollment;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    AuthService.beginTotpEnrollment().then((e) {
      if (mounted) setState(() => _enrollment = e);
    }).catchError((e) {
      if (mounted) setState(() => _error = AuthService.errorMessage(e));
    });
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final e = _enrollment;
    if (e == null || !RegExp(r'^\d{6}$').hasMatch(_code.text.trim())) {
      setState(() => _error = 'Enter the 6-digit code from your app.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AuthService.verifyTotp(
          factorId: e.factorId, code: _code.text.trim());
      if (mounted) Navigator.pop(context, true);
    } catch (err) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = AuthService.errorMessage(err);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = _enrollment;
    return AlertDialog(
      title: const Text('Set up admin 2-step login'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('1. Open Google Authenticator (or Authy).\n'
                '2. Add account → "Enter a setup key".\n'
                '3. Paste the key below, then type the 6-digit code it shows.'),
            const SizedBox(height: 12),
            if (e == null && _error == null)
              const Center(child: CircularProgressIndicator())
            else if (e != null)
              SelectableText(e.secret,
                  style: const TextStyle(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w800,
                      fontSize: 15)),
            const SizedBox(height: 12),
            TextField(
              controller: _code,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: const InputDecoration(
                  labelText: '6-digit code', counterText: ''),
            ),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Color(0xFFD64545))),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: _busy ? null : () => Navigator.pop(context, false),
            child: const Text('Cancel')),
        FilledButton(
            onPressed: (_busy || e == null) ? null : _verify,
            child: const Text('Verify & continue')),
      ],
    );
  }
}
