import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'services/supabase_service.dart';
import 'services/auth_service.dart';
import 'models/app_profile.dart';
import 'services/auth_gate.dart';
import 'services/auth_dialogs.dart';
import 'services/seller_service.dart';
import 'services/buyer_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseService.init(); // connects to Supabase before the UI starts
  runApp(const LoopLabApp());
}

// =============================================================
// INPUT FORMAT VALIDATION HELPER (REGEX CHECKS)
// =============================================================
class AppValidators {
  // Validates standard email structure (e.g., name@domain.com)
  static bool isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email.trim());
  }

  // Validates phone number (allows optional +, spaces, dashes, 10-15 digits)
  static bool isValidPhone(String phone) {
    final cleaned = phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    return RegExp(r'^\+?[0-9]{10,15}$').hasMatch(cleaned);
  }

  // Accepts either a valid email or a valid phone number
  static bool isValidEmailOrPhone(String input) {
    return isValidEmail(input) || isValidPhone(input);
  }

  // Checks password strength (minimum 6 characters)
  static bool isValidPassword(String password) {
    return password.trim().length >= 6;
  }
}

class LoopLabApp extends StatelessWidget {
  const LoopLabApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LoopLab',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFFAF4F1),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFD64545),
          primary: const Color(0xFF1E1E24),
          secondary: const Color(0xFFFFD8CC),
        ),
        fontFamily: 'sans-serif',
      ),
      home: const AuthGate(),
    );
  }
}

// -------------------------------------------------------------
// SCREEN 1: LUXURY CINEMATIC SPLASH (ZERO-DEPENDENCY MOTION)
// -------------------------------------------------------------
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with TickerProviderStateMixin {
  late AnimationController _cameraController;
  late AnimationController _textAnimController;
  late AnimationController _fadeExitController;

  late Animation<double> _cameraScale;
  late Animation<Alignment> _cameraPan;
  late Animation<double> _titleSlide;
  late Animation<double> _titleOpacity;
  late Animation<double> _subSlide;
  late Animation<double> _subOpacity;
  late Animation<double> _exitFade;

  @override
  void initState() {
    super.initState();

    // 1. Cinematic Camera Sweep Controller (Slow pan & zoom over image)
    _cameraController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 7),
    )..forward();

    _cameraScale = Tween<double>(begin: 1.0, end: 1.18).animate(
      CurvedAnimation(parent: _cameraController, curve: Curves.easeInOut),
    );

    _cameraPan = Tween<Alignment>(
      begin: Alignment.center,
      end: const Alignment(0.15, -0.1),
    ).animate(
      CurvedAnimation(parent: _cameraController, curve: Curves.easeInOut),
    );

    // 2. Kinetic Text Controller
    _textAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _titleSlide = Tween<double>(begin: 30.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _textAnimController,
        curve: const Interval(0.1, 0.7, curve: Curves.easeOutCubic),
      ),
    );

    _titleOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _textAnimController,
        curve: const Interval(0.1, 0.6, curve: Curves.easeIn),
      ),
    );

    _subSlide = Tween<double>(begin: 25.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _textAnimController,
        curve: const Interval(0.4, 0.9, curve: Curves.easeOutCubic),
      ),
    );

    _subOpacity = Tween<double>(begin: 0.0, end: 0.85).animate(
      CurvedAnimation(
        parent: _textAnimController,
        curve: const Interval(0.4, 0.85, curve: Curves.easeIn),
      ),
    );

    // 3. Smooth Screen Exit Controller
    _fadeExitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _exitFade = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _fadeExitController, curve: Curves.easeInOut),
    );

    _startPresentationTimeline();
  }

  void _startPresentationTimeline() async {
    _textAnimController.forward();

    // Stays active for 5.5 seconds so you can watch the camera movement
    await Future.delayed(const Duration(milliseconds: 5500));
    if (!mounted) return;

    await _fadeExitController.forward();
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 350),
        pageBuilder: (context, animation, secondaryAnimation) =>
            const RoleAuthScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  void dispose() {
    _cameraController.dispose();
    _textAnimController.dispose();
    _fadeExitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: FadeTransition(
        opacity: _exitFade,
        child: Stack(
          children: [
            // Moving Cinematic Camera Viewport
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _cameraController,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _cameraScale.value,
                    alignment: _cameraPan.value,
                    child: Image.asset(
                      'assets/luxury_bags.jpg',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: const Color(0xFF141416),
                        child: const Center(
                          child: Icon(Icons.shopping_bag_outlined,
                              size: 70, color: Colors.white24),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // Dynamic Ambient Dark Vignette
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.2),
                      Colors.black.withValues(alpha: 0.55),
                      Colors.black.withValues(alpha: 0.94),
                    ],
                    stops: const [0.0, 0.45, 1.0],
                  ),
                ),
              ),
            ),

            // Foreground Text & Controls
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(30),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          color: Colors.white.withValues(alpha: 0.14),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.diamond_outlined, size: 14, color: Color(0xFFFFD8CC)),
                              SizedBox(width: 6),
                              Text(
                                'M-Commerce',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.8,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const Spacer(),

                    // Animated Title
                    AnimatedBuilder(
                      animation: _textAnimController,
                      builder: (context, child) {
                        return Transform.translate(
                          offset: Offset(0, _titleSlide.value),
                          child: Opacity(
                            opacity: _titleOpacity.value,
                            child: const Text(
                              'Curated\nElegance.',
                              style: TextStyle(
                                fontSize: 48,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                height: 1.08,
                                letterSpacing: -1.4,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 14),

                    // Animated Subtitle
                    AnimatedBuilder(
                      animation: _textAnimController,
                      builder: (context, child) {
                        return Transform.translate(
                          offset: Offset(0, _subSlide.value),
                          child: Opacity(
                            opacity: _subOpacity.value,
                            child: const Text(
                              'Discover premier collections, intelligent curation, and an effortless shopping experience.',
                              style: TextStyle(
                                fontSize: 15,
                                color: Colors.white,
                                height: 1.45,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 36),

                    // Progress Line
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: SizedBox(
                        height: 4,
                        child: LinearProgressIndicator(
                          backgroundColor: Colors.white.withValues(alpha: 0.15),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFFD64545),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
// -------------------------------------------------------------
// SCREEN 2: ROLE SELECTION SCREEN
// -------------------------------------------------------------
class RoleAuthScreen extends StatelessWidget {
  const RoleAuthScreen({super.key});

  void _onRoleSelected(BuildContext context, String roleTitle) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Proceeding as $roleTitle...'),
        backgroundColor: const Color(0xFF1E1E24),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF4F1),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 14),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFECE5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  ' M-commerce',
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFD64545),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Choose Your Role',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1E1E24),
                  letterSpacing: -0.6,
                  height: 1.25,
                ),
              ),

              const SizedBox(height: 24),

              // 1. BUYER CARD (STACKED VERTICALLY)
              _RoleCard(
                question: 'are u a\nbuyer?',
                subtitle: 'Discover & shop curated drops',
                icon: Icons.local_mall_outlined,
                accentBadge: 'Curated Picks',
                buttonLabel: 'buy things',
                isPrimary: false,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const BuyerAuthScreen()),
                  );
                },
              ),

              const SizedBox(height: 18),

              // 2. SELLER CARD (STACKED VERTICALLY)
              _RoleCard(
                question: 'are u a\nseller ?',
                subtitle: 'List, scale & manage inventory',
                icon: Icons.storefront_outlined,
                accentBadge: 'Seller Hub',
                buttonLabel: 'sell things\nhere',
                isPrimary: true,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const SellerAuthScreen()),
                  );
                },
              ),

              const SizedBox(height: 28),

              // 3. ADMIN BUTTON (OVAL PILL)
              InkWell(
                borderRadius: BorderRadius.circular(30),
                onTap: () async {
                  await Future.delayed(const Duration(seconds: 1));
                  if (context.mounted) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const AdminLoginScreen()),
                    );
                  }
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: Colors.grey.shade300, width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.shield_outlined,
                          size: 16, color: Colors.grey.shade700),
                      const SizedBox(width: 8),
                      Text(
                        'admin',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatefulWidget {
  final String question;
  final String subtitle;
  final IconData icon;
  final String accentBadge;
  final String buttonLabel;
  final bool isPrimary;
  final VoidCallback onTap;

  const _RoleCard({
    required this.question,
    required this.subtitle,
    required this.icon,
    required this.accentBadge,
    required this.buttonLabel,
    required this.isPrimary,
    required this.onTap,
  });

  @override
  State<_RoleCard> createState() => _RoleCardState();
}

class _RoleCardState extends State<_RoleCard> {
  bool _isHoveredOrPressed = false;

  void _handleTap() async {
    setState(() => _isHoveredOrPressed = true);
    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;
    setState(() => _isHoveredOrPressed = false);
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _isHoveredOrPressed = true),
      onTapCancel: () => setState(() => _isHoveredOrPressed = false),
      onTap: _handleTap,
      child: AnimatedScale(
        scale: _isHoveredOrPressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: widget.isPrimary
                  ? const Color(0xFFD64545).withValues(alpha: 0.3)
                  : Colors.grey.shade200,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.isPrimary
                    ? const Color(0xFFD64545).withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.04),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: widget.isPrimary
                      ? const Color(0xFFFFECE5)
                      : const Color(0xFFF1EFEF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  widget.accentBadge,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: widget.isPrimary
                        ? const Color(0xFFD64545)
                        : const Color(0xFF555555),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Container(
                height: 56,
                width: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.isPrimary
                      ? const Color(0xFFD64545)
                      : const Color(0xFF1E1E24),
                ),
                child: Icon(widget.icon, color: Colors.white, size: 26),
              ),
              const SizedBox(height: 12),
              Text(
                widget.question.replaceAll('\n', ' '),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1E1E24),
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                ),
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                height: 46,
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: widget.isPrimary
                      ? const Color(0xFF1E1E24)
                      : const Color(0xFFFAF4F1),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: widget.isPrimary
                        ? Colors.transparent
                        : const Color(0xFF1E1E24),
                    width: 1.2,
                  ),
                ),
                child: Text(
                  widget.buttonLabel.replaceAll('\n', ' '),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: widget.isPrimary
                        ? Colors.white
                        : const Color(0xFF1E1E24),
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================
// SCREEN 3: SELLER REGISTRATION & LOGIN (VALIDATED)
// =============================================================
class SellerAuthScreen extends StatefulWidget {
  const SellerAuthScreen({super.key});

  @override
  State<SellerAuthScreen> createState() => _SellerAuthScreenState();
}

class _SellerAuthScreenState extends State<SellerAuthScreen> {
  bool _isLogin = true;
  bool _obscurePassword = true;
  bool _isLoading = false;
  VerifyChannel _verifyChannel = VerifyChannel.email;

  final TextEditingController _loginIdController = TextEditingController();
  final TextEditingController _storeNameController = TextEditingController();
  final TextEditingController _ownerNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _bankDetailsController = TextEditingController();

  @override
  void dispose() {
    _loginIdController.dispose();
    _storeNameController.dispose();
    _ownerNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _addressController.dispose();
    _bankDetailsController.dispose();
    super.dispose();
  }

  void _showValidationError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline_rounded,
                color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: const Color(0xFFD64545),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _generateSecureTokenAndLogin() async {
    final id = _loginIdController.text.trim();
    final password = _passwordController.text.trim();

    if (id.isEmpty || password.isEmpty) {
      _showValidationError('Enter your email or phone number and password.');
      return;
    }
    if (!AppValidators.isValidEmailOrPhone(id)) {
      _showValidationError('Enter a valid seller email or phone number.');
      return;
    }
    if (!AppValidators.isValidPassword(password)) {
      _showValidationError('Password must be at least 6 characters long.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      AppProfile profile;
      try {
        // Password only. Verified accounts are never asked for a code here.
        profile = await AuthService.signInWithIdentifier(
            identifier: id, password: password, expectedRole: 'seller');
      } on VerificationRequired catch (v) {
        // Account was created but its one-time code was never entered.
        if (!mounted) return;
        final ok =
            await verifyAccount(context, v.target, codeAlreadySent: false);
        if (!ok) {
          _showValidationError(
              'Verify your account to continue. Log in again to retry.');
          return;
        }
        profile = await AuthService.finishLogin('seller');
      }
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) =>
              SellerDashboardScreen(storeName: profile.storeName ?? 'My Store'),
        ),
      );
    } catch (e) {
      _showValidationError(AuthService.errorMessage(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _validateAndRegisterSeller() async {
    if (_storeNameController.text.trim().isEmpty ||
        _ownerNameController.text.trim().isEmpty ||
        _emailController.text.trim().isEmpty ||
        _phoneController.text.trim().isEmpty ||
        _passwordController.text.trim().isEmpty ||
        _addressController.text.trim().isEmpty ||
        _bankDetailsController.text.trim().isEmpty) {
      _showValidationError(
          'Please complete all 7 registration fields to verify your store.');
      return;
    }
    if (_storeNameController.text.trim().length < 2) {
      _showValidationError('Store Name must be at least 2 characters.');
      return;
    }
    if (!AppValidators.isValidEmail(_emailController.text)) {
      _showValidationError('Invalid email format (e.g. contact@store.com).');
      return;
    }
    if (!AppValidators.isValidPhone(_phoneController.text)) {
      _showValidationError(
          'Invalid phone format. Enter 10-15 digits (e.g. +1 800 234 5678).');
      return;
    }
    if (!AppValidators.isValidPassword(_passwordController.text)) {
      _showValidationError('Password must be at least 6 characters.');
      return;
    }
    if (_bankDetailsController.text.trim().length < 8) {
      _showValidationError(
          'Bank/Payout account must contain at least 8 alphanumeric characters.');
      return;
    }

    final storeName = _storeNameController.text.trim();

    setState(() => _isLoading = true);
    try {
      final target = await AuthService.signUp(
        channel: _verifyChannel,
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        password: _passwordController.text.trim(),
        role: 'seller',
        details: {
          'store_name': storeName,
          'owner_name': _ownerNameController.text.trim(),
          'address': _addressController.text.trim(),
          // Bank details are NOT sent. They get a protected table later.
        },
      );
      if (!mounted) return;
      if (target != null) {
        // The code is already on its way to the channel the seller picked.
        final ok = await verifyAccount(context, target);
        if (!mounted) return;
        if (!ok) {
          _showValidationError(
              'Account created but not verified yet. Log in and we will send a fresh code.');
          return;
        }
      }
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => SellerDashboardScreen(storeName: storeName),
        ),
      );
    } catch (e) {
      _showValidationError(AuthService.errorMessage(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Color(0xFF1B1B1F)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 22.0, vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isLogin ? 'Seller\nPortal Login' : 'Register\nYour Business',
                style: const TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1B1B1F),
                  height: 1.12,
                  letterSpacing: -1.0,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _isLogin
                    ? 'Authenticate your seller identity and establish a secure session token.'
                    : 'Establish verified business identity and configure financial payout details.',
                style: TextStyle(
                    fontSize: 13, color: Colors.grey.shade600, height: 1.4),
              ),
              const SizedBox(height: 24),
              Container(
                height: 54,
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: const Color(0xFFEDE3DE),
                  borderRadius: BorderRadius.circular(35),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _isLogin = true),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          decoration: BoxDecoration(
                            color: _isLogin ? Colors.white : Colors.transparent,
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: _isLogin
                                ? [
                                    BoxShadow(
                                      color:
                                          Colors.black.withValues(alpha: 0.08),
                                      blurRadius: 10,
                                      offset: const Offset(0, 3),
                                    )
                                  ]
                                : [],
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Seller Login',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: _isLogin
                                  ? const Color(0xFFD64545)
                                  : Colors.grey.shade700,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _isLogin = false),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          decoration: BoxDecoration(
                            color:
                                !_isLogin ? Colors.white : Colors.transparent,
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: !_isLogin
                                ? [
                                    BoxShadow(
                                      color:
                                          Colors.black.withValues(alpha: 0.08),
                                      blurRadius: 10,
                                      offset: const Offset(0, 3),
                                    )
                                  ]
                                : [],
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Registration',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: !_isLogin
                                  ? const Color(0xFFD64545)
                                  : Colors.grey.shade700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 26),
              if (_isLogin) ...[
                _buildOvalTextField(
                  controller: _loginIdController,
                  mainTerm: 'Email / Phone Identification',
                  hint: 'seller@store.com or +1 800 234 5678',
                  icon: Icons.alternate_email_rounded,
                ),
                const SizedBox(height: 16),
                _buildOvalTextField(
                  controller: _passwordController,
                  mainTerm: 'Seller Password',
                  hint: '••••••••••••',
                  icon: Icons.lock_outline_rounded,
                  isPassword: true,
                  obscureText: _obscurePassword,
                  onTogglePassword: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  height: 58,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD64545),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: const StadiumBorder(),
                    ),
                    onPressed: _isLoading ? null : _generateSecureTokenAndLogin,
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Generate Token & Login',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward_rounded, size: 20),
                      ],
                    ),
                  ),
                ),
              ] else ...[
                _buildOvalTextField(
                  controller: _storeNameController,
                  mainTerm: 'Store Name',
                  hint: 'e.g. Aura Luxury Studio',
                  icon: Icons.storefront_rounded,
                ),
                const SizedBox(height: 16),
                _buildOvalTextField(
                  controller: _ownerNameController,
                  mainTerm: 'Owner Name',
                  hint: 'e.g. Alexander Pierce',
                  icon: Icons.person_outline_rounded,
                ),
                const SizedBox(height: 16),
                _buildOvalTextField(
                  controller: _emailController,
                  mainTerm: 'Business Email',
                  hint: 'contact@store.com',
                  icon: Icons.mail_outline_rounded,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                _buildOvalTextField(
                  controller: _phoneController,
                  mainTerm: 'Business Phone',
                  hint: '+1 800 234 5678',
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),
                _buildOvalTextField(
                  controller: _passwordController,
                  mainTerm: 'Password (Hash)',
                  hint: 'Enter secure master password',
                  icon: Icons.key_rounded,
                  isPassword: true,
                  obscureText: _obscurePassword,
                  onTogglePassword: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
                const SizedBox(height: 16),
                _buildOvalTextField(
                  controller: _addressController,
                  mainTerm: 'Business Address',
                  hint: 'Suite 400, Commerce Blvd, New York, NY',
                  icon: Icons.location_on_outlined,
                ),
                const SizedBox(height: 16),
                _buildOvalTextField(
                  controller: _bankDetailsController,
                  mainTerm: 'Bank / Payout Details',
                  hint: 'IBAN / Routing / Payout Account Number',
                  icon: Icons.account_balance_outlined,
                ),
                const SizedBox(height: 20),
                VerifyChannelPicker(
                  value: _verifyChannel,
                  onChanged: (c) => setState(() => _verifyChannel = c),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 58,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1B1B1F),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: const StadiumBorder(),
                    ),
                    onPressed: _isLoading ? null : _validateAndRegisterSeller,
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Register Now',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(Icons.check_circle_outline_rounded, size: 20),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOvalTextField({
    required TextEditingController controller,
    required String mainTerm,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    bool obscureText = false,
    VoidCallback? onTogglePassword,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 14.0, bottom: 6.0),
          child: Text(
            mainTerm,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1B1B1F),
              letterSpacing: 0.2,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(35),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.035),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: TextField(
            controller: controller,
            obscureText: obscureText,
            keyboardType: keyboardType,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1B1B1F),
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                color: Colors.grey.shade400,
                fontSize: 13,
                fontWeight: FontWeight.w400,
              ),
              prefixIcon: Padding(
                padding: const EdgeInsets.only(left: 16, right: 12),
                child: Icon(icon, size: 20, color: const Color(0xFFD64545)),
              ),
              suffixIcon: isPassword
                  ? Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: IconButton(
                        icon: Icon(
                          obscureText
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          size: 20,
                          color: Colors.grey.shade500,
                        ),
                        onPressed: onTogglePassword,
                      ),
                    )
                  : null,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(35),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(35),
                borderSide:
                    const BorderSide(color: Color(0xFFD64545), width: 1.5),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// =============================================================
// SCREEN 4: BUYER REGISTRATION & LOGIN (ONBOARDING)
// =============================================================
class BuyerAuthScreen extends StatefulWidget {
  const BuyerAuthScreen({super.key});

  @override
  State<BuyerAuthScreen> createState() => _BuyerAuthScreenState();
}

class _BuyerAuthScreenState extends State<BuyerAuthScreen> {
  bool _isLogin = true;
  bool _obscurePassword = true;
  bool _isLoading = false;
  VerifyChannel _verifyChannel = VerifyChannel.email;

  final TextEditingController _loginIdController = TextEditingController();
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void dispose() {
    _loginIdController.dispose();
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submitBuyerAuth() async {
    // ---------------- LOGIN ----------------
    if (_isLogin) {
      final id = _loginIdController.text.trim();
      final password = _passwordController.text.trim();

      if (id.isEmpty || password.isEmpty) {
        _showBuyerError('Enter your email or phone number and password.');
        return;
      }
      if (!AppValidators.isValidEmailOrPhone(id)) {
        _showBuyerError('Enter a valid email or phone number.');
        return;
      }

      setState(() => _isLoading = true);
      try {
        try {
          // Password only. Verified accounts are never asked for a code here.
          await AuthService.signInWithIdentifier(
              identifier: id, password: password, expectedRole: 'buyer');
        } on VerificationRequired catch (v) {
          // Account was created but its one-time code was never entered.
          if (!mounted) return;
          final ok =
              await verifyAccount(context, v.target, codeAlreadySent: false);
          if (!ok) {
            _showBuyerError(
                'Verify your account to continue. Log in again to retry.');
            return;
          }
          await AuthService.finishLogin('buyer');
        }
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const BuyerMainHub()),
        );
      } catch (e) {
        _showBuyerError(AuthService.errorMessage(e));
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
      return;
    }

    // ---------------- REGISTER ----------------
    final name = _fullNameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    final password = _passwordController.text.trim();

    if (name.isEmpty || email.isEmpty || password.length < 6) {
      _showBuyerError(
          'Enter your name, email and a password of at least 6 characters.');
      return;
    }
    if (!AppValidators.isValidEmail(email)) {
      _showBuyerError('Enter a valid email address.');
      return;
    }
    if (_verifyChannel == VerifyChannel.phone && phone.isEmpty) {
      _showBuyerError('Enter your phone number to receive the code by SMS.');
      return;
    }
    if (phone.isNotEmpty && !AppValidators.isValidPhone(phone)) {
      _showBuyerError('Invalid phone format. Enter 10-15 digits.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final target = await AuthService.signUp(
        channel: _verifyChannel,
        email: email,
        phone: phone,
        password: password,
        role: 'buyer',
        details: {'full_name': name},
      );
      if (!mounted) return;
      if (target != null) {
        // The code is already on its way to the channel the buyer picked.
        final ok = await verifyAccount(context, target);
        if (!mounted) return;
        if (!ok) {
          _showBuyerError(
              'Account created but not verified yet. Log in and we will send a fresh code.');
          return;
        }
      }
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const BuyerMainHub()),
      );
    } catch (e) {
      _showBuyerError(AuthService.errorMessage(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showBuyerError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline_rounded,
                color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: const Color(0xFFD64545),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF4F1),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Color(0xFF1B1B1F)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 22.0, vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isLogin
                    ? 'Buyer\nAccount Login'
                    : 'Create Your\nShopping Profile',
                style: const TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1B1B1F),
                  height: 1.12,
                  letterSpacing: -1.0,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _isLogin
                    ? 'Log in to track your orders and view your personalized catalog.'
                    : 'User account creation for personalized shopping and order history.',
                style: TextStyle(
                    fontSize: 13, color: Colors.grey.shade600, height: 1.4),
              ),
              const SizedBox(height: 24),

              // Mode Switcher Capsule
              Container(
                height: 54,
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: const Color(0xFFEDE3DE),
                  borderRadius: BorderRadius.circular(35),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _isLogin = true),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          decoration: BoxDecoration(
                            color: _isLogin ? Colors.white : Colors.transparent,
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: _isLogin
                                ? [
                                    BoxShadow(
                                      color:
                                          Colors.black.withValues(alpha: 0.08),
                                      blurRadius: 10,
                                      offset: const Offset(0, 3),
                                    )
                                  ]
                                : [],
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Buyer Login',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: _isLogin
                                  ? const Color(0xFFD64545)
                                  : Colors.grey.shade700,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _isLogin = false),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          decoration: BoxDecoration(
                            color:
                                !_isLogin ? Colors.white : Colors.transparent,
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: !_isLogin
                                ? [
                                    BoxShadow(
                                      color:
                                          Colors.black.withValues(alpha: 0.08),
                                      blurRadius: 10,
                                      offset: const Offset(0, 3),
                                    )
                                  ]
                                : [],
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Register Now',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: !_isLogin
                                  ? const Color(0xFFD64545)
                                  : Colors.grey.shade700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 26),

              if (_isLogin) ...[
                // --- BUYER LOGIN FIELDS ---
                _buildBuyerOvalTextField(
                  controller: _loginIdController,
                  mainTerm: 'Email or Phone',
                  hint: 'buyer@example.com or +1 234 567 8900',
                  icon: Icons.alternate_email_rounded,
                ),
                const SizedBox(height: 16),
                _buildBuyerOvalTextField(
                  controller: _passwordController,
                  mainTerm: 'Password',
                  hint: '••••••••••••',
                  icon: Icons.lock_outline_rounded,
                  isPassword: true,
                  obscureText: _obscurePassword,
                  onTogglePassword: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 58,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1B1B1F),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: const StadiumBorder(),
                    ),
                    // ✅ AFTER:
                    onPressed: _isLoading ? null : _submitBuyerAuth,
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Login as Buyer',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.3),
                        ),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward_rounded, size: 20),
                      ],
                    ),
                  ),
                ),
              ] else ...[
                // --- BUYER ONBOARDING FIELDS ---
                _buildBuyerOvalTextField(
                  controller: _fullNameController,
                  mainTerm: 'Full Name',
                  hint: 'Jane Doe',
                  icon: Icons.person_outline_rounded,
                ),
                const SizedBox(height: 16),
                _buildBuyerOvalTextField(
                  controller: _emailController,
                  mainTerm: 'Email Address',
                  hint: 'buyer@example.com',
                  icon: Icons.mail_outline_rounded,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                _buildBuyerOvalTextField(
                  controller: _phoneController,
                  mainTerm: _verifyChannel == VerifyChannel.phone
                      ? 'Phone Number (gets your code)'
                      : 'Phone Number (optional)',
                  hint: '+1 234 567 8900',
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),
                _buildBuyerOvalTextField(
                  controller: _passwordController,
                  mainTerm: 'Secure Password',
                  hint: 'Create secure password',
                  icon: Icons.lock_outline_rounded,
                  isPassword: true,
                  obscureText: _obscurePassword,
                  onTogglePassword: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
                const SizedBox(height: 20),
                VerifyChannelPicker(
                  value: _verifyChannel,
                  onChanged: (c) => setState(() => _verifyChannel = c),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 58,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD64545),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: const StadiumBorder(),
                    ),
                    // ✅ AFTER:
                    onPressed: _isLoading ? null : _submitBuyerAuth,
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Register Now',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.3),
                        ),
                        SizedBox(width: 8),
                        Icon(Icons.check_circle_outline_rounded, size: 20),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBuyerOvalTextField({
    required TextEditingController controller,
    required String mainTerm,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    bool obscureText = false,
    VoidCallback? onTogglePassword,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 14.0, bottom: 6.0),
          child: Text(
            mainTerm,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1B1B1F),
              letterSpacing: 0.2,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(35),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.035),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: TextField(
            controller: controller,
            obscureText: obscureText,
            keyboardType: keyboardType,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1B1B1F),
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                color: Colors.grey.shade400,
                fontSize: 13,
                fontWeight: FontWeight.w400,
              ),
              prefixIcon: Padding(
                padding: const EdgeInsets.only(left: 16, right: 12),
                child: Icon(icon, size: 20, color: const Color(0xFFD64545)),
              ),
              suffixIcon: isPassword
                  ? Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: IconButton(
                        icon: Icon(
                          obscureText
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          size: 20,
                          color: Colors.grey.shade500,
                        ),
                        onPressed: onTogglePassword,
                      ),
                    )
                  : null,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(35),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(35),
                borderSide:
                    const BorderSide(color: Color(0xFFD64545), width: 1.5),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// =============================================================
// SCREEN 5: ADMIN GOVERNANCE DASHBOARD MODULE (LIGHT MODERN THEME)
// =============================================================
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  // Sample Data for User Management Governance (Section 3.1)
  final List<Map<String, dynamic>> _users = [
    {'name': 'Ali', 'role': 'Buyer', 'isSuspended': false},
    {'name': 'Sara', 'role': 'Seller', 'isSuspended': false},
    {'name': 'Zayn', 'role': 'Seller', 'isSuspended': true},
  ];

  // Sample Data for Product Moderation Queue (Section 3.2)
  final List<Map<String, dynamic>> _pendingProducts = [
    {
      'title': 'Italian Velvet Loafers',
      'category': 'Shoes',
      'price': 'Rs. 18,500',
      'seller': 'Aura Studio',
      'status': 'Pending'
    },
    {
      'title': 'Cashmere Overcoat',
      'category': 'Apparel',
      'price': 'Rs. 42,000',
      'seller': 'Noble Threads',
      'status': 'Pending'
    },
  ];

  void _toggleUserSuspension(int index) {
    setState(() {
      _users[index]['isSuspended'] = !_users[index]['isSuspended'];
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _users[index]['isSuspended']
              ? '${_users[index]['name']} has been suspended from LoopLab.'
              : '${_users[index]['name']} account re-activated.',
        ),
        backgroundColor: const Color(0xFF1B1B1F),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  void _moderateProduct(int index, String action) {
    final title = _pendingProducts[index]['title'];
    setState(() {
      _pendingProducts.removeAt(index);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Item "$title" $action.'),
        backgroundColor: action == 'Approved'
            ? const Color(0xFF2E7D32)
            : const Color(0xFFD64545),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF4F1), // Warm Peach Tint
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Color(0xFF1B1B1F)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Row(
          children: [
            Icon(Icons.shield_rounded, color: Color(0xFFD64545), size: 20),
            SizedBox(width: 8),
            Text(
              'ADMIN DASHBOARD',
              style: TextStyle(
                color: Color(0xFF1B1B1F),
                fontSize: 14,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 6),

              // ==========================================
              // 1. TOP METRICS STRIP (Buyers, Sellers, Revenue)
              // ==========================================
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      label: 'Buyers',
                      value: '1,240',
                      icon: Icons.people_outline_rounded,
                      accentColor: const Color(0xFF3F51B5),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildMetricCard(
                      label: 'Sellers',
                      value: '86',
                      icon: Icons.storefront_outlined,
                      accentColor: const Color(0xFFE65100),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildMetricCard(
                      label: 'Revenue',
                      value: 'Rs. 450K',
                      icon: Icons.account_balance_wallet_outlined,
                      accentColor: const Color(0xFFD64545),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ==========================================
              // 2. RECENT ACTIVITY LOGS
              // ==========================================
              _buildSectionTitle('RECENT ACTIVITY', Icons.bar_chart_rounded),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.035),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _buildActivityRow('New Buyer registered (@m.ali)',
                        'Just now', const Color(0xFF00C853)),
                    Divider(color: Colors.grey.shade200, height: 20),
                    _buildActivityRow('Product listing approved (AirPods Max)',
                        '4m ago', const Color(0xFFAB47BC)),
                    Divider(color: Colors.grey.shade200, height: 20),
                    _buildActivityRow('Payout processed to Seller Store',
                        '12m ago', const Color(0xFF00C853)),
                  ],
                ),
              ),
              const SizedBox(height: 26),

              // ==========================================
              // 3. USER MANAGEMENT & GOVERNANCE
              // ==========================================
              _buildSectionTitle(
                  'USER MANAGEMENT', Icons.manage_accounts_outlined),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.035),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _users.length,
                  separatorBuilder: (_, __) =>
                      Divider(color: Colors.grey.shade100, height: 1),
                  itemBuilder: (context, index) {
                    final user = _users[index];
                    final bool isSuspended = user['isSuspended'];
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16.0, vertical: 12.0),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: const Color(0xFFFFECE5),
                            child: Text(
                              user['name'][0],
                              style: const TextStyle(
                                color: Color(0xFFD64545),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user['name'],
                                  style: const TextStyle(
                                    color: Color(0xFF1B1B1F),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  user['role'],
                                  style: TextStyle(
                                    color: Colors.grey.shade500,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: isSuspended
                                  ? const Color(0xFFFFECE5)
                                  : const Color(0xFFE8F5E9),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              isSuspended ? 'Suspended' : 'Active',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isSuspended
                                    ? const Color(0xFFD64545)
                                    : const Color(0xFF2E7D32),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: Icon(
                              isSuspended
                                  ? Icons.replay_circle_filled_rounded
                                  : Icons.block_rounded,
                              color: isSuspended
                                  ? const Color(0xFF2E7D32)
                                  : const Color(0xFFD64545),
                              size: 22,
                            ),
                            tooltip: isSuspended
                                ? 'Reactivate User'
                                : 'Suspend User',
                            onPressed: () => _toggleUserSuspension(index),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 26),

              // ==========================================
              // 4. PRODUCT MODERATION REVIEW QUEUE
              // ==========================================
              _buildSectionTitle(
                  'PRODUCT MODERATION', Icons.inventory_2_outlined),
              const SizedBox(height: 10),
              if (_pendingProducts.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.035),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text(
                      'All product listings have been reviewed.',
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ),
                )
              else
                Column(
                  children: _pendingProducts.asMap().entries.map((entry) {
                    final int idx = entry.key;
                    final item = entry.value;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.035),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                item['title'],
                                style: const TextStyle(
                                  color: Color(0xFF1B1B1F),
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF3E0),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Text(
                                  'Pending',
                                  style: TextStyle(
                                      color: Color(0xFFEF6C00),
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Seller: ${item['seller']}  •  Category: ${item['category']}  •  ${item['price']}',
                            style: TextStyle(
                                color: Colors.grey.shade600, fontSize: 12),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF1B1B1F),
                                    foregroundColor: Colors.white,
                                    shape: const StadiumBorder(),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 11),
                                    elevation: 0,
                                  ),
                                  icon:
                                      const Icon(Icons.check_rounded, size: 16),
                                  label: const Text('Approve',
                                      style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold)),
                                  onPressed: () =>
                                      _moderateProduct(idx, 'Approved'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFFD64545),
                                    side: const BorderSide(
                                        color: Color(0xFFD64545), width: 1.2),
                                    shape: const StadiumBorder(),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 11),
                                  ),
                                  icon:
                                      const Icon(Icons.close_rounded, size: 16),
                                  label: const Text('Reject',
                                      style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold)),
                                  onPressed: () =>
                                      _moderateProduct(idx, 'Rejected'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.flag_outlined,
                                    color: Colors.orange, size: 20),
                                tooltip: 'Flag for Inappropriate Content',
                                onPressed: () =>
                                    _moderateProduct(idx, 'Flagged'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              const SizedBox(height: 26),

              // ==========================================
              // 5. FINANCE & TRANSACTION LOGS
              // ==========================================
              _buildSectionTitle('FINANCE LOGS', Icons.receipt_long_rounded),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.035),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _buildFinanceRow(
                      icon: Icons.check_circle_outline_rounded,
                      title: 'Successful Payment',
                      amount: '+ Rs. 2,500',
                      statusColor: const Color(0xFF2E7D32),
                    ),
                    Divider(color: Colors.grey.shade200, height: 20),
                    _buildFinanceRow(
                      icon: Icons.cancel_outlined,
                      title: 'Failed Transaction (Card Void)',
                      amount: 'Rs. 1,200',
                      statusColor: const Color(0xFFD64545),
                    ),
                    Divider(color: Colors.grey.shade200, height: 20),
                    _buildFinanceRow(
                      icon: Icons.replay_rounded,
                      title: 'Refund Tracking Dispatched',
                      amount: '- Rs. 800',
                      statusColor: const Color(0xFFE65100),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFFD64545)),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF1B1B1F),
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required String label,
    required String value,
    required IconData icon,
    required Color accentColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: accentColor),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: Color(0xFF1B1B1F),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade500,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityRow(String text, String time, Color indicatorColor) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: indicatorColor,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
                color: Color(0xFF1B1B1F),
                fontSize: 13,
                fontWeight: FontWeight.w600),
          ),
        ),
        Text(
          time,
          style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildFinanceRow({
    required IconData icon,
    required String title,
    required String amount,
    required Color statusColor,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: statusColor),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
                color: Color(0xFF1B1B1F),
                fontSize: 13,
                fontWeight: FontWeight.w600),
          ),
        ),
        Text(
          amount,
          style: TextStyle(
            color: statusColor,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

// =============================================================
// SCREEN 6: SECURE ADMIN AUTHENTICATION GATEWAY
// =============================================================
class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final TextEditingController _adminIdController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _securityKeyController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Live listeners to update the lock/unlock state as you type
    _adminIdController.addListener(_onFieldChanged);
    _passwordController.addListener(_onFieldChanged);
    _securityKeyController.addListener(_onFieldChanged);
  }

  void _onFieldChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    _adminIdController.dispose();
    _passwordController.dispose();
    _securityKeyController.dispose();
    super.dispose();
  }

  bool get _isFormValid {
    return _adminIdController.text.trim().isNotEmpty &&
        _passwordController.text.trim().isNotEmpty;
  }

  Future<void> _authenticateAndEnter() async {
    final adminId = _adminIdController.text.trim();
    final password = _passwordController.text.trim();
    final code = _securityKeyController.text.trim();

    if (adminId.isEmpty || password.isEmpty) {
      _showAdminError('Portal Locked: Admin ID and Password required.');
      return;
    }
    if (!AppValidators.isValidEmail(adminId)) {
      _showAdminError(
          'Admin ID must be a valid email (e.g. root@looplab.internal).');
      return;
    }
    if (!AppValidators.isValidPassword(password)) {
      _showAdminError('Master Password must be at least 6 characters.');
      return;
    }
    if (code.isNotEmpty && !RegExp(r'^\d{6}$').hasMatch(code)) {
      _showAdminError('The authenticator code is exactly 6 digits.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      // Step 1: password + admin role check
      await AuthService.signIn(
          email: adminId, password: password, expectedRole: 'admin');

      // Step 2: authenticator code (first login = one-time setup)
      final factorId = await AuthService.verifiedTotpFactorId();
      if (factorId == null) {
        if (!mounted) return;
        final ok = await showTotpEnrollDialog(context);
        if (!ok) {
          throw AuthFailure(
              'Authenticator setup is required for admin access.');
        }
      } else {
        if (code.isEmpty) {
          throw AuthFailure(
              'Enter the 6-digit code from your authenticator app.');
        }
        await AuthService.verifyTotp(factorId: factorId, code: code);
      }

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AdminDashboardScreen()),
      );
    } catch (e) {
      await AuthService.signOutQuietly(); // never leave a half-logged-in admin
      _showAdminError(AuthService.errorMessage(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showAdminError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.shield_outlined, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: const Color(0xFFD64545),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF4F1),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Color(0xFF1B1B1F)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 22.0, vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFECE5),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.shield_rounded,
                        size: 16, color: Color(0xFFD64545)),
                    SizedBox(width: 6),
                    Text(
                      'SECURE ADMIN GATEWAY',
                      style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFD64545),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Authorized\nAccess Only',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1B1B1F),
                  height: 1.12,
                  letterSpacing: -1.0,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Platform governance requires dual-factor authentication or biometric authorization.',
                style: TextStyle(
                    fontSize: 13, color: Colors.grey.shade600, height: 1.4),
              ),
              const SizedBox(height: 26),
              _buildAdminOvalField(
                controller: _adminIdController,
                mainTerm: 'Admin ID / Encrypted Email',
                hint: 'root@looplab.internal',
                icon: Icons.badge_outlined,
              ),
              const SizedBox(height: 16),
              _buildAdminOvalField(
                controller: _passwordController,
                mainTerm: 'Master Password',
                hint: '••••••••••••••••',
                icon: Icons.lock_outline_rounded,
                isPassword: true,
                obscureText: _obscurePassword,
                onTogglePassword: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
              const SizedBox(height: 16),
              _buildAdminOvalField(
                controller: _securityKeyController,
                mainTerm: 'Authenticator Code (2FA)',
                hint: '6-digit code (blank on first login)',
                icon: Icons.vpn_key_outlined,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 58,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isFormValid
                          ? const Color(0xFF1B1B1F)
                          : const Color(0xFFD64545),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: const StadiumBorder(),
                    ),
                    onPressed: _isLoading ? null : _authenticateAndEnter,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _isFormValid
                              ? Icons.lock_open_rounded
                              : Icons.lock_rounded,
                          size: 20,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          _isFormValid
                              ? 'Unlock & Enter Dashboard'
                              : 'Locked — Enter All Credentials',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: Text(
                  'End-to-End Encrypted Gateway • LoopLab 2026',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAdminOvalField({
    required TextEditingController controller,
    required String mainTerm,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    bool obscureText = false,
    VoidCallback? onTogglePassword,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 14.0, bottom: 6.0),
          child: Text(
            mainTerm,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1B1B1F),
              letterSpacing: 0.2,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(35),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.035),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: TextField(
            controller: controller,
            obscureText: obscureText,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1B1B1F),
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                color: Colors.grey.shade400,
                fontSize: 13,
                fontWeight: FontWeight.w400,
              ),
              prefixIcon: Padding(
                padding: const EdgeInsets.only(left: 16, right: 12),
                child: Icon(icon, size: 20, color: const Color(0xFFD64545)),
              ),
              suffixIcon: isPassword
                  ? Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: IconButton(
                        icon: Icon(
                          obscureText
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          size: 20,
                          color: Colors.grey.shade500,
                        ),
                        onPressed: onTogglePassword,
                      ),
                    )
                  : null,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(35),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(35),
                borderSide:
                    const BorderSide(color: Color(0xFFD64545), width: 1.5),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// =============================================================
// SCREEN 7: SELLER MASTER HUB (3 TABS: DASHBOARD, INVENTORY, ME)
// =============================================================
class SellerDashboardScreen extends StatefulWidget {
  final String storeName;
  const SellerDashboardScreen(
      {super.key, this.storeName = 'Aura Luxury Studio'});

  @override
  State<SellerDashboardScreen> createState() => _SellerDashboardScreenState();
}

class _SellerDashboardScreenState extends State<SellerDashboardScreen> {
  int _currentTabIndex = 0;

    final List<Map<String, dynamic>> _catalog = [];
  bool _catalogLoading = true;
  String? _catalogError;
  int _overviewRefresh = 0;

  @override
  void initState() {
    super.initState();
    _loadCatalog();
  }

  Future<void> _loadCatalog() async {
    setState(() {
      _catalogLoading = true;
      _catalogError = null;
    });
    try {
      final items = await SellerService.fetchProducts();
      if (!mounted) return;
      setState(() {
        _catalog
          ..clear()
          ..addAll(items);
        _catalogLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _catalogError = SellerService.errorMessage(e);
        _catalogLoading = false;
      });
    }
  }

  void _toast(String message,
      {bool error = false, bool success = false, int seconds = 2}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error
            ? const Color(0xFFD64545)
            : success
                ? const Color(0xFF2E7D32)
                : const Color(0xFF1B1B1F),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        duration: Duration(seconds: seconds),
      ),
    );
  }

  int _indexOfId(String id) => _catalog.indexWhere((p) => p['id'] == id);

  Future<void> _updateStock(int index, int delta) async {
    final id = _catalog[index]['id'] as String;
    final current = _catalog[index]['stock'] as int;
    if (current + delta < 0) return;
    setState(() => _catalog[index]['stock'] = current + delta);
    try {
      final serverStock = await SellerService.adjustStock(id, delta);
      if (!mounted) return;
      final i = _indexOfId(id);
      if (i >= 0) setState(() => _catalog[i]['stock'] = serverStock);
    } catch (e) {
      if (!mounted) return;
      final i = _indexOfId(id);
      if (i >= 0) {
        setState(
            () => _catalog[i]['stock'] = (_catalog[i]['stock'] as int) - delta);
      }
      _toast(SellerService.errorMessage(e), error: true);
    }
  }

  Future<void> _deleteProduct(int index) async {
    final id = _catalog[index]['id'] as String;
    final deletedTitle = _catalog[index]['title'];
    try {
      await SellerService.deleteProduct(id);
      if (!mounted) return;
      final i = _indexOfId(id);
      if (i >= 0) setState(() => _catalog.removeAt(i));
      _toast('Removed "$deletedTitle" from catalog.', seconds: 1);
    } catch (e) {
      _toast(SellerService.errorMessage(e), error: true);
    }
  }

  Future<void> _updateProduct(
      int index, Map<String, dynamic> updatedProduct) async {
    try {
      final saved = await SellerService.updateProduct(updatedProduct);
      if (!mounted) return;
      final i = _indexOfId(saved['id'] as String);
      if (i >= 0) setState(() => _catalog[i] = saved);
      _toast('Updated "${saved['title']}" successfully!',
          success: true, seconds: 1);
    } catch (e) {
      _toast(SellerService.errorMessage(e), error: true);
    }
  }

  /// null = success, otherwise an error message for the Add sheet.
  Future<String?> _addProduct(Map<String, dynamic> newProduct) async {
    try {
      final saved = await SellerService.addProduct(newProduct);
      if (!mounted) return null;
      setState(() => _catalog.insert(0, saved));
      _toast('"${saved['title']}" added. It goes live once admin approves it.',
          success: true);
      return null;
    } catch (e) {
      return SellerService.errorMessage(e);
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF4F1),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        // BACK ARROW: Only appears on Inventory (1) and Me (2) and navigates back to Dashboard (0)
        leading: _currentTabIndex != 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Color(0xFF1B1B1F)),
                onPressed: () => setState(() {
                  _currentTabIndex = 0;
                  _overviewRefresh++;
                }),
              )
            : null,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.storeName.toUpperCase(),
              style: const TextStyle(
                color: Color(0xFF1B1B1F),
                fontSize: 13,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
            Row(
              children: [
                const Icon(Icons.circle, color: Color(0xFF2E7D32), size: 7),
                const SizedBox(width: 5),
                Text(
                  _currentTabIndex == 0
                      ? 'Live Overview'
                      : _currentTabIndex == 1
                          ? 'Catalog & Inventory'
                          : 'Seller Profile (Me)',
                  style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 11,
                      fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Icon(Icons.notifications_none_rounded,
                color: Color(0xFF1B1B1F), size: 20),
          ),
        ],
      ),
            body: _catalogLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFD64545)))
          : _catalogError != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_catalogError!,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey.shade700)),
                        const SizedBox(height: 14),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFD64545),
                            foregroundColor: Colors.white,
                            shape: const StadiumBorder(),
                          ),
                          onPressed: _loadCatalog,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : IndexedStack(
                  index: _currentTabIndex,
        children: [
          _SellerOverviewTab(
            catalog: _catalog,
            onGoToInventory: () => setState(() => _currentTabIndex = 1),
            refreshToken: _overviewRefresh,
          ),
          _SellerInventoryTab(
            catalog: _catalog,
            onStockChange: _updateStock,
            onDelete: _deleteProduct,
            onEdit: _updateProduct, // Hooked up edit callback
            onAddProduct: _addProduct,
          ),
          SellerProfileScreen(
                      storeName: widget.storeName,
                      sellerId: SellerService.sellerCode(),
                    ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          margin: const EdgeInsets.only(left: 20, right: 20, bottom: 12),
          height: 66,
          decoration: BoxDecoration(
            color: const Color(0xFF1B1B1F),
            borderRadius: BorderRadius.circular(35),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 22,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildFloatingNavItem(
                index: 0,
                icon: Icons.grid_view_rounded,
                label: 'Dashboard',
              ),
              _buildFloatingNavItem(
                index: 1,
                icon: Icons.inventory_2_rounded,
                label: 'Inventory',
                badgeCount: _catalog
                    .where((i) =>
                        (i['stock'] as int) <= (i['lowThreshold'] as int))
                    .length,
              ),
              _buildFloatingNavItem(
                index: 2,
                icon: Icons.person_outline_rounded,
                label: 'Me',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingNavItem({
    required int index,
    required IconData icon,
    required String label,
    int badgeCount = 0,
  }) {
    final bool isSelected = _currentTabIndex == index;
    return GestureDetector(
      onTap: () => setState(() {
        _currentTabIndex = index;
        if (index == 0) _overviewRefresh++;
      }),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFD64545) : Colors.transparent,
          borderRadius: BorderRadius.circular(25),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: isSelected ? Colors.white : Colors.white60,
                ),
                if (badgeCount > 0)
                  Positioned(
                    right: -6,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '$badgeCount',
                        style: const TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFFD64545),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// =============================================================
// TAB 1: PRODUCT & INVENTORY MANAGEMENT VIEW (WITH EDIT & DELETE)
// =============================================================
class _SellerInventoryTab extends StatefulWidget {
  final List<Map<String, dynamic>> catalog;
  final Function(int, int) onStockChange;
  final Function(int) onDelete;
  final Function(int, Map<String, dynamic>) onEdit;
  final Function(Map<String, dynamic>) onAddProduct;

  const _SellerInventoryTab({
    required this.catalog,
    required this.onStockChange,
    required this.onDelete,
    required this.onEdit,
    required this.onAddProduct,
  });

  @override
  State<_SellerInventoryTab> createState() => _SellerInventoryTabState();
}

class _SellerInventoryTabState extends State<_SellerInventoryTab> {
  String _selectedCategory = 'All';
  String _searchQuery = '';

  final List<String> _categories = [
    'All',
    'Bags',
    'Shoes',
    'Apparel',
    'Accessories'
  ];

  void _openAddProductSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AddProductSheet(
        onAdd: widget.onAddProduct,
      ),
    );
  }

  void _openBulkUploadSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _BulkUploadSheet(
        onImportSimulated: (count) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text('Successfully parsed and imported $count SKU records!'),
              backgroundColor: const Color(0xFF2E7D32),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredCatalog = widget.catalog.where((item) {
      final matchesCategory =
          _selectedCategory == 'All' || item['category'] == _selectedCategory;
      final matchesSearch = item['title']
              .toString()
              .toLowerCase()
              .contains(_searchQuery.toLowerCase()) ||
          item['sku']
              .toString()
              .toLowerCase()
              .contains(_searchQuery.toLowerCase());
      return matchesCategory && matchesSearch;
    }).toList();

    final lowStockCount = widget.catalog
        .where((i) => (i['stock'] as int) <= (i['lowThreshold'] as int))
        .length;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Action Buttons: + Add Product & Bulk Upload
          Row(
            children: [
              Expanded(
                flex: 6,
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD64545),
                      foregroundColor: Colors.white,
                      shape: const StadiumBorder(),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.add_rounded, size: 20),
                    label: const Text(
                      'Add Product',
                      style:
                          TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                    ),
                    onPressed: _openAddProductSheet,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 5,
                child: SizedBox(
                  height: 48,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF1B1B1F),
                      side: const BorderSide(
                          color: Color(0xFFEDE3DE), width: 1.5),
                      shape: const StadiumBorder(),
                    ),
                    icon: const Icon(Icons.table_view_rounded,
                        size: 18, color: Color(0xFF2E7D32)),
                    label: const Text(
                      'Bulk Import',
                      style:
                          TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                    ),
                    onPressed: _openBulkUploadSheet,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Inventory Summary Pill Metric Strip
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildQuickMetric('Catalog Total', '${widget.catalog.length}',
                    const Color(0xFF1B1B1F)),
                Container(height: 24, width: 1, color: Colors.grey.shade200),
                _buildQuickMetric(
                    'Active Units',
                    '${widget.catalog.fold<int>(0, (sum, i) => sum + (i['stock'] as int))}',
                    const Color(0xFF2E7D32)),
                Container(height: 24, width: 1, color: Colors.grey.shade200),
                _buildQuickMetric('Low Stock Alert', '$lowStockCount',
                    const Color(0xFFD64545)),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Search & Filter Box
          Container(
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: InputDecoration(
                hintText: 'Search by SKU (LL-...) or Title',
                hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                prefixIcon: const Icon(Icons.search_rounded,
                    size: 20, color: Color(0xFFD64545)),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Category Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _categories.map((cat) {
                final bool isSelected = _selectedCategory == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: FilterChip(
                    label: Text(cat),
                    selected: isSelected,
                    onSelected: (_) => setState(() => _selectedCategory = cat),
                    backgroundColor: Colors.white,
                    selectedColor: const Color(0xFFFFECE5),
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight:
                          isSelected ? FontWeight.w800 : FontWeight.w600,
                      color: isSelected
                          ? const Color(0xFFD64545)
                          : Colors.grey.shade700,
                    ),
                    shape: StadiumBorder(
                      side: BorderSide(
                        color: isSelected
                            ? const Color(0xFFD64545)
                            : Colors.grey.shade200,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 18),

          // Product Card List
          if (filteredCatalog.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              alignment: Alignment.center,
              child: Text(
                'No products matching filters.',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filteredCatalog.length,
              itemBuilder: (context, index) {
                final item = filteredCatalog[index];
                final int originalIndex = widget.catalog.indexOf(item);
                final bool isLowStock =
                    (item['stock'] as int) <= (item['lowThreshold'] as int);

                return Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: isLowStock
                          ? const Color(0xFFD64545).withValues(alpha: 0.35)
                          : Colors.transparent,
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.035),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFECE5),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(Icons.diamond_outlined,
                                color: Color(0xFFD64545), size: 24),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        item['title'],
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF1B1B1F),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    // ✏️ EDIT PRODUCT BUTTON BESIDE DELETE
                                    IconButton(
                                      constraints: const BoxConstraints(),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 4),
                                      icon: const Icon(Icons.edit_outlined,
                                          color: Color(0xFF1B1B1F), size: 19),
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                EditProductScreen(
                                              product: item,
                                              onSave: (updated) =>
                                                  widget.onEdit(
                                                      originalIndex, updated),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                    // 🗑️ DELETE PRODUCT BUTTON
                                    IconButton(
                                      constraints: const BoxConstraints(),
                                      padding: EdgeInsets.zero,
                                      icon: const Icon(
                                          Icons.delete_outline_rounded,
                                          color: Colors.grey,
                                          size: 20),
                                      onPressed: () =>
                                          widget.onDelete(originalIndex),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF7F3F0),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        item['sku'],
                                        style: const TextStyle(
                                          fontFamily: 'monospace',
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF1B1B1F),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Rs. ${item['price'].toStringAsFixed(0)}',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFFD64545),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Divider(color: Colors.grey.shade100, height: 1),
                      const SizedBox(height: 10),

                      // Variants Display (Sizes & Color Dots)
                      Row(
                        children: [
                          const Text('Variants: ',
                              style:
                                  TextStyle(fontSize: 11, color: Colors.grey)),
                          ...(item['sizes'] as List<String>)
                              .map((size) => Container(
                                    margin: const EdgeInsets.only(right: 4),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(size,
                                        style: const TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold)),
                                  )),
                          const SizedBox(width: 8),
                          ...(item['colors'] as List<Color>)
                              .map((color) => Container(
                                    margin: const EdgeInsets.only(right: 5),
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: color,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: Colors.white, width: 1.5),
                                      boxShadow: [
                                        BoxShadow(
                                            color: Colors.black
                                                .withValues(alpha: 0.1),
                                            blurRadius: 2),
                                      ],
                                    ),
                                  )),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Live Stock Stepper
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    isLowStock
                                        ? Icons.warning_rounded
                                        : Icons.check_circle_rounded,
                                    size: 14,
                                    color: isLowStock
                                        ? const Color(0xFFD64545)
                                        : const Color(0xFF2E7D32),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    isLowStock
                                        ? 'Low Stock Triggered'
                                        : 'Stock Optimal',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: isLowStock
                                          ? const Color(0xFFD64545)
                                          : const Color(0xFF2E7D32),
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                'Alert threshold: <= ${item['lowThreshold']} units',
                                style: TextStyle(
                                    fontSize: 10, color: Colors.grey.shade400),
                              ),
                            ],
                          ),
                          Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFF7F3F0),
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove, size: 16),
                                  onPressed: () =>
                                      widget.onStockChange(originalIndex, -1),
                                ),
                                Text(
                                  '${item['stock']}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                    color: isLowStock
                                        ? const Color(0xFFD64545)
                                        : const Color(0xFF1B1B1F),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.add, size: 16),
                                  onPressed: () =>
                                      widget.onStockChange(originalIndex, 1),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildQuickMetric(String title, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
              fontSize: 18, fontWeight: FontWeight.w900, color: color),
        ),
        const SizedBox(height: 2),
        Text(
          title,
          style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade500,
              fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

// =============================================================
// MODAL SHEET: ADD NEW PRODUCT WITH VARIANTS & SKU
// =============================================================
class _AddProductSheet extends StatefulWidget {
  final Function(Map<String, dynamic>) onAdd;
  const _AddProductSheet({required this.onAdd});

  @override
  State<_AddProductSheet> createState() => _AddProductSheetState();
}

class _AddProductSheetState extends State<_AddProductSheet> {
  final _titleController = TextEditingController();
  final _skuController = TextEditingController();
  final _priceController = TextEditingController();
  final _stockController = TextEditingController();
  final _lowThresholdController = TextEditingController(text: '5');

  String _category = 'Bags';
  final List<String> _selectedSizes = [];
  final List<Color> _selectedColors = [];

  final List<String> _sizeOptions = [
    'XS',
    'S',
    'M',
    'L',
    'XL',
    'One Size',
    '40',
    '41',
    '42',
    '43'
  ];
  final List<Color> _colorOptions = [
    const Color(0xFF1B1B1F),
    const Color(0xFFD64545),
    Colors.brown,
    const Color(0xFFFFD8CC),
    const Color(0xFF2E7D32),
    Colors.grey,
  ];

  @override
  void initState() {
    super.initState();
    _skuController.text = 'LL-${Random().nextInt(900) + 100}';
  }

    bool _saving = false;

  void _showSheetError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFD64545),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  Future<void> _submit() async {
    if (_saving) return;
    if (_titleController.text.trim().isEmpty ||
        _priceController.text.trim().isEmpty ||
        _stockController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Title, Price, and Stock count are required.'),
          backgroundColor: const Color(0xFFD64545),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      );
      return;
    }

    final newProduct = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'title': _titleController.text.trim(),
      'sku': _skuController.text.trim().toUpperCase(),
      'category': _category,
      'price': double.tryParse(_priceController.text.trim()) ?? 0.0,
      'stock': int.tryParse(_stockController.text.trim()) ?? 0,
      'lowThreshold': int.tryParse(_lowThresholdController.text.trim()) ?? 5,
      'sizes': _selectedSizes.isEmpty ? ['Standard'] : _selectedSizes,
      'colors':
          _selectedColors.isEmpty ? [const Color(0xFF1B1B1F)] : _selectedColors,
    };

        if (double.tryParse(_priceController.text.trim()) == null ||
        int.tryParse(_stockController.text.trim()) == null ||
        int.tryParse(_lowThresholdController.text.trim()) == null) {
      _showSheetError(
          'Price must be a number. Stock and alert threshold must be whole numbers.');
      return;
    }

    setState(() => _saving = true);
    final dynamic error = await widget.onAdd(newProduct);
    if (!mounted) return;
    setState(() => _saving = false);
    if (error is String) {
      _showSheetError(error);
      return;
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: 24,
        left: 24,
        right: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Add New Catalog Item',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1B1B1F)),
            ),
            const SizedBox(height: 4),
            Text('Assign SKU codes, variant tags, and safety thresholds.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            const SizedBox(height: 20),

            TextField(
              controller: _titleController,
              decoration: _sheetFieldDecoration(
                  'Product Name (e.g. Suede Chelsea Boots)'),
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _skuController,
                    decoration: _sheetFieldDecoration('SKU Code'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F3F0),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _category,
                        isExpanded: true,
                        items: ['Bags', 'Shoes', 'Apparel', 'Accessories']
                            .map((c) => DropdownMenuItem(
                                value: c,
                                child: Text(c,
                                    style: const TextStyle(fontSize: 13))))
                            .toList(),
                        onChanged: (val) => setState(() => _category = val!),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _priceController,
                    keyboardType: TextInputType.number,
                    decoration: _sheetFieldDecoration('Price (Rs.)'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _stockController,
                    keyboardType: TextInputType.number,
                    decoration: _sheetFieldDecoration('Initial Stock'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _lowThresholdController,
                    keyboardType: TextInputType.number,
                    decoration: _sheetFieldDecoration('Alert Min'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Variant Selector: Sizes
            const Text('Size Variants',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              children: _sizeOptions.map((sz) {
                final isSelected = _selectedSizes.contains(sz);
                return ChoiceChip(
                  label: Text(sz),
                  selected: isSelected,
                  selectedColor: const Color(0xFFFFECE5),
                  labelStyle: TextStyle(
                    fontSize: 11,
                    color:
                        isSelected ? const Color(0xFFD64545) : Colors.black87,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                  onSelected: (val) {
                    setState(() {
                      val ? _selectedSizes.add(sz) : _selectedSizes.remove(sz);
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 14),

            // Variant Selector: Colors
            const Text('Color Variants',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Row(
              children: _colorOptions.map((c) {
                final isSelected = _selectedColors.contains(c);
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      isSelected
                          ? _selectedColors.remove(c)
                          : _selectedColors.add(c);
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 10),
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFFD64545)
                            : Colors.grey.shade300,
                        width: isSelected ? 3 : 1,
                      ),
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, size: 14, color: Colors.white)
                        : null,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD64545),
                  foregroundColor: Colors.white,
                  shape: const StadiumBorder(),
                  elevation: 0,
                ),
                onPressed: _saving ? null : _submit,
                child: const Text('Add to Live Catalog',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _sheetFieldDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
      filled: true,
      fillColor: const Color(0xFFF7F3F0),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
    );
  }
}

// =============================================================
// MODAL SHEET: EXCEL / CSV BULK IMPORT SIMULATOR
// =============================================================
class _BulkUploadSheet extends StatefulWidget {
  final Function(int) onImportSimulated;
  const _BulkUploadSheet({required this.onImportSimulated});

  @override
  State<_BulkUploadSheet> createState() => _BulkUploadSheetState();
}

class _BulkUploadSheetState extends State<_BulkUploadSheet> {
  bool _isUploading = false;

  void _triggerSimulatedUpload() async {
    setState(() => _isUploading = true);
    await Future.delayed(const Duration(milliseconds: 1400));
    if (!mounted) return;
    Navigator.pop(context);
    widget.onImportSimulated(14);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(26),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 5,
            decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10)),
          ),
          const SizedBox(height: 20),
          const Icon(Icons.cloud_upload_outlined,
              size: 48, color: Color(0xFFD64545)),
          const SizedBox(height: 12),
          const Text(
            'Bulk Catalog Import',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: Color(0xFF1B1B1F)),
          ),
          const SizedBox(height: 6),
          Text(
            'Upload your .xlsx, .xls, or .csv spreadsheet with columns: Title, SKU, Category, Price, Stock, Variants.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 12, color: Colors.grey.shade600, height: 1.4),
          ),
          const SizedBox(height: 24),
          InkWell(
            onTap: _isUploading ? null : _triggerSimulatedUpload,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F3F0),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: const Color(0xFFFFD0C5),
                    width: 1.5,
                    style: BorderStyle.solid),
              ),
              child: Column(
                children: [
                  if (_isUploading) ...[
                    const CircularProgressIndicator(color: Color(0xFFD64545)),
                    const SizedBox(height: 12),
                    const Text('Parsing SKU rows & validating format...',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.bold)),
                  ] else ...[
                    const Icon(Icons.file_present_rounded,
                        color: Color(0xFF2E7D32), size: 32),
                    const SizedBox(height: 8),
                    const Text('Tap to Choose looplab_catalog.xlsx',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700)),
                    Text('Accepts Excel / CSV up to 10MB',
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade500)),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
        ],
      ),
    );
  }
}

// =============================================================
// SUB-TAB 0: OVERVIEW (METRICS, TRENDS, INVENTORY & PENDING TASKS)
// =============================================================
class _SellerOverviewTab extends StatefulWidget {
  final List<Map<String, dynamic>> catalog;
  final VoidCallback onGoToInventory;
  final int refreshToken;

  const _SellerOverviewTab({
    required this.catalog,
    required this.onGoToInventory,
    this.refreshToken = 0,
  });
  @override
  State<_SellerOverviewTab> createState() => _SellerOverviewTabState();
}

class _SellerOverviewTabState extends State<_SellerOverviewTab> {
    bool _isWeekly = true;
  Map<String, dynamic>? _m;
  List<Map<String, dynamic>> _pendingTasks = [];

  @override
  void initState() {
    super.initState();
    _loadMetrics();
  }

  @override
  void didUpdateWidget(covariant _SellerOverviewTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) _loadMetrics();
  }

  Future<void> _loadMetrics() async {
    final period = _isWeekly ? 'week' : 'month';
    try {
      final m = await SellerService.overview(period);
      if (!mounted || period != (_isWeekly ? 'week' : 'month')) return;
      final dispatch = (m['pending_dispatch'] as num).toInt();
      setState(() {
        _m = m;
        _pendingTasks = [
          if (dispatch > 0)
            {
              'task':
                  'Dispatch $dispatch ${dispatch == 1 ? 'shipment' : 'shipments'} to courier',
              'due': 'Today',
              'urgent': true,
              'icon': Icons.local_shipping_outlined,
            },
        ];
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(SellerService.errorMessage(e)),
          backgroundColor: const Color(0xFFD64545),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      );
    }
  }

  void _setPeriod(bool weekly) {
    if (_isWeekly == weekly) return;
    setState(() => _isWeekly = weekly);
    _loadMetrics();
  }

  num _num(String key) => (_m?[key] as num?) ?? 0;

  int _pipe(String key) =>
      (((_m?['pipeline'] as Map?)?[key]) as num?)?.toInt() ?? 0;

  String _short(double v) {
    if (v >= 1000) {
      final k = v / 1000;
      return 'Rs. ${k == k.roundToDouble() ? k.round() : k.toStringAsFixed(1)}K';
    }
    return 'Rs. ${v.round()}';
  }

  List<Map<String, dynamic>> get _series {
    final wanted = _isWeekly ? 'week' : 'month';
    final s = _m?['series'];
    if (_m?['period'] == wanted && s is List && s.isNotEmpty) {
      return s
          .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }
    final labels = _isWeekly
        ? const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
        : const ['Wk 1', 'Wk 2', 'Wk 3', 'Wk 4'];
    return [
      for (final l in labels) {'label': l, 'value': 0, 'amount': 0}
    ];
  }

  String get _peakText {
    double best = 0;
    String label = '';
    for (final e in _series) {
      final a = (e['amount'] as num).toDouble();
      if (a > best) {
        best = a;
        label = e['label'] as String;
      }
    }
    if (best <= 0) return 'No sales in this period yet';
    return 'Peak: $label (${_short(best)})';
  }

  String get _changeLabel {
    final c = _m?['change_pct'] as num?;
    if (c == null) return 'New';
    return '${c >= 0 ? '+' : ''}${c.toStringAsFixed(1)}%';
  }

  bool get _changeUp => ((_m?['change_pct'] as num?) ?? 0) >= 0;
  @override
  Widget build(BuildContext context) {
        final series = _series;
    final activeData =
        series.map<double>((e) => (e['value'] as num).toDouble()).toList();
    final activeLabels =
        series.map<String>((e) => e['label'] as String).toList();
    final double rawMax = activeData.reduce(max);
    final double maxVal = rawMax <= 0 ? 1 : rawMax;
    final lowStockItems = widget.catalog
        .where((i) => (i['stock'] as int) <= (i['lowThreshold'] as int))
        .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Gross Revenue Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: const Color(0xFF1B1B1F),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFECE5).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'GROSS REVENUE',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.0,
                          color: Color(0xFFFFD8CC),
                        ),
                      ),
                    ),
                    
                                        Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: (_changeUp
                                ? const Color(0xFF2E7D32)
                                : const Color(0xFFD64545))
                            .withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(
                              _changeUp
                                  ? Icons.arrow_upward_rounded
                                  : Icons.arrow_downward_rounded,
                              color: _changeUp
                                  ? const Color(0xFF4CAF50)
                                  : const Color(0xFFEF9A9A),
                              size: 12),
                          const SizedBox(width: 4),
                          Text(
                            _changeLabel,
                            style: TextStyle(
                              color: _changeUp
                                  ? const Color(0xFF81C784)
                                  : const Color(0xFFEF9A9A),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                                Text(
                  'Rs. ${SellerService.money(_num('revenue'))}',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1.0,
                  ),
                ),
                const SizedBox(height: 18),
                Divider(color: Colors.white.withValues(alpha: 0.12), height: 1),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _subMetric('Orders', '${_num('orders').toInt()}', Icons.shopping_bag_outlined),
                    _subMetric('Avg Ticket', _short(_num('avg_ticket').toDouble()), Icons.receipt_outlined),
                    _subMetric('Products', '${widget.catalog.length}',
                        Icons.grid_view_rounded),
                  ],
                ),
                const SizedBox(height: 16),
                Divider(color: Colors.white.withValues(alpha: 0.12), height: 1),
                const SizedBox(height: 12),

                // ORDER PIPELINE (UNCONFIRMED / SHIPPING / IN REVIEW)
                const Text(
                  'ORDER STATUS PIPELINE (TAP TO VIEW)',
                  style: TextStyle(
                      color: Colors.white60,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _buildPipelineChip(
                      context: context,
                      status: 'Unconfirmed',
                                            count: '${_pipe('unconfirmed')}',
                      onReturn: _loadMetrics,
                      badgeColor: const Color(0xFFD64545),
                    ),
                    const SizedBox(width: 8),
                    _buildPipelineChip(
                      context: context,
                      status: 'Shipping',
                                            count: '${_pipe('shipping')}',
                      onReturn: _loadMetrics,
                      badgeColor: Colors.amber.shade700,
                    ),
                    const SizedBox(width: 8),
                    _buildPipelineChip(
                      context: context,
                      status: 'In Review',
                                            count: '${_pipe('in_review')}',
                      onReturn: _loadMetrics,
                      badgeColor: const Color(0xFF5C6BC0),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 2. Sales Trend Graph
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _sectionHeader('SALES PERFORMANCE', Icons.insights_rounded),
              Container(
                height: 34,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: const Color(0xFFEDE3DE),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    _pillToggle('Weekly', _isWeekly, () => _setPeriod(true)),
                    _pillToggle('Monthly', !_isWeekly, () => _setPeriod(false)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.035),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _peakText,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const Text('Units: Thousands',
                        style: TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 120,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(activeData.length, (idx) {
                      final double heightPercent = activeData[idx] / maxVal;
                      final bool isMax = activeData[idx] == maxVal;
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            activeData[idx] == activeData[idx].roundToDouble()
                                ? '${activeData[idx].toInt()}'
                                : activeData[idx].toStringAsFixed(1),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isMax
                                  ? const Color(0xFFD64545)
                                  : Colors.grey.shade500,
                            ),
                          ),
                          const SizedBox(height: 6),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 350),
                            width: _isWeekly ? 22 : 44,
                            height: 80 * heightPercent,
                            decoration: BoxDecoration(
                              color: isMax
                                  ? const Color(0xFFD64545)
                                  : const Color(0xFFEDE3DE),
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            activeLabels[idx],
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isMax
                                  ? const Color(0xFF1B1B1F)
                                  : Colors.grey.shade500,
                            ),
                          ),
                        ],
                      );
                    }),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 3. Critical Inventory Alerts
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _sectionHeader('CRITICAL INVENTORY', Icons.warning_amber_rounded),
              GestureDetector(
                onTap: widget.onGoToInventory,
                child: const Text(
                  'Manage All →',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFD64545)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Column(
            children: lowStockItems.map((item) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.025),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.circle, color: Color(0xFFD64545), size: 8),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        item['title'] as String,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Text(
                      '${item['stock']} remaining',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFFD64545),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),

          // 4. Pending Operational Tasks
          _sectionHeader('PENDING OPERATIONAL TASKS', Icons.checklist_rounded),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.035),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
                        child: _pendingTasks.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      'No pending tasks. You are all caught up.',
                      style: TextStyle(
                          fontSize: 12.5, color: Colors.grey.shade500),
                    ),
                  )
                : ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _pendingTasks.length,
              separatorBuilder: (_, __) =>
                  Divider(color: Colors.grey.shade100, height: 1),
              itemBuilder: (context, index) {
                final task = _pendingTasks[index];
                final bool isUrgent = task['urgent'] as bool;
                return ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: CircleAvatar(
                    radius: 18,
                    backgroundColor: isUrgent
                        ? const Color(0xFFFFECE5)
                        : const Color(0xFFF7F3F0),
                    child: Icon(
                      task['icon'] as IconData,
                      size: 18,
                      color: isUrgent
                          ? const Color(0xFFD64545)
                          : const Color(0xFF1B1B1F),
                    ),
                  ),
                  title: Text(
                    task['task'] as String,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1B1B1F)),
                  ),
                  subtitle: Text(
                    task['due'] as String,
                    style: TextStyle(
                      fontSize: 11,
                      color: isUrgent
                          ? const Color(0xFFD64545)
                          : Colors.grey.shade500,
                      fontWeight:
                          isUrgent ? FontWeight.w700 : FontWeight.normal,
                    ),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded,
                      color: Colors.grey, size: 14),
                                   onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SellerOrdersScreen(),
                      ),
                    ).then((_) => _loadMetrics());
                  },

                );
              },
            ),
          ),
          const SizedBox(height: 60),
        ],
      ),
    );
  }

  Widget _pillToggle(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: isSelected ? const Color(0xFFD64545) : Colors.grey.shade700,
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFFD64545)),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF1B1B1F),
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.1,
          ),
        ),
      ],
    );
  }

  Widget _subMetric(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: Colors.white54, size: 16),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 13),
            ),
            Text(label,
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6), fontSize: 10)),
          ],
        ),
      ],
    );
  }
}

Widget _buildPipelineChip({
  required BuildContext context,
  required String status,
  required String count,
  required Color badgeColor,
  VoidCallback? onReturn,
}) {
  return Expanded(
    child: InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
                        builder: (context) => const SellerOrdersScreen(),
          ),
        ).then((_) => onReturn?.call());
      },
      borderRadius: BorderRadius.circular(12),

      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                  color: badgeColor, borderRadius: BorderRadius.circular(10)),
              child: Text(count,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w900)),
            ),
            const SizedBox(height: 4),
            Text(
              status,
              style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                  fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    ),
  );
}

// =============================================================
// SUB-TAB 2: ORDERS FULFILLMENT & PROMOTIONS MANAGEMENT
// =============================================================
class _SellerOrdersTab extends StatefulWidget {
  const _SellerOrdersTab();

  @override
  State<_SellerOrdersTab> createState() => _SellerOrdersTabState();
}

class _SellerOrdersTabState extends State<_SellerOrdersTab> {
  int _activeSubView = 0;

    final List<Map<String, dynamic>> _orders = [];
  final List<Map<String, dynamic>> _coupons = [];
  bool _loading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    try {
      final results = await Future.wait([
        SellerService.fetchOrders(),
        SellerService.fetchCoupons(),
      ]);
      if (!mounted) return;
      setState(() {
        _orders
          ..clear()
          ..addAll(results[0]);
        _coupons
          ..clear()
          ..addAll(results[1]);
        _loading = false;
        _loadError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = SellerService.errorMessage(e);
      });
    }
  }

  void _snack(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            error ? const Color(0xFFD64545) : const Color(0xFF1B1B1F),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget _statusNote(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 12),
      child: Center(
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
        ),
      ),
    );
  }

  Future<void> _advanceOrderStatus(int index) async {
    final orderId = _orders[index]['orderId'] as String;
    try {
      final res = await SellerService.advanceOrder(orderId);
      if (!mounted) return;
      setState(() {
        final i = _orders.indexWhere((o) => o['orderId'] == orderId);
        if (i >= 0) {
          _orders[i]['status'] = res['status'];
          _orders[i]['trackingId'] = (res['tracking_id'] as String?) ?? '';
        }
      });
      _snack('Order $orderId advanced to ${res['status']}!');
    } catch (e) {
      _snack(SellerService.errorMessage(e), error: true);
      _loadAll();
    }
  }

  void _editTrackingId(int index) {
    final orderId = _orders[index]['orderId'] as String;
    final controller =
        TextEditingController(text: _orders[index]['trackingId'] as String);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Courier Tracking: ${_orders[index]['orderId']}',
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1B1B1F)),
            ),
            const SizedBox(height: 4),
            Text('Attach courier dispatch airway bill number.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            const SizedBox(height: 18),
            TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: 'e.g. TCS-772910-PK or LCS-Express',
                filled: true,
                fillColor: const Color(0xFFF7F3F0),
                prefixIcon: const Icon(Icons.local_shipping_outlined,
                    color: Color(0xFFD64545)),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1B1B1F),
                  foregroundColor: Colors.white,
                  shape: const StadiumBorder(),
                ),
                onPressed: () async {
                  try {
                    final saved =
                        await SellerService.setTracking(orderId, controller.text);
                    if (!mounted) return;
                    setState(() {
                      final i =
                          _orders.indexWhere((o) => o['orderId'] == orderId);
                      if (i >= 0) _orders[i]['trackingId'] = saved;
                    });
                    Navigator.pop(context);
                  } catch (e) {
                    _snack(SellerService.errorMessage(e), error: true);
                  }
                },
                child: const Text('Save Tracking Details',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openCreateCouponSheet() {
    final codeCtrl = TextEditingController();
    final discountCtrl = TextEditingController();
    final minSpendCtrl = TextEditingController();
    String type = 'Percentage';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Generate Promo Coupon',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1B1B1F)),
              ),
              const SizedBox(height: 4),
              Text('Incentivize buyers with percentage or flat discounts.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              const SizedBox(height: 18),
              TextField(
                controller: codeCtrl,
                textCapitalization: TextCapitalization.characters,
                decoration: _fieldStyle('Coupon Code (e.g. FLASH25)',
                    Icons.confirmation_number_outlined),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: discountCtrl,
                      keyboardType: TextInputType.number,
                      decoration: _fieldStyle(
                          type == 'Percentage' ? 'Value (%)' : 'Amount (Rs.)',
                          Icons.percent_rounded),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F3F0),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: type,
                          isExpanded: true,
                          items: ['Percentage', 'Flat']
                              .map((t) => DropdownMenuItem(
                                  value: t,
                                  child: Text(t,
                                      style: const TextStyle(fontSize: 13))))
                              .toList(),
                          onChanged: (val) => setSheetState(() => type = val!),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: minSpendCtrl,
                keyboardType: TextInputType.number,
                decoration: _fieldStyle('Minimum Order Limit (Rs.)',
                    Icons.shopping_basket_outlined),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD64545),
                    foregroundColor: Colors.white,
                    shape: const StadiumBorder(),
                    elevation: 0,
                  ),
                  
                  onPressed: () async {
                    if (codeCtrl.text.trim().isEmpty ||
                        discountCtrl.text.trim().isEmpty) {
                      return;
                    }
                    final value = double.tryParse(discountCtrl.text.trim());
                    final minSpend = minSpendCtrl.text.trim().isEmpty
                        ? 0.0
                        : double.tryParse(minSpendCtrl.text.trim());
                    if (value == null ||
                        value <= 0 ||
                        (type == 'Percentage' && value > 100)) {
                      _snack(
                          type == 'Percentage'
                              ? 'Enter a percentage between 1 and 100.'
                              : 'Enter a valid flat amount.',
                          error: true);
                      return;
                    }
                    if (minSpend == null || minSpend < 0) {
                      _snack('Minimum spend must be a valid amount.',
                          error: true);
                      return;
                    }
                    try {
                      final created = await SellerService.createCoupon(
                        code: codeCtrl.text,
                        type: type,
                        value: value,
                        minSpend: minSpend,
                      );
                      if (!mounted) return;
                      setState(() => _coupons.insert(0, created));
                      Navigator.pop(context);
                    } catch (e) {
                      _snack(SellerService.errorMessage(e), error: true);
                    }
                  },

                  child: const Text('Deploy Coupon Campaign',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _fieldStyle(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
      filled: true,
      fillColor: const Color(0xFFF7F3F0),
      prefixIcon: Icon(icon, size: 20, color: const Color(0xFFD64545)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 48,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFFEDE3DE),
              borderRadius: BorderRadius.circular(26),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() => _activeSubView = 0);
                      _loadAll();
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        color: _activeSubView == 0
                            ? Colors.white
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: _activeSubView == 0
                            ? [
                                BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.06),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2))
                              ]
                            : [],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Orders Fulfillment (${_orders.length})',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: _activeSubView == 0
                              ? const Color(0xFFD64545)
                              : Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() => _activeSubView = 1);
                      _loadAll();
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        color: _activeSubView == 1
                            ? Colors.white
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: _activeSubView == 1
                            ? [
                                BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.06),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2))
                              ]
                            : [],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Coupons & Promos',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: _activeSubView == 1
                              ? const Color(0xFFD64545)
                              : Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          if (_activeSubView == 0) ...[
                      if (_activeSubView == 0 && _orders.isEmpty)
            _statusNote(_loading
                ? 'Loading orders...'
                : (_loadError ?? 'No orders to fulfil yet.')),
          if (_activeSubView == 1 && _coupons.isEmpty)
            _statusNote(_loading
                ? 'Loading coupons...'
                : (_loadError ?? 'No coupons yet. Create your first campaign below.')),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _orders.length,
              itemBuilder: (context, index) {
                final order = _orders[index];
                final status = order['status'] as String;

                Color statusBg;
                Color statusFg;
                if (status == 'Confirmed') {
                  statusBg = const Color(0xFFFFECE5);
                  statusFg = const Color(0xFFD64545);
                } else if (status == 'Packed') {
                  statusBg = const Color(0xFFFFF3E0);
                  statusFg = const Color(0xFFE65100);
                } else {
                  statusBg = const Color(0xFFE8F5E9);
                  statusFg = const Color(0xFF2E7D32);
                }

                return Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.035),
                          blurRadius: 12,
                          offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            order['orderId'] as String,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                              color: Color(0xFF1B1B1F),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                                color: statusBg,
                                borderRadius: BorderRadius.circular(12)),
                            child: Text(
                              status.toUpperCase(),
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  color: statusFg,
                                  letterSpacing: 0.8),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Buyer: ${order['buyer']}',
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1B1B1F)),
                      ),
                      Text(
                        order['items'] as String,
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            order['total'] as String,
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFFD64545)),
                          ),
                          Text(
                            order['date'] as String,
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey.shade400),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Divider(color: Colors.grey.shade100, height: 1),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => _editTrackingId(index),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF7F3F0),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.local_shipping_outlined,
                                        size: 16, color: Color(0xFF1B1B1F)),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        (order['trackingId'] as String).isEmpty
                                            ? 'Add Tracking ID'
                                            : order['trackingId'] as String,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: (order['trackingId'] as String)
                                                  .isEmpty
                                              ? Colors.grey
                                              : const Color(0xFF1B1B1F),
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (status != 'Shipped')
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1B1B1F),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: const StadiumBorder(),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 8),
                              ),
                              onPressed: () => _advanceOrderStatus(index),
                              child: Text(
                                status == 'Confirmed'
                                    ? 'Mark Packed'
                                    : 'Dispatch',
                                style: const TextStyle(
                                    fontSize: 11, fontWeight: FontWeight.w800),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ] else ...[
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD64545),
                  foregroundColor: Colors.white,
                  shape: const StadiumBorder(),
                  elevation: 0,
                ),
                icon: const Icon(Icons.add_rounded, size: 20),
                label: const Text('Create New Coupon Campaign',
                    style:
                        TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                onPressed: _openCreateCouponSheet,
              ),
            ),
            const SizedBox(height: 18),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _coupons.length,
              itemBuilder: (context, index) {
                final coupon = _coupons[index];
                final bool isActive = coupon['isActive'] as bool;

                return Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: isActive
                          ? const Color(0xFFD64545).withValues(alpha: 0.3)
                          : Colors.grey.shade200,
                    ),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.035),
                          blurRadius: 10,
                          offset: const Offset(0, 3)),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isActive
                              ? const Color(0xFFFFECE5)
                              : const Color(0xFFF1EFEF),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(Icons.loyalty_rounded,
                            color: isActive
                                ? const Color(0xFFD64545)
                                : Colors.grey,
                            size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  coupon['code'] as String,
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF1B1B1F),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE8F5E9),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    coupon['discount'] as String,
                                    style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
                                        color: Color(0xFF2E7D32)),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Min Spend: ${coupon['minSpend']} • ${coupon['expires']}',
                              style: TextStyle(
                                  fontSize: 11, color: Colors.grey.shade500),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value:
                            coupon['expires'] == 'Expired' ? false : isActive,
                        activeThumbColor: const Color(0xFFD64545),
                        // If coupon is expired, toggle is locked to null:
                        onChanged: coupon['expires'] == 'Expired'
                            ? null
                            : (val) async {
                                final previous = coupon['isActive'] as bool;
                                setState(() => coupon['isActive'] = val);
                                try {
                                  await SellerService.setCouponActive(
                                      coupon['id'] as String, val);
                                } catch (e) {
                                  if (!mounted) return;
                                  setState(() => coupon['isActive'] = previous);
                                  _snack(SellerService.errorMessage(e),
                                      error: true);
                                }
                              },
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
          const SizedBox(height: 60),
        ],
      ),
    );
  }
}

// =============================================================
// GLOBAL BUYER CART & ORDER STATE MANAGER
// =============================================================
class BuyerCartState {
  static final ValueNotifier<List<Map<String, dynamic>>> cartNotifier =
      ValueNotifier<List<Map<String, dynamic>>>([]);

  // Unpaid and Processing orders for the Buyer profile badges.
  // These now come from the server (see refreshOrders).
  static final ValueNotifier<List<Map<String, dynamic>>> unpaidOrdersNotifier =
      ValueNotifier<List<Map<String, dynamic>>>([]);
  static final ValueNotifier<List<Map<String, dynamic>>>
      processingOrdersNotifier = ValueNotifier<List<Map<String, dynamic>>>([]);

  // Signed-in buyer's profile (name / phone) for the Me tab and checkout.
  static final ValueNotifier<AppProfile?> profileNotifier =
      ValueNotifier<AppProfile?>(null);

  // Bumped by the tab bar so Shop / Category reload fresh data from the server.
  static final ValueNotifier<int> catalogRefresh = ValueNotifier<int>(0);

  static int get totalCount => cartNotifier.value
      .fold<int>(0, (sum, item) => sum + (item['qty'] as int? ?? 1));

  /// Wipes everything. Called when a buyer logs in so one account never
  /// sees another account's cart or orders.
  static void reset() {
    cartNotifier.value = [];
    unpaidOrdersNotifier.value = [];
    processingOrdersNotifier.value = [];
    profileNotifier.value = null;
  }

  static Future<void> loadProfile() async {
    try {
      profileNotifier.value = await AuthService.currentProfile();
    } catch (_) {
      // keep the placeholder name if this fails
    }
  }

  static Future<void> refreshOrders() async {
    try {
      final all = await BuyerService.fetchOrders();
      unpaidOrdersNotifier.value =
          all.where((o) => o['bucket'] == 'unpaid').toList();
      processingOrdersNotifier.value =
          all.where((o) => o['bucket'] == 'processing').toList();
    } catch (_) {
      // keep the old counts if the network fails
    }
  }

  /// [product] must be a product map from BuyerService (it carries id, stock,
  /// sizes and colorHexes). Returns false when nothing could be added
  /// (out of stock, or already at the maximum quantity).
  static bool addItem(Map<String, dynamic> product,
      {String? size, Color? color}) {
    final list = List<Map<String, dynamic>>.from(cartNotifier.value);
    final String title = (product['title'] as String?) ?? 'Item';
    final double price =
        product['price'] is num ? (product['price'] as num).toDouble() : 0.0;
    final String? productId = product['id'] as String?;
    final int stock = (product['stock'] as num?)?.toInt() ?? 50;
    if (stock <= 0) return false;
    final int maxQty = stock < 50 ? stock : 50;

    final List<String> sizes =
        (product['sizes'] as List?)?.cast<String>() ?? <String>[];
    final List<String> hexes =
        (product['colorHexes'] as List?)?.cast<String>() ?? <String>[];
    final String? pickedSize =
        (size == null || size.trim().isEmpty) ? null : size;
    final String? effSize =
        pickedSize ?? (sizes.isNotEmpty ? sizes.first : null);
    final String? colorHex = color != null
        ? SellerService.colorToHex(color)
        : (hexes.isNotEmpty ? hexes.first : null);

    final existingIndex = list.indexWhere((i) =>
        i['productId'] == productId &&
        i['size'] == effSize &&
        i['colorHex'] == colorHex);
    if (existingIndex >= 0) {
      final int current = list[existingIndex]['qty'] as int;
      if (current >= maxQty) return false;
      list[existingIndex] = Map<String, dynamic>.from(list[existingIndex]);
      list[existingIndex]['qty'] = current + 1;
    } else {
      list.add({
        'id': 'ITEM-${DateTime.now().microsecondsSinceEpoch}',
        'productId': productId,
        'size': effSize,
        'colorHex': colorHex,
        'stock': stock,
        'title': title,
        'variant':
            '${effSize ?? "Standard"} / ${colorHex != null ? "Selected Color" : "Default"}',
        'unitPrice': price,
        'qty': 1,
        'icon': Icons.diamond_outlined,
      });
    }
    cartNotifier.value = list;
    return true;
  }

  static void updateQty(int index, int delta) {
    final list = List<Map<String, dynamic>>.from(cartNotifier.value);
    if (index < 0 || index >= list.length) return;
    final int newQty = (list[index]['qty'] as int) + delta;
    final int stock = (list[index]['stock'] as int?) ?? 50;
    final int maxQty = stock < 50 ? stock : 50;
    if (newQty > maxQty) return;
    if (newQty <= 0) {
      list.removeAt(index);
    } else {
      list[index] = Map<String, dynamic>.from(list[index]);
      list[index]['qty'] = newQty;
    }
    cartNotifier.value = list;
  }

  static void clearCart() {
    cartNotifier.value = [];
  }
}

/// Shows the product's first uploaded photo, or a placeholder icon when the
/// seller has not added any.
class BuyerProductThumb extends StatelessWidget {
  final Map<String, dynamic> product;
  final IconData icon;
  final double iconSize;
  const BuyerProductThumb({
    super.key,
    required this.product,
    this.icon = Icons.diamond_outlined,
    this.iconSize = 40,
  });

  @override
  Widget build(BuildContext context) {
    final List urls = (product['imageUrls'] as List?) ?? const [];
    final Widget placeholder =
        Icon(icon, size: iconSize, color: Colors.grey.shade400);
    if (urls.isEmpty) return placeholder;
    return Image.network(
      urls.first.toString(),
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (_, __, ___) => placeholder,
    );
  }
}

// =============================================================
// BUYER MODULE: 4 TABS ONLY (SHOP, CATEGORY, CART, ME)
// =============================================================
class BuyerMainHub extends StatefulWidget {
  const BuyerMainHub({super.key});

  @override
  State<BuyerMainHub> createState() => _BuyerMainHubState();
}

class _BuyerMainHubState extends State<BuyerMainHub> {
  int _currentNavIndex = 0;

  @override
  void initState() {
    super.initState();
    BuyerCartState.reset(); // fresh cart + orders for this login
    BuyerCartState.loadProfile();
    BuyerCartState.refreshOrders();
  }

  void _goToShopTab() {
    setState(() => _currentNavIndex = 0);
    BuyerCartState.catalogRefresh.value++; // stock changed after an order
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF4F1),
      body: IndexedStack(
        index: _currentNavIndex,
        children: [
          const BuyerHomeScreen(),
          BuyerProductListingScreen(
            categoryTitle: 'Category Taxonomy',
            onBackToDashboard: _goToShopTab,
          ),
          BuyerCartCheckoutScreen(
            onBackToDashboard: _goToShopTab,
          ),
          const BuyerProfileScreen(),
        ],
      ),
      bottomNavigationBar: ValueListenableBuilder<List<Map<String, dynamic>>>(
        valueListenable: BuyerCartState.cartNotifier,
        builder: (context, cart, _) {
          final int badgeCount = BuyerCartState.totalCount;
          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 16,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SafeArea(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildNavItem(0, Icons.storefront_rounded, 'Shop'),
                    _buildNavItem(1, Icons.category_outlined, 'Category'),
                    _buildNavItem(
                      2,
                      Icons.shopping_bag_outlined,
                      'Cart',
                      badge: badgeCount > 0 ? '$badgeCount' : null,
                    ),
                    _buildNavItem(3, Icons.person_outline_rounded, 'Me'),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label,
      {String? badge}) {
    final bool isSelected = _currentNavIndex == index;
    return GestureDetector(
      onTap: () {
        final bool changed = _currentNavIndex != index;
        setState(() => _currentNavIndex = index);
        if (changed && (index == 0 || index == 1)) {
          BuyerCartState.catalogRefresh.value++;
        }
        if (changed && index == 3) BuyerCartState.refreshOrders();
      },
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(
                icon,
                size: 24,
                color: isSelected
                    ? const Color(0xFFD64545)
                    : const Color(0xFF1B1B1F).withValues(alpha: 0.6),
              ),
              if (badge != null)
                Positioned(
                  right: -6,
                  top: -4,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: Color(0xFFD64545),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      badge,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
              color: isSelected
                  ? const Color(0xFFD64545)
                  : const Color(0xFF1B1B1F).withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================
// SCREEN 2: HOME / SHOP LANDING PAGE (INFINITE SCROLL)
// =============================================================
class BuyerHomeScreen extends StatefulWidget {
  const BuyerHomeScreen({super.key});

  @override
  State<BuyerHomeScreen> createState() => _BuyerHomeScreenState();
}

class _BuyerHomeScreenState extends State<BuyerHomeScreen> {
  int _selectedCategoryIndex = 0;
  bool _isLoadingMore = false;
  final List<String> _topTabs = [
    'All',
    'Women',
    'Jewelry & Accs',
    'Men',
    'Lingerie',
    'Shoes',
    'Curve'
  ];

  final List<Map<String, String>> _circularCategories = [
    {'title': 'Women', 'icon': '👗'},
    {'title': 'Curve', 'icon': '💃'},
    {'title': 'Kids', 'icon': '🧸'},
    {'title': 'Men', 'icon': '👔'},
    {'title': 'Jewelry', 'icon': '💍'},
    {'title': 'Beauty', 'icon': '💄'},
    {'title': 'Bags', 'icon': '👜'},
    {'title': 'Shoes', 'icon': '👠'},
  ];

  // ---- live catalog (buyer_list_products) ----
  static const int _pageSize = 20;
  final List<Map<String, dynamic>> _products = [];
  bool _initialLoading = true;
  bool _hasMore = true;
  String? _loadError;

  /// Discounted products only (original price set by the seller).
  List<Map<String, dynamic>> get _superDeals {
    const palette = [0xFFD64545, 0xFFE65100, 0xFF5C6BC0, 0xFF2E7D32];
    final deals = <Map<String, dynamic>>[];
    for (final p in _products) {
      if (p['originalPrice'] == null || p['discount'] == null) continue;
      deals.add({
        'title': p['title'],
        'price': 'Rs. ${BuyerService.money(p['price'] as num)}',
        'original': 'Rs. ${BuyerService.money(p['originalPrice'] as num)}',
        'tag': '${p['discount']} OFF',
        'color': palette[deals.length % palette.length],
      });
      if (deals.length >= 8) break;
    }
    return deals;
  }

  @override
  void initState() {
    super.initState();
    BuyerCartState.catalogRefresh.addListener(_silentRefresh);
    _loadInitial();
  }

  @override
  void dispose() {
    BuyerCartState.catalogRefresh.removeListener(_silentRefresh);
    super.dispose();
  }

  void _silentRefresh() => _loadInitial(silent: true);

  Future<void> _loadInitial({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _initialLoading = true;
        _loadError = null;
      });
    }
    try {
      final items = await BuyerService.fetchProducts(limit: _pageSize);
      if (!mounted) return;
      setState(() {
        _products
          ..clear()
          ..addAll(items);
        _hasMore = items.length >= _pageSize;
        _initialLoading = false;
        _isLoadingMore = false;
        _loadError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _initialLoading = false;
        if (!silent || _products.isEmpty) {
          _loadError = BuyerService.errorMessage(e);
        }
      });
    }
  }

  // Infinite scroll: quietly appends the next page from the server.
  Future<void> _loadMoreRecommendations() async {
    if (_isLoadingMore || !_hasMore || _initialLoading || _products.isEmpty) {
      return;
    }
    setState(() => _isLoadingMore = true);
    try {
      final items = await BuyerService.fetchProducts(
          limit: _pageSize, offset: _products.length);
      if (!mounted) return;
      setState(() {
        final known = _products.map((p) => p['id']).toSet();
        _products.addAll(items.where((p) => !known.contains(p['id'])));
        _hasMore = items.length >= _pageSize;
        _isLoadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingMore = false;
        _hasMore = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF4F1),
      body: SafeArea(
        child: NotificationListener<ScrollNotification>(
          onNotification: (ScrollNotification scrollInfo) {
            if (scrollInfo.metrics.pixels >=
                scrollInfo.metrics.maxScrollExtent - 250) {
              _loadMoreRecommendations();
            }
            return false;
          },
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Search Bar
                Container(
                  color: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Text(
                            'LOOPLAB',
                            style: TextStyle(
                              fontFamily: 'serif',
                              fontSize: 19,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2.0,
                              color: Color(0xFF1B1B1F),
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            icon: const Icon(Icons.favorite_border_rounded,
                                size: 22, color: Color(0xFF1B1B1F)),
                            onPressed: () {},
                          ),
                          const SizedBox(width: 14),
                          IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            icon: const Icon(Icons.mail_outline_rounded,
                                size: 22, color: Color(0xFF1B1B1F)),
                            onPressed: () {},
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7F3F0),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: const Color(0xFFEDE3DE)),
                        ),
                        child: const Row(
                          children: [
                            SizedBox(width: 12),
                            Icon(Icons.search_rounded,
                                color: Color(0xFFD64545), size: 20),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Search collections or products...',
                                style:
                                    TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.only(right: 12.0),
                              child: Icon(Icons.camera_alt_outlined,
                                  size: 18, color: Color(0xFF1B1B1F)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Top Categories Bar
                Container(
                  height: 40,
                  color: Colors.white,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: _topTabs.length,
                    itemBuilder: (context, index) {
                      final bool isSelected = _selectedCategoryIndex == index;
                      return GestureDetector(
                        onTap: () =>
                            setState(() => _selectedCategoryIndex = index),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: isSelected
                                    ? const Color(0xFFD64545)
                                    : Colors.transparent,
                                width: 2.2,
                              ),
                            ),
                          ),
                          child: Text(
                            _topTabs[index],
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isSelected
                                  ? FontWeight.w900
                                  : FontWeight.w500,
                              color: isSelected
                                  ? const Color(0xFFD64545)
                                  : const Color(0xFF1B1B1F)
                                      .withValues(alpha: 0.7),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // Hero Campaign Card
                Container(
                  margin: const EdgeInsets.all(14),
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFD64545), Color(0xFF901A1E)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFD64545).withValues(alpha: 0.35),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 6,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                '',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.8),
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'SAVE BIG ON\n800K+ PICKS',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                height: 1.1,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: const Color(0xFFD64545),
                                shape: const StadiumBorder(),
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                              ),
                              onPressed: () {},
                              child: const Text('SHOP NOW',
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900)),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 5,
                        child: Row(
                          children: [
                            _buildMiniBannerCard(
                                'Rs. 580', Icons.phone_iphone_rounded),
                            const SizedBox(width: 8),
                            _buildMiniBannerCard(
                                'Rs. 3,312', Icons.shopping_bag_outlined),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Trust Badges
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 14),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFEDE3DE)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildTrustBadge(Icons.local_shipping_outlined,
                          'Free Shipping', 'Over Rs. 4,000'),
                      Container(
                          height: 20, width: 1, color: Colors.grey.shade200),
                      _buildTrustBadge(Icons.replay_rounded, 'Easy Return',
                          '15 Days Window'),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Circular Categories
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      mainAxisSpacing: 14,
                      crossAxisSpacing: 10,
                      childAspectRatio: 0.78,
                    ),
                    itemCount: _circularCategories.length,
                    itemBuilder: (context, index) {
                      final item = _circularCategories[index];
                      return Column(
                        children: [
                          Container(
                            width: 54,
                            height: 54,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: const Color(0xFFEDE3DE), width: 1.2),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.03),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            alignment: Alignment.center,
                            child: Text(item['icon']!,
                                style: const TextStyle(fontSize: 22)),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            item['title']!,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1B1B1F),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),

                // Super Deals Carousel (shown only when the server has discounted products)
                if (_superDeals.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    children: [
                      const Text(
                        'Super Deals',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF1B1B1F),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD64545),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('02:44:12',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold)),
                      ),
                      const Spacer(),
                      const Text('View All',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFD64545))),
                      const Icon(Icons.arrow_forward_ios_rounded,
                          size: 11, color: Color(0xFFD64545)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 170,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: _superDeals.length,
                    itemBuilder: (context, index) {
                      final deal = _superDeals[index];
                      return Container(
                        width: 130,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              height: 75,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF7F3F0),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              alignment: Alignment.center,
                              child: Icon(Icons.image_outlined,
                                  size: 30, color: Colors.grey.shade400),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              deal['price'],
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFFD64545)),
                            ),
                            Text(
                              deal['original'],
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey.shade400,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Color(deal['color'])
                                    .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                deal['tag'],
                                style: TextStyle(
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                    color: Color(deal['color'])),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 24),
                ],

                // Infinite Curated Grid
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    children: [
                      const Icon(Icons.auto_awesome_rounded,
                          size: 16, color: Color(0xFFD64545)),
                      const SizedBox(width: 6),
                      const Text(
                        'Curated For You',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF1B1B1F)),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFECE5),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text('Live Feed',
                            style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFD64545))),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (_initialLoading && _products.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Color(0xFFD64545)),
                      ),
                    ),
                  )
                else if (_loadError != null && _products.isEmpty)
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: 30, horizontal: 24),
                    child: Center(
                      child: Column(
                        children: [
                          Text(_loadError!,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey.shade600)),
                          TextButton(
                            onPressed: () => _loadInitial(),
                            child: const Text('Retry',
                                style: TextStyle(
                                    color: Color(0xFFD64545),
                                    fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
                  )
                else if (_products.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: Text('No products available yet.',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade600)),
                    ),
                  )
                else
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.68,
                  ),
                  itemCount: _products.length,
                  itemBuilder: (context, index) {
                    final item = _products[index];
                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                ProductDetailScreen(product: item),
                          ),
                        );
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.035),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Stack(
                              children: [
                                Container(
                                  height: 135,
                                  clipBehavior: Clip.antiAlias,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFF7F3F0),
                                    borderRadius: BorderRadius.vertical(
                                        top: Radius.circular(18)),
                                  ),
                                  alignment: Alignment.center,
                                  child: BuyerProductThumb(
                                      product: item,
                                      icon: Icons.diamond_outlined,
                                      iconSize: 40),
                                ),
                                if (item['isHot'] == true)
                                  Positioned(
                                    top: 8,
                                    left: 8,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFD64545),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text(
                                        'HOT',
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 8,
                                            fontWeight: FontWeight.w900),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            Padding(
                              padding: const EdgeInsets.all(10.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item['tag'],
                                    style: const TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF5C6BC0)),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    item['title'],
                                    style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF1B1B1F)),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    item['reviewSnippet'],
                                    style: TextStyle(
                                        fontSize: 9,
                                        color: Colors.grey.shade500),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            'Rs. ${BuyerService.money(item['price'] as num)}',
                                            style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w900,
                                                color: Color(0xFFD64545)),
                                          ),
                                          if (item['discount'] != null) ...[
                                            const SizedBox(width: 4),
                                            Text(
                                              item['discount'] as String,
                                              style: const TextStyle(
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.bold,
                                                  color: Color(0xFF2E7D32)),
                                            ),
                                          ],
                                        ],
                                      ),
                                      GestureDetector(
                                        onTap: () {
                                          final bool added =
                                              BuyerCartState.addItem(item);
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                              content: Text(added
                                                  ? 'Added "${item['title']}" to cart!'
                                                  : '"${item['title']}" is out of stock or at its limit.'),
                                              backgroundColor:
                                                  const Color(0xFF1B1B1F),
                                              behavior:
                                                  SnackBarBehavior.floating,
                                              shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          16)),
                                              duration:
                                                  const Duration(seconds: 1),
                                            ),
                                          );
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF7F3F0),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: const Icon(
                                              Icons.add_shopping_cart_rounded,
                                              size: 16,
                                              color: Color(0xFF1B1B1F)),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),

                // Bottom Loader
                if (_isLoadingMore)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24.0),
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Color(0xFFD64545)),
                      ),
                    ),
                  )
                else
                  const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMiniBannerCard(String price, IconData icon) {
    return Expanded(
      child: Container(
        height: 100,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 28, color: const Color(0xFF1B1B1F)),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFFFECE5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                price,
                style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFFD64545)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrustBadge(IconData icon, String title, String subtitle) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFFD64545)),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1B1B1F))),
            Text(subtitle,
                style: TextStyle(fontSize: 9, color: Colors.grey.shade500)),
          ],
        ),
      ],
    );
  }
}

// =============================================================
// SCREEN 3B: PRODUCT DETAIL VIEW (GALLERY / VARIANTS / AR / REVIEWS)
// =============================================================
class ProductDetailScreen extends StatefulWidget {
  final Map<String, dynamic> product;
  const ProductDetailScreen({super.key, required this.product});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  final int _selectedImageIndex = 0;
  String _selectedSize = '';
  Color _selectedColor = const Color(0xFF1B1B1F);

  List<Map<String, dynamic>> _reviews = [];
  bool _reviewsLoading = true;

  @override
  void initState() {
    super.initState();
    // Start on the product's real first size / color so "Add to Cart" is valid.
    final sizes = (widget.product['sizes'] as List?) ?? const [];
    if (sizes.isNotEmpty) _selectedSize = sizes.first.toString();
    final colors = (widget.product['colors'] as List?) ?? const [];
    if (colors.isNotEmpty && colors.first is Color) {
      _selectedColor = colors.first as Color;
    }
    final id = widget.product['id'];
    if (id is String) {
      _loadReviews(id);
    } else {
      _reviewsLoading = false;
    }
  }

  Future<void> _loadReviews(String productId) async {
    try {
      final list = await BuyerService.fetchReviews(productId, limit: 10);
      if (!mounted) return;
      setState(() {
        _reviews = list;
        _reviewsLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _reviewsLoading = false);
    }
  }

  void _triggerARPreviewModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.70,
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Color(0xFF1B1B1F),
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.view_in_ar_rounded,
                        color: Color(0xFFFFD8CC), size: 22),
                    SizedBox(width: 8),
                    Text('AR Quick Look',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: Colors.white)),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Text(
              'Simulating 3D LiDAR camera surface projection and fit preview.',
              style: TextStyle(color: Colors.white60, fontSize: 12),
            ),
            const Spacer(),
            Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFD64545), width: 2),
                color: Colors.white.withValues(alpha: 0.05),
              ),
              child: const Icon(Icons.view_in_ar_rounded,
                  size: 60, color: Colors.white),
            ),
            const SizedBox(height: 16),
            const Text('Point camera at flat surface',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14)),
            const Text('Detecting lighting and environment depth...',
                style: TextStyle(color: Colors.white54, fontSize: 11)),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD64545),
                  foregroundColor: Colors.white,
                  shape: const StadiumBorder(),
                ),
                icon: const Icon(Icons.camera_alt_outlined),
                label: const Text('Calibrate Camera AR Fit',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sizes = widget.product['sizes'] as List<dynamic>? ?? ['S', 'M', 'L'];
    final colors = widget.product['colors'] as List<dynamic>? ??
        [const Color(0xFF1B1B1F), const Color(0xFFD64545)];

    return Scaffold(
      backgroundColor: const Color(0xFFFAF4F1),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Color(0xFF1B1B1F), size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.product['brand'] ?? 'EXCLUSIVE',
          style: const TextStyle(
              color: Color(0xFF1B1B1F),
              fontSize: 13,
              fontWeight: FontWeight.w900),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 260,
              width: double.infinity,
              color: Colors.white,
              child: Center(
                child: BuyerProductThumb(
                    product: widget.product,
                    icon: Icons.diamond_outlined,
                    iconSize: 100),
              ),
            ),
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Rs. ${BuyerService.money(widget.product['price'] is num ? widget.product['price'] as num : 0)}',
                    style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFFD64545)),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.product['title'] ?? 'Luxury Catalog Item',
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1B1B1F)),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.product['description'] ??
                        'Curated item from verified merchants on LoopLab.',
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey.shade600, height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // AR Fitting Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: InkWell(
                onTap: _triggerARPreviewModal,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFFFD0C5)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.view_in_ar_rounded,
                          color: Color(0xFFD64545), size: 24),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('AR 3D Interactive Fitting',
                                style: TextStyle(
                                    fontWeight: FontWeight.w800, fontSize: 13)),
                            Text(
                                'Preview proportions and fit in your camera viewport',
                                style: TextStyle(
                                    fontSize: 11, color: Colors.grey)),
                          ],
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios_rounded,
                          size: 14, color: Colors.grey),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Variants (Size & Color)
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Select Size',
                      style:
                          TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: sizes.map((s) {
                      final isSel = _selectedSize == s.toString();
                      return ChoiceChip(
                        label: Text(s.toString()),
                        selected: isSel,
                        selectedColor: const Color(0xFFFFECE5),
                        labelStyle: TextStyle(
                          fontWeight: isSel ? FontWeight.w800 : FontWeight.w500,
                          color: isSel
                              ? const Color(0xFFD64545)
                              : const Color(0xFF1B1B1F),
                        ),
                        onSelected: (_) =>
                            setState(() => _selectedSize = s.toString()),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),
                  const Text('Select Color',
                      style:
                          TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Row(
                    children: colors.map((c) {
                      final color = c is Color ? c : const Color(0xFF1B1B1F);
                      final isSel = _selectedColor == color;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedColor = color),
                        child: Container(
                          margin: const EdgeInsets.only(right: 12),
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSel
                                  ? const Color(0xFFD64545)
                                  : Colors.grey.shade300,
                              width: isSel ? 3 : 1,
                            ),
                          ),
                          child: isSel
                              ? const Icon(Icons.check,
                                  size: 14, color: Colors.white)
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Reviews
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      'Customer Reviews (${widget.product['reviewsCount'] ?? _reviews.length})',
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 12),
                  if (_reviewsLoading)
                    const Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Color(0xFFD64545)),
                      ),
                    )
                  else if (_reviews.isEmpty)
                    Text(
                        'No reviews yet. Buyers can review a product once their order is delivered.',
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade600))
                  else
                    ...List.generate(_reviews.length, (i) {
                      final r = _reviews[i];
                      final int rawStars = r['rating'] as int;
                      final int stars =
                          rawStars < 0 ? 0 : (rawStars > 5 ? 5 : rawStars);
                      final String comment = (r['comment'] as String?) ?? '';
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (i > 0) const Divider(height: 20),
                          Text('${r['name']}  ${'★' * stars}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 12)),
                          if (comment.isNotEmpty)
                            Text(comment,
                                style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade600)),
                        ],
                      );
                    }),
                ],
              ),
            ),
            const SizedBox(height: 90),
          ],
        ),
      ),
      bottomSheet: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 10,
                offset: const Offset(0, -2))
          ],
        ),
        child: SafeArea(
          child: Row(
            children: [
              Expanded(
                flex: 4,
                child: SizedBox(
                  height: 48,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(
                          color: Color(0xFF1B1B1F), width: 1.5),
                      shape: const StadiumBorder(),
                    ),
                    onPressed: () {
                      // 1. THIS SAVES THE PRODUCT TO YOUR CART:
                      final bool added = BuyerCartState.addItem(
                        widget.product,
                        size: _selectedSize,
                        color: _selectedColor,
                      );

                      // 2. THIS SHOWS THE CONFIRMATION MESSAGE:
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(added
                              ? 'Added "${widget.product['title'] ?? 'Item'}" to bag!'
                              : 'Sorry, this item is out of stock or at its limit.'),
                          backgroundColor: const Color(0xFF1B1B1F),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    },
                    child: const Text('Add to Cart',
                        style: TextStyle(
                            color: Color(0xFF1B1B1F),
                            fontWeight: FontWeight.w800,
                            fontSize: 13)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 5,
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD64545),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: const StadiumBorder(),
                    ),
                    onPressed: () {
                      // 1. Adds this selected item & variants to the cart
                      final int stock =
                          (widget.product['stock'] as num?)?.toInt() ?? 1;
                      if (stock <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Sorry, this item is out of stock.'),
                            backgroundColor: const Color(0xFF1B1B1F),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                            duration: const Duration(seconds: 1),
                          ),
                        );
                        return;
                      }
                      BuyerCartState.addItem(
                        widget.product,
                        size: _selectedSize,
                        color: _selectedColor,
                      );

                      // 2. Navigates directly into the Checkout Screen
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const BuyerCartCheckoutScreen(),
                        ),
                      );
                    },
                    child: const Text('Buy Now',
                        style: TextStyle(
                            fontWeight: FontWeight.w900, fontSize: 13)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================
// SCREEN 4: CART, MULTI-STEP CHECKOUT & TEST SANDBOX PAYMENT
// =============================================================
class BuyerCartCheckoutScreen extends StatefulWidget {
  final VoidCallback? onBackToDashboard;
  const BuyerCartCheckoutScreen({super.key, this.onBackToDashboard});

  @override
  State<BuyerCartCheckoutScreen> createState() =>
      _BuyerCartCheckoutScreenState();
}

class _BuyerCartCheckoutScreenState extends State<BuyerCartCheckoutScreen> {
  int _checkoutStep = 0;

  // Coupon Engine
  final TextEditingController _couponCtrl = TextEditingController();
  double _appliedDiscount = 0.0;
  String _activeCouponCode = '';

  // Shipping Form Controllers
  final _addressCtrl =
      TextEditingController(text: 'House 14-B, Sunset Boulevard, Phase 6');
  final _cityCtrl = TextEditingController(text: 'Lahore');
  final _phoneCtrl = TextEditingController(text: '+92 300 1234567');
  String _deliveryMethod = 'Standard';

  // Payment Method State
  String _paymentOption = 'Card';
  final _cardNumberCtrl = TextEditingController(text: '4242 •••• •••• 4242');
  final _cardExpiryCtrl = TextEditingController(text: '09/28');
  final _cardCvcCtrl = TextEditingController(text: '883');
  bool _isProcessingPayment = false;

  // Server pricing (buyer_quote_checkout). Null until the first quote arrives;
  // until then the old local estimate is shown.
  Map<String, dynamic>? _quote;
  String? _quoteError;
  int _quoteSeq = 0;
  // Unpaid orders created when the buyer backs out of the payment step.
  final List<String> _pendingUnpaid = [];

  List<Map<String, dynamic>> get _cart => BuyerCartState.cartNotifier.value;

  double _numOf(dynamic v) => (v as num?)?.toDouble() ?? 0.0;

  @override
  void initState() {
    super.initState();
    BuyerCartState.cartNotifier.addListener(_onCartChanged);
    _refreshQuote();
  }

  @override
  void dispose() {
    BuyerCartState.cartNotifier.removeListener(_onCartChanged);
    super.dispose();
  }

  void _toastMsg(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor:
            error ? const Color(0xFFD64545) : const Color(0xFF2E7D32),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  void _onCartChanged() {
    _cancelPendingUnpaid(); // the reserved items no longer match the cart
    if (mounted) {
      setState(() {
        _quote = null;
        _quoteError = null;
        _appliedDiscount = 0.0;
      });
    }
    _refreshQuote();
  }

  /// Asks the server for the real subtotal / shipping / tax / discount.
  Future<void> _refreshQuote() async {
    final int seq = ++_quoteSeq;
    final cart = List<Map<String, dynamic>>.from(_cart);
    if (cart.isEmpty) {
      if (mounted) {
        setState(() {
          _quote = null;
          _quoteError = null;
          _appliedDiscount = 0.0;
          _activeCouponCode = '';
        });
      }
      return;
    }
    String? droppedMsg;
    try {
      Map<String, dynamic> q;
      try {
        q = await BuyerService.quote(cart,
            delivery: _deliveryMethod,
            coupon: _activeCouponCode.isEmpty ? null : _activeCouponCode);
      } catch (e) {
        if (_activeCouponCode.isEmpty) rethrow;
        // The coupon no longer fits this cart: drop it and price without it.
        droppedMsg = BuyerService.errorMessage(e);
        q = await BuyerService.quote(cart, delivery: _deliveryMethod);
      }
      if (!mounted || seq != _quoteSeq) return;
      final String? dropped = droppedMsg;
      setState(() {
        _quote = q;
        _quoteError = null;
        if (dropped != null) _activeCouponCode = '';
        _appliedDiscount = _numOf(q['discount']);
      });
      if (dropped != null) _toastMsg(dropped, error: true);
    } catch (e) {
      if (!mounted || seq != _quoteSeq) return;
      setState(() {
        _quote = null;
        _quoteError = BuyerService.errorMessage(e);
      });
    }
  }

  Future<void> _applyCoupon() async {
    final code = _couponCtrl.text.trim().toUpperCase();
    if (code.isEmpty) {
      _toastMsg('Enter a voucher code first.', error: true);
      return;
    }
    if (_cart.isEmpty) return;
    FocusScope.of(context).unfocus();
    try {
      final q = await BuyerService.quote(_cart,
          delivery: _deliveryMethod, coupon: code);
      if (!mounted) return;
      final String applied = (q['coupon_code'] as String?) ?? code;
      setState(() {
        _quote = q;
        _quoteError = null;
        _activeCouponCode = applied;
        _appliedDiscount = _numOf(q['discount']);
      });
      _toastMsg('Voucher "$applied" applied!');
    } catch (e) {
      _toastMsg(BuyerService.errorMessage(e), error: true);
    }
  }

  double _calculateSubtotal(List<Map<String, dynamic>> items) {
    final q = _quote;
    if (q != null) return _numOf(q['subtotal']);
    double sum = 0.0;
    for (var item in items) {
      sum += (item['unitPrice'] as double) * (item['qty'] as int);
    }
    return sum;
  }

  double _calculateShipping(List<Map<String, dynamic>> items) {
    if (items.isEmpty) return 0.0;
    final q = _quote;
    if (q != null) return _numOf(q['shipping']);
    return _deliveryMethod == 'Express' ? 600.0 : 250.0;
  }

  double _calculateTax(double subtotal) {
    final q = _quote;
    if (q != null) return _numOf(q['tax']);
    return subtotal * 0.05;
  }

  double _calculateGrandTotal(List<Map<String, dynamic>> items) {
    if (items.isEmpty) return 0.0;
    final q = _quote;
    if (q != null) return _numOf(q['grand_total']);
    final sub = _calculateSubtotal(items);
    final total =
        sub + _calculateShipping(items) + _calculateTax(sub) - _appliedDiscount;
    return total > 0 ? total : 0.0;
  }

  Future<String> _buyerName() async {
    final cached = BuyerCartState.profileNotifier.value?.fullName?.trim();
    if (cached != null && cached.isNotEmpty) return cached;
    try {
      final profile = await AuthService.currentProfile();
      final name = profile.fullName?.trim();
      if (name != null && name.isNotEmpty) return name;
    } catch (_) {}
    return 'LoopLab Buyer';
  }

  /// Buyer backed out of the payment step: keep the items reserved as an
  /// Unpaid order (the server expires it after 24 hours).
  Future<void> _recordUnpaidOrder() async {
    if (_pendingUnpaid.isNotEmpty || _cart.isEmpty || _isProcessingPayment) {
      return;
    }
    final cart = List<Map<String, dynamic>>.from(_cart);
    try {
      final res = await BuyerService.placeOrder(
        cart: cart,
        delivery: _deliveryMethod,
        // COD is confirmed immediately by the server, so reserve as Card.
        payment: _paymentOption == 'COD' ? 'Card' : _paymentOption,
        coupon: _activeCouponCode.isEmpty ? null : _activeCouponCode,
        name: await _buyerName(),
        phone: _phoneCtrl.text.trim(),
        address: _addressCtrl.text.trim(),
        city: _cityCtrl.text.trim(),
        payNow: false,
      );
      for (final o in (res['orders'] as List?) ?? const []) {
        _pendingUnpaid.add((o as Map)['order_number'] as String);
      }
      BuyerCartState.refreshOrders();
    } catch (_) {
      // Nothing to show: the buyer only went back a step.
    }
  }

  Future<void> _cancelPendingUnpaid() async {
    if (_pendingUnpaid.isEmpty) return;
    final numbers = List<String>.from(_pendingUnpaid);
    _pendingUnpaid.clear();
    for (final n in numbers) {
      try {
        await BuyerService.cancelOrder(n);
      } catch (_) {}
    }
    BuyerCartState.refreshOrders();
  }

  Future<void> _placeOrder() async {
    final cart = List<Map<String, dynamic>>.from(_cart);
    if (cart.isEmpty) return;
    setState(() => _isProcessingPayment = true);
    try {
      await _cancelPendingUnpaid(); // release the stock held by an Unpaid order
      final res = await BuyerService.placeOrder(
        cart: cart,
        delivery: _deliveryMethod,
        payment: _paymentOption,
        coupon: _activeCouponCode.isEmpty ? null : _activeCouponCode,
        name: await _buyerName(),
        phone: _phoneCtrl.text.trim(),
        address: _addressCtrl.text.trim(),
        city: _cityCtrl.text.trim(),
        payNow: true,
      );
      if (!mounted) return;
      setState(() => _isProcessingPayment = false);
      final orderNumbers = ((res['orders'] as List?) ?? const [])
          .map<String>((o) => (o as Map)['order_number'].toString())
          .toList();
      BuyerCartState.refreshOrders();
      _showOrderConfirmed(
        orderNumbers,
        _numOf(res['grand_total']),
        (res['payment_status'] as String?) ?? '',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessingPayment = false);
      _toastMsg(BuyerService.errorMessage(e), error: true);
    }
  }

  void _showOrderConfirmed(
      List<String> orderNumbers, double grandTotal, String paymentStatus) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFFE8F5E9),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_rounded,
                  color: Color(0xFF2E7D32), size: 40),
            ),
            const SizedBox(height: 18),
            const Text(
              'Order Confirmed!',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1B1B1F)),
            ),
            const SizedBox(height: 8),
            Text(
              orderNumbers.length > 1
                  ? 'Orders ${orderNumbers.join(', ')} have been sent to fulfillment pipeline.'
                  : 'Order #${orderNumbers.isEmpty ? '' : orderNumbers.first} has been sent to fulfillment pipeline.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 12, color: Colors.grey.shade600, height: 1.4),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F3F0),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                paymentStatus == 'cod'
                    ? 'Cash on Delivery: Rs. ${grandTotal.toStringAsFixed(0)} due on arrival'
                    : 'Paid: Rs. ${grandTotal.toStringAsFixed(0)} via $_paymentOption (Sandbox)',
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFD64545)),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1B1B1F),
                  foregroundColor: Colors.white,
                  shape: const StadiumBorder(),
                  elevation: 0,
                ),
                onPressed: () {
                  Navigator.pop(context);
                  // The order already exists on the server; just reset the cart.
                  BuyerCartState.clearCart();
                  setState(() {
                    _checkoutStep = 0;
                    _activeCouponCode = '';
                    _appliedDiscount = 0.0;
                    _couponCtrl.clear();
                    _quote = null;
                    _quoteError = null;
                  });
                  if (widget.onBackToDashboard != null) {
                    widget.onBackToDashboard!();
                  }
                },
                child: const Text('Back to Discovery Home',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<Map<String, dynamic>>>(
      valueListenable: BuyerCartState.cartNotifier,
      builder: (context, cartItems, _) {
        final subtotal = _calculateSubtotal(cartItems);
        final grandTotal = _calculateGrandTotal(cartItems);

        return Scaffold(
          backgroundColor: const Color(0xFFFAF4F1),
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Color(0xFF1B1B1F), size: 18),
              onPressed: () {
                if (_checkoutStep == 2) {
                  // User reached the payment step but backed out: mark as Unpaid!
                  _recordUnpaidOrder();
                  setState(() => _checkoutStep--);
                } else if (_checkoutStep > 0) {
                  setState(() => _checkoutStep--);
                } else if (widget.onBackToDashboard != null) {
                  widget.onBackToDashboard!();
                } else {
                  Navigator.pop(context);
                }
              },
            ),
            title: Text(
              _checkoutStep == 0
                  ? 'SHOPPING BAG (${cartItems.length})'
                  : _checkoutStep == 1
                      ? 'CHECKOUT & SHIPPING'
                      : 'SECURE PAYMENT SANDBOX',
              style: const TextStyle(
                  color: Color(0xFF1B1B1F),
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.1),
            ),
            actions: [
              Container(
                margin: const EdgeInsets.only(right: 16),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                    color: const Color(0xFFFFECE5),
                    borderRadius: BorderRadius.circular(12)),
                alignment: Alignment.center,
                child: Text(
                  'Step ${_checkoutStep + 1}/3',
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFD64545)),
                ),
              ),
            ],
          ),
          body: cartItems.isEmpty && _checkoutStep == 0
              ? _buildEmptyCart()
              : SingleChildScrollView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_checkoutStep == 0) ...[
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: cartItems.length,
                          itemBuilder: (context, idx) {
                            final item = cartItems[idx];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                      color:
                                          Colors.black.withValues(alpha: 0.03),
                                      blurRadius: 10,
                                      offset: const Offset(0, 3)),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 70,
                                    height: 70,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF7F3F0),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Icon(
                                      item['icon'] is IconData
                                          ? item['icon']
                                          : Icons.diamond_outlined,
                                      size: 32,
                                      color: Colors.grey.shade400,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item['title'] as String,
                                          style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w800,
                                              color: Color(0xFF1B1B1F)),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(item['variant'] as String,
                                            style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey.shade500)),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Rs. ${(item['unitPrice'] as double).toStringAsFixed(0)}',
                                          style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w900,
                                              color: Color(0xFFD64545)),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF7F3F0),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Row(
                                      children: [
                                        IconButton(
                                          constraints: const BoxConstraints(
                                              minWidth: 32, minHeight: 32),
                                          padding: EdgeInsets.zero,
                                          icon: const Icon(Icons.remove,
                                              size: 14),
                                          onPressed: () =>
                                              BuyerCartState.updateQty(idx, -1),
                                        ),
                                        Text('${item['qty']}',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13)),
                                        IconButton(
                                          constraints: const BoxConstraints(
                                              minWidth: 32, minHeight: 32),
                                          padding: EdgeInsets.zero,
                                          icon: const Icon(Icons.add, size: 14),
                                          onPressed: () =>
                                              BuyerCartState.updateQty(idx, 1),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: const Color(0xFFEDE3DE)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.loyalty_rounded,
                                  color: Color(0xFFD64545), size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TextField(
                                  controller: _couponCtrl,
                                  textCapitalization:
                                      TextCapitalization.characters,
                                  decoration: InputDecoration(
                                    hintText: 'Enter Voucher Code',
                                    hintStyle: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade400),
                                    border: InputBorder.none,
                                    isDense: true,
                                  ),
                                ),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1B1B1F),
                                  foregroundColor: Colors.white,
                                  shape: const StadiumBorder(),
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 8),
                                ),
                                onPressed: _applyCoupon,
                                child: const Text('Apply',
                                    style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildOrderSummaryCard(cartItems, subtotal, grandTotal),
                      ] else if (_checkoutStep == 1) ...[
                        _buildSectionHeader(
                            'DELIVERY DESTINATION', Icons.location_on_outlined),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20)),
                          child: Column(
                            children: [
                              _buildShippingField('Street Address',
                                  _addressCtrl, Icons.home_outlined),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                      child: _buildShippingField('City',
                                          _cityCtrl, Icons.apartment_outlined)),
                                  const SizedBox(width: 10),
                                  Expanded(
                                      child: _buildShippingField(
                                          'Phone Contact',
                                          _phoneCtrl,
                                          Icons.phone_outlined)),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        _buildSectionHeader(
                            'DELIVERY SPEED', Icons.local_shipping_outlined),
                        const SizedBox(height: 10),
                        _buildDeliveryOption(
                            'Standard Delivery (3-5 Days)',
                            'Rs. 250',
                            'Standard',
                            'Covers national road couriers'),
                        const SizedBox(height: 8),
                        _buildDeliveryOption(
                            'Air Express Dispatch (24-48 Hrs)',
                            'Rs. 600',
                            'Express',
                            'Priority packaging & air-freight tracking'),
                        const SizedBox(height: 16),
                        _buildOrderSummaryCard(cartItems, subtotal, grandTotal),
                      ] else ...[
                        _buildSectionHeader('PAYMENT METHOD (SANDBOX ACTIVE)',
                            Icons.security_rounded),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                              color: const Color(0xFFEDE3DE),
                              borderRadius: BorderRadius.circular(20)),
                          child: Row(
                            children: [
                              _buildPaymentTab(
                                  'Card', Icons.credit_card_rounded),
                              _buildPaymentTab('JazzCash',
                                  Icons.account_balance_wallet_outlined),
                              _buildPaymentTab('COD', Icons.handshake_outlined),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (_paymentOption == 'Card') ...[
                          Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(22),
                              border:
                                  Border.all(color: const Color(0xFFFFECE5)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Encrypted Card Details',
                                        style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 13)),
                                    Icon(Icons.lock_rounded,
                                        size: 16, color: Colors.grey.shade400),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                _buildShippingField(
                                    'Card Number',
                                    _cardNumberCtrl,
                                    Icons.credit_card_outlined),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                        child: _buildShippingField(
                                            'Expires',
                                            _cardExpiryCtrl,
                                            Icons.calendar_today_outlined)),
                                    const SizedBox(width: 10),
                                    Expanded(
                                        child: _buildShippingField(
                                            'CVC / CVV',
                                            _cardCvcCtrl,
                                            Icons.password_outlined)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ] else if (_paymentOption == 'JazzCash') ...[
                          Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(22)),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Mobile Wallet OTP Authorization',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 13)),
                                const SizedBox(height: 6),
                                Text(
                                    'You will receive a sandbox approval request prompt on your mobile wallet.',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade600)),
                                const SizedBox(height: 14),
                                _buildShippingField('Account Phone Number',
                                    _phoneCtrl, Icons.phone_android_rounded),
                              ],
                            ),
                          ),
                        ] else ...[
                          Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(22)),
                            child: Row(
                              children: [
                                const Icon(Icons.info_outline_rounded,
                                    color: Color(0xFFD64545)),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Pay with cash upon inspection & doorstep delivery. No advance online charges applied.',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade700),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        _buildOrderSummaryCard(cartItems, subtotal, grandTotal),
                      ],
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
          bottomSheet: cartItems.isEmpty
              ? null
              : Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 10,
                          offset: const Offset(0, -2))
                    ],
                  ),
                  child: SafeArea(
                    child: SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD64545),
                          foregroundColor: Colors.white,
                          shape: const StadiumBorder(),
                          elevation: 0,
                        ),
                        onPressed: _isProcessingPayment
                            ? null
                            : () {
                                if (_checkoutStep < 2) {
                                  setState(() => _checkoutStep++);
                                } else {
                                  _placeOrder();
                                }
                              },
                        child: _isProcessingPayment
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2),
                              )
                            : Text(
                                _checkoutStep == 0
                                    ? 'Proceed to Shipping (Rs. ${grandTotal.toStringAsFixed(0)})'
                                    : _checkoutStep == 1
                                        ? 'Continue to Payment'
                                        : 'Authorize & Place Order (Rs. ${grandTotal.toStringAsFixed(0)})',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w900, fontSize: 14),
                              ),
                      ),
                    ),
                  ),
                ),
        );
      },
    );
  }

  Widget _buildEmptyCart() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
                color: Color(0xFFFFECE5), shape: BoxShape.circle),
            child: const Icon(Icons.remove_shopping_cart_outlined,
                size: 48, color: Color(0xFFD64545)),
          ),
          const SizedBox(height: 18),
          const Text('Your Shopping Bag is Empty',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1B1B1F))),
          const SizedBox(height: 6),
          Text('Explore the feed to add fashion & lifestyle pieces.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        ],
      ),
    );
  }

  Widget _buildOrderSummaryCard(List<Map<String, dynamic>> cartItems,
      double subtotal, double grandTotal) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.035),
              blurRadius: 10,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Order Cost Summary',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          _summaryRow('Subtotal Items', 'Rs. ${subtotal.toStringAsFixed(0)}'),
          const SizedBox(height: 6),
          _summaryRow('Estimated Delivery',
              'Rs. ${_calculateShipping(cartItems).toStringAsFixed(0)}'),
          const SizedBox(height: 6),
          _summaryRow('Taxes & GST (5%)',
              'Rs. ${_calculateTax(subtotal).toStringAsFixed(0)}'),
          if (_appliedDiscount > 0) ...[
            const SizedBox(height: 6),
            _summaryRow('Coupon Voucher ($_activeCouponCode)',
                '- Rs. ${_appliedDiscount.toStringAsFixed(0)}',
                isDiscount: true),
          ],
          if (_quoteError != null) ...[
            const SizedBox(height: 10),
            Text(_quoteError!,
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFD64545))),
          ],
          const SizedBox(height: 10),
          Divider(color: Colors.grey.shade200, height: 1),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Grand Total',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF1B1B1F))),
              Text(
                'Rs. ${grandTotal.toStringAsFixed(0)}',
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFFD64545)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value, {bool isDiscount = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 12,
                color:
                    isDiscount ? const Color(0xFF2E7D32) : Colors.grey.shade600,
                fontWeight: isDiscount ? FontWeight.bold : FontWeight.normal)),
        Text(value,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isDiscount
                    ? const Color(0xFF2E7D32)
                    : const Color(0xFF1B1B1F))),
      ],
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFFD64545)),
        const SizedBox(width: 8),
        Text(title,
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1B1B1F),
                letterSpacing: 1.0)),
      ],
    );
  }

  Widget _buildShippingField(
      String hint, TextEditingController ctrl, IconData icon) {
    return TextField(
      controller: ctrl,
      decoration: InputDecoration(
        labelText: hint,
        labelStyle: TextStyle(fontSize: 11, color: Colors.grey.shade500),
        prefixIcon: Icon(icon, size: 18, color: const Color(0xFFD64545)),
        filled: true,
        fillColor: const Color(0xFFF7F3F0),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none),
      ),
    );
  }

  Widget _buildDeliveryOption(
      String title, String cost, String val, String desc) {
    final bool isSelected = _deliveryMethod == val;
    return GestureDetector(
      onTap: () {
        setState(() => _deliveryMethod = val);
        _refreshQuote();
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color:
                  isSelected ? const Color(0xFFD64545) : Colors.grey.shade200,
              width: isSelected ? 1.5 : 1),
        ),
        child: Row(
          children: [
            Icon(
                isSelected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
                color: isSelected ? const Color(0xFFD64545) : Colors.grey,
                size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 12)),
                  Text(desc,
                      style:
                          TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                ],
              ),
            ),
            Text(cost,
                style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1B1B1F),
                    fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentTab(String label, IconData icon) {
    final isSelected = _paymentOption == label;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _paymentOption = label),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 6)
                  ]
                : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 16,
                  color: isSelected
                      ? const Color(0xFFD64545)
                      : Colors.grey.shade600),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: isSelected
                      ? const Color(0xFFD64545)
                      : Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================
// SUBPAGE: ACTUAL SELLER ORDERS SCREEN (WITH BACK ARROW)
// =============================================================
class SellerOrdersScreen extends StatelessWidget {
  const SellerOrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF4F1),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Color(0xFF1B1B1F), size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'ORDERS & SHIPMENTS',
          style: TextStyle(
            color: Color(0xFF1B1B1F),
            fontSize: 13,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.0,
          ),
        ),
      ),
      body: const _SellerOrdersTab(),
    );
  }
}

// =============================================================
// SUBPAGE: MINIMAL SELLER PROFILE (NAME, ID, SETTINGS, FEEDBACK, LOGOUT)
// =============================================================
class SellerProfileScreen extends StatelessWidget {
  final String storeName;
  final String sellerId;
  const SellerProfileScreen(
      {super.key, this.storeName = 'My Store', this.sellerId = ''});

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Log Out of Store?',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
        content: const Text(
            'Are you sure you want to log out of your seller account?',
            style: TextStyle(fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel',
                style:
                    TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD64545),
              foregroundColor: Colors.white,
              shape: const StadiumBorder(),
              elevation: 0,
            ),
            onPressed: () {
              Navigator.pop(dialogCtx);
              // Cleanly logs out and returns to Role Selection screen
              logout(context); // signs out of Supabase, then back to Welcome
            },
            child: const Text('Log Out',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Seller Name & ID Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.035),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 30,
                  backgroundColor: Color(0xFFFFECE5),
                  child: Icon(Icons.storefront_rounded,
                      size: 32, color: Color(0xFFD64545)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        storeName,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF1B1B1F),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7F3F0),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Seller ID: $sellerId',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 2. Account Setting & Feedback Options
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              children: [
                ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                  leading: const Icon(Icons.settings_outlined,
                      color: Color(0xFF1B1B1F)),
                  title: const Text('Account Setting',
                      style:
                          TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded,
                      size: 14, color: Colors.grey),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Account settings opened'),
                        backgroundColor: const Color(0xFF1B1B1F),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                    );
                  },
                ),
                Divider(
                    height: 1,
                    indent: 18,
                    endIndent: 18,
                    color: Colors.grey.shade200),
                ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                  leading: const Icon(Icons.feedback_outlined,
                      color: Color(0xFF1B1B1F)),
                  title: const Text('Feedback',
                      style:
                          TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded,
                      size: 14, color: Colors.grey),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Feedback dialog opened'),
                        backgroundColor: const Color(0xFF1B1B1F),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // 3. Clear Log Out Button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD64545),
                foregroundColor: Colors.white,
                shape: const StadiumBorder(),
                elevation: 0,
              ),
              icon: const Icon(Icons.logout_rounded, size: 18),
              label: const Text(
                'Log Out',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
              ),
              onPressed: () => _showLogoutDialog(context),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================
// SUBPAGE: EDIT PRODUCT SCREEN (PRICE, NAME, STOCK, SKU)
// =============================================================
class EditProductScreen extends StatefulWidget {
  final Map<String, dynamic> product;
  final Function(Map<String, dynamic>) onSave;

  const EditProductScreen({
    super.key,
    required this.product,
    required this.onSave,
  });

  @override
  State<EditProductScreen> createState() => _EditProductScreenState();
}

class _EditProductScreenState extends State<EditProductScreen> {
  late TextEditingController _titleController;
  late TextEditingController _skuController;
  late TextEditingController _priceController;
  late TextEditingController _stockController;
  late TextEditingController _thresholdController;
  late String _category;

  @override
  void initState() {
    super.initState();
    _titleController =
        TextEditingController(text: widget.product['title'].toString());
    _skuController =
        TextEditingController(text: widget.product['sku'].toString());
    _priceController = TextEditingController(
        text: (widget.product['price'] as num).toString());
    _stockController =
        TextEditingController(text: widget.product['stock'].toString());
    _thresholdController =
        TextEditingController(text: widget.product['lowThreshold'].toString());
    _category = widget.product['category'] ?? 'Bags';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _skuController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    _thresholdController.dispose();
    super.dispose();
  }

  void _saveChanges() {
    if (_titleController.text.trim().isEmpty ||
        _priceController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Title and price cannot be empty.'),
          backgroundColor: const Color(0xFFD64545),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      );
      return;
    }

    final updated = Map<String, dynamic>.from(widget.product);
    updated['title'] = _titleController.text.trim();
    updated['sku'] = _skuController.text.trim().toUpperCase();
    updated['price'] = double.tryParse(_priceController.text.trim()) ??
        (widget.product['price'] as num).toDouble();
    updated['stock'] = int.tryParse(_stockController.text.trim()) ??
        (widget.product['stock'] as int);
    updated['lowThreshold'] = int.tryParse(_thresholdController.text.trim()) ??
        (widget.product['lowThreshold'] as int);
    updated['category'] = _category;

    widget.onSave(updated);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF4F1),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Color(0xFF1B1B1F), size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'EDIT PRODUCT DETAILS',
          style: TextStyle(
            color: Color(0xFF1B1B1F),
            fontSize: 13,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.0,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildFieldGroup('Product Title', _titleController,
                'e.g. Italian Velvet Loafers'),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                    child: _buildFieldGroup(
                        'SKU Code', _skuController, 'LL-SHO-501')),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Category',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _category,
                            isExpanded: true,
                            items: ['Bags', 'Shoes', 'Apparel', 'Accessories']
                                .map((c) => DropdownMenuItem(
                                    value: c,
                                    child: Text(c,
                                        style: const TextStyle(fontSize: 13))))
                                .toList(),
                            onChanged: (val) =>
                                setState(() => _category = val!),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                    child: _buildFieldGroup(
                        'Price (Rs.)', _priceController, '18500',
                        isNumber: true)),
                const SizedBox(width: 12),
                Expanded(
                    child: _buildFieldGroup('Live Stock', _stockController, '4',
                        isNumber: true)),
                const SizedBox(width: 12),
                Expanded(
                    child: _buildFieldGroup(
                        'Alert Min', _thresholdController, '8',
                        isNumber: true)),
              ],
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD64545),
                  foregroundColor: Colors.white,
                  shape: const StadiumBorder(),
                  elevation: 0,
                ),
                icon: const Icon(Icons.check_circle_rounded, size: 20),
                label: const Text('Save & Update Product',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                onPressed: _saveChanges,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFieldGroup(
      String label, TextEditingController controller, String hint,
      {bool isNumber = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1B1B1F))),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: TextField(
            controller: controller,
            keyboardType: isNumber ? TextInputType.number : TextInputType.text,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade400),
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ),
      ],
    );
  }
}

// =============================================================
// BUYER PRODUCT LISTING SCREEN (WITH RESTORED FILTERS, SORT & INFINITE SCROLL)
// =============================================================
class BuyerProductListingScreen extends StatefulWidget {
  final String categoryTitle;
  final VoidCallback? onBackToDashboard;
  const BuyerProductListingScreen({
    super.key,
    this.categoryTitle = 'Category Taxonomy',
    this.onBackToDashboard,
  });

  @override
  State<BuyerProductListingScreen> createState() =>
      _BuyerProductListingScreenState();
}

class _BuyerProductListingScreenState extends State<BuyerProductListingScreen> {
  bool _isLoadingMore = false;

  // Filter & Sort State
  String _selectedSort = 'Popularity';
  double _maxPriceFilter = 50000;
  String _selectedBrandFilter = 'All';
  double _minRatingFilter = 0.0;

  List<String> _brandsList = ['All'];

  // ---- live catalog (buyer_list_products), filtered + sorted on the server ----
  static const int _pageSize = 20;
  final List<Map<String, dynamic>> _products = [];
  bool _initialLoading = true;
  bool _hasMore = true;
  String? _loadError;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    BuyerCartState.catalogRefresh.addListener(_silentRefresh);
    _loadBrands();
    _reload();
  }

  @override
  void dispose() {
    BuyerCartState.catalogRefresh.removeListener(_silentRefresh);
    super.dispose();
  }

  void _silentRefresh() {
    _loadBrands();
    _reload(silent: true);
  }

  Future<void> _loadBrands() async {
    try {
      final brands = await BuyerService.fetchBrands();
      if (!mounted) return;
      setState(() {
        _brandsList = brands;
        if (!_brandsList.contains(_selectedBrandFilter)) {
          _selectedBrandFilter = 'All';
        }
      });
    } catch (_) {
      // brand chips just stay on "All"
    }
  }

  Future<List<Map<String, dynamic>>> _fetchPage(int offset) {
    return BuyerService.fetchProducts(
      maxPrice: _maxPriceFilter < 50000 ? _maxPriceFilter : null,
      brand: _selectedBrandFilter,
      minRating: _minRatingFilter,
      sort: _selectedSort,
      limit: _pageSize,
      offset: offset,
    );
  }

  /// Reloads page 1 with the current sort + filters.
  Future<void> _reload({bool silent = false}) async {
    final int req = ++_requestId;
    if (!silent) {
      setState(() {
        _initialLoading = true;
        _loadError = null;
        _isLoadingMore = false;
      });
    }
    try {
      final items = await _fetchPage(0);
      if (!mounted || req != _requestId) return;
      setState(() {
        _products
          ..clear()
          ..addAll(items);
        _hasMore = items.length >= _pageSize;
        _initialLoading = false;
        _isLoadingMore = false;
        _loadError = null;
      });
    } catch (e) {
      if (!mounted || req != _requestId) return;
      setState(() {
        _initialLoading = false;
        if (!silent || _products.isEmpty) {
          _loadError = BuyerService.errorMessage(e);
        }
      });
    }
  }

  // Infinite Scroll Trigger: next page from the server
  Future<void> _loadMoreBatch() async {
    if (_isLoadingMore || !_hasMore || _initialLoading || _products.isEmpty) {
      return;
    }
    final int req = _requestId;
    setState(() => _isLoadingMore = true);
    try {
      final items = await _fetchPage(_products.length);
      if (!mounted || req != _requestId) return;
      setState(() {
        final known = _products.map((p) => p['id']).toSet();
        _products.addAll(items.where((p) => !known.contains(p['id'])));
        _hasMore = items.length >= _pageSize;
        _isLoadingMore = false;
      });
    } catch (_) {
      if (!mounted || req != _requestId) return;
      setState(() {
        _isLoadingMore = false;
        _hasMore = false;
      });
    }
  }

  // --- SORT BOTTOM SHEET MODAL ---
  void _showSortBottomSheet() {
    final List<String> sortOptions = [
      'Popularity',
      'Price: Low to High',
      'Price: High to Low',
      'Customer Rating',
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Sort Products By',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1B1B1F)),
            ),
            const SizedBox(height: 14),
            ...sortOptions.map((opt) {
              final isSelected = _selectedSort == opt;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  opt,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                    color: isSelected
                        ? const Color(0xFFD64545)
                        : const Color(0xFF1B1B1F),
                  ),
                ),
                trailing: isSelected
                    ? const Icon(Icons.check_circle_rounded,
                        color: Color(0xFFD64545), size: 22)
                    : null,
                onTap: () {
                  setState(() => _selectedSort = opt);
                  Navigator.pop(ctx);
                  _reload();
                },
              );
            }),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  // --- MULTI-LAYER FILTER BOTTOM SHEET MODAL ---
  void _showFilterBottomSheet() {
    double tempPrice = _maxPriceFilter;
    String tempBrand = _selectedBrandFilter;
    double tempRating = _minRatingFilter;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.only(
            top: 24,
            left: 24,
            right: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Multi-Layer Filters',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF1B1B1F)),
                  ),
                  TextButton(
                    onPressed: () {
                      setModalState(() {
                        tempPrice = 50000;
                        tempBrand = 'All';
                        tempRating = 0.0;
                      });
                    },
                    child: const Text('Reset All',
                        style: TextStyle(
                            color: Color(0xFFD64545),
                            fontWeight: FontWeight.bold,
                            fontSize: 12)),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // 1. PRICE FILTER
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Max Price Filter',
                      style:
                          TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                  Text('Up to Rs. ${tempPrice.toInt()}',
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFFD64545))),
                ],
              ),
              Slider(
                value: tempPrice,
                min: 500,
                max: 50000,
                divisions: 99,
                activeColor: const Color(0xFFD64545),
                inactiveColor: const Color(0xFFFFECE5),
                onChanged: (val) => setModalState(() => tempPrice = val),
              ),
              const SizedBox(height: 14),

              // 2. BRAND FILTER
              const Text('Filter by Brand',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _brandsList.map((brand) {
                  final isSelected = tempBrand == brand;
                  return ChoiceChip(
                    label: Text(brand),
                    selected: isSelected,
                    selectedColor: const Color(0xFFFFECE5),
                    backgroundColor: const Color(0xFFF7F3F0),
                    labelStyle: TextStyle(
                      fontSize: 11,
                      fontWeight:
                          isSelected ? FontWeight.w800 : FontWeight.w600,
                      color:
                          isSelected ? const Color(0xFFD64545) : Colors.black87,
                    ),
                    onSelected: (_) => setModalState(() => tempBrand = brand),
                  );
                }).toList(),
              ),
              const SizedBox(height: 18),

              // 3. RATING FILTER
              const Text('Minimum Customer Rating',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [0.0, 4.0, 4.5, 4.8].map((rt) {
                  final isSelected = tempRating == rt;
                  final label = rt == 0.0 ? 'All' : '$rt★ & up';
                  return ChoiceChip(
                    label: Text(label),
                    selected: isSelected,
                    selectedColor: const Color(0xFFFFECE5),
                    backgroundColor: const Color(0xFFF7F3F0),
                    labelStyle: TextStyle(
                      fontSize: 11,
                      fontWeight:
                          isSelected ? FontWeight.w800 : FontWeight.w600,
                      color:
                          isSelected ? const Color(0xFFD64545) : Colors.black87,
                    ),
                    onSelected: (_) => setModalState(() => tempRating = rt),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              // APPLY BUTTON
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1B1B1F),
                    foregroundColor: Colors.white,
                    shape: const StadiumBorder(),
                    elevation: 0,
                  ),
                  onPressed: () {
                    setState(() {
                      _maxPriceFilter = tempPrice;
                      _selectedBrandFilter = tempBrand;
                      _minRatingFilter = tempRating;
                    });
                    Navigator.pop(ctx);
                    _reload();
                  },
                  child: const Text('Apply Filters',
                      style:
                          TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Filtering and sorting now happen on the server (see _fetchPage).
  List<Map<String, dynamic>> _getProcessedProducts() => _products;

  @override
  Widget build(BuildContext context) {
    final displayedProducts = _getProcessedProducts();
    final bool hasActiveFilters = _maxPriceFilter < 50000 ||
        _selectedBrandFilter != 'All' ||
        _minRatingFilter > 0.0;

    return Scaffold(
      backgroundColor: const Color(0xFFFAF4F1),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Color(0xFF1B1B1F), size: 18),
          onPressed: () {
            if (widget.onBackToDashboard != null) {
              widget.onBackToDashboard!(); // Navigates to the Shop tab
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: Text(
          widget.categoryTitle.toUpperCase(),
          style: const TextStyle(
              color: Color(0xFF1B1B1F),
              fontSize: 13,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.1),
        ),
      ),
      body: Column(
        children: [
          // ==========================================
          // SORT & MULTI-LAYER FILTER ACTION STRIP (RESTORED)
          // ==========================================
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                // Sort Button with Current Selection
                Expanded(
                  child: InkWell(
                    onTap: _showSortBottomSheet,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 8, horizontal: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F3F0),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.swap_vert_rounded,
                              size: 18, color: Color(0xFFD64545)),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              _selectedSort,
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF1B1B1F)),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Multi-Layer Filter Button with Active Indicator
                Expanded(
                  child: InkWell(
                    onTap: _showFilterBottomSheet,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 8, horizontal: 10),
                      decoration: BoxDecoration(
                        color: hasActiveFilters
                            ? const Color(0xFFFFECE5)
                            : const Color(0xFFF7F3F0),
                        borderRadius: BorderRadius.circular(12),
                        border: hasActiveFilters
                            ? Border.all(color: const Color(0xFFD64545))
                            : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.tune_rounded,
                            size: 18,
                            color: hasActiveFilters
                                ? const Color(0xFFD64545)
                                : const Color(0xFF1B1B1F),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            hasActiveFilters ? 'Filter (Active)' : 'Filter',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: hasActiveFilters
                                  ? const Color(0xFFD64545)
                                  : const Color(0xFF1B1B1F),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ==========================================
          // PRODUCT GRID WITH INFINITE SCROLL
          // ==========================================
          Expanded(
            child: (_initialLoading && displayedProducts.isEmpty)
                ? const Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Color(0xFFD64545)),
                    ),
                  )
                : (_loadError != null && displayedProducts.isEmpty)
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.cloud_off_rounded,
                                  size: 48, color: Colors.grey),
                              const SizedBox(height: 12),
                              Text(_loadError!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13)),
                              TextButton(
                                onPressed: () => _reload(),
                                child: const Text('Retry',
                                    style: TextStyle(
                                        color: Color(0xFFD64545),
                                        fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        ),
                      )
                    : displayedProducts.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.search_off_rounded,
                            size: 48, color: Colors.grey),
                        const SizedBox(height: 12),
                        Text(
                            hasActiveFilters
                                ? 'No products match these filters'
                                : 'No products available yet',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _maxPriceFilter = 50000;
                              _selectedBrandFilter = 'All';
                              _minRatingFilter = 0.0;
                            });
                            _reload();
                          },
                          child: const Text('Reset Filters',
                              style: TextStyle(
                                  color: Color(0xFFD64545),
                                  fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  )
                : NotificationListener<ScrollNotification>(
                    onNotification: (ScrollNotification scrollInfo) {
                      if (scrollInfo.metrics.pixels >=
                          scrollInfo.metrics.maxScrollExtent - 250) {
                        _loadMoreBatch();
                      }
                      return false;
                    },
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(12),
                      children: [
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 12,
                            childAspectRatio: 0.65,
                          ),
                          itemCount: displayedProducts.length,
                          itemBuilder: (context, index) {
                            final p = displayedProducts[index];
                            return GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) =>
                                          ProductDetailScreen(product: p)),
                                );
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(18),
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          Colors.black.withValues(alpha: 0.035),
                                      blurRadius: 10,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      height: 140,
                                      clipBehavior: Clip.antiAlias,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFF7F3F0),
                                        borderRadius: BorderRadius.vertical(
                                            top: Radius.circular(18)),
                                      ),
                                      alignment: Alignment.center,
                                      child: BuyerProductThumb(
                                          product: p,
                                          icon: Icons.diamond_outlined,
                                          iconSize: 44),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(10.0),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            p['brand'] as String,
                                            style: TextStyle(
                                                fontSize: 10,
                                                color: Colors.grey.shade500,
                                                fontWeight: FontWeight.w600),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            p['title'] as String,
                                            style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                                color: Color(0xFF1B1B1F)),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              const Icon(Icons.star_rounded,
                                                  size: 14,
                                                  color: Colors.amber),
                                              const SizedBox(width: 2),
                                              Text('${p['rating']}',
                                                  style: const TextStyle(
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.bold)),
                                              const SizedBox(width: 4),
                                              Text('(${p['reviewsCount']})',
                                                  style: TextStyle(
                                                      fontSize: 9,
                                                      color: Colors
                                                          .grey.shade500)),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            'Rs. ${(p['price'] as double).toStringAsFixed(0)}',
                                            style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w900,
                                                color: Color(0xFFD64545)),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                        if (_isLoadingMore)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 20.0),
                            child: Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Color(0xFFD64545)),
                              ),
                            ),
                          )
                        else
                          const SizedBox(height: 30),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// =============================================================
// BUYER "ME" PROFILE SCREEN (WITH DYNAMIC UNPAID & PROCESSING BADGES)
// =============================================================
class BuyerProfileScreen extends StatelessWidget {
  const BuyerProfileScreen({super.key});

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Log Out of Buyer Account?',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
        content: const Text('Are you sure you want to log out?',
            style: TextStyle(fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel',
                style:
                    TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD64545),
              foregroundColor: Colors.white,
              shape: const StadiumBorder(),
              elevation: 0,
            ),
            onPressed: () {
              Navigator.pop(dialogCtx);
              logout(context); // signs out of Supabase, then back to Welcome
            },
            child: const Text('Log Out',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User Header
            Row(
              children: [
                const CircleAvatar(
                  radius: 30,
                  backgroundColor: Color(0xFFFFECE5),
                  child: Icon(Icons.person_rounded,
                      size: 36, color: Color(0xFFD64545)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: ValueListenableBuilder<AppProfile?>(
                    valueListenable: BuyerCartState.profileNotifier,
                    builder: (context, profile, _) {
                      final String rawName = profile?.fullName?.trim() ?? '';
                      final String name =
                          rawName.isNotEmpty ? rawName : 'LoopLab Buyer';
                      final String email =
                          SupabaseService.client.auth.currentUser?.email ?? '';
                      final String contact =
                          email.isNotEmpty ? email : (profile?.phone ?? '');
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF1B1B1F)),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            contact,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey.shade600),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // 1. Vouchers & Points Row
            Container(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 2)),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildIconAction(
                      Icons.confirmation_number_outlined, 'Vouchers'),
                  Container(height: 24, width: 1, color: Colors.grey.shade200),
                  _buildIconAction(Icons.monetization_on_outlined, 'Points'),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 2. My Orders Section (Dynamic Unpaid & Processing Badges)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 2)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'My Orders',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1B1B1F)),
                      ),
                      Row(
                        children: [
                          Text('View All',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade500,
                                  fontWeight: FontWeight.bold)),
                          const Icon(Icons.chevron_right_rounded,
                              size: 16, color: Colors.grey),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      ValueListenableBuilder<List<Map<String, dynamic>>>(
                        valueListenable: BuyerCartState.unpaidOrdersNotifier,
                        builder: (context, unpaidList, _) {
                          return _buildIconAction(
                            Icons.payment_rounded,
                            'Unpaid',
                            badgeCount: unpaidList.length,
                          );
                        },
                      ),
                      ValueListenableBuilder<List<Map<String, dynamic>>>(
                        valueListenable:
                            BuyerCartState.processingOrdersNotifier,
                        builder: (context, processingList, _) {
                          return _buildIconAction(
                            Icons.inventory_2_outlined,
                            'Processing',
                            badgeCount: processingList.length,
                          );
                        },
                      ),
                      _buildIconAction(
                          Icons.local_shipping_outlined, 'Shipped'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 3. Customer Service
           // 3. Customer Service
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2)),
                ],
              ),
              child: Material(
                type: MaterialType.transparency,
                borderRadius: BorderRadius.circular(18),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF7F3F0),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.support_agent_rounded, color: Color(0xFF1B1B1F), size: 22),
                  ),
                  title: const Text(
                    'Customer Service',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF1B1B1F)),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded, size: 18, color: Colors.grey),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Connecting to live support...'),
                        backgroundColor: const Color(0xFF1B1B1F),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 28),

            // 4. Log Out Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD64545),
                  foregroundColor: Colors.white,
                  shape: const StadiumBorder(),
                  elevation: 0,
                ),
                icon: const Icon(Icons.logout_rounded, size: 18),
                label: const Text('Log Out',
                    style:
                        TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                onPressed: () => _showLogoutDialog(context),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildIconAction(IconData icon, String label, {int badgeCount = 0}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(icon, size: 24, color: const Color(0xFF1B1B1F)),
            if (badgeCount > 0)
              Positioned(
                right: -8,
                top: -4,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Color(0xFFD64545),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$badgeCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1B1B1F)),
        ),
      ],
    );
  }
}