// lib/widgets/translatable_text.dart
import 'package:flutter/material.dart';
import '../services/translation_service.dart';

class TranslatableText extends StatefulWidget {
  final String data;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  final bool softWrap;

  const TranslatableText(
    this.data, {
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
    _translationService.addListener(_onTranslationChanged);
    _loadTranslation();
  }

  @override
  void dispose() {
    _translationService.removeListener(_onTranslationChanged);
    super.dispose();
  }

  @override
  void didUpdateWidget(TranslatableText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data != widget.data) {
      _loadTranslation();
    }
  }

  void _onTranslationChanged() {
    if (mounted) {
      _loadTranslation();
    }
  }

  Future<void> _loadTranslation() async {
    print('🔧 _loadTranslation called - showTranslated: ${_translationService.showTranslated}, preferredLanguage: ${_translationService.preferredLanguage}, text: "${widget.data}"');
    
    if (!_translationService.showTranslated ||
        _translationService.preferredLanguage == 'auto') {
      setState(() {
        _translatedText = null;
      });
      return;
    }
    
    print('🔧 PROCEEDING with translation...');  

    setState(() {
      _isLoading = true;
    });

    try {
      final translated = await _translationService.translate(
        widget.data,
        _translationService.preferredLanguage,
      );

      if (mounted) {
        setState(() {
          _translatedText = translated;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Translation error: $e');
      if (mounted) {
        setState(() {
          _translatedText = null;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayText = _translationService.showTranslated && _translatedText != null
        ? _translatedText!
        : widget.data;

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