// lib/ui/core/ui/settings/widgets/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:mobile_speech_recognition/ui/core/themes/theme_provider.dart';
import 'package:mobile_speech_recognition/services/logger_service.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _version = '';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      _version = packageInfo.version;
    });
  }

  @override
  Widget build(BuildContext context) {
    final _logger = LoggerService();
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Settings',
          style: TextStyle(
            color: colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        scrolledUnderElevation: 0.0,
        backgroundColor: colorScheme.surfaceBright,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            _logger.debug('Back button pressed in settings');
            Navigator.pop(context);
          },
        ),
      ),
      backgroundColor: colorScheme.surfaceBright,
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              // Theme Section
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Appearance',
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ListTile(
                        leading: Icon(
                          Icons.palette_outlined,
                          color: colorScheme.primary,
                        ),
                        title: const Text('Theme'),
                        subtitle: Consumer<ThemeProvider>(
                          builder: (context, themeProvider, child) {
                            return Text(themeProvider.themeDisplayName);
                          },
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          _logger.info('Theme selector opened');
                          _showThemeSelector(context);
                        },
                        contentPadding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 80), // Space for version text
            ],
          ),
          // Version text at bottom right
          Positioned(
            bottom: 16,
            right: 16,
            child: Text(
              'v$_version',
              style: textTheme.bodyLarge?.copyWith(
                color: colorScheme.onTertiaryContainer.withOpacity(1),
                fontWeight: FontWeight.bold
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showThemeSelector(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return const ThemeSelectionBottomSheet();
      },
    );
  }
}

class ThemeSelectionBottomSheet extends StatelessWidget {
  const ThemeSelectionBottomSheet({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final _logger = LoggerService();
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.onSurfaceVariant.withOpacity(0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Title
          Text(
            'Select Theme',
            style: textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),

          // Theme options
          Consumer<ThemeProvider>(
            builder: (context, themeProvider, child) {
              return Column(
                children: AppTheme.values.map((theme) {
                  final isSelected = themeProvider.currentTheme == theme;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    elevation: isSelected ? 2 : 0,
                    color: isSelected 
                        ? colorScheme.primaryContainer 
                        : colorScheme.surface,
                    child: ListTile(
                      title: Text(
                        ThemeProvider.getThemeDisplayName(theme),
                        style: textTheme.bodyLarge?.copyWith(
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          color: isSelected 
                              ? colorScheme.onPrimaryContainer 
                              : colorScheme.onSurface,
                        ),
                      ),
                      leading: _getThemeIcon(theme, colorScheme, isSelected),
                      trailing: isSelected
                          ? Icon(
                              Icons.check_circle,
                              color: colorScheme.primary,
                            )
                          : null,
                      onTap: () async {
                        final themeName = ThemeProvider.getThemeDisplayName(theme);
                        _logger.info('Theme changed to: $themeName');
                        
                        await themeProvider.setTheme(theme);
                        Navigator.pop(context);
                      },
                    ),
                  );
                }).toList(),
              );
            },
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _getThemeIcon(AppTheme theme, ColorScheme colorScheme, bool isSelected) {
    IconData iconData;
    Color iconColor;

    switch (theme) {
      case AppTheme.light:
      case AppTheme.lightMediumContrast:
      case AppTheme.lightHighContrast:
        iconData = Icons.light_mode;
        break;
      case AppTheme.dark:
      case AppTheme.darkMediumContrast:
      case AppTheme.darkHighContrast:
        iconData = Icons.dark_mode;
        break;
    }

    iconColor = isSelected 
        ? colorScheme.primary 
        : colorScheme.onSurfaceVariant;

    return Icon(iconData, color: iconColor);
  }
}