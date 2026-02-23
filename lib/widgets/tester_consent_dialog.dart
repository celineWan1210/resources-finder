// lib/widgets/tester_consent_dialog.dart
import 'package:flutter/material.dart';
import '../services/tester_service.dart';

/// Shows a one-time modal asking the user to become a tester.
/// Call [TesterConsentDialog.showIfNeeded] from any screen's initState.
class TesterConsentDialog extends StatelessWidget {
  const TesterConsentDialog({super.key});

  /// Shows the dialog only if the user has not yet seen it.
  static Future<void> showIfNeeded(BuildContext context) async {
    final service = TesterService();
    final hasSeen = await service.hasSeenConsent();
    if (hasSeen) return;

    if (!context.mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const TesterConsentDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      elevation: 16,
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.science_outlined,
                size: 40,
                color: Colors.blue.shade700,
              ),
            ),
            const SizedBox(height: 20),

            // Title
            const Text(
              'Become a Community\nResources Finder Tester',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 16),

            // Body
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: const Text(
                'Would you like to help improve Community Resources Finder by becoming a tester?\n\n'
                'If you agree, short feedback prompts will appear after you use selected features. '
                'Your feedback is anonymous and used only to improve the app.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, height: 1.55, color: Colors.black87),
              ),
            ),
            const SizedBox(height: 24),

            // Buttons
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.check_circle_outline, size: 20),
                label: const Text(
                  'Become a tester',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                onPressed: () async {
                  await TesterService().setConsentResponse(agreed: true);
                  if (context.mounted) Navigator.of(context).pop();
                },
              ),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () async {
                await TesterService().setConsentResponse(agreed: false);
                if (context.mounted) Navigator.of(context).pop();
              },
              child: Text(
                'Not now',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 15),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
