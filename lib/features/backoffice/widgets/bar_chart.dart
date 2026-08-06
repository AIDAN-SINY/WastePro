import 'package:flutter/material.dart';

import '../theme.dart';

/// Simple animated bar chart (design's Chart.js cards), pure Flutter —
/// no chart dependency needed.
class BoBarChart extends StatelessWidget {
  const BoBarChart({
    super.key,
    required this.values,
    required this.labels,
    this.barColor,
    this.height = 130,
  });

  final List<double> values;
  final List<String> labels;
  final Color? barColor;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) return const SizedBox.shrink();
    final max = values.reduce((a, b) => a > b ? a : b).clamp(0.0001, double.infinity).toDouble();
    final barArea = height - 20; // room for labels
    final color = barColor ?? BackofficeTheme.green;

    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < values.length; i++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: values[i] / max * barArea),
                      duration: Duration(milliseconds: 550 + i * 70),
                      curve: Curves.easeOutCubic,
                      builder: (context, v, _) => AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        height: v.clamp(2, barArea),
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(5),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      labels[i],
                      style: BackofficeTheme.inter(
                        9,
                        color: BackofficeTheme.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
