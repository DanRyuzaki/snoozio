import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:snoozio/features/main/presentation/pages/drawer/account_info_dialog.dart';
import 'package:snoozio/features/main/presentation/pages/drawer/legal_document_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:snoozio/features/main/presentation/pages/diagnostics/notification_diagnostic_screen.dart';
import 'dart:math';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  Future<Map<String, dynamic>> _getUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('No user logged in');

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (!userDoc.exists) throw Exception('User document not found');

    final data = userDoc.data() ?? {};
    return {
      'displayName': data['displayName'] ?? 'User',
      'email': user.email ?? 'No email',
      'avatar': data['avatar'] ?? '😊',
      'isGuest': data['isGuest'] ?? false,
    };
  }

  Future<void> _showAccountInfo(BuildContext context) async {
    Navigator.pop(context);
    await showDialog(
      context: context,
      builder: (context) => const AccountInfoDialog(),
    );
  }

  Future<void> _showDeveloperTools(BuildContext context) async {
    final random = Random();
    final num1 = random.nextInt(10) + 1;
    final num2 = random.nextInt(10) + 1;
    final correctAnswer = num1 + num2;

    final answer = await showDialog<int>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _CaptchaDialog(num1: num1, num2: num2),
    );

    if (!context.mounted) return;

    if (answer != null && answer == correctAnswer) {
      Navigator.of(context).pop();
      Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute(
          builder: (context) => const NotificationDiagnosticScreen(),
        ),
      );
    } else if (answer != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Incorrect answer. Access denied.'),
          backgroundColor: Color(0xFFE74C3C),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _showEmailHotline(BuildContext context) async {
    Navigator.pop(context);
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E0F33),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            HugeIcon(
              icon: HugeIcons.strokeRoundedCustomerSupport,
              color: Color(0xFFE0AAFF),
              size: 24,
            ),
            SizedBox(width: 12),
            Text(
              'Help Center',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
          ],
        ),
        content: const Text(
          'You may contact our team via email: snoozio.helpdesk@gmail.com',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final url = Uri.parse('mailto:snoozio.helpdesk@gmail.com');
              if (await canLaunchUrl(url)) {
                await launchUrl(url);
              } else {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Could not open email app'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
              if (context.mounted) Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6C5CE7),
            ),
            child: const Text('Email', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _showLegalDocument(BuildContext context, String docType) async {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LegalDocumentScreen(documentType: docType),
      ),
    );
  }

  Future<void> _openGitHub(BuildContext context, uri) async {
    final url = Uri.parse(uri);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open GitHub'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _signOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E0F33),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Sign Out', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to sign out?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE74C3C),
            ),
            child: const Text(
              'Sign Out',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        await GoogleSignIn.instance.signOut();
        await FirebaseAuth.instance.signOut();

        if (context.mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error signing out: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: const Color(0xFF1A0D2E),
      child: Column(
        children: [
          FutureBuilder<Map<String, dynamic>>(
            future: _getUserData(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox(
                  height: 250,
                  child: Center(
                    child: CircularProgressIndicator(color: Color(0xFF9D4EDD)),
                  ),
                );
              }

              if (snapshot.hasError || !snapshot.hasData) {
                return const SizedBox(
                  height: 250,
                  child: Center(
                    child: Text(
                      'Error loading user data',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                );
              }

              final userData = snapshot.data!;
              return _buildHeader(userData);
            },
          ),

          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildMenuItem(
                  icon: HugeIcons.strokeRoundedUser,
                  title: 'Account Information',
                  onTap: () => _showAccountInfo(context),
                ),
                _buildMenuItem(
                  icon: HugeIcons.strokeRoundedCustomerSupport,
                  title: 'Help Center',
                  onTap: () => _showEmailHotline(context),
                ),

                _buildMenuItem(
                  icon: HugeIcons.strokeRoundedCode,
                  title: 'Developer Tools',
                  subtitle: 'Diagnostics & troubleshooting',
                  onTap: () => _showDeveloperTools(context),
                  iconColor: const Color(0xFFFF9800),
                ),

                const Divider(
                  color: Colors.white24,
                  height: 32,
                  indent: 16,
                  endIndent: 16,
                ),

                _buildMenuItem(
                  icon: HugeIcons.strokeRoundedFileView,
                  title: 'Terms of Use',
                  onTap: () => _showLegalDocument(context, 'tou'),
                ),
                _buildMenuItem(
                  icon: HugeIcons.strokeRoundedSecurityLock,
                  title: 'Privacy Policy',
                  onTap: () => _showLegalDocument(context, 'pp'),
                ),
                _buildMenuItem(
                  icon: HugeIcons.strokeRoundedGithub,
                  title: 'GitHub',
                  onTap: () => _openGitHub(
                    context,
                    'https://github.com/DanRyuzaki/snoozio',
                  ),
                ),

                const Divider(
                  color: Colors.white24,
                  height: 32,
                  indent: 16,
                  endIndent: 16,
                ),

                _buildMenuItem(
                  icon: HugeIcons.strokeRoundedLogout03,
                  title: 'Sign Out',
                  onTap: () => _signOut(context),
                  textColor: const Color(0xFFE74C3C),
                  iconColor: const Color(0xFFE74C3C),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(Map<String, dynamic> userData) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 60, 24, 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF2E1A47).withValues(alpha: 0.8),
            const Color(0xFF1A0D2E).withValues(alpha: 0.9),
          ],
        ),
        border: Border(
          bottom: BorderSide(
            color: const Color(0xFF9D4EDD).withValues(alpha: 0.3),
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF9D4EDD).withValues(alpha: 0.3),
                  const Color(0xFF6C5CE7).withValues(alpha: 0.3),
                ],
              ),
              border: Border.all(
                color: const Color(0xFF9D4EDD).withValues(alpha: 0.5),
                width: 3,
              ),
            ),
            child: Center(
              child: Text(
                userData['avatar'],
                style: const TextStyle(fontSize: 40),
              ),
            ),
          ),
          const SizedBox(height: 16),

          Text(
            userData['displayName'],
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),

          Text(
            userData['email'],
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildBadge(
                icon: HugeIcons.strokeRoundedCheckmarkCircle02,
                label: 'Online',
                color: const Color(0xFF27AE60),
              ),
              const SizedBox(width: 8),
              _buildBadge(
                icon: userData['isGuest']
                    ? HugeIcons.strokeRoundedUserQuestion01
                    : HugeIcons.strokeRoundedUserAccount,
                label: userData['isGuest'] ? 'Guest' : 'Account',
                color: userData['isGuest']
                    ? const Color(0xFFFF9800)
                    : const Color(0xFF9D4EDD),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBadge({
    required List<List<dynamic>> icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          HugeIcon(icon: icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required List<List<dynamic>> icon,
    required String title,
    required VoidCallback onTap,
    String? subtitle,
    Color? textColor,
    Color? iconColor,
  }) {
    return ListTile(
      leading: HugeIcon(
        icon: icon,
        size: 24,
        color: iconColor ?? const Color(0xFFE0AAFF),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: textColor ?? Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: TextStyle(
                color: (textColor ?? Colors.white).withValues(alpha: 0.6),
                fontSize: 12,
              ),
            )
          : null,
      onTap: onTap,
      hoverColor: Colors.white.withValues(alpha: 0.05),
      splashColor: Colors.white.withValues(alpha: 0.1),
    );
  }
}

class _CaptchaDialog extends StatefulWidget {
  final int num1;
  final int num2;

  const _CaptchaDialog({required this.num1, required this.num2});

  @override
  State<_CaptchaDialog> createState() => _CaptchaDialogState();
}

class _CaptchaDialogState extends State<_CaptchaDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E0F33),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          HugeIcon(
            icon: HugeIcons.strokeRoundedSecurityCheck,
            color: Color(0xFFE0AAFF),
            size: 24,
          ),
          SizedBox(width: 12),
          Text(
            'Security Check',
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Please solve this math problem to access Developer Tools:',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF6C5CE7).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF6C5CE7).withValues(alpha: 0.4),
              ),
            ),
            child: Text(
              '${widget.num1} + ${widget.num2} = ?',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _controller,
            keyboardType: TextInputType.number,
            autofocus: true,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
            decoration: InputDecoration(
              hintText: 'Your answer',
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.1),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.2),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.2),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Color(0xFF6C5CE7),
                  width: 2,
                ),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
        ),
        ElevatedButton(
          onPressed: () {
            final answer = int.tryParse(_controller.text);
            Navigator.pop(context, answer);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF6C5CE7),
          ),
          child: const Text('Verify', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}
