// lib/widgets/feature_feedback_dialog.dart
import 'package:flutter/material.dart';
import '../services/tester_service.dart';
import 'tester_completion_dialog.dart';

/// A compact feedback popup shown after a key feature is used.
/// Only displays if the user opted in as a tester.
/// Call [FeatureFeedbackDialog.showIfTester] after a feature action completes.
class FeatureFeedbackDialog extends StatefulWidget {
  final String featureName;

  const FeatureFeedbackDialog({super.key, required this.featureName});

  /// Shows the feedback dialog only if the user is a tester AND hasn't
  /// already submitted feedback for [featureName].
  static Future<void> showIfTester(
    BuildContext context,
    String featureName,
  ) async {
    final service = TesterService();
    final isTester = await service.isTester();
    if (!isTester) return;

    // Skip if this user already answered for this feature
    final alreadyAnswered = await service.hasAlreadyAnswered(featureName);
    if (alreadyAnswered) return;

    if (!context.mounted) return;

    await showDialog(
      context: context,
      builder: (context) =>
          FeatureFeedbackDialog(featureName: featureName),
    );
  }

  @override
  State<FeatureFeedbackDialog> createState() => _FeatureFeedbackDialogState();
}

class _FeatureFeedbackDialogState extends State<FeatureFeedbackDialog> {
  bool? _helpful; // null = not yet answered
  final TextEditingController _commentController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_helpful == null) return;
    setState(() => _isSubmitting = true);

    final saved = await TesterService().saveFeedback(
      feature: widget.featureName,
      helpful: _helpful!,
      comment: _commentController.text.trim().isEmpty
          ? null
          : _commentController.text.trim(),
    );

    if (!mounted) return;
    Navigator.of(context).pop();

    if (!saved) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You have already submitted feedback for this feature.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    // Check if all features are now answered — show the completion dialog
    final allDone = await TesterService().hasCompletedAllFeatures();
    if (allDone && mounted) {
      // Small delay so the feedback dialog has fully closed first
      await Future.delayed(const Duration(milliseconds: 350));
      if (mounted) {
        await TesterCompletionDialog.show(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 12,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.rate_review_outlined,
                      color: Colors.green.shade700, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Quick Feedback',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        widget.featureName,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: Colors.grey.shade400, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Question
            const Text(
              'Was this feature helpful and easy to use?',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 14),

            // Yes / No buttons
            Row(
              children: [
                _VoteButton(
                  label: '👍  Yes',
                  selected: _helpful == true,
                  selectedColor: Colors.green,
                  onTap: () => setState(() => _helpful = true),
                ),
                const SizedBox(width: 12),
                _VoteButton(
                  label: '👎  No',
                  selected: _helpful == false,
                  selectedColor: Colors.red,
                  onTap: () => setState(() => _helpful = false),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Optional comment
            TextField(
              controller: _commentController,
              maxLines: 2,
              maxLength: 200,
              decoration: InputDecoration(
                hintText: 'Any comments? (optional)',
                hintStyle:
                    TextStyle(fontSize: 13, color: Colors.grey.shade400),
                contentPadding: const EdgeInsets.all(12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                counterStyle:
                    TextStyle(fontSize: 11, color: Colors.grey.shade400),
              ),
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 16),

            // Submit
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _helpful == null || _isSubmitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade600,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade200,
                  disabledForegroundColor: Colors.grey.shade400,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text(
                        'Submit Feedback',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
            const SizedBox(height: 4),
            Center(
              child: Text(
                'Anonymous · Does not affect your app usage',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VoteButton extends StatelessWidget {
  final String label;
  final bool selected;
  final Color selectedColor;
  final VoidCallback onTap;

  const _VoteButton({
    required this.label,
    required this.selected,
    required this.selectedColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? selectedColor.withValues(alpha: 0.12)
                : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? selectedColor : Colors.grey.shade300,
              width: selected ? 2 : 1,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              fontWeight:
                  selected ? FontWeight.bold : FontWeight.normal,
              color: selected ? selectedColor : Colors.grey.shade600,
            ),
          ),
        ),
      ),
    );
  }
}
