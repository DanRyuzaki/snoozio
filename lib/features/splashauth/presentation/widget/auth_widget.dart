import 'package:flutter/material.dart';

class AuthWidget extends StatelessWidget {
  final Animation<double> slideAnimation;
  final Animation<double> fadeAnimation;
  final Animation<double> buttonScaleAnimation;
  final bool isLoading;

  final Future<void> Function() onGoogleSignIn;
  final Future<void> Function() onGuestSignIn;

  const AuthWidget({
    super.key,
    required this.slideAnimation,
    required this.fadeAnimation,
    required this.buttonScaleAnimation,
    required this.isLoading,
    required this.onGoogleSignIn,
    required this.onGuestSignIn,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: Offset(0, slideAnimation.value),
      child: FadeTransition(
        opacity: fadeAnimation,
        child: Column(
          children: [
            _buildTitle(),
            const SizedBox(height: 10),
            _buildSubtitle(),
            const SizedBox(height: 30),
            _buildGoogleSignInButton(),
            const SizedBox(height: 32),
            _buildDivider(),
            const SizedBox(height: 20),
            _buildGuestButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildTitle() => const Text(
    "Get Started",
    textAlign: TextAlign.center,
    style: TextStyle(
      color: Colors.white,
      fontSize: 30,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.2,
    ),
  );

  Widget _buildSubtitle() => Text(
    "Your better days begin with better nights",
    style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 16),
  );

  Widget _buildGoogleSignInButton() {
    return Transform.scale(
      scale: buttonScaleAnimation.value,
      child: InkWell(
        onTap: isLoading ? null : onGoogleSignIn,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF8B5FD6), Color(0xFF6A3FB5)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.g_mobiledata, color: Colors.white, size: 28),
              SizedBox(width: 16),
              Text(
                "Continue with Google",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDivider() => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Container(
        width: 40,
        height: 1,
        color: Colors.white.withValues(alpha: 0.3),
      ),
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: Text("or", style: TextStyle(color: Colors.white70)),
      ),
      Container(
        width: 40,
        height: 1,
        color: Colors.white.withValues(alpha: 0.3),
      ),
    ],
  );

  Widget _buildGuestButton() {
    return TextButton(
      onPressed: isLoading ? null : onGuestSignIn,
      child: Text(
        "Continue as Guest",
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.8),
          fontSize: 16,
          fontWeight: FontWeight.w500,
          decoration: TextDecoration.underline,
        ),
      ),
    );
  }
}
