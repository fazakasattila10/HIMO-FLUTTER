import 'package:flutter/material.dart';
import 'package:flutter_opencv_bridge/app_colors.dart';

class ProgressBar extends StatelessWidget {
  final int activeCount;
  final int totalCount;
  final double height;

  const ProgressBar({
    super.key,
    required this.activeCount,
    this.totalCount = 3,
    this.height = 14,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(totalCount * 2 - 1, (index) {
        if (index.isOdd) {
          // spacer
          return const SizedBox(width: 2);
        }

        final i = index ~/ 2;
        final isActive = i < activeCount;

        return Expanded(
          child: Container(
            height: height,
            decoration: BoxDecoration(
              color: isActive ? AppColors.blue_light : Colors.transparent,
              borderRadius: BorderRadius.circular(4),
              border: isActive
                  ? null
                  : Border.all(
                color: AppColors.blue_light,
                width: 1,
              ),
            ),
          ),
        );
      }),
    );
  }
}
