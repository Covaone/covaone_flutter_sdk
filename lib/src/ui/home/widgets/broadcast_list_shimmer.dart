import 'package:flutter/material.dart';
import '../../shared/shimmer_line.dart';

/// Shimmer placeholder shown while broadcasts are loading.
/// Repeats a thumbnail + three lines pattern 3 times.
class BroadcastListShimmer extends StatelessWidget {
  const BroadcastListShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        _ShimmerRow(),
        _ShimmerRow(),
        _ShimmerRow(),
      ],
    );
  }
}

class _ShimmerRow extends StatelessWidget {
  // ignore: unused_element
  const _ShimmerRow();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ShimmerBlock(width: 80, height: 80, borderRadius: 8),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 6),
                    ShimmerBlock(width: double.infinity, height: 14),
                    SizedBox(height: 8),
                    ShimmerBlock(width: 160, height: 12),
                    SizedBox(height: 8),
                    ShimmerBlock(width: 100, height: 11),
                  ],
                ),
              ),
            ],
          ),
        ),
        Divider(height: 1, indent: 16, endIndent: 16,
            color: Color(0xFFF0F0F0)),
      ],
    );
  }
}
