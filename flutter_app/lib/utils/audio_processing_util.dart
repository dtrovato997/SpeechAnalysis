import 'dart:math';
import 'dart:typed_data';

class Complex {
  final double real;
  final double imaginary;

  const Complex(this.real, this.imaginary);

  Complex operator +(Complex other) {
    return Complex(real + other.real, imaginary + other.imaginary);
  }

  Complex operator -(Complex other) {
    return Complex(real - other.real, imaginary - other.imaginary);
  }

  Complex operator *(Complex other) {
    return Complex(
      real * other.real - imaginary * other.imaginary,
      real * other.imaginary + imaginary * other.real,
    );
  }

  double get magnitude => sqrt(real * real + imaginary * imaginary);
  double get magnitudeSquared => real * real + imaginary * imaginary;

  @override
  String toString() => '($real, ${imaginary}i)';
}

class MelSpectrogramComputer {
  // Whisper constants
  static const int sampleRate = 16000;
  static const int nFft = 400;
  static const int hopLength = 160;
  static const int nMel = 80;

  // Cached values for performance
  static List<double>? _hannWindow;
  static List<Complex>? _twiddleFactors;
  static List<List<double>>? _melFilterBank;

  /// Initialize cached values
  static void _initializeCache() {
    if (_hannWindow == null) {
      _hannWindow = _generateHannWindow(nFft);
      _twiddleFactors = _generateTwiddleFactors(nFft);
      _melFilterBank = _generateMelFilterBank(nMel, nFft ~/ 2 + 1, sampleRate);
    }
  }

  /// Generate Hann window
  static List<double> _generateHannWindow(int size) {
    return List.generate(size, (i) {
      return 0.5 * (1.0 - cos(2.0 * pi * i / size));
    });
  }

  /// Generate twiddle factors for FFT
  static List<Complex> _generateTwiddleFactors(int size) {
    return List.generate(size, (i) {
      final angle = -2.0 * pi * i / size;
      return Complex(cos(angle), sin(angle));
    });
  }

  /// FFT implementation using Cooley-Tukey algorithm
  static List<Complex> _fft(List<double> input) {
    final n = input.length;
    if (n <= 1) {
      return [Complex(input.isNotEmpty ? input[0] : 0.0, 0.0)];
    }

    // Ensure n is a power of 2
    final nextPowerOf2 = _nextPowerOfTwo(n);
    final paddedInput = List<double>.filled(nextPowerOf2, 0.0);
    for (int i = 0; i < n; i++) {
      paddedInput[i] = input[i];
    }

    return _fftRecursive(paddedInput.map((x) => Complex(x, 0.0)).toList());
  }

  /// Recursive FFT implementation
  static List<Complex> _fftRecursive(List<Complex> input) {
    final n = input.length;
    if (n <= 1) return input;

    // Divide
    final even = <Complex>[];
    final odd = <Complex>[];
    for (int i = 0; i < n; i++) {
      if (i % 2 == 0) {
        even.add(input[i]);
      } else {
        odd.add(input[i]);
      }
    }

    // Conquer
    final evenFft = _fftRecursive(even);
    final oddFft = _fftRecursive(odd);

    // Combine
    final result = List<Complex>.filled(n, const Complex(0, 0));
    for (int k = 0; k < n ~/ 2; k++) {
      final angle = -2.0 * pi * k / n;
      final twiddle = Complex(cos(angle), sin(angle));
      final t = twiddle * oddFft[k];

      result[k] = evenFft[k] + t;
      result[k + n ~/ 2] = evenFft[k] - t;
    }

    return result;
  }

  /// Find next power of 2
  static int _nextPowerOfTwo(int n) {
    int power = 1;
    while (power < n) {
      power *= 2;
    }
    return power;
  }

  /// Convert Hz to Mel scale
  static double _hzToMel(double hz) {
    return 2595.0 * log(1.0 + hz / 700.0) / ln10;
  }

  /// Convert Mel scale to Hz
  static double _melToHz(double mel) {
    return 700.0 * (pow(10.0, mel / 2595.0) - 1.0);
  }

  /// Generate mel filter bank
  static List<List<double>> _generateMelFilterBank(int nMel, int nFft, int sampleRate) {
    final fmax = sampleRate / 2.0;
    final melMin = _hzToMel(0);
    final melMax = _hzToMel(fmax);

    // Create equally spaced points in mel space
    final melPoints = List.generate(nMel + 2, (i) {
      return melMin + (melMax - melMin) * i / (nMel + 1);
    });

    // Convert back to Hz
    final hzPoints = melPoints.map(_melToHz).toList();

    // Convert to FFT bin numbers
    final binPoints = hzPoints.map((hz) {
      return (hz * nFft / (sampleRate / 2.0)).floor();
    }).toList();

    // Create triangular filters
    final filters = List.generate(nMel, (m) {
      final filter = List<double>.filled(nFft, 0.0);
      final left = binPoints[m];
      final center = binPoints[m + 1];
      final right = binPoints[m + 2];

      for (int k = left; k <= right && k < nFft; k++) {
        if (k >= left && k <= center && center != left) {
          filter[k] = (k - left) / (center - left);
        } else if (k > center && k <= right && right != center) {
          filter[k] = (right - k) / (right - center);
        }
      }

      return filter;
    });

    return filters;
  }

  /// Apply mel filters to power spectrum
  static List<double> _applyMelFilters(List<double> powerSpectrum, List<List<double>> melFilters) {
    return melFilters.map((filter) {
      double sum = 0.0;
      for (int i = 0; i < min(filter.length, powerSpectrum.length); i++) {
        sum += filter[i] * powerSpectrum[i];
      }
      return sum;
    }).toList();
  }

  /// Add reflection padding to signal
  static List<double> _addReflectionPadding(List<double> signal, int padSize) {
    final padded = <double>[];

    // Left padding (reflect)
    for (int i = padSize - 1; i >= 0; i--) {
      padded.add(signal[min(i, signal.length - 1)]);
    }

    // Original signal
    padded.addAll(signal);

    // Right padding (reflect)
    for (int i = 0; i < padSize; i++) {
      final index = signal.length - 1 - i;
      padded.add(signal[max(0, index)]);
    }

    return padded;
  }

  /// Compute mel spectrogram from audio samples
  static MelSpectrogramResult computeMelSpectrogram(List<double> samples) {
    _initializeCache();

    final frameSize = nFft;
    final frameStep = hopLength;
    final padSize = frameSize ~/ 2;

    // Add reflection padding
    final paddedSamples = _addReflectionPadding(samples, padSize);

    // Calculate number of frames
    final nFrames = (paddedSamples.length - frameSize) ~/ frameStep + 1;

    // Result matrix: [nMel, nFrames]
    final melSpectrogram = List.generate(nMel, (_) => List<double>.filled(nFrames, 0.0));

    // Process each frame
    for (int frameIdx = 0; frameIdx < nFrames; frameIdx++) {
      final frameStart = frameIdx * frameStep;
      final frameEnd = frameStart + frameSize;

      // Extract frame and apply window
      final frame = List<double>.generate(frameSize, (i) {
        final sampleIdx = frameStart + i;
        final sample = sampleIdx < paddedSamples.length ? paddedSamples[sampleIdx] : 0.0;
        return sample * _hannWindow![i];
      });

      // Compute FFT
      final fftResult = _fft(frame);

      // Compute power spectrum (magnitude squared)
      final powerSpectrum = fftResult.take(frameSize ~/ 2 + 1).map((c) => c.magnitudeSquared).toList();

      // Apply mel filters
      final melValues = _applyMelFilters(powerSpectrum, _melFilterBank!);

      // Convert to log scale and store
      for (int melIdx = 0; melIdx < nMel; melIdx++) {
        final logValue = log(max(melValues[melIdx], 1e-10)) / ln10;
        melSpectrogram[melIdx][frameIdx] = logValue;
      }
    }

    // Normalize (same as whisper.cpp)
    double maxVal = double.negativeInfinity;
    for (int i = 0; i < nMel; i++) {
      for (int j = 0; j < nFrames; j++) {
        if (melSpectrogram[i][j] > maxVal) {
          maxVal = melSpectrogram[i][j];
        }
      }
    }

    maxVal -= 8.0;

    // Apply normalization
    for (int i = 0; i < nMel; i++) {
      for (int j = 0; j < nFrames; j++) {
        if (melSpectrogram[i][j] < maxVal) {
          melSpectrogram[i][j] = maxVal;
        }
        melSpectrogram[i][j] = (melSpectrogram[i][j] + 4.0) / 4.0;
      }
    }

    return MelSpectrogramResult(melSpectrogram, nMel, nFrames);
  }

  /// Prepare audio for Whisper (resample, pad/truncate to 30s, normalize)
  static List<double> padAudioForWhisper(List<double> samples) {
    const targetSampleRate = 16000;
    const targetDuration = 30; // seconds
    const targetSamples = targetSampleRate * targetDuration;


    // Pad or truncate to exactly 30 seconds
    if (samples.length < targetSamples) {
      // Pad with zeros
      samples.addAll(List.filled(targetSamples - samples.length, 0.0));
    } else if (samples.length > targetSamples) {
      // Truncate
      samples = samples.take(targetSamples).toList();
    }

    // Normalize to [-1, 1]
    return _normalizeAudio(samples);
  }

  /// Normalize audio to [-1, 1] range
  static List<double> _normalizeAudio(List<double> samples) {
    if (samples.isEmpty) return samples;

    final maxAbs = samples.map((s) => s.abs()).reduce(max);
    if (maxAbs == 0.0) return samples;

    final scale = 1.0 / maxAbs;
    return samples.map((s) => s * scale).toList();
  }

  /// Convert mel spectrogram to flat list (for ONNX input)
  static Float32List melSpectrogramToFloat32List(MelSpectrogramResult result) {
    final flatList = <double>[];
    for (int i = 0; i < result.nMel; i++) {
      flatList.addAll(result.data[i]);
    }
    return Float32List.fromList(flatList);
  }
}

class MelSpectrogramResult {
  final List<List<double>> data; // [nMel, nFrames]
  final int nMel;
  final int nFrames;

  MelSpectrogramResult(this.data, this.nMel, this.nFrames);

  /// Get as a flat Float32List for ONNX input
  Float32List toFloat32List() {
    return MelSpectrogramComputer.melSpectrogramToFloat32List(this);
  }

  @override
  String toString() {
    return 'MelSpectrogramResult(nMel: $nMel, nFrames: $nFrames)';
  }
}

// Helper class for easy usage
class WhisperMelSpectrogram {
  /// Compute mel spectrogram for language detection, it expects PCM samples at 16kHz.
  static MelSpectrogramResult forLanguageDetection(List<double> pcmSamples) {
    // pad the audio to 30 seconds and normalize
    final preparedSamples = MelSpectrogramComputer.padAudioForWhisper(pcmSamples);
    
    // Compute mel spectrogram
    return MelSpectrogramComputer.computeMelSpectrogram(preparedSamples);
  }

}