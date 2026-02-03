import 'package:flutter/material.dart';
import 'services/translation_service.dart';
import 'translatable_text.dart';

/// Language selector and translation toggle button
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
            ? Colors.blue 
            : Colors.grey,
      ),
      tooltip: 'Translation',
      onSelected: (value) {
        if (value == 'toggle') {
          _translationService.toggleTranslation();
        } else if (value == 'select') {
          _showLanguageMenu();
        } else if (value == 'clear') {
          _translationService.clearCache();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: TranslatableText('Translation cache cleared')),
          );
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
              TranslatableText(
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
                // ✅ FIXED: Keep flag separate from translatable text
                Text(
                  _translationService.getLanguageFlag(
                    _translationService.preferredLanguage,
                  ),
                  style: const TextStyle(fontSize: 20),
                ),
                const SizedBox(width: 12),
                TranslatableText('Change Language'),
              ],
            ),
          ),
        ],
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'clear',
          child: Row(
            children: [
              Icon(Icons.cleaning_services, size: 20),
              SizedBox(width: 12),
              TranslatableText('Clear Cache'),
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
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.8,
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
                
                TranslatableText(
                  'Select Translation Language',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                TranslatableText(
                  'Content will be automatically translated to your preferred language',
                  style: TextStyle(color: Colors.grey, fontSize: 14),
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
                  code: 'en',
                  flag: '🇬🇧',
                  name: 'English',
                  description: 'Translate to English',
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
      
      // ✅ FIXED: Flag in separate widget, won't get translated
      leading: Container(
        width: 48,
        height: 48,
        alignment: Alignment.center,
        child: Text(
          flag,
          style: const TextStyle(fontSize: 32),
        ),
      ),
      
      title: TranslatableText(
        name,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          fontSize: 16,
        ),
      ),
      subtitle: TranslatableText(
        description,
        style: const TextStyle(fontSize: 12),
      ),
      trailing: isSelected
          ? const Icon(Icons.check_circle, color: Colors.blue, size: 24)
          : null,
      selected: isSelected,
      onTap: () {
        translationService.setPreferredLanguage(code);
        if (code != 'auto') {
          if (!translationService.showTranslated) {
            translationService.toggleTranslation();
          }
        } else {
          if (translationService.showTranslated) {
            translationService.toggleTranslation();
          }
        }
        Navigator.pop(context);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: TranslatableText('Language set to $name'),
            duration: const Duration(seconds: 2),
          ),
        );
      },
    );
  }
}

/// Compact translation toggle switch with FLAG PRESERVED
class CompactTranslationToggle extends StatefulWidget {
  const CompactTranslationToggle({super.key});

  @override
  State<CompactTranslationToggle> createState() => _CompactTranslationToggleState();
}

class _CompactTranslationToggleState extends State<CompactTranslationToggle> {
  final TranslationService _translationService = TranslationService();

  @override
  void initState() {
    super.initState();
    _translationService.addListener(_onChanged);
  }

  @override
  void dispose() {
    _translationService.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ✅ FIXED: Flag in separate Text widget
          Text(
            _translationService.getLanguageFlag(
              _translationService.preferredLanguage,
            ),
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(width: 8),
          // Status text (can be regular Text, doesn't need translation)
          TranslatableText(
            _translationService.showTranslated ? 'Translated' : 'Original',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          ),
          const SizedBox(width: 8),
          Switch(
            value: _translationService.showTranslated,
            onChanged: (value) {
              _translationService.toggleTranslation();
            },
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }
}
