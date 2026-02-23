// lib/widgets/tester_completion_dialog.dart
import 'package:flutter/material.dart';

/// Shown once when a tester has answered feedback for all 5 key features.
/// Thanks them and offers personalised feature recommendations to explore next.
class TesterCompletionDialog extends StatelessWidget {
  const TesterCompletionDialog({super.key});

  static Future<void> show(BuildContext context) async {
    if (!context.mounted) return;
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => const TesterCompletionDialog(),
    );
  }

  // Recommendations shown in the dialog
  static const List<_Rec> _recs = [
    _Rec(
      icon: Icons.share_location_outlined,
      color: Color(0xFF1E88E5),
      title: 'Share Resources',
      description:
          'Know a food bank or shelter not on the map? Add it via Community Contribution to help others find it.',
    ),
    _Rec(
      icon: Icons.mic_outlined,
      color: Color(0xFF43A047),
      title: 'Try Voice Navigation',
      description:
          'Say "find food banks near me" or "open shelters" hands-free — especially handy on the go.',
    ),
    _Rec(
      icon: Icons.language_outlined,
      color: Color(0xFF8E24AA),
      title: 'Change Your Language',
      description:
          'Switch to Bahasa Malaysia or 简体中文 to read all resource listings in your preferred language.',
    ),
    _Rec(
      icon: Icons.volunteer_activism_outlined,
      color: Color(0xFFE53935),
      title: 'Request Help',
      description:
          'If you or someone you know needs food, shelter, or supplies — submit a Help Request to get matched with community resources.',
    ),
    _Rec(
      icon: Icons.map_outlined,
      color: Color(0xFFF4511E),
      title: 'Explore the Map',
      description:
          'Browse the Food Bank and Shelter maps to see real-time community contributions and official locations near you.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Header ────────────────────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade700, Colors.indigo.shade600],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.emoji_events_rounded,
                      size: 40, color: Colors.white),
                ),
                const SizedBox(height: 14),
                const Text(
                  'You\'ve Tested Everything! 🎉',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Thank you for being a Community Resources Finder tester. '
                  'Your anonymous feedback helps us build a better experience for everyone.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.88),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),

          // ── Recommendations ───────────────────────────────────────────────
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Explore more features',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.black54,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ..._recs.map((rec) => _RecCard(rec: rec)),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),

          // ── Close button ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Continue Exploring',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Data class ────────────────────────────────────────────────────────────────

class _Rec {
  final IconData icon;
  final Color color;
  final String title;
  final String description;
  const _Rec(
      {required this.icon,
      required this.color,
      required this.title,
      required this.description});
}

// ── Card widget ───────────────────────────────────────────────────────────────

class _RecCard extends StatelessWidget {
  final _Rec rec;
  const _RecCard({required this.rec});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: rec.color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: rec.color.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: rec.color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(rec.icon, color: rec.color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rec.title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: rec.color.withValues(alpha: 0.9),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  rec.description,
                  style: const TextStyle(fontSize: 12.5, height: 1.5, color: Colors.black87),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
