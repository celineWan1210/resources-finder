import 'package:flutter/material.dart';
import 'map_screen.dart';
import 'contribution_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Get the arguments passed from login screen
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final bool isGuest = args?['isGuest'] ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Community Resource Finder"),
        actions: [
          if (isGuest)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Chip(
                label: const Text('Guest', style: TextStyle(fontSize: 12)),
                backgroundColor: Colors.orange,
              ),
            ),
        ],
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Food Banks Card
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const MapScreen()),
              );
            },
            child: Card(
              color: Colors.lightBlue,
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: const SizedBox(
                width: double.infinity,
                height: 150,
                child: Center(
                  child: Text(
                    "Food Banks Near Me",
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ),

          // Contribution Card - Disabled for guests
          GestureDetector(
            onTap: () {
              if (isGuest) {
                // Show dialog for guests
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Login Required'),
                    content: const Text('You need to login with Google to contribute resources.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.pushReplacementNamed(context, '/');
                        },
                        child: const Text('Login'),
                      ),
                    ],
                  ),
                );
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ContributionScreen()),
                );
              }
            },
            child: Card(
              color: isGuest ? Colors.grey : Colors.green,
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: SizedBox(
                width: double.infinity,
                height: 150,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Contribute",
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold),
                      ),
                      if (isGuest)
                        const Padding(
                          padding: EdgeInsets.only(top: 8.0),
                          child: Text(
                            "Login required",
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}