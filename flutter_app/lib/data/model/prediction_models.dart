

class AgePrediction {
  final double predictedAge;

  AgePrediction({required this.predictedAge});

  factory AgePrediction.fromJson(Map<String, dynamic> json) {
    return AgePrediction(
      predictedAge: (json['predicted_age'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {'predicted_age': predictedAge};
  }
}

class GenderPrediction {
  final String predictedGender;
  final Map<String, double> probabilities;
  final double confidence;

  GenderPrediction({
    required this.predictedGender,
    required this.probabilities,
    required this.confidence,
  });

  factory GenderPrediction.fromJson(Map<String, dynamic> json) {
    final probMap = <String, double>{};
    final probs = json['probabilities'] as Map<String, dynamic>;
    
    probs.forEach((key, value) {
      probMap[key] = (value as num).toDouble();
    });

    return GenderPrediction(
      predictedGender: json['predicted_gender'] as String,
      probabilities: probMap,
      confidence: (json['confidence'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'predicted_gender': predictedGender,
      'probabilities': probabilities,
      'confidence': confidence,
    };
  }
}

class AgeGenderPrediction {
  final AgePrediction age;
  final GenderPrediction gender;

  AgeGenderPrediction({
    required this.age,
    required this.gender,
  });

  factory AgeGenderPrediction.fromJson(Map<String, dynamic> json) {
    return AgeGenderPrediction(
      age: AgePrediction.fromJson(json['age']),
      gender: GenderPrediction.fromJson(json['gender']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'age': age.toJson(),
      'gender': gender.toJson(),
    };
  }

  /// Convert to AudioAnalysis format with separate age and gender fields
  Map<String, dynamic> toAudioAnalysisFormat() {
    return {
      'age': age.predictedAge, // Return the age as a double
      'gender': gender.probabilities, // Return gender probabilities as Map<String, double>
    };
  }
}

class LanguagePrediction {
  final String languageCode;
  final double probability;

  LanguagePrediction({
    required this.languageCode,
    required this.probability,
  });

  factory LanguagePrediction.fromJson(Map<String, dynamic> json) {
    return LanguagePrediction(
      languageCode: json['language_code'] as String,
      probability: (json['probability'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'language_code': languageCode,
      'probability': probability,
    };
  }
}

class NationalityPrediction {
  final String predictedLanguage;
  final double confidence;
  final List<LanguagePrediction> topLanguages;

  NationalityPrediction({
    required this.predictedLanguage,
    required this.confidence,
    required this.topLanguages,
  });

  factory NationalityPrediction.fromJson(Map<String, dynamic> json) {
    final topLangsList = json['top_languages'] as List<dynamic>;
    final topLanguages = topLangsList.map((lang) => 
      LanguagePrediction.fromJson(lang as Map<String, dynamic>)
    ).toList();

    return NationalityPrediction(
      predictedLanguage: json['predicted_language'] as String,
      confidence: (json['confidence'] as num).toDouble(),
      topLanguages: topLanguages,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'predicted_language': predictedLanguage,
      'confidence': confidence,
      'top_languages': topLanguages.map((lang) => lang.toJson()).toList(),
    };
  }

  /// Convert to AudioAnalysis format
  Map<String, double> toAudioAnalysisFormat() {
    final result = <String, double>{};
    
    for (final lang in topLanguages) {
      result[lang.languageCode.toUpperCase()] = lang.probability;
    }
    
    return result;
  }
}

class EmotionPrediction {
  final String predictedEmotion;
  final double confidence;
  final Map<String, double> allEmotions;

  EmotionPrediction({
    required this.predictedEmotion,
    required this.confidence,
    required this.allEmotions,
  });

  factory EmotionPrediction.fromJson(Map<String, dynamic> json) {
    final emotionsMap = <String, double>{};
    final emotions = json['all_emotions'] as Map<String, dynamic>;
    
    emotions.forEach((key, value) {
      emotionsMap[key] = (value as num).toDouble();
    });

    return EmotionPrediction(
      predictedEmotion: json['predicted_emotion'] as String,
      confidence: (json['confidence'] as num).toDouble(),
      allEmotions: emotionsMap,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'predicted_emotion': predictedEmotion,
      'confidence': confidence,
      'all_emotions': allEmotions,
    };
  }

  /// Convert to AudioAnalysis format
  Map<String, double> toAudioAnalysisFormat() {
    return Map<String, double>.from(allEmotions);
  }
}

class CompletePrediction {
  final AgeGenderPrediction demographics;
  final NationalityPrediction nationality;
  final EmotionPrediction emotion;

  CompletePrediction({
    required this.demographics,
    required this.nationality,
    required this.emotion,
  });

  factory CompletePrediction.fromJson(Map<String, dynamic> json) {
    return CompletePrediction(
      demographics: AgeGenderPrediction.fromJson(json['demographics']),
      nationality: NationalityPrediction.fromJson(json['nationality']),
      emotion: EmotionPrediction.fromJson(json['emotion']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'demographics': demographics.toJson(),
      'nationality': nationality.toJson(),
      'emotion': emotion.toJson(),
    };
  }
}

class ApiResponse<T> {
  final bool success;
  final T? predictions;
  final String? error;

  ApiResponse({
    required this.success,
    this.predictions,
    this.error,
  });

  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) fromJsonT,
  ) {
    return ApiResponse(
      success: json['success'] as bool,
      predictions: json['success'] == true && json['predictions'] != null
          ? fromJsonT(json['predictions'] as Map<String, dynamic>)
          : null,
      error: json['error'] as String?,
    );
  }
}