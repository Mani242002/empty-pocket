import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/calculation/financial_calculator.dart';
import '../../../../core/domain/entities/category_constants.dart';
import '../../../../core/utilities/app_haptics.dart';
import '../../../../core/utilities/currency_formatter.dart';

class InteractiveDonutChart extends StatefulWidget {
  final List<CategorySpendingSummary> categories;
  final int? selectedIndex;
  final ValueChanged<int?>? onSliceSelected;

  const InteractiveDonutChart({
    super.key,
    required this.categories,
    this.selectedIndex,
    this.onSliceSelected,
  });

  @override
  State<InteractiveDonutChart> createState() => _InteractiveDonutChartState();
}

class _InteractiveDonutChartState extends State<InteractiveDonutChart>
    with SingleTickerProviderStateMixin {
  late int? _internalSelectedIndex;
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _internalSelectedIndex = widget.selectedIndex;
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    );
    _animationController.forward();
  }

  @override
  void didUpdateWidget(covariant InteractiveDonutChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedIndex != oldWidget.selectedIndex) {
      setState(() {
        _internalSelectedIndex = widget.selectedIndex;
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details, Size size) {
    if (widget.categories.isEmpty) return;

    final center = Offset(size.width / 2, size.height / 2);
    final touchPosition = details.localPosition;
    final dx = touchPosition.dx - center.dx;
    final dy = touchPosition.dy - center.dy;
    final distance = math.sqrt(dx * dx + dy * dy);

    final minDimension = math.min(size.width, size.height);
    final outerRadius = minDimension * 0.44;
    final innerRadius = outerRadius * 0.58;

    // Check if touch is inside the ring (with 12px tolerance)
    if (distance < innerRadius - 12 || distance > outerRadius + 16) {
      if (_internalSelectedIndex != null) {
        setState(() => _internalSelectedIndex = null);
        widget.onSliceSelected?.call(null);
        AppHaptics.buttonPress();
      }
      return;
    }

    // Calculate touch angle in radians, normalized starting from top (-pi / 2)
    var angle = math.atan2(dy, dx);
    // Convert angle so that 0 is at 12 o'clock (-pi/2) and goes clockwise [0, 2*pi]
    angle = (angle + math.pi / 2);
    if (angle < 0) {
      angle += 2 * math.pi;
    }

    final totalAmount = widget.categories.fold<double>(0.0, (sum, c) => sum + c.amount);
    if (totalAmount <= 0) return;

    double currentAngle = 0.0;
    int? tappedIndex;

    for (int i = 0; i < widget.categories.length; i++) {
      final sweepAngle = (widget.categories[i].amount / totalAmount) * 2 * math.pi;
      if (angle >= currentAngle && angle <= currentAngle + sweepAngle) {
        tappedIndex = i;
        break;
      }
      currentAngle += sweepAngle;
    }

    if (tappedIndex != null) {
      AppHaptics.selectionClick();
      final newIndex = (_internalSelectedIndex == tappedIndex) ? null : tappedIndex;
      setState(() => _internalSelectedIndex = newIndex);
      widget.onSliceSelected?.call(newIndex);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final financialColors = context.financialColors;

    if (widget.categories.isEmpty) {
      return const SizedBox.shrink();
    }

    final totalAmount = widget.categories.fold<double>(0.0, (sum, c) => sum + c.amount);

    final selectedCategory = (_internalSelectedIndex != null &&
            _internalSelectedIndex! >= 0 &&
            _internalSelectedIndex! < widget.categories.length)
        ? widget.categories[_internalSelectedIndex!]
        : null;

    final selectedColor = selectedCategory != null
        ? CategoryConstants.getColorForCategory(selectedCategory.category)
        : null;
    final selectedIcon = selectedCategory != null
        ? CategoryConstants.getIconForCategory(selectedCategory.category)
        : null;

    return LayoutBuilder(
      builder: (context, constraints) {
        final chartSize = math.min(constraints.maxWidth, 240.0);

        return Column(
          children: [
            Center(
              child: SizedBox(
                width: chartSize,
                height: chartSize,
                child: GestureDetector(
                  onTapDown: (details) => _handleTapDown(details, Size(chartSize, chartSize)),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Animated Donut Canvas
                      AnimatedBuilder(
                        animation: _animation,
                        builder: (context, child) {
                          return CustomPaint(
                            size: Size(chartSize, chartSize),
                            painter: _DonutChartPainter(
                              categories: widget.categories,
                              selectedIndex: _internalSelectedIndex,
                              progress: _animation.value,
                              isDark: isDark,
                              dividerColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                            ),
                          );
                        },
                      ),

                      // Center Content (Total or Selected Slice Details)
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        transitionBuilder: (child, anim) => FadeTransition(
                          opacity: anim,
                          child: ScaleTransition(scale: anim, child: child),
                        ),
                        child: selectedCategory != null
                            ? Column(
                                key: ValueKey('selected_${selectedCategory.category}'),
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: selectedColor?.withAlpha(isDark ? 50 : 30),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      selectedIcon ?? Icons.category_rounded,
                                      size: 18,
                                      color: selectedColor,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    selectedCategory.category,
                                    style: theme.textTheme.labelMedium?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      CurrencyFormatter.format(selectedCategory.amount),
                                      style: theme.textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -0.5,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '${selectedCategory.percentage.toStringAsFixed(1)}%',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: selectedColor,
                                    ),
                                  ),
                                ],
                              )
                            : Column(
                                key: const ValueKey('total_center'),
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'TOTAL SPENT',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.9,
                                      color: financialColors.textMuted,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      CurrencyFormatter.format(totalAmount),
                                      style: theme.textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -0.5,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${widget.categories.length} Categories',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w600,
                                      color: financialColors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _internalSelectedIndex == null
                  ? 'Tap a slice to inspect category'
                  : 'Tap again to reset view',
              style: TextStyle(
                fontSize: 11,
                color: financialColors.textMuted,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _DonutChartPainter extends CustomPainter {
  final List<CategorySpendingSummary> categories;
  final int? selectedIndex;
  final double progress;
  final bool isDark;
  final Color dividerColor;

  _DonutChartPainter({
    required this.categories,
    required this.selectedIndex,
    required this.progress,
    required this.isDark,
    required this.dividerColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (categories.isEmpty) return;

    final center = Offset(size.width / 2, size.height / 2);
    final minDimension = math.min(size.width, size.height);
    final baseOuterRadius = minDimension * 0.44;
    final baseInnerRadius = baseOuterRadius * 0.58;
    final strokeWidth = baseOuterRadius - baseInnerRadius;

    final totalAmount = categories.fold<double>(0.0, (sum, c) => sum + c.amount);
    if (totalAmount <= 0) return;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.butt;

    double currentAngle = -math.pi / 2;
    final maxTotalSweep = 2 * math.pi * progress;

    for (int i = 0; i < categories.length; i++) {
      final category = categories[i];
      final rawSweep = (category.amount / totalAmount) * 2 * math.pi;
      final sweepAngle = math.min(rawSweep, math.max(0.0, maxTotalSweep - (currentAngle - (-math.pi / 2))));

      if (sweepAngle <= 0) break;

      final isSelected = (selectedIndex == i);
      final color = CategoryConstants.getColorForCategory(category.category);

      final currentStrokeWidth = isSelected ? strokeWidth + 6 : strokeWidth;
      final currentRadius = isSelected
          ? (baseInnerRadius + baseOuterRadius) / 2 + 2
          : (baseInnerRadius + baseOuterRadius) / 2;

      paint.strokeWidth = currentStrokeWidth;
      paint.color = color;

      // Draw active slice
      final rect = Rect.fromCircle(center: center, radius: currentRadius);
      canvas.drawArc(rect, currentAngle, sweepAngle, false, paint);

      // Draw subtle shadow for selected slice
      if (isSelected) {
        final shadowPaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = currentStrokeWidth + 4
          ..color = color.withAlpha(isDark ? 60 : 35)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
        canvas.drawArc(rect, currentAngle, sweepAngle, false, shadowPaint);
      }

      currentAngle += sweepAngle;
    }

    // Slices separation dividers
    if (categories.length > 1 && progress > 0.8) {
      final dividerPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = dividerColor;

      double divAngle = -math.pi / 2;
      for (int i = 0; i < categories.length; i++) {
        final rawSweep = (categories[i].amount / totalAmount) * 2 * math.pi;
        final p1 = Offset(
          center.dx + (baseInnerRadius - 2) * math.cos(divAngle),
          center.dy + (baseInnerRadius - 2) * math.sin(divAngle),
        );
        final p2 = Offset(
          center.dx + (baseOuterRadius + 4) * math.cos(divAngle),
          center.dy + (baseOuterRadius + 4) * math.sin(divAngle),
        );
        canvas.drawLine(p1, p2, dividerPaint);
        divAngle += rawSweep;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) {
    return oldDelegate.categories != categories ||
        oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.progress != progress ||
        oldDelegate.isDark != isDark ||
        oldDelegate.dividerColor != dividerColor;
  }
}
