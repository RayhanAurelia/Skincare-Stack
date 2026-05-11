import 'dart:io';
import 'package:flutter/material.dart';
import '../../services/skin_ai_service.dart';

class SkinAnalysisResultPage extends StatelessWidget {
  final SkinAnalysisResult result;
  final File imageFile;

  const SkinAnalysisResultPage({
    super.key,
    required this.result,
    required this.imageFile,
  });

  Color get _skinColor {
    switch (result.skinType.toLowerCase()) {
      case 'oily':
        return const Color(0xFF1E88E5);
      case 'dry':
        return const Color(0xFFEF6C00);
      case 'normal':
        return const Color(0xFF2E7D32);
      default:
        return const Color(0xFF3F51B5);
    }
  }

  String _getLabelDisplay(String label) {
    switch (label.toLowerCase()) {
      case 'oily':
        return 'Berminyak';
      case 'dry':
        return 'Kering';
      case 'normal':
        return 'Normal';
      default:
        return label[0].toUpperCase() + label.substring(1);
    }
  }

  Color _getLabelColor(String label) {
    switch (label.toLowerCase()) {
      case 'oily':
        return const Color(0xFF1E88E5);
      case 'dry':
        return const Color(0xFFEF6C00);
      case 'normal':
        return const Color(0xFF2E7D32);
      default:
        return const Color(0xFF3F51B5);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(context),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  _buildSkinTypeCard(),
                  const SizedBox(height: 16),
                  _buildProbabilityCard(),
                  const SizedBox(height: 16),
                  _buildRecommendationsCard(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 300,
      pinned: true,
      stretch: true,
      backgroundColor: const Color(0xFF3F51B5),
      leading: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black26,
          shape: BoxShape.circle,
        ),
        child: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [StretchMode.zoomBackground],
        background: Stack(
          fit: StackFit.expand,
          children: [
            Image.file(imageFile, fit: BoxFit.cover),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.0, 0.5, 1.0],
                  colors: [
                    Colors.black.withValues(alpha:0.2),
                    Colors.transparent,
                    Colors.black.withValues(alpha:0.75),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: 20,
              left: 20,
              right: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Hasil Analisis AI',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        result.emoji,
                        style: const TextStyle(fontSize: 30),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          result.displayName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            height: 1.1,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: _skinColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${(result.confidence * 100).toStringAsFixed(1)}% Confidence',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.3,
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

  Widget _buildSkinTypeCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _skinColor.withValues(alpha:0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _skinColor.withValues(alpha:0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _skinColor.withValues(alpha:0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.info_outline, color: _skinColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  result.displayName,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: _skinColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  result.description,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.black87,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProbabilityCard() {
    final sortedEntries = result.probabilities.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bar_chart_rounded,
                  color: Color(0xFF3F51B5), size: 22),
              const SizedBox(width: 8),
              const Text(
                'Distribusi Tipe Kulit',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ...sortedEntries.map((entry) =>
              _buildProbBar(entry.key, entry.value)),
        ],
      ),
    );
  }

  Widget _buildProbBar(String label, double value) {
    final color = _getLabelColor(label);
    final displayLabel = _getLabelDisplay(label);
    final isTop = label.toLowerCase() == result.skinType.toLowerCase();

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  if (isTop)
                    Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'TERDETEKSI',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  Text(
                    displayLabel,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight:
                          isTop ? FontWeight.bold : FontWeight.normal,
                      color: isTop ? color : Colors.black87,
                    ),
                  ),
                ],
              ),
              Text(
                '${(value * 100).toStringAsFixed(1)}%',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: value,
              minHeight: isTop ? 10 : 7,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(
                isTop ? color : color.withValues(alpha:0.4),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendationsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.tips_and_updates_outlined,
                  color: Color(0xFF3F51B5), size: 22),
              const SizedBox(width: 8),
              const Text(
                'Rekomendasi Perawatan',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Disesuaikan untuk ${result.displayName.toLowerCase()}',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          ...result.recommendations.asMap().entries.map(
                (e) => _buildRecommendationItem(e.key + 1, e.value),
              ),
        ],
      ),
    );
  }

  Widget _buildRecommendationItem(int index, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: _skinColor,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$index',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _skinColor.withValues(alpha:0.05),
                borderRadius: BorderRadius.circular(10),
                border:
                    Border.all(color: _skinColor.withValues(alpha:0.15)),
              ),
              child: Text(
                text,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: Colors.black87,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
