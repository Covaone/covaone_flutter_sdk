import 'package:flutter/material.dart';

import '../shared/shimmer_line.dart';

/// Full-width shimmer shown while a broadcast detail is loading.
class BroadcastDetailShimmer extends StatelessWidget {
  const BroadcastDetailShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    return Container(
      color: const Color(0xFFF4F5F7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShimmerBlock(width: w, height: 160, borderRadius: 0),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerBlock(width: w * 0.75, height: 24, borderRadius: 8),
                const SizedBox(height: 14),
                const Row(
                  children: [
                    ShimmerBlock(width: 96, height: 28, borderRadius: 20),
                    SizedBox(width: 8),
                    ShimmerBlock(width: 110, height: 28, borderRadius: 20),
                  ],
                ),
                const SizedBox(height: 18),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ShimmerBlock(width: w * 0.9, height: 14, borderRadius: 6),
                      const SizedBox(height: 10),
                      ShimmerBlock(
                          width: w * 0.82, height: 14, borderRadius: 6),
                      const SizedBox(height: 10),
                      ShimmerBlock(width: w * 0.7, height: 14, borderRadius: 6),
                      const SizedBox(height: 16),
                      ShimmerBlock(
                          width: w * 0.55, height: 16, borderRadius: 6),
                      const SizedBox(height: 10),
                      ShimmerBlock(
                          width: w * 0.88, height: 14, borderRadius: 6),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
