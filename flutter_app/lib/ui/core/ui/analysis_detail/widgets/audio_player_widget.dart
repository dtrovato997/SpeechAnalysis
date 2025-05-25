// lib/ui/core/ui/analysis_detail/widgets/audio_player_widget.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:mobile_speech_recognition/services/logger_service.dart';

class AudioPlayerWidget extends StatefulWidget {
  final String audioPath;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  const AudioPlayerWidget({
    Key? key,
    required this.audioPath,
    required this.colorScheme,
    required this.textTheme,
  }) : super(key: key);

  @override
  State<AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<AudioPlayerWidget> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final LoggerService _logger = LoggerService();
  
  StreamSubscription<PlayerState>? _playerStateSubscription;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration?>? _durationSubscription;
  StreamSubscription<ProcessingState>? _processingStateSubscription;
  
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _isLoading = true;
  bool _isCompleted = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _logger.info('AudioPlayerWidget initialized for file: ${widget.audioPath}');
    _initializeAudio();
  }

  @override
  void dispose() {
    _logger.debug('AudioPlayerWidget disposing');
    _playerStateSubscription?.cancel();
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _processingStateSubscription?.cancel();
    
    _audioPlayer.dispose();
    _logger.debug('AudioPlayer disposed successfully');
    super.dispose();
  }

  Future<void> _initializeAudio() async {
    try {
      _logger.debug('Starting audio initialization for: ${widget.audioPath}');
      
      // Check if file exists
      final file = File(widget.audioPath);
      if (!await file.exists()) {
        _logger.error('Audio file not found: ${widget.audioPath}');
        throw Exception('Audio file not found');
      }

      _logger.debug('Audio file exists, setting up listeners');

      _playerStateSubscription = _audioPlayer.playerStateStream.listen((state) {
        _logger.debug('Player state changed: playing=${state.playing}, processingState=${state.processingState}');
        if (mounted) {
          setState(() {
            _isPlaying = state.playing;
          });
        }
      });

      _positionSubscription = _audioPlayer.positionStream.listen((position) {
        if (mounted) {
          setState(() {
            _position = position;
          });
        }
      });

      _durationSubscription = _audioPlayer.durationStream.listen((duration) {
        if (duration != null) {
          _logger.debug('Audio duration loaded: ${_formatDuration(duration)}');
        }
        if (mounted) {
          setState(() {
            _duration = duration ?? Duration.zero;
          });
        }
      });

      _processingStateSubscription = _audioPlayer.processingStateStream.listen((state) {
        _logger.debug('Processing state changed: $state');
        if (state == ProcessingState.completed) {
          _logger.info('Audio playback completed');
          if (mounted) {
            setState(() {
              _isPlaying = false;
              _isCompleted = true;
            });
          }
        }
      });

      // Load the audio file
      _logger.debug('Loading audio file...');
      await _audioPlayer.setFilePath(widget.audioPath);
      
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      
      _logger.info('Audio player initialized successfully');
    } catch (e) {
      _logger.error('Failed to initialize audio player', e);
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _togglePlayback() async {
    try {
      if (_isPlaying) {
        _logger.debug('Pausing audio playback');
        await _audioPlayer.pause();
      } else {
        // If completed, reset first
        if (_isCompleted) {
          _logger.info('Audio completed, resetting and playing from start');
          await _resetAndPlay();
        } else {
          _logger.debug('Resuming audio playback');
          await _audioPlayer.play();
        }
      }
    } catch (e) {
      _logger.error('Error controlling audio playback', e);
      if (mounted) {
        setState(() {
          _error = "Error controlling playback";
        });
      }
    }
  }

  Future<void> _resetAndPlay() async {
    try {
      _logger.debug('Resetting audio to start and playing');
      await _audioPlayer.seek(Duration.zero);
      setState(() {
        _isCompleted = false;
        _position = Duration.zero;
      });
      await _audioPlayer.play();
      _logger.info('Audio reset and playback started');
    } catch (e) {
      _logger.error('Error resetting audio playback', e);
      if (mounted) {
        setState(() {
          _error = "Error resetting playback";
        });
      }
    }
  }

  Future<void> _seekTo(Duration position) async {
    try {
      _logger.debug('Seeking to position: ${_formatDuration(position)}');
      await _audioPlayer.seek(position);
      // If we seek after completion, clear the completed state
      if (_isCompleted) {
        _logger.debug('Cleared completion state after seeking');
        setState(() {
          _isCompleted = false;
        });
      }
    } catch (e) {
      _logger.warning('Error seeking audio position', e);
      // Handle seek error silently
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      color: widget.colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Audio recording',
              style: widget.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: widget.colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: Icon(
                      _isCompleted 
                          ? Icons.replay 
                          : (_isPlaying ? Icons.pause : Icons.play_arrow),
                      color: widget.colorScheme.onPrimary,
                    ),
                    onPressed: _isLoading ? null : _togglePlayback,
                  ),
                ),
                const SizedBox(width: 12),
                
                Expanded(
                  child: ProgressBar(
                    progress: _position,
                    total: _duration,
                    barHeight: 4.0,
                    baseBarColor: widget.colorScheme.secondaryContainer,
                    progressBarColor: widget.colorScheme.primary,
                    thumbColor: widget.colorScheme.primary,
                    timeLabelTextStyle: widget.textTheme.bodySmall,
                    onSeek: _isLoading ? null : (duration) {
                      _seekTo(duration);
                    },
                  ),
                ),
              ],
            ),
            
            if (_isLoading)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Row(
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: widget.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Loading audio...',
                      style: widget.textTheme.bodySmall?.copyWith(
                        color: widget.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 16,
                      color: widget.colorScheme.error,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Error loading audio',
                        style: widget.textTheme.bodySmall?.copyWith(
                          color: widget.colorScheme.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}