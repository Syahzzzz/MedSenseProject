import 'package:flutter/material.dart';
import '../translations.dart';

class LanguageSelectorWidget extends StatelessWidget {
  const LanguageSelectorWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: appLanguageNotifier,
      builder: (context, currentLang, child) {
        return ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            AppTranslations.get('language'),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(currentLang),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
          onTap: () => _showLanguageDialog(context, currentLang),
        );
      },
    );
  }

  void _showLanguageDialog(BuildContext context, String currentLang) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(AppTranslations.get('language')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: ['English', 'Bahasa Melayu', 'Mandarin'].map((lang) {
              return ListTile(
                title: Text(lang),
                trailing: lang == currentLang
                    ? const Icon(Icons.check, color: Color(0xFFFBC02D))
                    : null,
                onTap: () {
                  // Update the global notifier
                  appLanguageNotifier.value = lang;
                  Navigator.pop(context);
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }
}