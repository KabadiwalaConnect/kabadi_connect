import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

final appLanguage = AppLanguage();

class AppLanguage extends ChangeNotifier {
  String _code = 'en';

  String get code => _code;
  Locale get locale => Locale(_code);

  static const supportedCodes = ['en', 'hi', 'mr'];

  Future<void> load() async {
    final deviceCode =
        WidgetsBinding.instance.platformDispatcher.locale.languageCode;

    _code = supportedCodes.contains(deviceCode) ? deviceCode : 'en';

    try {
      final preferences = await SharedPreferences.getInstance();
      final savedCode = preferences.getString('app_language');

      if (savedCode != null && supportedCodes.contains(savedCode)) {
        _code = savedCode;
      }
    } catch (_) {
      // Keep the supported device language if storage cannot be read.
    }

    notifyListeners();
  }

  void select(String code) {
    if (!supportedCodes.contains(code) || code == _code) return;

    _code = code;
    notifyListeners();
  }

  Future<void> save() async {
    final preferences = await SharedPreferences.getInstance();

    final saved = await preferences.setString('app_language', _code);

    if (!saved) {
      throw StateError('Could not save language preference.');
    }
  }

  String text(String key) {
    return _translations[_code]?[key] ?? _translations['en']?[key] ?? key;
  }

  static const Map<String, Map<String, String>> _translations = {
    'en': {
      'chooseLanguage': 'Choose language',
      'languageSubtitle': 'Select your preferred language',
      'continue': 'Continue',
      'saving': 'Saving…',
      'saveError': 'Could not save. Please try again.',
      'welcome': 'Welcome!',
      'nextPending': 'The next screen will be added in the next step.',
      'changeLanguage': 'Change language',
      'whoAreYou': 'Who are you?',
      'roleSubtitle': 'Choose your role so we can serve you better.',
      'collectorRole': 'Collector',
      'recyclerRole': 'Recycler',
      'collectorDescription':
          'I collect scrap from homes, shops and other places.',
      'recyclerDescription': 'I recycle or process collected scrap.',
      'brandTagline': 'A better tomorrow, a cleaner tomorrow',
      'togetherMessage': 'Together, we turn waste into value',
      'selectedRole': 'Selected role',
      'profilePending':
          'Your registration screen will be added in the next step.',
      'changeRole': 'Change role',
    },
    'hi': {
      'chooseLanguage': 'भाषा चुनें',
      'languageSubtitle': 'अपनी पसंद की भाषा चुनें',
      'continue': 'आगे बढ़ें',
      'saving': 'सहेज रहे हैं…',
      'saveError': 'सहेजा नहीं जा सका। दोबारा कोशिश करें।',
      'welcome': 'स्वागत है!',
      'nextPending': 'अगली स्क्रीन अगले चरण में जोड़ी जाएगी।',
      'changeLanguage': 'भाषा बदलें',
      'whoAreYou': 'आप कौन हैं?',
      'roleSubtitle': 'अपनी भूमिका चुनें ताकि हम आपको बेहतर सेवा दे सकें।',
      'collectorRole': 'कबाड़ संग्राहक',
      'recyclerRole': 'रीसायकलकर्ता',
      'collectorDescription':
          'मैं घरों, दुकानों या अन्य स्थानों से कबाड़ इकट्ठा करता/करती हूँ।',
      'recyclerDescription':
          'मैं कबाड़ को रीसायकल या प्रोसेस करने का काम करता/करती हूँ।',
      'brandTagline': 'बेहतर कल, साफ़ कल',
      'togetherMessage': 'साथ मिलकर, कचरे को कीमत में बदलें',
      'selectedRole': 'चुनी गई भूमिका',
      'profilePending': 'आपकी पंजीकरण स्क्रीन अगले चरण में जोड़ी जाएगी।',
      'changeRole': 'भूमिका बदलें',
    },
    'mr': {
      'chooseLanguage': 'भाषा निवडा',
      'languageSubtitle': 'तुमच्या पसंतीची भाषा निवडा',
      'continue': 'पुढे जा',
      'saving': 'जतन करत आहोत…',
      'saveError': 'जतन करता आले नाही. पुन्हा प्रयत्न करा.',
      'welcome': 'स्वागत आहे!',
      'nextPending': 'पुढील स्क्रीन पुढच्या टप्प्यात जोडली जाईल.',
      'changeLanguage': 'भाषा बदला',
      'whoAreYou': 'तुम्ही कोण आहात?',
      'roleSubtitle':
          'आम्हाला अधिक चांगली सेवा देता यावी म्हणून तुमची भूमिका निवडा.',
      'collectorRole': 'भंगार संकलक',
      'recyclerRole': 'पुनर्चक्रणकर्ता',
      'collectorDescription':
          'मी घरे, दुकाने किंवा इतर ठिकाणांहून भंगार गोळा करतो/करते.',
      'recyclerDescription':
          'मी भंगाराचे पुनर्चक्रण किंवा प्रक्रिया करण्याचे काम करतो/करते.',
      'brandTagline': 'उत्तम उद्या, स्वच्छ उद्या',
      'togetherMessage': 'एकत्र येऊन, कचऱ्याला मूल्य देऊया',
      'selectedRole': 'निवडलेली भूमिका',
      'profilePending': 'तुमची नोंदणी स्क्रीन पुढच्या टप्प्यात जोडली जाईल.',
      'changeRole': 'भूमिका बदला',
    },
  };
}
