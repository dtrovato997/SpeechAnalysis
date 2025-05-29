import 'package:flutter/material.dart';
import 'package:mobile_speech_recognition/ui/core/ui/home_page/view_models/home_view_model.dart';
import 'package:mobile_speech_recognition/ui/core/ui/home_page/widgets/recent_analysis_view_pager.dart';
import 'package:mobile_speech_recognition/ui/core/ui/record_audio/widgets/record_audio_screen.dart';
import 'package:mobile_speech_recognition/ui/core/ui/analysis_list/widgets/analysis_list_screen.dart';
import 'package:mobile_speech_recognition/ui/core/ui/upload_audio/widgets/upload_audio_screen.dart';
import 'package:mobile_speech_recognition/services/microphone_permission_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // Define a consistent horizontal padding value
  final double horizontalPadding = 16.0;
  late HomeViewModel viewModel;
  int _currentIndex = 0;
  final MicrophonePermissionService _permissionService = MicrophonePermissionService();

  @override
  void initState() {
    super.initState();
    viewModel = HomeViewModel(context);
  }

  @override
  Widget build(BuildContext context) {
    // Get theme colors
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      // Only show the app bar on the home tab
      appBar: AppBar(
        title: Text(
          'Speech Analysis',
          style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.bold),
          
          textAlign: TextAlign.left
        ),
        scrolledUnderElevation: 0.0,    
        backgroundColor: colorScheme.surfaceBright,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.settings, color: colorScheme.primary),
            onPressed: () {
              // Handle settings button press
            },
          ),
        ],
      ),
      backgroundColor: colorScheme.surfaceBright,
      
      // Use IndexedStack to preserve the state of each tab
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _buildHomeContent(),
          const AnalysisListScreen(),
        ],
      ),
      

      bottomNavigationBar: NavigationBar(
        backgroundColor: colorScheme.surfaceBright,
        indicatorColor: colorScheme.primaryContainer,
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: [
          NavigationDestination(
            icon: Icon(Icons.home_outlined, color: colorScheme.onSurfaceVariant),
            selectedIcon: Icon(Icons.home, color: colorScheme.onPrimaryContainer),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.list_alt_outlined, color: colorScheme.onSurfaceVariant),
            selectedIcon: Icon(Icons.list_alt, color: colorScheme.onPrimaryContainer),
            label: 'Analysis',
          ),
        ],
      ),
    );
  }

  Widget _buildHomeContent() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: Column(
                mainAxisSize: MainAxisSize.max,
                children: [
                  // Title
                  buildTitleSection(),

                  Expanded(
                    flex: 1,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: _buildFixedHeightCards(),
                    ),
                  ),

                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: createRecentAnalysisSection(),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Padding buildTitleSection() {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: 14.0,
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          'Start new analysis',
          style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          softWrap: true,
          overflow: TextOverflow.visible,
          textAlign: TextAlign.left,
        ),
      ),
    );
  }

  Column createRecentAnalysisSection() {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      children: [
        // Title for Recent Analyses
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: 14.0,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent analyses',
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                softWrap: true,
                overflow: TextOverflow.visible,
              ),
              TextButton(
                onPressed: () {
                  // Simply switch to the analysis tab
                  setState(() {
                    _currentIndex = 1;
                  });
                },
                child: Text(
                  'View all',
                  style: TextStyle(color: Theme.of(context).colorScheme.primary),
                ),
              ),
            ],
          ),
        ),

        Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          child: RecentAnalysisViewPager(
            viewModel: viewModel,
            horizontalPadding: horizontalPadding,
            onItemTap: (item) {
              // Handle tap on carousel item
              if (item.id != null) {
                Navigator.pushNamed(
                  context, 
                  '/analysis-detail', 
                  arguments: int.parse(item.id!)
                );
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFixedHeightCards() {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: Column(
        children: [
          // Box 1: Record Speech
          Container(
            constraints: const BoxConstraints(
              minHeight: 120.0, // Fixed height card
            ),
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: InkWell(
                onTap: () => _handleRecordAudioTap(),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(40),
                        ),
                        child: Icon(
                          Icons.mic,
                          size: 48,
                          color: colorScheme.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Record Speech',
                              style: textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Record and analyze your speech',
                              style: textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Box 2: Upload Audio
          Container(
            constraints: const BoxConstraints(
              minHeight: 120, // Fixed height card
            ),
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: InkWell(
                onTap: () {
                  showModalBottomSheet(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.95,
                    ),
                    context: context,
                    isDismissible: false,
                    enableDrag: false,
                    isScrollControlled: true,
                    useSafeArea: true,
                    builder: (BuildContext context) {
                      return UploadAudioScreen();
                    });
                },
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(40),
                        ),
                        child: Icon(
                          Icons.upload_file,
                          size: 48,
                          color: colorScheme.onSecondaryContainer,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Upload Audio',
                              style: textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Analyze existing audio recordings',
                              style: textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleRecordAudioTap() async {
    try {
      final isGranted = await _permissionService.isPermissionGranted();
      
      if (isGranted) {
        _showRecordingScreen();
        return;
      }

      final result = await _permissionService.requestPermission();
      
      switch (result) {
        case PermissionResult.granted:
          _showRecordingScreen();
          break;
          
        case PermissionResult.denied:
          _showPermissionDeniedDialog();
          break;
          
        case PermissionResult.permanentlyDenied:
          _showPermissionPermanentlyDeniedDialog();
          break;
          
        case PermissionResult.error:
          _showPermissionErrorDialog();
          break;
      }
    } catch (e) {
      // Handle any unexpected errors
      _showPermissionErrorDialog();
    }
  }

  /// Show the recording screen
  void _showRecordingScreen() {
    showModalBottomSheet(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.95,
      ),
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (BuildContext context) {
        return RecordAudioScreen();
      },
    );
  }

  /// Show dialog when permission is denied
  void _showPermissionDeniedDialog() {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          icon: Icon(
            Icons.mic_off,
            color: colorScheme.error,
            size: 32,
          ),
          title: Text(
            'Microphone Permission Required',
            style: textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'To record audio for speech analysis, this app needs access to your device\'s microphone.',
                style: textTheme.bodyLarge,
              ),
              const SizedBox(height: 12),
              Text(
                'Please grant microphone permission and try again.',
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Try requesting permission again
                _handleRecordAudioTap();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
              ),
              child: const Text('Try Again'),
            ),
          ],
        );
      },
    );
  }

  /// Show dialog when permission is permanently denied
  void _showPermissionPermanentlyDeniedDialog() {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          icon: Icon(
            Icons.settings,
            color: colorScheme.primary,
            size: 32,
          ),
          title: Text(
            'Permission Required',
            style: textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Microphone access has been permanently denied.',
                style: textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ]
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                // Open app settings
                await _permissionService.openSettings();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
              ),
              child: const Text('Open Settings'),
            ),
          ],
        );
      },
    );
  }

  /// Show dialog when there's an error with permission handling
  void _showPermissionErrorDialog() {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          icon: Icon(
            Icons.error_outline,
            color: colorScheme.error,
            size: 32,
          ),
          title: Text(
            'Permission Error',
            style: textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'An error occurred while requesting microphone permission.',
                style: textTheme.bodyLarge,
              ),
              const SizedBox(height: 12),
              Text(
                'Please try again or check your device settings.',
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Try again
                _handleRecordAudioTap();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
              ),
              child: const Text('Try Again'),
            ),
          ],
        );
      },
    );
  }
}