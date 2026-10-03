import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

/// Roman Urdu is Urdu written in Latin script, left to right. Flutter's `ur` locale assumes
/// Nastaliq and RTL, which would mirror every layout and put Urdu-script dates and button labels
/// inside a Latin-script UI. So under `ur` the app keeps its own strings but takes direction,
/// dates and the framework's labels from English.
bool isRomanUrdu(Locale locale) => locale.languageCode == 'ur';

/// The locale to hand `DateFormat`: English under Roman Urdu, otherwise the app's own.
String dateLocaleOf(BuildContext context) {
  final locale = Localizations.localeOf(context);
  return isRomanUrdu(locale) ? 'en' : locale.toString();
}

class _EnglishFor<T> extends LocalizationsDelegate<T> {
  const _EnglishFor(this._english);

  final LocalizationsDelegate<T> _english;

  @override
  bool isSupported(Locale locale) => isRomanUrdu(locale);

  @override
  Future<T> load(Locale locale) => _english.load(const Locale('en'));

  @override
  bool shouldReload(covariant LocalizationsDelegate<T> old) => false;
}

/// Listed before the app's delegates: `Localizations` uses the first delegate of each type that
/// supports the locale, so these win for `ur` and step aside for everything else.
const romanUrduDelegates = <LocalizationsDelegate<dynamic>>[
  _EnglishFor<MaterialLocalizations>(GlobalMaterialLocalizations.delegate),
  _EnglishFor<CupertinoLocalizations>(GlobalCupertinoLocalizations.delegate),
  _EnglishFor<WidgetsLocalizations>(GlobalWidgetsLocalizations.delegate),
];
