import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';
import 'widgets/translatable_text.dart';
import 'services/tester_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final user = FirebaseAuth.instance.currentUser;
  Map<String, dynamic>? userData;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      if (user != null) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user!.uid)
            .get();

        if (doc.exists) {
          setState(() {
            userData = doc.data();
            isLoading = false;
          });
        } else {
          setState(() {
            isLoading = false;
          });
        }
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
    }
  }

  // ── Future Improvements Dialog ───────────────────────────────────────────────

  void _showFutureImprovementsDialog() {
    final TextEditingController suggestionController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.lightbulb_outline, color: Colors.amber),
            SizedBox(width: 12),
            TranslatableText('Future Improvements'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const TranslatableText(
              'We\'d love to hear your ideas! What features or improvements would you like to see in the app?',
              style: TextStyle(fontSize: 14, color: Colors.black87),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: suggestionController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Share your suggestions here...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.blue),
                ),
                filled: true,
                fillColor: Colors.grey[50],
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
          ],
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
            onPressed: () async {
              final suggestion = suggestionController.text.trim();
              Navigator.pop(context);

              final saved = await TesterService().saveCompletionFeedback(
                suggestion: suggestion.isEmpty ? null : suggestion,
              );

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: TranslatableText(
                      saved
                          ? '🙏 Thank you for your feedback!'
                          : 'Feedback already submitted — thank you!',
                    ),
                    backgroundColor: saved ? Colors.green : Colors.orange,
                    duration: const Duration(seconds: 3),
                  ),
                );
              }
            },
            icon: const Icon(Icons.send, size: 18),
            label: const TranslatableText('Submit'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: const TranslatableText(
          'Profile',
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
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  // Profile Header
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.blue[700]!, Colors.blue[500]!],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Column(
                      children: [
                        const SizedBox(height: 20),
                        CircleAvatar(
                          radius: 60,
                          backgroundColor: Colors.white,
                          child: user?.photoURL != null
                              ? ClipOval(
                                  child: Image.network(
                                    user!.photoURL!,
                                    width: 120,
                                    height: 120,
                                    fit: BoxFit.cover,
                                  ),
                                )
                              : TranslatableText(
                                  user?.displayName
                                          ?.substring(0, 1)
                                          .toUpperCase() ??
                                      'U',
                                  style: const TextStyle(
                                    fontSize: 48,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue,
                                  ),
                                ),
                        ),
                        const SizedBox(height: 16),
                        TranslatableText(
                          user?.displayName ?? 'User',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TranslatableText(
                          user?.email ?? '',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),

                  // Profile Details
                  Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionTitle('Account Information'),
                        const SizedBox(height: 12),
                        _buildInfoCard(
                          icon: Icons.email,
                          title: 'Email',
                          value: user?.email ?? 'Not available',
                          color: Colors.blue,
                        ),
                        const SizedBox(height: 12),
                        _buildInfoCard(
                          icon: Icons.verified_user,
                          title: 'Email Verified',
                          value: user?.emailVerified == true ? 'Yes' : 'No',
                          color: user?.emailVerified == true
                              ? Colors.green
                              : Colors.orange,
                        ),
                        const SizedBox(height: 12),
                        _buildInfoCard(
                          icon: Icons.calendar_today,
                          title: 'Member Since',
                          value: _formatDate(user?.metadata.creationTime),
                          color: Colors.purple,
                        ),

                        const SizedBox(height: 24),
                        _buildSectionTitle('Tester Dashboard'),
                        const SizedBox(height: 12),
                        _buildTesterDashboard(),

                        const SizedBox(height: 24),
                        _buildSectionTitle('Statistics'),
                        const SizedBox(height: 12),
                        Center(
                          child: SizedBox(
                            width: double.infinity,
                            child: _buildStatCard(
                              icon: Icons.volunteer_activism,
                              title: 'Contributions',
                              value: userData?['contributionCount']
                                      ?.toString() ??
                                  '0',
                              color: Colors.green,
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),
                        _buildSectionTitle('Actions'),
                        const SizedBox(height: 12),
                        _buildActionButton(
                          context: context,
                          icon: Icons.verified_user,
                          title: 'Get Moderator Code',
                          subtitle: 'Generate code to access moderator portal',
                          color: Colors.purple,
                          onTap: () {
                            _showVerificationCodeDialog(context, user!);
                          },
                        ),
                        const SizedBox(height: 12),
                        _buildActionButton(
                          context: context,
                          icon: Icons.edit,
                          title: 'Edit Profile',
                          subtitle: 'Update your profile information',
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: TranslatableText(
                                      'Edit profile feature coming soon!')),
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        _buildActionButton(
                          context: context,
                          icon: Icons.settings,
                          title: 'Settings',
                          subtitle: 'Manage your preferences',
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: TranslatableText(
                                      'Settings feature coming soon!')),
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        _buildActionButton(
                          context: context,
                          icon: Icons.help_outline,
                          title: 'Help & Support',
                          subtitle: 'Get help with the app',
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: TranslatableText(
                                      'Help & Support feature coming soon!')),
                            );
                          },
                        ),
                        const SizedBox(height: 24),
                        _buildActionButton(
                          context: context,
                          icon: Icons.logout,
                          title: 'Logout',
                          subtitle: 'Sign out of your account',
                          color: Colors.red,
                          onTap: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const TranslatableText('Logout'),
                                content: const TranslatableText(
                                    'Are you sure you want to logout?'),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: const TranslatableText('Cancel'),
                                  ),
                                  ElevatedButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red,
                                    ),
                                    child: const TranslatableText('Logout'),
                                  ),
                                ],
                              ),
                            );

                            if (confirm == true && context.mounted) {
                              await FirebaseAuth.instance.signOut();
                              if (context.mounted) {
                                Navigator.pushReplacementNamed(
                                    context, '/login');
                              }
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildTesterDashboard() {
    return FutureBuilder<bool>(
      future: TesterService().isTester(),
      builder: (context, snapshot) {
        final isTester = snapshot.data ?? false;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const TranslatableText(
                    'Tester Status',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color:
                          isTester ? Colors.green[50] : Colors.grey[100],
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: isTester
                              ? Colors.green[200]!
                              : Colors.grey[300]!),
                    ),
                    child: TranslatableText(
                      isTester ? 'Active Tester' : 'Not a Tester',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isTester
                            ? Colors.green[700]
                            : Colors.grey[600],
                      ),
                    ),
                  ),
                ],
              ),
              if (isTester) ...[
                const SizedBox(height: 16),
                const TranslatableText(
                  'Feature Testing Progress',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                FutureBuilder<List<String>>(
                  future: TesterService().answeredFeatureKeys(),
                  builder: (context, answeredSnapshot) {
                    final answered = answeredSnapshot.data ?? [];
                    final mapVariants = [
                      'food_bank_map',
                      'shelter_map',
                      'resource_map'
                    ];
                    final mapDone =
                        answered.any((k) => mapVariants.contains(k));

                    final coreFeatures = [
                      'community_contribution',
                      'help_request',
                      'language_change',
                    ];

                    int completedCount = (mapDone ? 1 : 0) +
                        coreFeatures
                            .where((f) => answered.contains(f))
                            .length;
                    double progress = completedCount / 4;
                    final allDone = completedCount == 4;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            value: progress,
                            backgroundColor: Colors.grey[200],
                            valueColor: AlwaysStoppedAnimation<Color>(
                              allDone ? Colors.green[400]! : Colors.blue[400]!,
                            ),
                            minHeight: 8,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildFeatureStatusItem(
                            'Maps (Food/Shelter/All)', mapDone),
                        _buildFeatureStatusItem('Community Contribution',
                            answered.contains('community_contribution')),
                        _buildFeatureStatusItem('Help Request',
                            answered.contains('help_request')),
                        _buildFeatureStatusItem('Language Change',
                            answered.contains('language_change')),
                        const SizedBox(height: 16),

                        // ── Future Improvements Button ──────────────────────
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: allDone
                                ? _showFutureImprovementsDialog
                                : null,
                            icon: const Icon(Icons.lightbulb_outline, size: 18),
                            label: TranslatableText(
                              allDone
                                  ? '💡 Share Future Improvements'
                                  : 'Complete all features to unlock',
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: allDone
                                  ? Colors.amber[600]
                                  : Colors.grey[300],
                              foregroundColor: allDone
                                  ? Colors.white
                                  : Colors.grey[500],
                              disabledBackgroundColor: Colors.grey[200],
                              disabledForegroundColor: Colors.grey[400],
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),

                        if (!allDone) ...[
                          const SizedBox(height: 6),
                          Center(
                            child: TranslatableText(
                              '$completedCount / 4 features completed',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[500],
                              ),
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: () async {
                    await TesterService().resetTesterStatus();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: TranslatableText(
                                'Tester status reset. Restart app to see consent modal.')),
                      );
                      setState(() {});
                    }
                  },
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const TranslatableText('Reset Tester Status'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey[600],
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFeatureStatusItem(String label, bool isDone) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(
            isDone ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 14,
            color: isDone ? Colors.green : Colors.grey[400],
          ),
          const SizedBox(width: 8),
          TranslatableText(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isDone ? Colors.black87 : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return TranslatableText(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Colors.grey[800],
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TranslatableText(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 4),
                TranslatableText(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          TranslatableText(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          TranslatableText(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    Color? color,
    required VoidCallback onTap,
  }) {
    final buttonColor = color ?? Colors.blue;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: buttonColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: buttonColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TranslatableText(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  TranslatableText(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Not available';
    return '${date.day}/${date.month}/${date.year}';
  }

  void _showVerificationCodeDialog(BuildContext context, User user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.verified_user, color: Colors.purple),
            SizedBox(width: 12),
            TranslatableText('Generate Code'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const TranslatableText(
              'Generate a verification code to access the moderator portal.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.purple[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.purple[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.email, color: Colors.purple[700], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TranslatableText(
                      user.email ?? '',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.purple[900],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber[200]!),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: Colors.amber[800], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TranslatableText(
                      'The code will be shown on screen and will expire in 7 days. It can only be used once.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.amber[900],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
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
              _requestVerificationCode(context, user);
            },
            icon: const Icon(Icons.generating_tokens, size: 18),
            label: const TranslatableText('Generate Code'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple[600],
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

  Future<void> _requestVerificationCode(BuildContext context, User user) async {
    String code = _generateVerificationCode();
    _showCodeGeneratedDialog(context, code);

    try {
      await FirebaseFirestore.instance
          .collection('moderatorCodes')
          .doc(code)
          .set({
        'email': user.email,
        'code': code,
        'used': false,
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(
          DateTime.now().add(const Duration(days: 7)),
        ),
      });
    } catch (e) {
      print('Error saving code to Firestore: $e');
    }
  }

  String _generateVerificationCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    String code = '';
    for (int i = 0; i < 8; i++) {
      code += chars[random.nextInt(chars.length)];
    }
    return code;
  }

  void _showCodeGeneratedDialog(BuildContext context, String code) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.verified_user, color: Colors.green),
            SizedBox(width: 12),
            TranslatableText('Verification Code'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const TranslatableText(
              'Your moderator verification code:',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: code));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: TranslatableText('Code copied to clipboard!'),
                    backgroundColor: Colors.green,
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.purple[700]!, Colors.purple[500]!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.purple.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    TranslatableText(
                      code,
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 8,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.content_copy,
                          color: Colors.white.withValues(alpha: 0.9),
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        TranslatableText(
                          'Tap to copy',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: 0.9),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.amber[50],
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.amber[300]!, width: 1.5),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: Colors.amber[800], size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TranslatableText(
                          'Important:',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.amber[900],
                          ),
                        ),
                        const SizedBox(height: 4),
                        TranslatableText(
                          '• Valid for 7 days\n• Can only be used once\n• Use it to access moderator portal',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.amber[900],
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: code));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: TranslatableText('Code copied to clipboard!'),
                        backgroundColor: Colors.green,
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  icon: const Icon(Icons.content_copy, size: 18),
                  label: const TranslatableText('Copy Code'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.purple[600],
                    side: BorderSide(color: Colors.purple[600]!),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple[600],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const TranslatableText('Done'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}