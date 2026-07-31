import 'package:flutter/material.dart';

import 'app_strings.dart';
import 'locale_controller.dart';

class SystemSettingsScreen extends StatelessWidget {
  const SystemSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLanguage>(
      valueListenable: LocaleController.instance,
      builder: (context, language, child) {
        final s = AppStrings(language);
        return Scaffold(
          appBar: AppBar(title: Text(s.system)),
          body: ListView(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  s.languageLabel,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.black54,
                  ),
                ),
              ),
              ListTile(
                title: Text(s.german),
                leading: Icon(
                  language == AppLanguage.de
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                ),
                onTap: () => LocaleController.instance.update(AppLanguage.de),
              ),
              ListTile(
                title: Text(s.english),
                leading: Icon(
                  language == AppLanguage.en
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                ),
                onTap: () => LocaleController.instance.update(AppLanguage.en),
              ),
            ],
          ),
        );
      },
    );
  }
}
