// lib/ui/core/ui/analysis_list/widgets/analysis_list_screen.dart
import 'package:flutter/material.dart';
import 'package:mobile_speech_recognition/ui/core/analysis_card.dart';
import 'package:mobile_speech_recognition/ui/core/ui/analysis_list/view_models/analysis_list_view_model.dart';
import 'package:mobile_speech_recognition/ui/core/ui/analysis_detail/widgets/audio_analysis_detail_screen.dart';
import 'package:mobile_speech_recognition/domain/models/audio_analysis/audio_analysis.dart';
import 'package:mobile_speech_recognition/utils/analysis_format_utils.dart';
import 'package:provider/provider.dart';

class AnalysisListScreen extends StatefulWidget {
  const AnalysisListScreen({Key? key}) : super(key: key);

  @override
  State<AnalysisListScreen> createState() => _AnalysisListScreenState();
}

class _AnalysisListScreenState extends State<AnalysisListScreen> {
  late AnalysisListViewModel viewModel;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    viewModel = AnalysisListViewModel(context);
    
    _searchController.addListener(() {
      viewModel.filterAnalyses(_searchController.text);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return ChangeNotifierProvider.value(
      value: viewModel,
      child: Consumer<AnalysisListViewModel>(
        builder: (context, model, child) {
          return Column(
            children: [
              // Search Bar
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: SearchBar(
                  controller: _searchController,
                  hintText: 'Search analyses...',
                  onChanged: (value) {
                    model.filterAnalyses(value);
                  },
                  leading: Icon(Icons.search, color: colorScheme.primary),
                  trailing: [
                    if (_searchController.text.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                        },
                      ),
                  ],
                ),
              ),
              
              // Analysis List or Loading/Error states
              Expanded(
                child: _buildListContent(model, colorScheme),
              ),
            ],
          );
        }
      ),
    );
  }

  Widget _buildListContent(AnalysisListViewModel model, ColorScheme colorScheme) {
    // Show loading indicator if loading
    if (model.isLoading) {
      return Center(
        child: CircularProgressIndicator(color: colorScheme.primary),
      );
    }
    
    // Show error message if error occurred
    if (model.hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: colorScheme.error),
            const SizedBox(height: 16),
            Text(
              'Error loading analyses',
              style: TextStyle(color: colorScheme.error),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => model.loadAnalyses(),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    
    // Show empty state if no analyses
    if (model.filteredAnalyses.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              model.searchQuery.isEmpty ? Icons.mic_none : Icons.search_off,
              size: 48,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              model.searchQuery.isEmpty 
                  ? 'No analyses available yet' 
                  : 'No results found for "${model.searchQuery}"',
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 16,
              ),
            ),
            if (model.searchQuery.isEmpty) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                icon: const Icon(Icons.mic),
                label: const Text('Record New Analysis'),
                onPressed: () {
                  // Navigate to recording screen
                  // This should be implemented based on your navigation pattern
                },
              ),
            ],
          ],
        ),
      );
    }
    
    // Show list of analyses
    return RefreshIndicator(
      onRefresh: () => model.loadAnalyses(),
      color: colorScheme.primary,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        itemCount: model.filteredAnalyses.length,
        itemBuilder: (context, index) {
          final analysis = model.filteredAnalyses[index];
          return AnalysisCard(
            analysis: analysis,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AudioAnalysisDetailScreen(
                    analysisId: analysis.id!,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}