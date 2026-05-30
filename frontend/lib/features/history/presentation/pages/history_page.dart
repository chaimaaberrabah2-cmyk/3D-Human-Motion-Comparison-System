import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../analysis/data/datasources/analysis_remote_datasource.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({Key? key}) : super(key: key);

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  String _role = 'user';
  int? _userId;
  int? _establishmentId;
  bool _isLoading = true;
  List<Map<String, dynamic>> _performances = [];
  List<Map<String, dynamic>> _progressData = [];
  Map<String, dynamic>? _estStats;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final role = prefs.getString('user_role') ?? 'user';
    final userId = prefs.getInt('user_id');
    final estId = prefs.getInt('user_establishment_id');

    if (!mounted) return;
    setState(() {
      _role = role;
      _userId = userId;
      _establishmentId = estId;
    });

    final ds = AnalysisRemoteDataSource();

    if (userId != null) {
      try {
        final results = await Future.wait([
          ds.fetchHistory(userId),
          ds.fetchProgress(userId),
        ]);
        if (mounted) {
          setState(() {
            _performances = List<Map<String, dynamic>>.from(results[0]);
            _progressData = List<Map<String, dynamic>>.from(results[1]);
          });
        }
      } catch (e) {
        print('Error loading history: $e');
      }
    }

    if (role == 'admin' && estId != null) {
      try {
        final stats = await ds.fetchEstablishmentStats(estId);
        if (mounted) setState(() => _estStats = stats);
      } catch (e) {
        print('Error loading establishment stats: $e');
      }
    }

    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final l10n = AppLocalizations.of(context)!;
    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: _buildContent(context, l10n),
      ),
    );
  }

  Widget _buildContent(BuildContext context, AppLocalizations l10n) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _role == 'admin' ? 'Historique' : l10n.history,
            style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          _buildStatsRow(context, l10n),
          if (_progressData.length >= 2) ...[
            const SizedBox(height: 32),
            _buildProgressChart(context),
          ],
          if (_role == 'admin' && _estStats != null) ...[
            const SizedBox(height: 32),
            _buildEstablishmentDashboard(context),
          ],
          const SizedBox(height: 32),
          _buildRecentActivitySection(context, l10n),
        ],
      ),
    );
  }

  Widget _buildStatsRow(BuildContext context, AppLocalizations l10n) {
    final completed = _performances.where((p) => p['score'] != null).toList();
    final avgScore = completed.isEmpty
        ? 0.0
        : completed.fold<double>(0, (s, p) => s + (p['score'] as num).toDouble()) / completed.length;

    return LayoutBuilder(builder: (context, constraints) {
      final isWrap = constraints.maxWidth < 900;
      final cards = [
        _buildStatCard(context, l10n.totalSessions, '${_performances.length}', '', true),
        _buildStatCard(context, l10n.avgAccuracy, '${avgScore.toStringAsFixed(1)}%', '', true),
        _buildStatCard(context, l10n.activeCameras, '4/4', l10n.stable, true, isStatus: true),
      ];

      if (isWrap) {
        return Wrap(spacing: 16, runSpacing: 16, children: cards);
      }
      final w = (constraints.maxWidth - 32) / 3;
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: cards.map((c) => SizedBox(width: w, child: c)).toList(),
      );
    });
  }

  Widget _buildStatCard(BuildContext context, String title, String value, String trend, bool isPositive,
      {bool isStatus = false, double? width}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: width,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.5)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title.toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              )),
          const SizedBox(height: 12),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(value,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isStatus ? const Color(0xFFA855F7) : theme.textTheme.bodyLarge?.color,
                )),
            if (trend.isNotEmpty) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isStatus
                      ? const Color(0xFF10B981).withValues(alpha: 0.1)
                      : (isPositive ? const Color(0xFF10B981).withValues(alpha: 0.1) : const Color(0xFFEF4444).withValues(alpha: 0.1)),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(trend,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: isStatus ? const Color(0xFF10B981) : (isPositive ? const Color(0xFF10B981) : const Color(0xFFEF4444)),
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    )),
              ),
            ],
          ]),
        ],
      ),
    );
  }

  Widget _buildRecentActivitySection(BuildContext context, AppLocalizations l10n) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              children: [
                Icon(Icons.history_outlined, color: theme.primaryColor, size: 24),
                const SizedBox(width: 12),
                Text(l10n.recentActivity,
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const Divider(height: 1),
          if (_performances.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Text('No sessions yet. Start your first analysis!',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.5),
                    )),
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: 800,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      child: Row(
                        children: [
                          Expanded(flex: 3, child: _buildTableHeader(l10n.sessionId, theme)),
                          Expanded(flex: 3, child: _buildTableHeader('Exercise', theme)),
                          Expanded(flex: 3, child: _buildTableHeader(l10n.dateTime, theme)),
                          Expanded(flex: 2, child: _buildTableHeader(l10n.score, theme)),
                          Expanded(flex: 2, child: _buildTableHeader(l10n.performancePreview, theme)),
                        ],
                      ),
                    ),
                    ..._performances.map((p) => _buildActivityRow(context, l10n, p)),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildProgressChart(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final scores = _progressData
        .where((p) => p['score'] != null)
        .map((p) => (p['score'] as num).toDouble())
        .toList();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.trending_up, color: theme.primaryColor),
              const SizedBox(width: 12),
              Text('Progress Over Time',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 160,
            child: CustomPaint(
              painter: _SparklinePainter(
                scores: scores,
                lineColor: theme.primaryColor,
                fillColor: theme.primaryColor.withValues(alpha: 0.12),
                gridColor: theme.dividerColor.withValues(alpha: 0.3),
              ),
              child: Container(),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Session 1',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.5),
                  )),
              Text('Latest',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.5),
                  )),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEstablishmentDashboard(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final stats = _estStats!;
    final breakdown = (stats['by_exercise'] as List?)?.cast<Map>() ?? [];

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.business, color: theme.primaryColor),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  stats['establishment_name'] ?? 'Establishment Dashboard',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _buildMiniStat(context, 'Total Sessions', '${stats['total_sessions'] ?? 0}'),
              const SizedBox(width: 16),
              _buildMiniStat(context, 'Active Users', '${stats['unique_users'] ?? 0}'),
              const SizedBox(width: 16),
              _buildMiniStat(context, 'Avg Score',
                  stats['avg_score'] != null ? '${stats['avg_score']}%' : '--'),
            ],
          ),
          if (breakdown.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text('By Exercise',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                  color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.5),
                )),
            const SizedBox(height: 12),
            ...breakdown.map((ex) {
              final avg = ex['avg_score'];
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(ex['exercise'] ?? '-',
                          style: theme.textTheme.bodyMedium),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text('${ex['sessions']} sessions',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
                          )),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        avg != null ? '$avg%' : '--',
                        style: TextStyle(
                          color: theme.primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildMiniStat(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: theme.primaryColor.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                )),
            const SizedBox(height: 4),
            Text(value,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.primaryColor,
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildTableHeader(String text, ThemeData theme) {
    return Text(
      text.toUpperCase(),
      style: theme.textTheme.labelSmall?.copyWith(
        color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.5),
        fontWeight: FontWeight.bold,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildActivityRow(BuildContext context, AppLocalizations l10n, Map<String, dynamic> p) {
    final theme = Theme.of(context);
    final id = '#${p['performance_id']}';
    final exercise = p['exercise'] ?? '-';
    final score = p['score'] != null ? '${(p['score'] as num).toStringAsFixed(1)}%' : '--';
    final isCompleted = p['score'] != null;

    String dateStr = '-';
    if (p['created_at'] != null) {
      try {
        final dt = DateTime.parse(p['created_at']).toLocal();
        dateStr = '${dt.day}/${dt.month}/${dt.year}\n${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      } catch (_) {}
    }

    return Column(
      children: [
        const Divider(height: 1, indent: 24, endIndent: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Text(id,
                    style: TextStyle(color: theme.primaryColor, fontWeight: FontWeight.w600)),
              ),
              Expanded(
                flex: 3,
                child: Text(exercise, style: theme.textTheme.bodyMedium),
              ),
              Expanded(
                flex: 3,
                child: Text(dateStr,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.8),
                    )),
              ),
              Expanded(
                flex: 2,
                child: Text(score,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: isCompleted ? const Color(0xFF10B981) : theme.textTheme.bodyMedium?.color,
                      fontWeight: FontWeight.bold,
                    )),
              ),
              Expanded(
                flex: 2,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: theme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.visibility_outlined, size: 14, color: theme.primaryColor),
                      const SizedBox(width: 4),
                      Text(l10n.performancePreview,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.primaryColor,
                            fontWeight: FontWeight.bold,
                          )),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<double> scores;
  final Color lineColor;
  final Color fillColor;
  final Color gridColor;

  const _SparklinePainter({
    required this.scores,
    required this.lineColor,
    required this.fillColor,
    required this.gridColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (scores.length < 2) return;

    final minScore = scores.reduce(math.min);
    final maxScore = scores.reduce(math.max);
    final range = (maxScore - minScore).clamp(1.0, double.infinity);

    double xOf(int i) => i / (scores.length - 1) * size.width;
    double yOf(double v) => size.height - ((v - minScore) / range) * size.height * 0.85 - size.height * 0.05;

    // Draw horizontal grid lines
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (final pct in [0.0, 0.25, 0.5, 0.75, 1.0]) {
      final y = size.height - pct * size.height * 0.85 - size.height * 0.05;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Build path
    final path = Path();
    path.moveTo(xOf(0), yOf(scores[0]));
    for (int i = 1; i < scores.length; i++) {
      final x0 = xOf(i - 1);
      final x1 = xOf(i);
      final y0 = yOf(scores[i - 1]);
      final y1 = yOf(scores[i]);
      final cx = (x0 + x1) / 2;
      path.cubicTo(cx, y0, cx, y1, x1, y1);
    }

    // Fill
    final fillPath = Path.from(path)
      ..lineTo(xOf(scores.length - 1), size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(fillPath, Paint()..color = fillColor);

    // Line
    canvas.drawPath(
      path,
      Paint()
        ..color = lineColor
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    // Dots on each point
    final dotPaint = Paint()..color = lineColor;
    for (int i = 0; i < scores.length; i++) {
      canvas.drawCircle(Offset(xOf(i), yOf(scores[i])), 4, dotPaint);
      canvas.drawCircle(
        Offset(xOf(i), yOf(scores[i])),
        4,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
  }

  @override
  bool shouldRepaint(_SparklinePainter old) =>
      old.scores != scores || old.lineColor != lineColor;
}
