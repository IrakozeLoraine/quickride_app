import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:quickride/data/providers/language_provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class LanguageSelectionScreen extends StatelessWidget {
  const LanguageSelectionScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final languageProvider = Provider.of<LanguageProvider>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.language),
        elevation: 0,
      ),
      body: ListView(
        children: [
          _buildLanguageOption(
            context,
            languageProvider,
            'en',
            localizations.english,
            'English',
            'assets/images/flag_en.png',
          ),
          _buildLanguageOption(
            context,
            languageProvider,
            'fr',
            localizations.french,
            'Français',
            'assets/images/flag_fr.png',
          ),
          _buildLanguageOption(
            context,
            languageProvider,
            'rw',
            localizations.kinyarwanda,
            'Ikinyarwanda',
            'assets/images/flag_rw.png',
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageOption(
    BuildContext context,
    LanguageProvider languageProvider,
    String langCode,
    String localizedName,
    String nativeName,
    String flagAsset,
  ) {
    final bool isSelected = languageProvider.locale.languageCode == langCode;
    
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Colors.grey.shade200,
        child: Image.asset(
          flagAsset,
          width: 30,
          height: 30,
        ),
      ),
      title: Text(localizedName),
      subtitle: Text(nativeName),
      trailing: isSelected ? Icon(
        Icons.check_circle_outline,
        color: Theme.of(context).colorScheme.primary,
      ) : null,
      onTap: () async {
        await languageProvider.setLanguageCode(langCode);
        if (context.mounted) {
          Navigator.pop(context);
        }
      },
    );
  }
}
