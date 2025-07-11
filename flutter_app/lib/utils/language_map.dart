// lib/utils/language_mapping.dart
/// Comprehensive mapping of ISO 639-3 language codes to display names
class LanguageMap {
  static const Map<String, String> _languageMap = {
    // Major languages
    'ara': 'Arabic',
    'cmn': 'Mandarin Chinese',
    'eng': 'English',
    'spa': 'Spanish',
    'fra': 'French',
    'mlg': 'Malagasy',
    'swe': 'Swedish',
    'por': 'Portuguese',
    'vie': 'Vietnamese',
    'ful': 'Fulah',
    'sun': 'Sundanese',
    'asm': 'Assamese',
    'ben': 'Bengali',
    'zlm': 'Malay',
    'kor': 'Korean',
    'ind': 'Indonesian',
    'hin': 'Hindi',
    'tuk': 'Turkmen',
    'urd': 'Urdu',
    'aze': 'Azerbaijani',
    'slv': 'Slovenian',
    'mon': 'Mongolian',
    'hau': 'Hausa',
    'tel': 'Telugu',
    'swh': 'Swahili',
    'bod': 'Tibetan',
    'rus': 'Russian',
    'tur': 'Turkish',
    'heb': 'Hebrew',
    'mar': 'Marathi',
    'som': 'Somali',
    'tgl': 'Tagalog',
    'tat': 'Tatar',
    'tha': 'Thai',
    'cat': 'Catalan',
    'ron': 'Romanian',
    'mal': 'Malayalam',
    'bel': 'Belarusian',
    'pol': 'Polish',
    'yor': 'Yoruba',
    'nld': 'Dutch',
    'bul': 'Bulgarian',
    'hat': 'Haitian Creole',
    'afr': 'Afrikaans',
    'isl': 'Icelandic',
    'amh': 'Amharic',
    'tam': 'Tamil',
    'hun': 'Hungarian',
    'hrv': 'Croatian',
    'lit': 'Lithuanian',
    'cym': 'Welsh',
    'fas': 'Persian',
    'mkd': 'Macedonian',
    'ell': 'Greek',
    'bos': 'Bosnian',
    'deu': 'German',
    'sqi': 'Albanian',
    'jav': 'Javanese',
    'kmr': 'Northern Kurdish',
    'nob': 'Norwegian Bokmål',
    'uzb': 'Uzbek',
    'snd': 'Sindhi',
    'lat': 'Latin',
    'nya': 'Nyanja',
    'grn': 'Guarani',
    'mya': 'Burmese',
    'orm': 'Oromo',
    'lin': 'Lingala',
    'hye': 'Armenian',
    'yue': 'Cantonese',
    'pan': 'Punjabi',
    'jpn': 'Japanese',
    'kaz': 'Kazakh',
    'npi': 'Nepali',
    'kik': 'Kikuyu',
    'kat': 'Georgian',
    'guj': 'Gujarati',
    'kan': 'Kannada',
    'tgk': 'Tajik',
    'ukr': 'Ukrainian',
    'ces': 'Czech',
    'lav': 'Latvian',
    'bak': 'Bashkir',
    'khm': 'Khmer',
    'fao': 'Faroese',
    'glg': 'Galician',
    'ltz': 'Luxembourgish',
    'xog': 'Soga',
    'lao': 'Lao',
    'mlt': 'Maltese',
    'sin': 'Sinhala',
    'aka': 'Akan',
    'sna': 'Shona',
    'ita': 'Italian',
    'srp': 'Serbian',
    'mri': 'Māori',
    'nno': 'Norwegian Nynorsk',
    'pus': 'Pashto',
    'eus': 'Basque',
    'ory': 'Odia',
    'lug': 'Ganda',
    'bre': 'Breton',
    'luo': 'Luo',
    'slk': 'Slovak',
    'ewe': 'Ewe',
    'fin': 'Finnish',
    'rif': 'Tarifit',
    'dan': 'Danish',
    'yid': 'Yiddish',
    'yao': 'Yao',
    'mos': 'Mossi',
    'hne': 'Chhattisgarhi',
    'est': 'Estonian',
    'dyu': 'Dyula',
    'bam': 'Bambara',
    'uig': 'Uyghur',
    'sck': 'Sadri',
    'tso': 'Tsonga',
    'mup': 'Malvi',
    'ctg': 'Chittagonian',
    'ceb': 'Cebuano',
    'war': 'Waray',
    'bbc': 'Batak Toba',
    'vmw': 'Makhuwa',
    'sid': 'Sidamo',
    'tpi': 'Tok Pisin',
    'mag': 'Magahi',
    'san': 'Sanskrit',
    'kri': 'Krio',
    'lon': 'Malawi Lomwe',
    'kir': 'Kyrgyz',
    'run': 'Rundi',
    'ubl': 'Buhi\'non Bikol',
    'kin': 'Kinyarwanda',
    'rkt': 'Rangpuri',
    'xmm': 'Manado Malay',
    'tir': 'Tigrinya',
    'mai': 'Maithili',
    'nan': 'Min Nan Chinese',
    'nyn': 'Nyankole',
    'bcc': 'Southern Balochi',
    'hak': 'Hakka Chinese',
    'suk': 'Sukuma',
    'bem': 'Bemba',
    'rmy': 'Vlax Romani',
    'awa': 'Awadhi',
    'pcm': 'Nigerian Pidgin',
    'bgc': 'Haryanvi',
    'shn': 'Shan',
    'oci': 'Occitan',
    'wol': 'Wolof',
    'bci': 'Baoulé',
    'kab': 'Kabyle',
    'ilo': 'Iloko',
    'bcl': 'Central Bikol',
    'haw': 'Hawaiian',
    'mad': 'Madurese',
    'nod': 'Northern Thai',
    'sag': 'Sango',
    'sas': 'Sasak',
    'jam': 'Jamaican Creole',
    'mey': 'Hassaniyya',
    'shi': 'Tachelhit',
    'hil': 'Hiligaynon',
    'ace': 'Acehnese',
    'kam': 'Kamba',
    'min': 'Minangkabau',
    'umb': 'Umbundu',
    'hno': 'Northern Hindko',
    'ban': 'Balinese',
    'syl': 'Sylheti',
    'bxg': 'Bangala',
    'xho': 'Xhosa',
    'mww': 'Hmong Daw',
    'epo': 'Esperanto',
    'tzm': 'Central Atlas Tamazight',
    'zul': 'Zulu',
    'ibo': 'Igbo',
    'abk': 'Abkhazian',
    'guz': 'Gusii',
    'ckb': 'Central Kurdish',
    'knc': 'Central Kanuri',
    'nso': 'Northern Sotho',
    'bho': 'Bhojpuri',
    'dje': 'Zarma',
    'tiv': 'Tiv',
    'gle': 'Irish',
    'lua': 'Luba-Lulua',
    'skr': 'Saraiki',
    'bto': 'Rinconada Bikol',
    'kea': 'Kabuverdianu',
    'glk': 'Gilaki',
    'ast': 'Asturian',
    'sat': 'Santali',
    'ktu': 'Kituba',
    'bhb': 'Bhili',
    'emk': 'Eastern Maninkakan',
    'kng': 'Koongo',
    'kmb': 'Kimbundu',
    'tsn': 'Tswana',
    'gom': 'Goan Konkani',
    'ven': 'Venda',
    'sco': 'Scots',
    'glv': 'Manx',
    'sot': 'Southern Sotho',
    'sou': 'Southern Thai',
    'gno': 'Gondi',
    'nde': 'Northern Ndebele',
    'bjn': 'Banjar',
    'ina': 'Interlingua',
    'fmu': 'Far Western Muria',
    'esg': 'Aheri Gondi',
    'wes': 'Cameroon Pidgin',
    'pnb': 'Western Punjabi',
    'phr': 'Pahari-Potwari',
    'mui': 'Musi',
    'bug': 'Buginese',
    'mrr': 'Maria',
    'kas': 'Kashmiri',
    'lir': 'Liberian English',
    'vah': 'Varhadi-Nagpuri',
    'ssw': 'Swati',
    'rwr': 'Marwari',
    'pcc': 'Bouyei',
    'hms': 'Southern Qiandong Miao',
    'wbr': 'Wagdi',
    'swv': 'Shekhawati',
    'mtr': 'Mewari',
    'haz': 'Hazaragi',
    'aii': 'Assyrian Neo-Aramaic',
    'bns': 'Bundeli',
    'msi': 'Sabah Malay',
    'wuu': 'Wu Chinese',
    'hsn': 'Xiang Chinese',
    'bgp': 'Eastern Balochi',
    'tts': 'Northeastern Thai',
    'lmn': 'Lambadi',
    'dcc': 'Deccan',
    'bew': 'Betawi',
    'bjj': 'Kanauji',
    'ibb': 'Ibibio',
    'tji': 'Northern Tujia',
    'hoj': 'Hadothi',
    'cpx': 'Pu-Xian Chinese',
    'cdo': 'Min Dong Chinese',
    'daq': 'Dandami Maria',
    'mut': 'Western Muria',
    'nap': 'Neapolitan',
    'czh': 'Huizhou Chinese',
    'gdx': 'Godwari',
    'sdh': 'Southern Kurdish',
    'scn': 'Sicilian',
    'mnp': 'Min Bei Chinese',
    'bar': 'Bavarian',
    'mzn': 'Mazanderani',
    'gsw': 'Swiss German',
  };

    /// Map Whisper language codes to your app's language codes
  static String mapWhisperLanguageToCode(String whisperCode) {
    const whisperToAppMap = {
      'en': 'eng', // English
      'zh': 'cmn', // Chinese (Mandarin)
      'de': 'deu', // German
      'es': 'spa', // Spanish
      'ru': 'rus', // Russian
      'ko': 'kor', // Korean
      'fr': 'fra', // French
      'ja': 'jpn', // Japanese
      'pt': 'por', // Portuguese
      'tr': 'tur', // Turkish
      'pl': 'pol', // Polish
      'ca': 'cat', // Catalan
      'nl': 'nld', // Dutch
      'ar': 'ara', // Arabic
      'sv': 'swe', // Swedish
      'it': 'ita', // Italian
      'id': 'ind', // Indonesian
      'hi': 'hin', // Hindi
      'fi': 'fin', // Finnish
      'vi': 'vie', // Vietnamese
      'he': 'heb', // Hebrew
      'uk': 'ukr', // Ukrainian
      'el': 'ell', // Greek
      'ms': 'msa', // Malay
      'cs': 'ces', // Czech
      'ro': 'ron', // Romanian
      'da': 'dan', // Danish
      'hu': 'hun', // Hungarian
      'ta': 'tam', // Tamil
      'no': 'nor', // Norwegian
      'th': 'tha', // Thai
      'ur': 'urd', // Urdu
      'hr': 'hrv', // Croatian
      'bg': 'bul', // Bulgarian
      'lt': 'lit', // Lithuanian
      'la': 'lat', // Latin
      'mi': 'mri', // Maori
      'ml': 'mal', // Malayalam
      'cy': 'cym', // Welsh
      'sk': 'slk', // Slovak
      'te': 'tel', // Telugu
      'fa': 'fas', // Persian
      'lv': 'lav', // Latvian
      'bn': 'ben', // Bengali
      'sr': 'srp', // Serbian
      'az': 'aze', // Azerbaijani
      'sl': 'slv', // Slovenian
      'kn': 'kan', // Kannada
      'et': 'est', // Estonian
      'mk': 'mkd', // Macedonian
      'br': 'bre', // Breton
      'eu': 'eus', // Basque
      'is': 'isl', // Icelandic
      'hy': 'hye', // Armenian
      'ne': 'nep', // Nepali
      'mn': 'mon', // Mongolian
      'bs': 'bos', // Bosnian
      'kk': 'kaz', // Kazakh
      'sq': 'sqi', // Albanian
      'sw': 'swa', // Swahili
      'gl': 'glg', // Galician
      'mr': 'mar', // Marathi
      'pa': 'pan', // Punjabi
      'si': 'sin', // Sinhala
      'km': 'khm', // Khmer
      'sn': 'sna', // Shona
      'yo': 'yor', // Yoruba
      'so': 'som', // Somali
      'af': 'afr', // Afrikaans
      'oc': 'oci', // Occitan
      'ka': 'kat', // Georgian
      'be': 'bel', // Belarusian
      'tg': 'tgk', // Tajik
      'sd': 'snd', // Sindhi
      'gu': 'guj', // Gujarati
      'am': 'amh', // Amharic
      'yi': 'yid', // Yiddish
      'lo': 'lao', // Lao
      'uz': 'uzb', // Uzbek
      'fo': 'fao', // Faroese
      'ht': 'hat', // Haitian Creole
      'ps': 'pus', // Pashto
      'tk': 'tuk', // Turkmen
      'nn': 'nno', // Norwegian Nynorsk
      'mt': 'mlt', // Maltese
      'sa': 'san', // Sanskrit
      'lb': 'ltz', // Luxembourgish
      'my': 'mya', // Myanmar
      'bo': 'bod', // Tibetan
      'tl': 'tgl', // Tagalog
      'mg': 'mlg', // Malagasy
      'as': 'asm', // Assamese
      'tt': 'tat', // Tatar
      'haw': 'haw', // Hawaiian
      'ln': 'lin', // Lingala
      'ha': 'hau', // Hausa
      'ba': 'bak', // Bashkir
      'jw': 'jav', // Javanese
      'su': 'sun', // Sundanese
    };

    return whisperToAppMap[whisperCode] ?? 'unk';
  }

  static String getLanguageName(String code) {
    return _languageMap[code.toLowerCase()] ?? code.toUpperCase();
  }

  static List<String> getSupportedCodes() {
    return _languageMap.keys.toList();
  }

  static bool isSupported(String code) {
    return _languageMap.containsKey(code.toLowerCase());
  }

  static String getLanguageNameWithFallback(String code, {String fallback = 'Unknown'}) {
    final name = _languageMap[code.toLowerCase()];
    return name ?? fallback;
  }
}