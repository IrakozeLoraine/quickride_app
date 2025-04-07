
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:quickride/data/providers/auth_provider.dart';
import 'package:quickride/data/providers/language_provider.dart';
import 'package:quickride/data/providers/theme_provider.dart';
import 'package:quickride/routes/app_router.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isNotificationsEnabled = true;
  
  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }
  
  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isNotificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
    });
  }
  
  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', _isNotificationsEnabled);
  }
  
  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final authProvider = Provider.of<AuthProvider>(context);
    final languageProvider = Provider.of<LanguageProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    // Get current language name
    String currentLanguage;
    switch (languageProvider.locale.languageCode) {
      case 'en':
        currentLanguage = localizations.english;
        break;
      case 'fr':
        currentLanguage = localizations.french;
        break;
      case 'rw':
        currentLanguage = localizations.kinyarwanda;
        break;
      default:
        currentLanguage = localizations.english;
    }

    String currentTheme;
    switch (themeProvider.themeMode) {
      case ThemeMode.light:
        currentTheme = 'Light';
        break;
      case ThemeMode.dark:
        currentTheme = 'Dark';
        break;
      case ThemeMode.system:
        currentTheme = 'System';
        break;
    }
    
    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.settings),
        elevation: 0,
      ),
      body: ListView(
        children: [
          // Account section
          _buildSectionHeader('Account'),
          
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: Text(localizations.profile),
            trailing: const Icon(Icons.arrow_forward_ios_outlined, size: 16),
            onTap: () {
              Navigator.of(context).pushNamed(AppRouter.profile);
            },
          ),
          
          ListTile(
            leading: const Icon(Icons.history_outlined),
            title: Text(localizations.rideHistory),
            trailing: const Icon(Icons.arrow_forward_ios_outlined, size: 16),
            onTap: () {
              Navigator.of(context).pushNamed(AppRouter.rideHistory);
            },
          ),
          
          // Preferences section
          _buildSectionHeader('Preferences'),
          
          ListTile(
            leading: const Icon(Icons.language_outlined),
            title: Text(localizations.language),
            subtitle: Text(currentLanguage),
            trailing: const Icon(Icons.arrow_forward_ios_outlined, size: 16),
            onTap: () {
              Navigator.of(context).pushNamed(AppRouter.languageSelection);
            },
          ),
          
          ListTile(
            leading: const Icon(Icons.color_lens_outlined),
            title: Text(localizations.theme),
            subtitle: Text(currentTheme),
            trailing: const Icon(Icons.arrow_forward_ios_outlined, size: 16),
            onTap: () {
              _showThemeSelector();
            },
          ),
          
          SwitchListTile(
            secondary: const Icon(Icons.notifications_outlined),
            title: Text(localizations.notifications),
            value: _isNotificationsEnabled,
            onChanged: (value) {
              setState(() {
                _isNotificationsEnabled = value;
                _savePreferences();
              });
            },
          ),
          
          // Support section
          _buildSectionHeader('Support'),
          
          ListTile(
            leading: const Icon(Icons.help_outline),
            title: Text(localizations.help),
            trailing: const Icon(Icons.arrow_forward_ios_outlined, size: 16),
            onTap: () {
              _showContactDialog();
            },
          ),
          
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(localizations.about),
            trailing: const Icon(Icons.arrow_forward_ios_outlined, size: 16),
            onTap: () {
              _showAboutDialog();
            },
          ),
          
          // Logout
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout_outlined, color: Colors.red),
            title: Text(
              localizations.logout,
              style: const TextStyle(color: Colors.red),
            ),
            onTap: () async {
              // Confirm logout
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Logout'),
                  content: const Text('Are you sure you want to logout?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('Logout'),
                    ),
                  ],
                ),
              );
              
              if (confirmed == true && context.mounted) {
                await authProvider.signOut();
                Navigator.of(context).pushReplacementNamed(AppRouter.login);
              }
            },
          ),
        ],
      ),
    );
  }
  
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }

  void _showThemeSelector() {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final localizations = AppLocalizations.of(context)!;

    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Choose Theme'),
        children: [
          _buildThemeOption(
            context: context,
            title: localizations.light,
            icon: Icons.light_mode_outlined,
            selected: themeProvider.themeMode == ThemeMode.light,
            onTap: () {
              themeProvider.setThemeMode(ThemeMode.light);
              Navigator.pop(context);
            },
          ),
          _buildThemeOption(
            context: context,
            title: localizations.dark,
            icon: Icons.dark_mode_outlined,
            selected: themeProvider.themeMode == ThemeMode.dark,
            onTap: () {
              themeProvider.setThemeMode(ThemeMode.dark);
              Navigator.pop(context);
            },
          ),
          _buildThemeOption(
            context: context,
            title: 'System',
            icon: Icons.settings_system_daydream_outlined,
            selected: themeProvider.themeMode == ThemeMode.system,
            onTap: () {
              themeProvider.setThemeMode(ThemeMode.system);
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
  
  Widget _buildThemeOption({
    required BuildContext context,
    required String title,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return SimpleDialogOption(
      onPressed: onTap,
      child: Row(
        children: [
          Icon(
            icon,
            color: selected ? Theme.of(context).colorScheme.primary : null,
          ),
          const SizedBox(width: 16),
          Text(
            title,
            style: TextStyle(
              fontWeight: selected ? FontWeight.bold : null,
              color: selected ? Theme.of(context).colorScheme.primary : null,
            ),
          ),
          const Spacer(),
          if (selected)
            Icon(
              Icons.check_outlined,
              color: Theme.of(context).colorScheme.primary,
            ),
        ],
      ),
    );
  }

  void _showAboutDialog() {
    final localizations = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AboutDialog(
        applicationName: localizations.appTitle,
        applicationVersion: 'v1.0.0',
        applicationIcon: Icon(
          Icons.motorcycle,
          color: Theme.of(context).colorScheme.primary,
          size: 48,
        ),
        children: [
          const SizedBox(height: 16),
          Text(
            localizations.appDescription,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            localizations.copyRight,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }

  void _showContactDialog() {
    final localizations = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localizations.contactUs),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.email_outlined, size: 24),
                const SizedBox(width: 8),
                const Text('mukezwa@gmail.com'),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.phone_outlined, size: 24),
                const SizedBox(width: 8),
                const Text('0785735417'),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(localizations.closeButtonLabel),
          ),
        ],
      ),
    );
  }
}
