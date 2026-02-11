import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // Import for kIsWeb
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'firebase_options.dart';
import 'login_screen.dart';
import 'home_screen.dart';
import 'screens/moderator_login_screen.dart';
import 'screens/full_moderator_dashboard.dart' as dashboard;
import 'package:resource_finder/widgets/voice_navigation_button.dart';
import 'map_screen.dart' as map;
import 'contribution_screen.dart' as contrib;
import 'community_screen.dart' as community;
import 'request_help_screen.dart';
import 'profile_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load environment variables
  await dotenv.load(fileName: ".env");
  
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Community Resource Finder',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const AuthWrapper(),
      routes: {
        '/home': (context) => const HomeScreen(),
        '/login': (context) => const LoginScreen(),
        '/moderator-login': (context) => const ModeratorLoginScreen(),
        '/moderator-dashboard': (context) => const dashboard.ModeratorDashboard(),
        // VOICE NAVIGATION ROUTES
        '/community': (context) => const community.CommunityScreen(),
        '/contribute': (context) => const contrib.ContributionScreen(),
        '/request-help': (context) => const RequestHelpScreen(),
        '/profile': (context) => const ProfileScreen(),
      },
      // HANDLE MAP ROUTE WITH ARGUMENTS
      onGenerateRoute: (settings) {
        if (settings.name == '/map') {
          final args = settings.arguments as Map<String, dynamic>?;
          return MaterialPageRoute(
            builder: (context) => map.MapScreen(
              locationType: args?['locationType'] ?? 'foodbank',
            ),
          );
        }
        return null;
      },
      debugShowCheckedModeBanner: false,
    );
  }
}

// This checks if user is already logged in and routes them appropriately
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  Future<String?> _getUserRole(String uid) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      
      if (userDoc.exists) {
        return userDoc.data()?['role'] as String?;
      }
      
      // Check moderators collection as fallback
      final modDoc = await FirebaseFirestore.instance
          .collection('moderators')
          .doc(uid)
          .get();
      
      if (modDoc.exists) {
        return 'moderator';
      }
      
      return 'user'; // Default role
    } catch (e) {
      print('Error fetching user role: $e');
      return 'user';
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Show loading while checking auth state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }
        
        // If user is logged in, check their role
        if (snapshot.hasData && snapshot.data != null) {
          return FutureBuilder<String?>(
            future: _getUserRole(snapshot.data!.uid),
            builder: (context, roleSnapshot) {
              if (roleSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(
                    child: CircularProgressIndicator(),
                  ),
                );
              }
              
              final role = roleSnapshot.data ?? 'user';
              
              // Route based on role
              if (role == 'moderator') {
                return const dashboard.ModeratorDashboard();
              } else {
                return const HomeScreen();
              }
            },
          );
        }
        
        // If not logged in, route based on platform
        if (kIsWeb) {
          // Web: Show moderator-only login screen
          return const ModeratorOnlyScreen();
        } else {
          // Mobile/Desktop: Go straight to user login with voice tutorial
          return const LoginWithVoiceIntro();
        }
      },
    );
  }
}

// Wrapper for LoginScreen that shows voice feature tutorial on first launch
class LoginWithVoiceIntro extends StatefulWidget {
  const LoginWithVoiceIntro({super.key});

  @override
  State<LoginWithVoiceIntro> createState() => _LoginWithVoiceIntroState();
}

class _LoginWithVoiceIntroState extends State<LoginWithVoiceIntro> {
  @override
  void initState() {
    super.initState();
    _checkAndShowVoiceTutorial();
  }

  Future<void> _checkAndShowVoiceTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeenTutorial = prefs.getBool('has_seen_voice_tutorial') ?? false;
    
    if (!hasSeenTutorial && mounted) {
      // Wait a bit for the screen to render
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        _showVoiceTutorial();
      }
    }
  }

  void _showVoiceTutorial() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Row(
          children: [
            Icon(Icons.mic, color: Colors.blue, size: 32),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Voice Navigation',
                style: TextStyle(fontSize: 22),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Navigate hands-free with voice commands!',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              _buildCommandExample('🗺️', 'Find food banks near me'),
              _buildCommandExample('📍', 'Show shelters in my area'),
              _buildCommandExample('🤝', 'Go to community'),
              _buildCommandExample('✋', 'I need help'),
              _buildCommandExample('👤', 'Open my profile'),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.lightbulb_outline, color: Colors.blue),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Look for the microphone button at the bottom of the screen!',
                        style: TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('has_seen_voice_tutorial', true);
              if (mounted) {
                Navigator.pop(context);
              }
            },
            child: const Text('Got it!'),
          ),
        ],
      ),
    );
  }

  Widget _buildCommandExample(String emoji, String command) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '"$command"',
              style: const TextStyle(
                fontSize: 14,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const LoginScreen();
  }
}

// Web-only screen that shows only Moderator login option
class ModeratorOnlyScreen extends StatelessWidget {
  const ModeratorOnlyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.deepPurple.shade400,
              Colors.blue.shade400,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // App Logo/Icon
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.admin_panel_settings,
                      size: 80,
                      color: Colors.deepPurple,
                    ),
                  ),
                  const SizedBox(height: 40),
                  
                  // App Title
                  const Text(
                    'Community Resource Finder',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Moderator Portal',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.white70,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 60),
                  
                  // Moderator Login Card
                  Card(
                    elevation: 8,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ModeratorLoginScreen(),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.deepPurple.withOpacity(0.1),
                              Colors.deepPurple.withOpacity(0.05),
                            ],
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.deepPurple.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.admin_panel_settings,
                                size: 40,
                                color: Colors.deepPurple,
                              ),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Moderator Access',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.deepPurple,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Review and manage community contributions',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.arrow_forward_ios,
                              color: Colors.deepPurple,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                  
                  // Info text
                  Text(
                    'This is the moderator portal. Use the mobile app to access user features.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.8),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Initial screen to choose between User or Moderator login (UNUSED NOW - keeping for reference)
class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: const VoiceNavigationButton(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.blue.shade400,
              Colors.purple.shade400,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // App Logo/Icon
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.volunteer_activism,
                      size: 80,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(height: 40),
                  
                  // App Title
                  const Text(
                    'Community Resource Finder',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Connecting communities, sharing resources',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white70,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 60),
                  
                  // User Login Card
                  _buildRoleCard(
                    context: context,
                    title: 'Continue as User',
                    description: 'Find resources or contribute to your community',
                    icon: Icons.person,
                    color: Colors.blue,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const LoginScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  
                  // Moderator Login Card
                  _buildRoleCard(
                    context: context,
                    title: 'Moderator Access',
                    description: 'Review and manage community contributions',
                    icon: Icons.admin_panel_settings,
                    color: Colors.deepPurple,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ModeratorLoginScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 40),
                  
                  // Info text
                  Text(
                    'New here? Sign up as a user to get started',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.8),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  
                  // Voice command hint
                  Container(
                    margin: const EdgeInsets.only(bottom: 80),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(color: Colors.white.withOpacity(0.3)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.mic, color: Colors.white, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Use your voice to navigate',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoleCard({
    required BuildContext context,
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withOpacity(0.1),
                color.withOpacity(0.05),
              ],
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  size: 40,
                  color: color,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: color,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}