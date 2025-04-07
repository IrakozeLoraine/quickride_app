import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

class KinyarwandaMaterialLocalizations extends LocalizationsDelegate<MaterialLocalizations> {
  const KinyarwandaMaterialLocalizations();

  @override
  bool isSupported(Locale locale) => locale.languageCode == 'rw';

  @override
  Future<MaterialLocalizations> load(Locale locale) async {
    final localizations = await GlobalMaterialLocalizations.delegate.load(const Locale('en', ''));
    return localizations;
  }

  @override
  bool shouldReload(KinyarwandaMaterialLocalizations old) => false;
}
