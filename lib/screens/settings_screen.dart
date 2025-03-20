import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme_provider.dart';
import '../language_provider.dart';
import 'account_screen.dart'; // Import the new Account screen

class SettingsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    var themeProvider = Provider.of<ThemeProvider>(context);
    var languageProvider = Provider.of<LanguageProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Settings'),
      ),
      body: AnimatedSwitcher(
        duration: Duration(milliseconds: 300),
        child: ListView(
          key: ValueKey(themeProvider.themeMode),
          children: <Widget>[
            ListTile(
              title: Text('Account'),
              leading: Icon(Icons.person),
              onTap: () {
                // Navigate to Account Screen
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => AccountScreen()),
                );
              },
            ),
            Divider(),
            SwitchListTile(
              title: Text('Dark Mode'),
              value: themeProvider.themeMode == ThemeMode.dark,
              onChanged: (bool value) {
                themeProvider.toggleTheme(value);
              },
              secondary: Icon(Icons.dark_mode),
            ),
            Divider(),
            ListTile(
              title: Text('Language'),
              leading: Icon(Icons.language),
              trailing: DropdownButton<String>(
                value: languageProvider.locale.languageCode,
                onChanged: (String? newLanguage) {
                  if (newLanguage != null) {
                    languageProvider.changeLanguage(newLanguage);
                  }
                },
                items: [
                  DropdownMenuItem(value: 'en', child: Text('English')),
                  DropdownMenuItem(value: 'es', child: Text('Español')),
                  DropdownMenuItem(value: 'fr', child: Text('Français')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
