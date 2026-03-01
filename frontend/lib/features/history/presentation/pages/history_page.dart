import 'package:flutter/material.dart';
import '../../../home/presentation/widgets/home_sidebar.dart';
import '../../../../l10n/app_localizations.dart';

class HistoryPage extends StatelessWidget {
  const HistoryPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth > 1200;
          final isTablet = constraints.maxWidth > 600 && constraints.maxWidth <= 1200;

          if (isDesktop || isTablet) {
            return Row(
              children: [
                const HomeSidebar(),
                Expanded(
                  child: _buildContent(context, l10n),
                ),
              ],
            );
          } else {
            return Scaffold(
              appBar: AppBar(
                backgroundColor: theme.scaffoldBackgroundColor,
                elevation: 0,
                iconTheme: theme.iconTheme,
                title: Text(
                  l10n.history,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              drawer: const Drawer(
                child: HomeSidebar(),
              ),
              body: SafeArea(
                child: SingleChildScrollView(
                  child: _buildContent(context, l10n),
                ),
              ),
            );
          }
        },
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
            l10n.history,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.textTheme.bodyLarge?.color,
            ),
          ),
          const SizedBox(height: 24),
          
          // Stats Row
          _buildStatsRow(context, l10n),
          
          const SizedBox(height: 32),
          
          // Recent Activity Table
          _buildRecentActivitySection(context, l10n),
        ],
      ),
    );
  }

  Widget _buildStatsRow(BuildContext context, AppLocalizations l10n) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double cardWidth = (constraints.maxWidth - (3 * 16)) / 4;
        final bool isWrap = constraints.maxWidth < 900;

        if (isWrap) {
          return Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _buildStatCard(context, l10n.totalSessions, '142', '+12%', true),
              _buildStatCard(context, l10n.avgAccuracy, '96.4%', '+2.4%', true),
              _buildStatCard(context, l10n.processingTime, '1.2s', '-0.3s', false),
              _buildStatCard(context, l10n.activeCameras, '4/4', l10n.stable, true, isStatus: true),
            ],
          );
        }

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildStatCard(context, l10n.totalSessions, '142', '+12%', true, width: cardWidth),
            _buildStatCard(context, l10n.avgAccuracy, '96.4%', '+2.4%', true, width: cardWidth),
            _buildStatCard(context, l10n.processingTime, '1.2s', '-0.3s', false, width: cardWidth),
            _buildStatCard(context, l10n.activeCameras, '4/4', l10n.stable, true, isStatus: true, width: cardWidth),
          ],
        );
      }
    );
  }

  Widget _buildStatCard(
    BuildContext context, 
    String title, 
    String value, 
    String trend, 
    bool isPositive, 
    {bool isStatus = false, double? width}
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: width,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isStatus ? const Color(0xFFA855F7) : (isPositive && !isStatus && value.contains('%') ? const Color(0xFF10B981) : (value.contains('s') ? const Color(0xFFF59E0B) : theme.textTheme.bodyLarge?.color)),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isStatus 
                    ? const Color(0xFF10B981).withValues(alpha: 0.1)
                    : (isPositive ? const Color(0xFF10B981).withValues(alpha: 0.1) : const Color(0xFFEF4444).withValues(alpha: 0.1)),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  trend,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: isStatus 
                        ? const Color(0xFF10B981)
                        : (isPositive ? const Color(0xFF10B981) : const Color(0xFFEF4444)),
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.history_outlined,
                      color: theme.primaryColor,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      l10n.recentActivity,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () {},
                  child: Text(
                    l10n.viewAllRecords,
                    style: TextStyle(
                      color: theme.primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          
          // Table Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(
              children: [
                Expanded(flex: 3, child: _buildTableHeader(l10n.sessionId, theme)),
                Expanded(flex: 3, child: _buildTableHeader(l10n.dateTime, theme)),
                Expanded(flex: 2, child: _buildTableHeader(l10n.duration, theme)),
                Expanded(flex: 2, child: _buildTableHeader(l10n.score, theme)),
                Expanded(flex: 2, child: _buildTableHeader(l10n.performancePreview, theme)),
              ],
            ),
          ),
          
          // Table Rows
          _buildActivityRow(context, l10n, 'S-9421', 'Feb 17, 2026\n14:30', '12m 40s', '98.2', true),
          _buildActivityRow(context, l10n, 'S-9420', 'Feb 17, 2026\n11:15', '08m 15s', '97.5', true),
          _buildActivityRow(context, l10n, 'S-9419', 'Feb 16, 2026\n16:45', '24m 10s', '94.8', true),
          _buildActivityRow(context, l10n, 'S-9418', 'Feb 16, 2026\n09:20', '05m 55s', '--', false),
          
          const SizedBox(height: 16),
        ],
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

  Widget _buildActivityRow(
    BuildContext context, 
    AppLocalizations l10n,
    String id, 
    String dateTime, 
    String duration, 
    String score, 
    bool isCompleted
  ) {
    final theme = Theme.of(context);

    return Column(
      children: [
        const Divider(height: 1, indent: 24, endIndent: 24),
        InkWell(
          onTap: () {},
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Row(
              children: [
                // Session ID
                Expanded(
                  flex: 3,
                  child: Text(
                    id,
                    style: TextStyle(
                      color: theme.primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                // Date & Time
                Expanded(
                  flex: 3,
                  child: Text(
                    dateTime,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.8),
                    ),
                  ),
                ),
                // Duration
                Expanded(
                  flex: 2,
                  child: Text(
                    duration,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
                // Score
                Expanded(
                  flex: 2,
                  child: Text(
                    score,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: isCompleted ? const Color(0xFF10B981) : theme.textTheme.bodyMedium?.color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                // Preview Action
                Expanded(
                  flex: 2,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: InkWell(
                      onTap: () {
                        // Action for preview
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: theme.primaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.visibility_outlined,
                              size: 14,
                              color: theme.primaryColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              l10n.performancePreview,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.primaryColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
