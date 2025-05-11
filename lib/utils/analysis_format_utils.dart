// lib/utils/analysis_format_utils.dart
import 'package:flutter/material.dart';

/// Utility class for formatting analysis results across the app
class AnalysisFormatUtils {
  
  /// Maps for age and gender codes to display labels
  static const Map<String, String> ageGenderLabels = {
    'YF': 'Young Female',
    'YM': 'Young Male',
    'F': 'Female',
    'M': 'Male',
    'C': 'Child',
    'Unknown': 'Unknown',
  };
  
  /// Maps for nationality codes to display labels
  static const Map<String, String> nationalityLabels = {
    'IT': 'Italian',
    'FR': 'French',
    'EN': 'English',
    'ES': 'Spanish',
    'DE': 'German',
    'Unknown': 'Unknown',
  };
  
  /// Get display color for status
  static Color getStatusColor(String status, ColorScheme colorScheme) {
    switch (status.toLowerCase()) {
      case 'pending':
        // Use amber/orange which is more visible than yellow
        return colorScheme.tertiary;
      case 'completed':
        return colorScheme.primary;
      case 'failed':
        return colorScheme.error;
      default:
        return colorScheme?.onSurfaceVariant ?? Colors.grey;
    }
  }
  
  /// Parse age/gender result and return the most likely one
  static String parseAgeGenderResult(String? ageResult) {
    if (ageResult == null || ageResult.isEmpty) {
      return '--';
    }
    
    try {
      // Parse age/gender result string like "YF:85,YM:10,C:5"
      final Map<String, double> results = {};
      final pairs = ageResult.split(',');
      
      for (final pair in pairs) {
        final parts = pair.split(':');
        if (parts.length == 2) {
          final code = parts[0].trim();
          final value = double.tryParse(parts[1].trim()) ?? 0.0;
          results[code] = value;
        }
      }
      
      if (results.isEmpty) {
        return '--';
      }
      
      // Find the most likely result
      final topEntry = results.entries.reduce((a, b) => a.value > b.value ? a : b);
      return ageGenderLabels[topEntry.key] ?? topEntry.key;
      
    } catch (e) {
      return '--';
    }
  }
  
  /// Parse nationality result and return the most likely one
  static String parseNationalityResult(String? nationalityResult) {
    if (nationalityResult == null || nationalityResult.isEmpty) {
      return '--';
    }
    
    try {
      // Parse nationality result string like "IT:80,FR:12,EN:8"
      final Map<String, double> results = {};
      final pairs = nationalityResult.split(',');
      
      for (final pair in pairs) {
        final parts = pair.split(':');
        if (parts.length == 2) {
          final code = parts[0].trim();
          final value = double.tryParse(parts[1].trim()) ?? 0.0;
          results[code] = value;
        }
      }
      
      if (results.isEmpty) {
        return '--';
      }
      
      // Find the most likely result
      final topEntry = results.entries.reduce((a, b) => a.value > b.value ? a : b);
      return nationalityLabels[topEntry.key] ?? topEntry.key;
      
    } catch (e) {
      return '--';
    }
  }
  
  /// Parse result string into a map of code:value
  static Map<String, double> parseResultString(String? resultString) {
    final Map<String, double> results = {};
    
    if (resultString == null || resultString.isEmpty) {
      return results;
    }
    
    try {
      final pairs = resultString.split(',');
      
      for (final pair in pairs) {
        final parts = pair.split(':');
        if (parts.length == 2) {
          final code = parts[0].trim();
          final value = double.tryParse(parts[1].trim()) ?? 0.0;
          results[code] = value;
        }
      }
    } catch (e) {
      // Return empty map on error
    }
    
    return results;
  }
  
  /// Format date in a user-friendly way
  static String formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays < 1) {
      // Today, show time
      return 'Today, ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays < 2) {
      // Yesterday
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      // Within a week
      const List<String> weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
      final weekday = weekdays[date.weekday - 1];
      return weekday;
    } else {
      // Older than a week
      return '${date.day} ${getMonthName(date.month)} ${date.year}';
    }
  }
  
  /// Get month name abbreviation from month number (1-12)
  static String getMonthName(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[(month - 1).clamp(0, 11)];
  }
  
  /// Get icon for age/gender code
  static IconData getAgeGenderIcon(String code) {
    if (code.contains('F')) {
      return Icons.female;
    } else if (code.contains('M')) {
      return Icons.male;
    } else if (code.contains('C')) {
      return Icons.child_care;
    }
    return Icons.person;
  }
  
  /// Get icon for nationality code
  static IconData getNationalityIcon(String code) {
    return Icons.public;
  }
  
  /// Convert sendStatus code to display string
  static String getStatusText(int sendStatus) {
    switch (sendStatus) {
      case 0: // PENDING
        return 'Pending';
      case 1: // SENT/COMPLETED
        return 'Completed';
      case 2: // ERROR
        return 'Failed';
      default:
        return 'Unknown';
    }
  }
}