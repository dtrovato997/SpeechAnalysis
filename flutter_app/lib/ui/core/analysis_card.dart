import 'package:flutter/material.dart';
import 'package:mobile_speech_recognition/domain/models/audio_analysis/audio_analysis.dart';
import 'package:mobile_speech_recognition/ui/core/ui/analysis_detail/widgets/audio_analysis_detail_screen.dart';
import 'package:mobile_speech_recognition/utils/analysis_format_utils.dart';

class AnalysisCard extends StatelessWidget {
  final AudioAnalysis analysis;
  final VoidCallback? onTap;
  final bool showDetails;
  
  const AnalysisCard({
    Key? key,
    required this.analysis,
    this.onTap,
    this.showDetails = true,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    
    // Status indicator based on sendStatus
    final String statusText = AnalysisFormatUtils.getStatusText(analysis.sendStatus);
    final Color statusColor = AnalysisFormatUtils.getStatusColor(statusText, colorScheme);
    
    final Widget statusIndicator = Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: statusColor,
        shape: BoxShape.circle,
      ),
    );
    
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap ?? () {
          // Default navigation if no onTap provided
          if (analysis.id != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AudioAnalysisDetailScreen(
                  analysisId: analysis.id!,
                ),
              ),
            );
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title and Status row
              Row(
                children: [
                  Expanded(
                    child: Text(
                      analysis.title,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  statusIndicator,
                ],
              ),
              
              // Description if available
              if (analysis.description != null && analysis.description!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  analysis.description!,
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              
              if (showDetails) ...[
                const SizedBox(height: 8),
                // Divider for visual separation
                const Divider(),
                const SizedBox(height: 8),
                
                // Analysis data: age, gender and nationality sections
                Column(
                  children: [
                    // First row: Age and Gender
                    Row(
                      children: [
                        // Age section
                        _buildResultSection(
                          context: context,
                          label: 'Age',
                          value: AnalysisFormatUtils.parseAgeResult(analysis.ageResult),
                          icon: Icons.cake,
                          colorScheme: colorScheme,
                          textTheme: textTheme,
                        ),
                        
                        const SizedBox(width: 24),
                        
                        // Gender section
                        _buildResultSection(
                          context: context,
                          label: 'Gender',
                          value: AnalysisFormatUtils.parseGenderResult(analysis.genderResult),
                          icon: _getGenderIcon(analysis.genderResult),
                          colorScheme: colorScheme,
                          textTheme: textTheme,
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // Second row: Nationality (centered)
                    Row(
                      children: [
                        _buildResultSection(
                          context: context,
                          label: 'Nationality',
                          value: AnalysisFormatUtils.parseNationalityResult(analysis.nationalityResult),
                          icon: Icons.public,
                          colorScheme: colorScheme,
                          textTheme: textTheme,
                        ),
                        
                        // Empty expanded to balance the layout
                        const SizedBox(width: 24),
                        const Expanded(child: SizedBox()),
                      ],
                    ),
                  ],
                ),
              ],
              
              const SizedBox(height: 12),
              
              // Date row at the bottom
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Date
                  Text(
                    AnalysisFormatUtils.formatDate(analysis.creationDate),
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  
                  // Status text
                  Text(
                    statusText,
                    style: textTheme.bodySmall?.copyWith(
                      color: statusColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  IconData _getGenderIcon(Map<String, double>? genderResult) {
    if (genderResult == null || genderResult.isEmpty) {
      return Icons.person;
    }
    
    final topGender = genderResult.entries.reduce(
      (a, b) => a.value > b.value ? a : b,
    );
    
    switch (topGender.key.toUpperCase()) {
      case 'F':
      case 'FEMALE':
        return Icons.female;
      case 'M':
      case 'MALE':
        return Icons.male;
      default:
        return Icons.person;
    }
  }
  
  Widget _buildResultSection({
    required BuildContext context,
    required String label,
    required String value,
    required IconData icon,
    required ColorScheme colorScheme,
    required TextTheme textTheme,
  }) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                icon,
                size: 16,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  value,
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}