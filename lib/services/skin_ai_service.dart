import 'dart:io';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

class SkinAIService {
  static final SkinAIService _instance = SkinAIService._internal();
  factory SkinAIService() => _instance;
  SkinAIService._internal();

  Interpreter? _interpreter;
  List<String> _labels = [];
  bool _isInitialized = false;

  static const int _inputSize = 224;
  static const String _modelAsset = 'assets/models/skin_classifier.tflite';
  static const String _labelsAsset = 'assets/models/skin_labels.txt';

  bool get isModelAvailable => _isInitialized;

  Future<void> initialize() async {
    if (_isInitialized) return;
    _interpreter = await Interpreter.fromAsset(_modelAsset);
    final raw = await rootBundle.loadString(_labelsAsset);
    _labels = raw.trim().split('\n').where((l) => l.trim().isNotEmpty).toList();
    _isInitialized = true;
  }

  Future<SkinAnalysisResult> analyze(File imageFile) async {
    await initialize();

    final bytes = await imageFile.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) throw Exception('Gambar tidak dapat dibaca');
    final resized = img.copyResize(decoded, width: _inputSize, height: _inputSize);

    // Build input tensor [1, 224, 224, 3] normalized to [0, 1]
    final input = [
      List.generate(_inputSize, (y) => List.generate(_inputSize, (x) {
        final pixel = resized.getPixel(x, y);
        return [
          pixel.r.toDouble() / 255.0,
          pixel.g.toDouble() / 255.0,
          pixel.b.toDouble() / 255.0,
        ];
      }))
    ];

    // Output tensor [1, numClasses]
    final output = [List.filled(_labels.length, 0.0)];
    _interpreter!.run(input, output);

    final probs = List<double>.from(output[0]);
    int maxIdx = 0;
    for (int i = 1; i < probs.length; i++) {
      if (probs[i] > probs[maxIdx]) maxIdx = i;
    }

    return SkinAnalysisResult(
      skinType: _labels[maxIdx],
      confidence: probs[maxIdx],
      probabilities: Map.fromIterables(_labels, probs),
    );
  }

  void dispose() {
    _interpreter?.close();
    _isInitialized = false;
  }
}

class SkinAnalysisResult {
  final String skinType;
  final double confidence;
  final Map<String, double> probabilities;

  const SkinAnalysisResult({
    required this.skinType,
    required this.confidence,
    required this.probabilities,
  });

  String get displayName {
    switch (skinType.toLowerCase()) {
      case 'oily':
        return 'Kulit Berminyak';
      case 'dry':
        return 'Kulit Kering';
      case 'normal':
        return 'Kulit Normal';
      default:
        return skinType[0].toUpperCase() + skinType.substring(1);
    }
  }

  String get emoji {
    switch (skinType.toLowerCase()) {
      case 'oily':
        return '💧';
      case 'dry':
        return '🌵';
      case 'normal':
        return '✨';
      default:
        return '🔍';
    }
  }

  String get description {
    switch (skinType.toLowerCase()) {
      case 'oily':
        return 'Kulit kamu cenderung memproduksi sebum berlebih, terutama di area T-zone. Pilih produk yang oil-free dan non-comedogenic.';
      case 'dry':
        return 'Kulit kamu membutuhkan lebih banyak hidrasi. Fokus pada produk yang melembapkan dan menjaga skin barrier tetap sehat.';
      case 'normal':
        return 'Kulit kamu dalam kondisi seimbang. Pertahankan rutinitas yang sudah ada dan jaga konsistensi perawatan.';
      default:
        return 'Perhatikan kondisi kulit secara rutin dan sesuaikan produk dengan kebutuhan kulitmu.';
    }
  }

  List<String> get recommendations {
    switch (skinType.toLowerCase()) {
      case 'oily':
        return [
          'Gunakan foaming cleanser untuk mengangkat minyak berlebih',
          'Pilih toner dengan niacinamide atau salicylic acid',
          'Gunakan moisturizer bertekstur gel (oil-free)',
          'Aplikasikan clay mask 1–2× seminggu',
          'Pilih sunscreen bertekstur fluid atau gel, bukan cream',
        ];
      case 'dry':
        return [
          'Gunakan cream atau milk cleanser yang lembut',
          'Tambahkan serum hyaluronic acid setelah toner',
          'Pilih moisturizer kaya dengan ceramide atau shea butter',
          'Hindari produk dengan kandungan alkohol tinggi',
          'Mandi dengan air hangat, bukan air panas — mengurangi kelembapan kulit',
        ];
      case 'normal':
        return [
          'Pertahankan rutinitas skincare yang sudah ada',
          'Gunakan gentle cleanser dua kali sehari',
          'Moisturizer ringan sudah cukup untuk menjaga kelembapan',
          'Exfoliate 1–2× seminggu untuk kulit lebih cerah',
          'Selalu pakai sunscreen minimal SPF 30 setiap pagi',
        ];
      default:
        return [
          'Gunakan produk yang sesuai dengan kondisi kulitmu',
          'Konsultasikan dengan dermatologis untuk saran lebih lanjut',
        ];
    }
  }
}
