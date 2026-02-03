import 'package:flutter/material.dart';
import 'services/translation_service.dart'; // ✅ Updated import path

/// Widget that automatically translates text when translation is enabled
/// 
/// Place this file in: lib/translatable_text.dart
/// 
/// Usage:
/// ```dart
/// TranslatableText(
///   'Makanan untuk keluarga',
///   style: TextStyle(fontSize: 16),
/// )
/// ```
class TranslatableText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  final bool softWrap;

  const TranslatableText(
    this.text, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.softWrap = true,
  });

  @override
  State<TranslatableText> createState() => _TranslatableTextState();
}

class _TranslatableTextState extends State<TranslatableText> {
  final TranslationService _translationService = TranslationService();
  String? _translatedText;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _translationService.addListener(_onTranslationStateChanged);
    _translateIfNeeded();
  }

  @override
  void dispose() {
    _translationService.removeListener(_onTranslationStateChanged);
    super.dispose();
  }

  @override
  void didUpdateWidget(TranslatableText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _translateIfNeeded();
    }
  }

  void _onTranslationStateChanged() {
    if (mounted) {
      _translateIfNeeded();
    }
  }

  Future<void> _translateIfNeeded() async {
    if (!_translationService.showTranslated || 
        _translationService.preferredLanguage == 'auto') {
      setState(() {
        _translatedText = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final translated = await _translationService.translate(widget.text);

    if (mounted) {
      setState(() {
        _translatedText = translated;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show loading indicator while translating
    if (_isLoading) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              widget.text,
              style: widget.style?.copyWith(color: Colors.grey),
              textAlign: widget.textAlign,
              maxLines: widget.maxLines,
              overflow: widget.overflow,
              softWrap: widget.softWrap,
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(
                widget.style?.color ?? Colors.blue,
              ),
            ),
          ),
        ],
      );
    }

    // Show translated or original text
    final displayText = (_translationService.showTranslated && _translatedText != null)
        ? _translatedText!
        : widget.text;

    return Text(
      displayText,
      style: widget.style,
      textAlign: widget.textAlign,
      maxLines: widget.maxLines,
      overflow: widget.overflow,
      softWrap: widget.softWrap,
    );
  }
}

/// RichText version for more complex text with formatting
class TranslatableRichText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final List<TextSpan>? additionalSpans;

  const TranslatableRichText(
    this.text, {
    super.key,
    this.style,
    this.additionalSpans,
  });

  @override
  State<TranslatableRichText> createState() => _TranslatableRichTextState();
}

class _TranslatableRichTextState extends State<TranslatableRichText> {
  final TranslationService _translationService = TranslationService();
  String? _translatedText;

  @override
  void initState() {
    super.initState();
    _translationService.addListener(_translateIfNeeded);
    _translateIfNeeded();
  }

  @override
  void dispose() {
    _translationService.removeListener(_translateIfNeeded);
    super.dispose();
  }

  Future<void> _translateIfNeeded() async {
    if (!_translationService.showTranslated) {
      setState(() {
        _translatedText = null;
      });
      return;
    }

    final translated = await _translationService.translate(widget.text);
    if (mounted) {
      setState(() {
        _translatedText = translated;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayText = (_translationService.showTranslated && _translatedText != null)
        ? _translatedText!
        : widget.text;

    return RichText(
      text: TextSpan(
        text: displayText,
        style: widget.style ?? DefaultTextStyle.of(context).style,
        children: widget.additionalSpans,
      ),
    );
  }
}