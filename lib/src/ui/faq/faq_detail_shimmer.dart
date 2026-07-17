import 'package:flutter/material.dart';
import '../shared/shimmer_line.dart';

/// Shimmer shown while the FAQ detail "loads" (1.5 s simulated delay).
class FaqDetailShimmer extends StatelessWidget {
  const FaqDetailShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ShimmerBlock(width: w, height: 200, borderRadius: 0),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ShimmerBlock(width: w * 0.65, height: 20),
              const SizedBox(height: 12),
              ShimmerBlock(width: w * 0.9, height: 14),
              const SizedBox(height: 8),
              ShimmerBlock(width: w * 0.8, height: 14),
              const SizedBox(height: 8),
              ShimmerBlock(width: w * 0.55, height: 14),
            ],
          ),
        ),
      ],
    );
  }
}
