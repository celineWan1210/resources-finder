import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'map_screen.dart' as map;
import 'contribution_screen.dart' as contrib;
import 'profile_screen.dart';
import 'community_screen.dart' as community;
import 'request_help_screen.dart';
import 'widgets/translatable_text.dart';
import 'widgets/language_toggle.dart';
import 'widgets/voice_navigation_button.dart';
import 'widgets/tester_consent_dialog.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    _maybeShowTesterConsent();
  }

  Future<void> _maybeShowTesterConsent() async {
    // Short delay so the home screen finishes rendering first
    await Future.delayed(const Duration(milliseconds: 600));
    if (mounted) {
      await TesterConsentDialog.showIfNeeded(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final bool isGuest = user == null;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: const TranslatableText(
          "Community Resources",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue[700]!, Colors.blue[500]!],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          const LanguageToggle(),
          if (isGuest)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Chip(
                avatar: const Icon(Icons.person_outline, size: 16, color: Colors.white),
                label: const TranslatableText(
                  'Guest',
                  style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold),
                ),
                backgroundColor: Colors.orange[600],
              ),
            ),
          if (!isGuest)
            PopupMenuButton<String>(
              icon: CircleAvatar(
                backgroundColor: Colors.white.withValues(alpha: 0.3),
                child: Text(
                  user.displayName?.substring(0, 1).toUpperCase() ?? 'U',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
              onSelected: (value) async {
                if (value == 'profile') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ProfileScreen()),
                  );
                } else if (value == 'logout') {
                  await FirebaseAuth.instance.signOut();
                  if (context.mounted) {
                    Navigator.pushReplacementNamed(context, '/login');
                  }
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  enabled: false,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.displayName ?? 'User',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        user.email ?? '',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      const Divider(),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'profile',
                  child: Row(
                    children: [
                      Icon(Icons.person, color: Colors.blue, size: 20),
                      SizedBox(width: 12),
                      TranslatableText('Profile'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'logout',
                  child: Row(
                    children: [
                      Icon(Icons.logout, color: Colors.red, size: 20),
                      SizedBox(width: 12),
                      TranslatableText('Logout'),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      floatingActionButton: const VoiceNavigationButton(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue[50]!, Colors.white],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      TranslatableText(
                        isGuest ? 'Welcome, Guest!' : 'Welcome,',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                      if (!isGuest) ...[
                        const SizedBox(width: 6),
                        Text(
                          '${user.displayName?.split(' ')[0] ?? 'User'}!',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  TranslatableText(
                    'Find help or share resources in your community.',
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 16),

                  if (isGuest)
                    _buildGuestBanner(context),

                  const SizedBox(height: 10),

                  TranslatableText(
                    'Quick Actions',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildQuickActions(context),

                  const SizedBox(height: 20),

                  TranslatableText(
                    'Find Resources',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 12),

                  _buildActionCard(
                    context: context,
                    title: 'Food Banks',
                    subtitle: 'AI‑verified food resources near you',
                    actionLabel: 'Open map',
                    icon: Icons.restaurant_menu,
                    gradient: LinearGradient(
                      colors: [Colors.orange[400]!, Colors.orange[600]!],
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const map.MapScreen(locationType: 'foodbank')),
                      );
                    },
                  ),
                  const SizedBox(height: 14),

                  _buildActionCard(
                    context: context,
                    title: 'Shelters',
                    subtitle: 'Safe shelter locations and updates',
                    actionLabel: 'Open map',
                    icon: Icons.home_filled,
                    gradient: const LinearGradient(
                      colors: [Color.fromARGB(160, 233, 30, 99), Color.fromARGB(200, 233, 30, 99)],
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const map.MapScreen(locationType: 'shelter')),
                      );
                    },
                  ),
                  const SizedBox(height: 14),

                  _buildActionCard(
                    context: context,
                    title: 'Community Resources',
                    subtitle: 'Browse all shared resources',
                    actionLabel: 'Browse list',
                    icon: Icons.groups,
                    gradient: LinearGradient(
                      colors: [Colors.purple[400]!, Colors.purple[600]!],
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const community.CommunityScreen()),
                      );
                    },
                  ),

                  const SizedBox(height: 24),

                  TranslatableText(
                    'Contribute',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 12),

                  _buildActionCard(
                    context: context,
                    title: 'Share Resources',
                    subtitle: isGuest
                        ? 'Sign in to share with your community'
                        : 'Post food, shelter, or help offers',
                    actionLabel: isGuest ? 'Sign in' : 'Share now',
                    icon: isGuest ? Icons.lock_outline : Icons.volunteer_activism,
                    gradient: isGuest
                        ? LinearGradient(colors: [Colors.grey[400]!, Colors.grey[600]!])
                        : LinearGradient(colors: [Colors.green[400]!, Colors.green[600]!]),
                    isDisabled: isGuest,
                    onTap: () {
                      if (isGuest) {
                        _showLoginDialog(context);
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const contrib.ContributionScreen()),
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 14),

                  TranslatableText(
                    'Need Help',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 12),

                  _buildActionCard(
                    context: context,
                    title: 'Request Help',
                    subtitle: isGuest
                        ? 'Sign in to request assistance'
                        : 'Ask for food, shelter, or support',
                    actionLabel: isGuest ? 'Sign in' : 'Request now',
                    icon: isGuest ? Icons.lock_outline : Icons.help_outline,
                    gradient: isGuest
                        ? LinearGradient(colors: [Colors.grey[400]!, Colors.grey[600]!])
                        : LinearGradient(colors: [Colors.red[400]!, Colors.red[600]!]),
                    isDisabled: isGuest,
                    onTap: () {
                      if (isGuest) {
                        _showLoginDialog(context);
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const RequestHelpScreen()),
                        );
                      }
                    },
                  ),

                  const SizedBox(height: 24),

                  _buildHowItWorks(),
                  
                  // Extra spacing at bottom for voice button
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGuestBanner(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange[200]!),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.orange[700]),
          const SizedBox(width: 10),
          const Expanded(
            child: TranslatableText(
              'You are in Guest Mode. Sign in to share resources and request help.',
              style: TextStyle(
                fontSize: 13,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pushReplacementNamed(context, '/login');
            },
            child: const TranslatableText('Sign In'),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Row(
      children: [
        _quickAction(
          context: context,
          label: 'Food',
          icon: Icons.restaurant_menu,
          color: Colors.orange,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const map.MapScreen(locationType: 'foodbank')),
            );
          },
        ),
        const SizedBox(width: 10),
        _quickAction(
          context: context,
          label: 'Shelters',
          icon: Icons.home_filled,
          color: Colors.pink,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const map.MapScreen(locationType: 'shelter')),
            );
          },
        ),
        const SizedBox(width: 10),
        _quickAction(
          context: context,
          label: 'Help',
          icon: Icons.help_outline,
          color: Colors.red,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const RequestHelpScreen()),
            );
          },
        ),
      ],
    );
  }

  Widget _quickAction({
    required BuildContext context,
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Semantics(
        label: label,
        button: true,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                Icon(icon, color: color),
                const SizedBox(height: 6),
                TranslatableText(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  

  Widget _buildHowItWorks() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue[700], size: 24),
              const SizedBox(width: 12),
              TranslatableText(
                'How It Works',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoRow(
            icon: Icons.map,
            color: Colors.orange,
            title: 'Find Resources',
            description: 'Browse food banks and shelters on dedicated maps',
          ),
          const SizedBox(height: 12),
          _buildInfoRow(
            icon: Icons.verified,
            color: Colors.purple,
            title: 'AI Verified',
            description: 'Community contributions are checked for safety',
          ),
          const SizedBox(height: 12),
          _buildInfoRow(
            icon: Icons.volunteer_activism,
            color: Colors.green,
            title: 'Contribute',
            description: 'Share food, shelter, or volunteer opportunities',
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required Color color,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TranslatableText(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 2),
              TranslatableText(
                description,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required String actionLabel,
    required IconData icon,
    required Gradient gradient,
    required VoidCallback onTap,
    bool isDisabled = false,
  }) {
    return Semantics(
      label: title,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 220,
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                right: -20,
                top: -20,
                child: Icon(
                  icon,
                  size: 110,
                  color: Colors.white.withValues(alpha: 0.12),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        icon,
                        size: 28,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TranslatableText(
                      title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TranslatableText(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.95),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        TranslatableText(
                          actionLabel,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          Icons.arrow_forward,
                          size: 16,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (isDisabled)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLoginDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.lock_outline, color: Colors.orange),
            SizedBox(width: 12),
            TranslatableText('Login Required'),
          ],
        ),
        content: const TranslatableText(
          'You need to sign in with Google to contribute resources and help your community.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: TranslatableText(
              'Cancel',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushReplacementNamed(context, '/login');
            },
            icon: const Icon(Icons.login, size: 18),
            label: const TranslatableText('Sign In'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[600],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}