import 'package:mobile_speech_recognition/domain/models/audio_analysis/audio_analysis.dart';

/// Model class for carousel items
class AudioAnalysisHomeSummary {
  final String title;
  final String? status;
  final String? imageUrl;
  final DateTime? date;
  final String? id;

  AudioAnalysisHomeSummary({
    required this.title,
    this.status,
    this.imageUrl,
    this.date,
    this.id,
  });
  
  // Factory method to create a CarouselItem from an AudioAnalysis
  factory AudioAnalysisHomeSummary.fromAudioAnalysis(AudioAnalysis analysis) {
    // Calculate duration string if needed (this would require additional info)
    String subtitle = '';
    
    // You could determine the subtitle based on the analysis state
    if (analysis.completionDate != null) {
      subtitle = 'Completed';
    } else if (analysis.sendStatus == 1) { // Assuming 1 is TO_SEND based on spec
      subtitle = 'Pending';
    } else if (analysis.sendStatus == 4) { // Assuming 4 is FAILED based on spec
      subtitle = 'Failed';
    }
    
    return AudioAnalysisHomeSummary(
      id: analysis.id?.toString(),
      title: analysis.title,
      status: subtitle,
      date: analysis.creationDate,
    );
  }
}