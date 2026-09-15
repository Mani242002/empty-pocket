import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/domain/entities/reports_entity.dart';
import '../../../../core/utilities/app_haptics.dart';
import '../../../../core/utilities/currency_formatter.dart';

class CashflowPoint {
  final DateTime month;
  final double income;
  final double expense;
  final double net;
  final bool isForecast;

  const CashflowPoint({
    required this.month,
    required this.income,
    required this.expense,
    required this.net,
    required this.isForecast,
  });
}

class InteractiveCashflowLineChart extends StatefulWidget {
  final List<MonthlyTrendData> trends;
  final List<CashFlowForecastItem> forecast;

  const InteractiveCashflowLineChart({
    super.key,
    required this.trends,
    required this.forecast,
  });

  @override
  State<InteractiveCashflowLineChart> createState() => _InteractiveCashflowLineChartState();
}

class _InteractiveCashflowLineChartState extends State<InteractiveCashflowLineChart> {
  int? _selectedIndex;

  List<CashflowPoint> _buildPoints() {
    final points = <CashflowPoint>[];

    // Add historical trends
    for (final t in widget.trends) {
      points.add(CashflowPoint(
        month: t.month,
        income: t.totalIncome,
        expense: t.totalExpense,
        net: t.netSavings,
        isForecast: false,
      ));
    }

    // Add forecast points
    for (final f in widget.forecast) {
      points.add(CashflowPoint(
        month: f.month,
        income: f.projectedIncome,
        expense: f.projectedFixedExpenses,
        net: f.projectedNetCash,
        isForecast: true,
      ));
    }

    return points;
  }

  void _handleTouch(Offset localPosition, double chartWidth, int pointsCount) {
    if (pointsCount <= 1) return;

    final stepX = chartWidth / (pointsCount - 1);
    final rawIndex = (localPosition.dx / stepX).round().clamp(0, pointsCount - 1);

    if (_selectedIndex != rawIndex) {
      AppHaptics.selectionClick();
      setState(() {
        _selectedIndex = rawIndex;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final financialColors = context.financialColors;

    final points = _buildPoints();

    if (points.isEmpty || points.every((p) => p.income == 0 && p.expense == 0)) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Text(
            'No transaction history to display cashflow curves',
            style: TextStyle(color: financialColors.textMuted),
          ),
        ),
      );
    }

    // Default to the last historical point or last point if not touching
    final activeIndex = _selectedIndex ?? (points.indexWhere((p) => p.isForecast) != -1
        ? math.max(0, points.indexWhere((p) => p.isForecast) - 1)
        : points.length - 1);
    final activePoint = points[activeIndex.clamp(0, points.length - 1)];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Touch Scrubber Inspector Card
        Container(
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: activePoint.isForecast
                  ? AppColors.primaryTeal.withAlpha(isDark ? 80 : 50)
                  : financialColors.cardBorder,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          activePoint.isForecast ? Icons.auto_awesome_rounded : Icons.event_note_rounded,
                          size: 15,
                          color: activePoint.isForecast ? AppColors.primaryTeal : financialColors.textMuted,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            DateFormat('MMMM yyyy').format(activePoint.month),
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: activePoint.isForecast
                          ? AppColors.primaryTeal.withAlpha(isDark ? 45 : 25)
                          : financialColors.income.withAlpha(isDark ? 40 : 20),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      activePoint.isForecast ? '3-Mo Projection' : 'Actual Recorded',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: activePoint.isForecast ? AppColors.primaryTeal : financialColors.income,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('INCOME', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: financialColors.textMuted)),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '+${CurrencyFormatter.format(activePoint.income)}',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: financialColors.income),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('EXPENSE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: financialColors.textMuted)),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '-${CurrencyFormatter.format(activePoint.expense)}',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: financialColors.expense),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('NET CASH', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: financialColors.textMuted)),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            CurrencyFormatter.format(activePoint.net),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: activePoint.net >= 0 ? financialColors.income : financialColors.expense,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Interactive Chart Area
        LayoutBuilder(
          builder: (context, constraints) {
            final chartWidth = constraints.maxWidth;
            const chartHeight = 175.0;

            return GestureDetector(
              onHorizontalDragUpdate: (details) {
                _handleTouch(details.localPosition, chartWidth, points.length);
              },
              onTapDown: (details) {
                _handleTouch(details.localPosition, chartWidth, points.length);
              },
              child: CustomPaint(
                size: Size(chartWidth, chartHeight),
                painter: _BezierCashflowPainter(
                  points: points,
                  selectedIndex: activeIndex,
                  isDark: isDark,
                  financialColors: financialColors,
                ),
              ),
            );
          },
        ),

        const SizedBox(height: 8),

        // Scrubber hint & Legend
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    Container(width: 8, height: 8, decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.income)),
                    const SizedBox(width: 4),
                    const Text('Income', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                    const SizedBox(width: 10),
                    Container(width: 8, height: 8, decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.expense)),
                    const SizedBox(width: 4),
                    const Text('Expense', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                    const SizedBox(width: 10),
                    Container(
                      width: 14,
                      height: 2,
                      color: AppColors.primaryTeal,
                    ),
                    const SizedBox(width: 4),
                    const Text('Forecast (*)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primaryTeal)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Drag to scrub',
              style: TextStyle(fontSize: 10.5, fontStyle: FontStyle.italic, color: financialColors.textMuted),
            ),
          ],
        ),
      ],
    );
  }
}

class _BezierCashflowPainter extends CustomPainter {
  final List<CashflowPoint> points;
  final int selectedIndex;
  final bool isDark;
  final AppFinancialColors financialColors;

  _BezierCashflowPainter({
    required this.points,
    required this.selectedIndex,
    required this.isDark,
    required this.financialColors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final bottomPadding = 24.0;
    final topPadding = 12.0;
    final graphHeight = size.height - bottomPadding - topPadding;
    final graphWidth = size.width;

    // Find max value for Y scaling
    double maxVal = 1000.0;
    for (final p in points) {
      maxVal = math.max(maxVal, math.max(p.income, p.expense));
    }
    // Add 15% headroom
    maxVal *= 1.15;

    final stepX = points.length > 1 ? graphWidth / (points.length - 1) : graphWidth;

    // 1. Draw horizontal gridlines (3 lines)
    final gridPaint = Paint()
      ..color = financialColors.cardBorder.withAlpha(isDark ? 40 : 25)
      ..strokeWidth = 1.0;

    for (int i = 0; i <= 2; i++) {
      final y = topPadding + (graphHeight / 2) * i;
      canvas.drawLine(Offset(0, y), Offset(graphWidth, y), gridPaint);
    }

    // Precalculate coordinates
    final incomeCoords = <Offset>[];
    final expenseCoords = <Offset>[];

    for (int i = 0; i < points.length; i++) {
      final x = i * stepX;
      final incomeY = topPadding + graphHeight - ((points[i].income / maxVal) * graphHeight);
      final expenseY = topPadding + graphHeight - ((points[i].expense / maxVal) * graphHeight);

      incomeCoords.add(Offset(x, incomeY.clamp(topPadding, size.height - bottomPadding)));
      expenseCoords.add(Offset(x, expenseY.clamp(topPadding, size.height - bottomPadding)));
    }

    // 2. Draw Bezier paths (Past curve solid, Forecast curve dashed)
    final historicalCount = points.where((p) => !p.isForecast).length;

    _drawSmoothCurve(
      canvas: canvas,
      coords: incomeCoords,
      historicalCount: historicalCount,
      color: financialColors.income,
      topPadding: topPadding,
      bottomY: topPadding + graphHeight,
      size: size,
    );

    _drawSmoothCurve(
      canvas: canvas,
      coords: expenseCoords,
      historicalCount: historicalCount,
      color: financialColors.expense,
      topPadding: topPadding,
      bottomY: topPadding + graphHeight,
      size: size,
    );

    // 3. Draw vertical scrubber indicator for selected index
    if (selectedIndex >= 0 && selectedIndex < points.length) {
      final scrubX = selectedIndex * stepX;

      final scrubLinePaint = Paint()
        ..color = financialColors.textMuted.withAlpha(80)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;

      canvas.drawLine(
        Offset(scrubX, topPadding),
        Offset(scrubX, topPadding + graphHeight),
        scrubLinePaint,
      );

      // Draw Income Point Node
      final incPt = incomeCoords[selectedIndex];
      final expPt = expenseCoords[selectedIndex];

      _drawPointNode(canvas, incPt, financialColors.income);
      _drawPointNode(canvas, expPt, financialColors.expense);
    }

    // 4. Draw X-axis month labels at the bottom
    for (int i = 0; i < points.length; i++) {
      final p = points[i];
      final label = DateFormat('MMM').format(p.month) + (p.isForecast ? '*' : '');
      final isSelected = (i == selectedIndex);

      final textSpan = TextSpan(
        text: label,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
          color: isSelected
              ? (p.isForecast ? AppColors.primaryTeal : (isDark ? Colors.white : Colors.black))
              : financialColors.textMuted,
        ),
      );

      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      )..layout();

      final textX = (i * stepX) - (textPainter.width / 2);
      final clampedX = textX.clamp(0.0, graphWidth - textPainter.width);
      textPainter.paint(canvas, Offset(clampedX, size.height - bottomPadding + 6));
    }
  }

  void _drawPointNode(Canvas canvas, Offset center, Color color) {
    final outerPaint = Paint()
      ..color = color.withAlpha(50)
      ..style = PaintingStyle.fill;
    final haloPaint = Paint()
      ..color = isDark ? AppColors.darkSurface : AppColors.lightSurface
      ..style = PaintingStyle.fill;
    final corePaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, 7, outerPaint);
    canvas.drawCircle(center, 4.5, haloPaint);
    canvas.drawCircle(center, 3, corePaint);
  }

  void _drawSmoothCurve({
    required Canvas canvas,
    required List<Offset> coords,
    required int historicalCount,
    required Color color,
    required double topPadding,
    required double bottomY,
    required Size size,
  }) {
    if (coords.length < 2) return;

    // Draw historical part with gradient fill
    if (historicalCount >= 2) {
      final histCoords = coords.sublist(0, historicalCount);
      final linePath = Path();
      final areaPath = Path();

      linePath.moveTo(histCoords[0].dx, histCoords[0].dy);
      areaPath.moveTo(histCoords[0].dx, bottomY);
      areaPath.lineTo(histCoords[0].dx, histCoords[0].dy);

      for (int i = 0; i < histCoords.length - 1; i++) {
        final p0 = histCoords[i];
        final p1 = histCoords[i + 1];
        final midX = (p0.dx + p1.dx) / 2;

        linePath.cubicTo(midX, p0.dy, midX, p1.dy, p1.dx, p1.dy);
        areaPath.cubicTo(midX, p0.dy, midX, p1.dy, p1.dx, p1.dy);
      }

      areaPath.lineTo(histCoords.last.dx, bottomY);
      areaPath.close();

      // Draw subtle gradient fill
      final fillPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withAlpha(isDark ? 35 : 20),
            color.withAlpha(0),
          ],
        ).createShader(Rect.fromLTRB(0, topPadding, size.width, bottomY))
        ..style = PaintingStyle.fill;

      canvas.drawPath(areaPath, fillPaint);

      // Draw primary stroke
      final strokePaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round;

      canvas.drawPath(linePath, strokePaint);
    }

    // Draw forecast projection segment (from last historical to end) with dashed line
    if (historicalCount > 0 && historicalCount < coords.length) {
      final forecastCoords = coords.sublist(historicalCount - 1);
      final forecastPath = Path();
      forecastPath.moveTo(forecastCoords[0].dx, forecastCoords[0].dy);

      for (int i = 0; i < forecastCoords.length - 1; i++) {
        final p0 = forecastCoords[i];
        final p1 = forecastCoords[i + 1];
        final midX = (p0.dx + p1.dx) / 2;
        forecastPath.cubicTo(midX, p0.dy, midX, p1.dy, p1.dx, p1.dy);
      }

      _drawDashedPath(
        canvas: canvas,
        path: forecastPath,
        paint: Paint()
          ..color = color.withAlpha(160)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0
          ..strokeCap = StrokeCap.round,
        dashWidth: 4.5,
        dashSpace: 3.5,
      );
    }
  }

  void _drawDashedPath({
    required Canvas canvas,
    required Path path,
    required Paint paint,
    required double dashWidth,
    required double dashSpace,
  }) {
    for (final metric in path.computeMetrics()) {
      double distance = 0.0;
      while (distance < metric.length) {
        final len = math.min(dashWidth, metric.length - distance);
        final extract = metric.extractPath(distance, distance + len);
        canvas.drawPath(extract, paint);
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BezierCashflowPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.isDark != isDark;
  }
}
