import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/locale_provider.dart';
import '../../core/providers/theme_provider.dart';
import '../../core/localization/app_strings.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLocale = ref.watch(localeProvider);

    return Scaffold(
      appBar: AppBar(title: Text(AppStrings.tr(ref, 'titleSettings'))),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.language),
            title: Text(AppStrings.tr(ref, 'txtLanguage')),
            subtitle: Text(currentLocale.languageCode == 'en' ? 'English' : 'বাংলা'),
            trailing: DropdownButton<Locale>(
              value: currentLocale,
              underline: Container(),
              icon: const Icon(Icons.arrow_drop_down),
              items: const [
                DropdownMenuItem(
                  value: Locale('en'),
                  child: Text('English'),
                ),
                DropdownMenuItem(
                  value: Locale('bn'),
                  child: Text('বাংলা'),
                ),
              ],
              onChanged: (Locale? newLocale) {
                if (newLocale != null) {
                  ref.read(localeProvider.notifier).setLocale(newLocale);
                }
              },
            ),
          ),
          const Divider(),
          const Divider(),
          SwitchListTile(
            title: Text(AppStrings.tr(ref, 'txtDarkMode')),
            subtitle: Text(
              ref.watch(themeProvider) == ThemeMode.dark ? "Active: Dark Mode" : "Active: Light Mode",
              style: TextStyle(color: ref.watch(themeProvider) == ThemeMode.dark ? Colors.blueAccent : Colors.grey),
            ),
            value: ref.watch(themeProvider) == ThemeMode.dark,
            onChanged: (val) {
               ref.read(themeProvider.notifier).setTheme(val ? ThemeMode.dark : ThemeMode.light);
            },
          ),
        ],
      ),
    );
  }
}
