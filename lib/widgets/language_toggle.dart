// lib/widgets/language_toggle.dart
import 'package:flutter/material.dart';
import '../services/translation_service.dart';
import '../services/translation_cache_service.dart';
import 'feature_feedback_dialog.dart';

class LanguageToggle extends StatefulWidget {
  final bool showLanguageSelector;

  const LanguageToggle({
    super.key,
    this.showLanguageSelector = true,
  });

  @override
  State<LanguageToggle> createState() => _LanguageToggleState();
}

class _LanguageToggleState extends State<LanguageToggle> {
  final TranslationService _translationService = TranslationService();

  @override
  void initState() {
    super.initState();
    _translationService.addListener(_onTranslationChanged);
  }

  @override
  void dispose() {
    _translationService.removeListener(_onTranslationChanged);
    super.dispose();
  }

  void _onTranslationChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _showLanguageMenu() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _LanguageSelectionSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: Icon(
        _translationService.showTranslated 
            ? Icons.translate 
            : Icons.translate_outlined,
        color: _translationService.showTranslated 
            ? Colors.white
            : Colors.white,
      ),
      tooltip: 'Translation',
      onSelected: (value) async {  // ← Made async
        if (value == 'toggle') {
          _translationService.toggleTranslation();
        } else if (value == 'select') {
          _showLanguageMenu();
        } else if (value == 'clear') {
          // Clear memory cache
          _translationService.clearCache();
          
          // Delete bad Chinese translations from Firestore
          final cacheService = TranslationCacheService();
          await cacheService.deleteBadTranslations('zh');
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Translation cache cleared & bad translations removed!'),
                duration: Duration(seconds: 2),
              ),
            );
          }
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          value: 'toggle',
          child: Row(
            children: [
              Icon(
                _translationService.showTranslated 
                    ? Icons.visibility_off 
                    : Icons.visibility,
                size: 20,
              ),
              const SizedBox(width: 12),
              Text(
                _translationService.showTranslated 
                    ? 'Show Original' 
                    : 'Show Translated',
              ),
            ],
          ),
        ),
        if (widget.showLanguageSelector) ...[
          const PopupMenuDivider(),
          PopupMenuItem<String>(
            value: 'select',
            child: Row(
              children: [
                Text(
                  _translationService.getLanguageFlag(
                    _translationService.preferredLanguage,
                  ),
                  style: const TextStyle(fontSize: 20),
                ),
                const SizedBox(width: 12),
                const Text('Change Language'),
              ],
            ),
          ),
        ],
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: 'clear',
          child: Row(
            children: [
              Icon(Icons.cleaning_services, size: 20),
              SizedBox(width: 12),
              Text('Clear Cache'),
            ],
          ),
        ),
      ],
    );
  }
}

class _LanguageSelectionSheet extends StatelessWidget {
  final TranslationService _translationService = TranslationService();

  _LanguageSelectionSheet();

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.7,
      builder: (context, scrollController) {
        return SingleChildScrollView(
          controller: scrollController,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                
                const Text(
                  'Select Translation Language',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Content will be automatically translated to your preferred language',
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
                const SizedBox(height: 20),
                
                _LanguageOption(
                  code: 'auto',
                  flag: '🌐',
                  name: 'Auto Detect',
                  description: 'Show content in original language',
                ),
                const Divider(height: 1),
                
                _LanguageOption(
                  code: 'ms',
                  flag: '🇲🇾',
                  name: 'Bahasa Malaysia',
                  description: 'Translate to Malay',
                ),
                const Divider(height: 1),
              
              
                _LanguageOption(
                  code: 'zh',
                  flag: '🇨🇳',
                  name: '简体中文',
                  description: 'Translate to Chinese',
                ),
                
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _LanguageOption extends StatelessWidget {
  final String code;
  final String flag;
  final String name;
  final String description;

  const _LanguageOption({
    required this.code,
    required this.flag,
    required this.name,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    final translationService = TranslationService();
    final isSelected = translationService.preferredLanguage == code;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
      leading: Container(
        width: 48,
        height: 48,
        alignment: Alignment.center,
        child: Text(
          flag,
          style: const TextStyle(fontSize: 32),
        ),
      ),
      title: Text(
        name,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          fontSize: 16,
        ),
      ),
      subtitle: Text(
        description,
        style: const TextStyle(fontSize: 12),
      ),
      trailing: isSelected
          ? const Icon(Icons.check_circle, color: Colors.blue, size: 24)
          : null,
      selected: isSelected,
      onTap: () {
        // Toggle translation BEFORE setting language
        if (code != 'auto') {
          if (!translationService.showTranslated) {
            translationService.toggleTranslation();
          }
        } else {
          if (translationService.showTranslated) {
            translationService.toggleTranslation();
          }
        }
        
        translationService.setPreferredLanguage(code);
        
        Navigator.pop(context);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Language set to $name'),
            duration: const Duration(seconds: 2),
          ),
        );

        // Show tester feedback for Language Change
        FeatureFeedbackDialog.showIfTester(context, 'Language Change');
      },
    );
  }
}