import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

/// Roman Urdu is Urdu written in Latin script, left to right. Flutter's `ur`
/// locale assumes Nastaliq script and RTL layout, which would mirror every UI
/// and render Latin-script text inside RTL runs. So when the user picks Roman
/// Urdu (stored as the `ur` locale), the app keeps its own strings but takes
/// direction, formatted dates and the framework's own button/dialog labels from
/// English delegates. See [appFrame] in app.dart for the LTR override.
bool isRomanUrdu(Locale locale) => locale.languageCode == 'ur';

/// The locale string to pass to `DateFormat`: English under Roman Urdu,
/// otherwise the app's own locale.
String dateLocaleOf(BuildContext context) {
  final locale = Localizations.localeOf(context);
  return isRomanUrdu(locale) ? 'en' : locale.toString();
}

class _EnglishDelegate<T> extends LocalizationsDelegate<T> {
  const _EnglishDelegate(this._english);

  final LocalizationsDelegate<T> _english;

  @override
  bool isSupported(Locale locale) => isRomanUrdu(locale);

  @override
  Future<T> load(Locale locale) => _english.load(const Locale('en'));

  @override
  bool shouldReload(covariant LocalizationsDelegate<T> old) => false;
}

/// Listed before the app's own delegates: [Localizations] uses the first
/// delegate of each type that supports the locale, so these win for `ur` and
/// step aside for every other locale.
const romanUrduDelegates = <LocalizationsDelegate<dynamic>>[
  _EnglishDelegate<MaterialLocalizations>(
      GlobalMaterialLocalizations.delegate),
  _EnglishDelegate<CupertinoLocalizations>(
      GlobalCupertinoLocalizations.delegate),
  _EnglishDelegate<WidgetsLocalizations>(
      GlobalWidgetsLocalizations.delegate),
];
