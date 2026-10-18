import 'package:flutter/material.dart';

import '../locate/snap.dart';

class Copy {
  const Copy.english() : hindi = false;

  const Copy.hindi() : hindi = true;

  final bool hindi;

  RideWords get ride => hindi ? _hindiRide : const RideWords();

  String span(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.abs() % 60;
    if (hindi) {
      if (hours > 0) return '$hours घं $minutes मि';
      return '$minutes मि';
    }
    if (hours > 0) return '${hours}h ${minutes}m';
    return '${minutes}m';
  }

  String get appName => hindi ? 'हरियाणा रोडवेज़' : 'Haryana Roadways';
  String get findBus => hindi ? 'बस खोजें' : 'Find a bus';
  String get from => hindi ? 'कहाँ से' : 'From';
  String get to => hindi ? 'कहाँ तक' : 'To';
  String get today => hindi ? 'आज' : 'Today';
  String get searchBuses => hindi ? 'बसें देखें' : 'Search buses';
  String get findingStops => hindi ? 'स्टॉप खोज रहे हैं…' : 'Finding stops…';
  String get routes => hindi ? 'रूट' : 'Routes';
  String get routesHint => hindi ? 'इस जोड़े की आज की बसें खुलेंगी।' : 'Opens today’s buses for that pair.';
  String get recent => hindi ? 'हाल की खोज' : 'Recent';
  String get citiesForFrom => hindi ? 'कहाँ से के शहर' : 'Cities for From';
  String get citiesForTo => hindi ? 'कहाँ तक के शहर' : 'Cities for To';
  String get cityHint =>
      hindi ? 'शहर चुनें, फिर सूची से स्टॉप चुनें।' : 'Tap a city, then pick the matching stop.';
  String get swap => hindi ? 'स्टेशन बदलें' : 'Swap stations';
  String get chooseBoth => hindi ? 'दोनों स्टेशन सूची से चुनें।' : 'Choose both stations from the list.';
  String get gurgaon => hindi ? 'इस समय-सारणी में वर्तनी Gurgaon है।' : 'This timetable uses the spelling Gurgaon.';
  String get timetableDown => hindi ? 'समय-सारणी तक पहुँच नहीं बनी।' : 'Could not reach the timetable.';
  String get noMatch => hindi ? 'कोई स्टेशन नहीं मिला।' : 'No station matches.';
  String couldNotMatch(String from, String to) => hindi
      ? '$from से $to का स्टेशन नहीं मिला।'
      : 'Could not match $from to $to.';
  String busCount(int count) => hindi ? 'आज की $count बसें' : '$count buses · today';
  String get noBuses => hindi ? 'आज इस जोड़े की कोई बस नहीं।' : 'No buses for this pair today.';
  String get checking => hindi ? 'समय-सारणी देख रहे हैं…' : 'Checking the timetable…';
  String get noRider => hindi ? 'इस बस पर कोई यात्री नहीं' : 'No rider on this bus';
  String get liveDown => hindi ? 'लाइव स्थिति उपलब्ध नहीं' : 'Live position unavailable';
  String get couldNotPlace =>
      hindi ? 'इस बस को समय-सारणी पर नहीं रख सके।' : 'Could not place this bus on the timetable.';
  String stopCount(int index, int count) => hindi ? 'स्टॉप $index / $count' : 'Stop $index of $count';
  String get yourPosition => hindi ? 'आपकी स्थिति' : 'Your position';
  String get onThisBus => hindi ? 'मैं इस बस पर हूँ' : "I'm on this bus";
  String get sharing => hindi ? 'इस बस का स्थान जा रहा है' : 'Sharing this bus';
  String get shareAskTitle => hindi ? 'बस की जगह कैसे लें?' : 'How should we place this bus?';
  String get shareAskBody => hindi
      ? 'मोबाइल टॉवर से जगह मिल जाती है। जीपीएस चालू करने पर सटीकता ज्यादा होती है।'
      : 'The mobile tower can place this bus. GPS accuracy is higher.';
  String get useGps => hindi ? 'जीपीएस' : 'GPS';
  String get useGpsAccurate => hindi ? 'जीपीएस, ज्यादा सटीक' : 'GPS, higher accuracy';
  String get useTower => hindi ? 'टॉवर' : 'Tower';
  String get sharingGps => hindi ? 'जीपीएस से भेज रहे हैं' : 'Sharing with GPS';
  String get sharingTower => hindi ? 'टॉवर से भेज रहे हैं' : 'Sharing with tower';
  String get towerUnknown => hindi
      ? 'इस टॉवर की अनुमानित जगह नहीं मिली।'
      : 'No approximate place for this tower.';
  String get towerHidden =>
      hindi ? 'फ़ोन ने टॉवर की पहचान नहीं दी।' : 'The phone did not share this tower.';
  String get sharingHint =>
      hindi ? 'आपके फ़ोन से इस बस की जगह भेजी जा रही है' : 'Sharing this bus location from your phone';
  String get stopSharing => hindi ? 'रोकें' : 'Stop';
  String get locationOff => hindi ? 'लोकेशन बंद है' : 'Location is turned off';
  String get locationDenied =>
      hindi ? 'इस बस पर बैठने के लिए लोकेशन की अनुमति चाहिए' : 'Location permission is required to ride this bus';
  String get nearbyStops => hindi ? 'पास के स्टॉप' : 'Nearby stops';
  String allStops(int count) => hindi ? 'सभी $count स्टॉप' : 'All $count stops';
  String get next => hindi ? 'आगे' : 'Next';
  String get left => hindi ? 'छोड़ा' : 'Left';
  String get departs => hindi ? 'चलेगी' : 'Departs';
  String get here => hindi ? 'यहाँ' : 'Here';
  String get lightTheme => hindi ? 'हल्की थीम' : 'Light theme';
  String get darkTheme => hindi ? 'गहरी थीम' : 'Dark theme';
  String get language => hindi ? 'English' : 'हिन्दी';

  String distance(double km) {
    final shown = km >= 10 ? km.toStringAsFixed(0) : km.toStringAsFixed(1);
    return hindi ? '$shown किमी' : '$shown km';
  }

  /// Hindi labels for timetable words. A plate such as HR69GV7194 is left as-is.
  /// Anything still in Latin is written in Devanagari so the Hindi screen stays Hindi.
  String place(String name) {
    if (!hindi || name.isEmpty) return name;
    var text = name;
    for (final entry in _placeRes) {
      text = text.replaceAll(entry.key, entry.value);
    }
    return text.replaceAllMapped(RegExp(r'[A-Za-z]+'), (match) {
      final start = match.start;
      final end = match.end;
      final before = start > 0 ? text[start - 1] : '';
      final after = end < text.length ? text[end] : '';
      if (_digit.hasMatch(before) || _digit.hasMatch(after)) return match.group(0)!;
      return _devanagari(match.group(0)!);
    });
  }

  String trouble(Object error) {
    final raw = error.toString();
    if (!hindi) return raw;
    if (raw.contains('Location is turned off')) return locationOff;
    if (raw.contains('Location permission')) return locationDenied;
    if (raw.contains('Timetable')) return timetableDown;
    return raw;
  }

  static const _hindiRide = RideWords(
    scheduled: 'निर्धारित',
    notStarted: 'अभी नहीं चली',
    onRoad: 'रास्ते में',
    arrived: 'पहुँच गई',
    seen: 'यात्रियों ने देखी',
    noStops: 'इस ड्यूटी पर कोई स्टॉप नहीं',
    departs: '{name} से {clock} पर',
    arrivedAt: '{clock} पर {name}',
    minsTo: '{name} तक {mins} मिनट',
    dueAt: '{name} का समय हो गया',
    leftName: '{name} छोड़ चुकी',
    atStop: '{name} पर',
    leftNext: '{name} छोड़ी · आगे {next}',
    late: '{mins} मिनट लेट',
    early: '{mins} मिनट जल्दी',
  );

  static final _placeRes = () {
    final keys = _known.keys.toList()..sort((a, b) => b.length.compareTo(a.length));
    return [
      for (final key in keys)
        MapEntry(RegExp('\\b${RegExp.escape(key)}\\b', caseSensitive: false), _known[key]!),
    ];
  }();

  static final _digit = RegExp(r'\d');

  static const _known = {
    'Anand Vihar': 'आनंद विहार',
    'Kashmere Gate': 'कश्मीरी गेट',
    'Kashmiri Gate': 'कश्मीरी गेट',
    'Sri Ganganagar': 'श्री गंगानगर',
    'Charkhi Dadri': 'चरखी दादरी',
    'Yamuna Nagar': 'यमुनानगर',
    'Semi Deluxe': 'सेमी डीलक्स',
    'Bus Stand': 'बस स्टैंड',
    'Bus Adda': 'बस अड्डा',
    'Bye Pass': 'बाईपास',
    'New Delhi': 'नई दिल्ली',
    'Non AC': 'नॉन एसी',
    'Yamunanagar': 'यमुनानगर',
    'Bahadurgarh': 'बहादुरगढ़',
    'Dharamshala': 'धर्मशाला',
    'Dharamsala': 'धर्मशाला',
    'Muzaffarnagar': 'मुजफ्फरनगर',
    'Mahendragarh': 'महेंद्रगढ़',
    'Kurukshetra': 'कुरुक्षेत्र',
    'Hanumangarh': 'हनुमानगढ़',
    'Ganganagar': 'गंगानगर',
    'Saharanpur': 'सहारनपुर',
    'Pathankot': 'पठानकोट',
    'Ludhiana': 'लुधियाना',
    'Faridabad': 'फरीदाबाद',
    'Chandigarh': 'चंडीगढ़',
    'Panchkula': 'पंचकूला',
    'Ghaziabad': 'गाज़ियाबाद',
    'Dehradun': 'देहरादून',
    'Rishikesh': 'ऋषिकेश',
    'Haridwar': 'हरिद्वार',
    'Dharuhera': 'धारूहेड़ा',
    'Narnaul': 'नारनौल',
    'Ellenabad': 'ऐलनाबाद',
    'Kalanwali': 'कलांवाली',
    'Fatehabad': 'फतेहाबाद',
    'Nilokheri': 'नीलोखेड़ी',
    'Gharaunda': 'घरौंडा',
    'Samalkha': 'समालखा',
    'Ordinary': 'साधारण',
    'Express': 'एक्सप्रेस',
    'Deluxe': 'डीलक्स',
    'Sleeper': 'स्लीपर',
    'Seater': 'सीटर',
    'Volvo': 'वॉल्वो',
    'Bypass': 'बाईपास',
    'Gurugram': 'गुरुग्राम',
    'Gurgaon': 'गुड़गाँव',
    'Sonipat': 'सोनीपत',
    'Sonepat': 'सोनीपत',
    'Panipat': 'पानीपत',
    'Rohtak': 'रोहतक',
    'Jhajjar': 'झज्जर',
    'Bhiwani': 'भिवानी',
    'Rewari': 'रेवाड़ी',
    'Kaithal': 'कैथल',
    'Thanesar': 'थानेसर',
    'Pehowa': 'पेहोवा',
    'Jagadhri': 'जगाधरी',
    'Kalka': 'कालका',
    'Pinjore': 'पिंजौर',
    'Nalagarh': 'नालागढ़',
    'Shimla': 'शिमला',
    'Manali': 'मनाली',
    'Jaipur': 'जयपुर',
    'Jodhpur': 'जोधपुर',
    'Bikaner': 'बीकानेर',
    'Udaipur': 'उदयपुर',
    'Ajmer': 'अजमेर',
    'Alwar': 'अलवर',
    'Sikar': 'सीकर',
    'Churu': 'चूरू',
    'Agra': 'आगरा',
    'Mathura': 'मथुरा',
    'Meerut': 'मेरठ',
    'Noida': 'नोएडा',
    'Jammu': 'जम्मू',
    'Amritsar': 'अमृतसर',
    'Patiala': 'पटियाला',
    'Bathinda': 'बठिंडा',
    'Ambala': 'अम्बाला',
    'Karnal': 'करनाल',
    'Hisar': 'हिसार',
    'Hansi': 'हांसी',
    'Sirsa': 'सिरसा',
    'Jind': 'जींद',
    'Narwana': 'नरवाना',
    'Safidon': 'सफीदों',
    'Tohana': 'टोहाना',
    'Ratia': 'रतिया',
    'Dabwali': 'डबवाली',
    'Rania': 'रानिया',
    'Siwani': 'सिवानी',
    'Loharu': 'लोहारू',
    'Tosham': 'तोशाम',
    'Kosli': 'कोसली',
    'Bawal': 'बावल',
    'Pataudi': 'पटौदी',
    'Sohna': 'सोहना',
    'Manesar': 'मानेसर',
    'Bilaspur': 'बिलासपुर',
    'Nuh': 'नूह',
    'Palwal': 'पलवल',
    'Hodal': 'होडल',
    'Gohana': 'गोहाना',
    'Ganaur': 'गन्नौर',
    'Gannaur': 'गन्नौर',
    'Sampla': 'सांपला',
    'Murthal': 'मुरथल',
    'Kundli': 'कुंडली',
    'Narela': 'नरेला',
    'Assandh': 'असांध',
    'Ismailabad': 'इस्माइलाबाद',
    'Ladwa': 'लाडवा',
    'Shahbad': 'शाहबाद',
    'Cheeka': 'चीका',
    'Kalayat': 'कलायत',
    'Gulha': 'गुहला',
    'Mandi': 'मंडी',
    'Kullu': 'कुल्लू',
    'Solan': 'सोलन',
    'Una': 'ऊना',
    'Baddi': 'बद्दी',
    'Nahan': 'नाहन',
    'Paonta': 'पांवटा',
    'Roorkee': 'रुड़की',
    'Delhi': 'दिल्ली',
    'Depot': 'डिपो',
    'Terminal': 'टर्मिनल',
    'Station': 'स्टेशन',
    'Railway': 'रेलवे',
    'Junction': 'जंक्शन',
    'Crossing': 'क्रॉसिंग',
    'Flyover': 'फ्लाईओवर',
    'Hospital': 'अस्पताल',
    'University': 'विश्वविद्यालय',
    'College': 'कॉलेज',
    'School': 'स्कूल',
    'Market': 'मार्केट',
    'Colony': 'कॉलोनी',
    'Enclave': 'एन्क्लेव',
    'Nagar': 'नगर',
    'Chowk': 'चौक',
    'Gate': 'गेट',
    'Road': 'रोड',
    'City': 'सिटी',
    'Camp': 'कैंप',
    'Cantt': 'छावनी',
    'Sector': 'सेक्टर',
    'Village': 'गाँव',
    'Bridge': 'पुल',
    'Office': 'कार्यालय',
    'Stand': 'स्टैंड',
    'Adda': 'अड्डा',
    'Pull': 'पुल',
    'Mod': 'मोड़',
    'ISBT': 'आईएसबीटी',
    'AC': 'एसी',
  };
}

String _devanagari(String raw) {
  const consonants = {
    'chh': 'छ',
    'kh': 'ख',
    'gh': 'घ',
    'ch': 'च',
    'jh': 'झ',
    'th': 'थ',
    'dh': 'ध',
    'ph': 'फ',
    'bh': 'भ',
    'sh': 'श',
    'ng': 'ङ',
    'k': 'क',
    'g': 'ग',
    'c': 'क',
    'j': 'ज',
    't': 'त',
    'd': 'द',
    'n': 'न',
    'p': 'प',
    'b': 'ब',
    'm': 'म',
    'y': 'य',
    'r': 'र',
    'l': 'ल',
    'v': 'व',
    'w': 'व',
    's': 'स',
    'h': 'ह',
    'z': 'ज़',
    'f': 'फ़',
    'q': 'क़',
    'x': 'क्स',
  };
  const independent = {
    'aa': 'आ',
    'ai': 'ऐ',
    'au': 'औ',
    'ee': 'ई',
    'ii': 'ई',
    'oo': 'ऊ',
    'uu': 'ऊ',
    'a': 'अ',
    'e': 'ए',
    'i': 'इ',
    'o': 'ओ',
    'u': 'उ',
  };
  const matra = {
    'aa': 'ा',
    'ai': 'ै',
    'au': 'ौ',
    'ee': 'ी',
    'ii': 'ी',
    'oo': 'ू',
    'uu': 'ू',
    'a': '',
    'e': 'े',
    'i': 'ि',
    'o': 'ो',
    'u': 'ु',
  };
  final letters = raw.toLowerCase();
  final out = StringBuffer();
  var i = 0;
  var hanging = false;
  String? take(Map<String, String> table) {
    for (final key in table.keys) {
      if (letters.startsWith(key, i)) return key;
    }
    return null;
  }

  while (i < letters.length) {
    final vowel = take(hanging ? matra : independent);
    if (vowel != null) {
      out.write(hanging ? matra[vowel] : independent[vowel]);
      i += vowel.length;
      hanging = false;
      continue;
    }
    final consonant = take(consonants);
    if (consonant != null) {
      out.write(consonants[consonant]);
      i += consonant.length;
      hanging = consonant != 'x';
      continue;
    }
    out.write(letters[i]);
    i++;
    hanging = false;
  }
  return out.toString();
}

class LocaleHost extends InheritedWidget {
  const LocaleHost({
    super.key,
    required this.hindi,
    required this.toggle,
    required super.child,
  });

  final bool hindi;
  final VoidCallback toggle;

  static LocaleHost of(BuildContext context) {
    final host = context.dependOnInheritedWidgetOfExactType<LocaleHost>();
    assert(host != null, 'LocaleHost missing above this page');
    return host!;
  }

  static Copy copyOf(BuildContext context) => of(context).hindi ? const Copy.hindi() : const Copy.english();

  @override
  bool updateShouldNotify(LocaleHost oldWidget) => hindi != oldWidget.hindi;
}

class LanguageButton extends StatelessWidget {
  const LanguageButton({super.key, this.onDark = false});

  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final host = LocaleHost.of(context);
    return TextButton(
      style: TextButton.styleFrom(
        minimumSize: const Size(48, 48),
        foregroundColor: onDark ? const Color(0xFFFFFFFF) : null,
      ),
      onPressed: host.toggle,
      child: Text(host.hindi ? 'EN' : 'हिं', style: const TextStyle(fontWeight: FontWeight.w800)),
    );
  }
}
