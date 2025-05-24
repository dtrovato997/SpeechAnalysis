
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

  /// Convert to AudioAnalysis format
  Map<String, double> toAudioAnalysisFormat() {
    final result = <String, double>{};
    
    // Add age as normalized value
    result['age'] = age.predictedAge / 100.0;
    
    // Add gender probabilities
    result.addAll(gender.probabilities);
    
    return result;
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

class CompletePrediction {
  final AgeGenderPrediction demographics;
  final NationalityPrediction nationality;

  CompletePrediction({
    required this.demographics,
    required this.nationality,
  });

  factory CompletePrediction.fromJson(Map<String, dynamic> json) {
    return CompletePrediction(
      demographics: AgeGenderPrediction.fromJson(json['demographics']),
      nationality: NationalityPrediction.fromJson(json['nationality']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'demographics': demographics.toJson(),
      'nationality': nationality.toJson(),
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