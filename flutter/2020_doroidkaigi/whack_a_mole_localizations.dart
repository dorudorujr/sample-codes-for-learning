import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:whack_a_mole/localization/whack_a_mole_localization_ja.dart';

///abstract: 抽象クラス
abstract class WhackAMoleLocalizations {
  String get playerNameLabel;

  String get twitterIdLabel;

  String get cancel;

  String get play;

  static const LocalizationsDelegate<WhackAMoleLocalizations> delegate =
      _WhackAMoleLocalizationsDelegate();

  static WhackAMoleLocalizations of(BuildContext context) =>
      Localizations.of<WhackAMoleLocalizations>(
        context,
        WhackAMoleLocalizations,
      );
}

/// 多言語対応
class _WhackAMoleLocalizationsDelegate
    extends LocalizationsDelegate<WhackAMoleLocalizations> {
  const _WhackAMoleLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => locale.languageCode == 'ja';

  @override
  Future<WhackAMoleLocalizations> load(Locale locale) =>
      SynchronousFuture(WhackAMoleLocalizationJa());

  @override
  bool shouldReload(LocalizationsDelegate<WhackAMoleLocalizations> old) =>
      false;
}
