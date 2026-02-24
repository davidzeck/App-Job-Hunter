import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:job_scout/core/theme/app_theme.dart';

// ─── Base shimmer box ──────────────────────────────────────────

class SkeletonBox extends StatelessWidget {
  final double height;
  final double? width;
  final double borderRadius;

  const SkeletonBox({
    super.key,
    required this.height,
    this.width,
    this.borderRadius = 6,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: height,
      width: width ?? double.infinity,
      decoration: BoxDecoration(
        color: isDark ? AppColors.mutedDark : const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    )
        .animate(onPlay: (c) => c.repeat())
        .shimmer(
          duration: 1200.ms,
          color: isDark ? Colors.white10 : Colors.white60,
        );
  }
}

// ─── Job card skeleton ─────────────────────────────────────────

/// Mimics the layout of [JobCard] while data is loading.
class SkeletonJobCard extends StatelessWidget {
  const SkeletonJobCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Company avatar placeholder
            const SkeletonBox(height: 44, width: 44, borderRadius: 10),
            const SizedBox(width: 12),

            // Job info column
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  SkeletonBox(height: 14),               // title
                  SizedBox(height: 6),
                  SkeletonBox(height: 12, width: 130),   // company
                  SizedBox(height: 10),
                  SkeletonBox(height: 12, width: 100),   // location
                  SizedBox(height: 10),
                  Row(
                    children: [
                      SkeletonBox(height: 22, width: 60, borderRadius: 6), // chip
                      SizedBox(width: 8),
                      SkeletonBox(height: 22, width: 60, borderRadius: 6), // chip
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),
            const SkeletonBox(height: 11, width: 36), // time ago
          ],
        ),
      ),
    );
  }
}

// ─── Alert row skeleton ────────────────────────────────────────

/// Mimics the layout of the alert list item while data is loading.
class SkeletonAlertRow extends StatelessWidget {
  const SkeletonAlertRow({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Unread dot placeholder
          Padding(
            padding: const EdgeInsets.only(top: 5, right: 18),
            child: SkeletonBox(height: 8, width: 8, borderRadius: 4),
          ),

          // Content column
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                SkeletonBox(height: 14),            // job title
                SizedBox(height: 6),
                SkeletonBox(height: 12, width: 180), // company · location
                SizedBox(height: 6),
                SkeletonBox(height: 11, width: 60),  // time ago
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Stat card skeleton ────────────────────────────────────────

/// Mimics the layout of [StatCard] while data is loading.
class SkeletonStatCard extends StatelessWidget {
  const SkeletonStatCard({super.key});

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SkeletonBox(height: 36, width: 36, borderRadius: 8), // icon
            SizedBox(height: 12),
            SkeletonBox(height: 22, width: 56),  // value
            SizedBox(height: 6),
            SkeletonBox(height: 12, width: 80),  // label
          ],
        ),
      ),
    );
  }
}

// ─── Company card skeleton ─────────────────────────────────────

/// Mimics the layout of [_CompanyCard] while data is loading.
class SkeletonCompanyCard extends StatelessWidget {
  const SkeletonCompanyCard({super.key});

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SkeletonBox(height: 48, width: 48, borderRadius: 12), // logo
            SizedBox(height: 12),
            SkeletonBox(height: 14, width: 100),  // name
            SizedBox(height: 8),
            SkeletonBox(height: 12),               // description line 1
            SizedBox(height: 4),
            SkeletonBox(height: 12, width: 80),   // description line 2
            Spacer(),
            SkeletonBox(height: 24, width: 64, borderRadius: 20), // jobs badge
          ],
        ),
      ),
    );
  }
}

// ─── Mini alert card skeleton ──────────────────────────────────

/// Mimics the layout of the horizontal mini-alert card on the home screen.
class SkeletonMiniAlert extends StatelessWidget {
  const SkeletonMiniAlert({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: const Card(
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              SkeletonBox(height: 14),             // job title
              SizedBox(height: 6),
              SkeletonBox(height: 12, width: 160), // company · location
              Spacer(),
              SkeletonBox(height: 12, width: 50),  // bookmark chip area
            ],
          ),
        ),
      ),
    );
  }
}
