import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:snoozio/features/splashauth/presentation/widget/auth_widget.dart';
import 'package:zhi_starry_sky/starry_sky.dart';
import 'package:snoozio/features/splashauth/logic/service/auth_service.dart';
import 'package:snoozio/features/splashauth/logic/controller/splashauth_controller.dart';

class SplashAuthScreen extends StatefulWidget {
  const SplashAuthScreen({super.key});

  @override
  State<SplashAuthScreen> createState() => _SplashAuthScreenState();
}

class _SplashAuthScreenState extends State<SplashAuthScreen>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late AnimationController _buttonController;
  late AnimationController _pulseController;

  late Animation<double> _logoAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;
  late Animation<double> _buttonScaleAnimation;
  late Animation<double> _pulseAnimation;

  bool _showContent = false;
  bool _isLoading = false;
  SplashController? _splashController;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_splashController == null) {
      final authService = Provider.of<GoogleAuthService>(
        context,
        listen: false,
      );
      _splashController = SplashController(authService);
      _checkAuthenticationAndNavigate();
    }
  }

  void _setupAnimations() {
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _buttonController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _logoAnimation = Tween<double>(begin: 0, end: -20).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
      ),
    );

    _slideAnimation = Tween<double>(begin: 50, end: 0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.5, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    _buttonScaleAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _buttonController, curve: Curves.easeOut),
    );

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  Future<void> _checkAuthenticationAndNavigate() async {
    if (_splashController == null) return;

    final route = await _splashController!.checkInitialRoute();

    if (!mounted) return;

    if (route == '/main') {
      _navigateToRoute(route);
    } else if (route == '/assessment') {
      _navigateToRoute(route);
    } else {
      setState(() => _showContent = true);
      _controller.forward();
    }
  }

  void _navigateToRoute(String route) {
    Navigator.of(context).pushReplacementNamed(route);
  }

  Future<void> _handleGoogleSignIn() async {
    if (_splashController == null || _isLoading) return;

    _animateButton();
    setState(() => _isLoading = true);

    final route = await _splashController!.signInWithGoogle(context);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (route != null) {
      _navigateToRoute(route);
    } else {
      _showErrorMessage('Failed to sign in with Google');
    }
  }

  Future<void> _handleGuestSignIn() async {
    if (_splashController == null || _isLoading) return;

    setState(() => _isLoading = true);

    final route = await _splashController!.signInAsGuest();

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (route != null) {
      _navigateToRoute(route);
    } else {
      _showErrorMessage('Failed to continue as guest');
    }
  }

  void _animateButton() {
    _buttonController.forward().then((_) => _buttonController.reverse());
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _buttonController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          _buildBackground(),
          if (_isLoading) _buildLoadingOverlay(),
          _buildContent(),
        ],
      ),
    );
  }

  Widget _buildBackground() {
    return Stack(
      children: [
        const ColorFiltered(
          colorFilter: ColorFilter.matrix([
            -1,
            0,
            0,
            0,
            255,
            0,
            -1,
            0,
            0,
            255,
            0,
            0,
            -1,
            0,
            255,
            0,
            0,
            0,
            1,
            0,
          ]),
          child: StarrySkyView(),
        ),

        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFF2E1A47).withValues(alpha: 0.8),
                const Color(0xFF1A0D2E).withValues(alpha: 0.9),
                const Color(0xFF0D0A1A).withValues(alpha: 0.95),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.5),
      child: const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      ),
    );
  }

  Widget _buildContent() {
    return Center(
      child: AnimatedBuilder(
        animation: Listenable.merge([
          _controller,
          _buttonController,
          _pulseController,
        ]),
        builder: (context, child) {
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLogo(),
              SizedBox(height: 40 + _logoAnimation.value.abs() * 0.3),
              if (_showContent)
                AuthWidget(
                  slideAnimation: _slideAnimation,
                  fadeAnimation: _fadeAnimation,
                  buttonScaleAnimation: _buttonScaleAnimation,
                  isLoading: _isLoading,
                  onGoogleSignIn: _handleGoogleSignIn,
                  onGuestSignIn: _handleGuestSignIn,
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildLogo() {
    return Transform.translate(
      offset: Offset(0, _logoAnimation.value),
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: 0.95 + (0.05 * _pulseAnimation.value),
            child: Image.asset(
              "assets/icon/Snoozio-No-BG-2.png",
              width: 210,
              fit: BoxFit.contain,
            ),
          );
        },
      ),
    );
  }
}
