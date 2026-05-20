// ============================================================
// lib/features/home/presentation/pages/exercise_detail_page.dart
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/exercise.dart';
import '../../../analysis/presentation/pages/new_analysis_page.dart';
import '../../../analysis/presentation/widgets/smplx_viewer_widget.dart';
import 'package:provider/provider.dart';
import '../../../../core/navigation/navigation_provider.dart';

class ExerciseDetailPage extends StatefulWidget {
  final Exercise exercise;
  const ExerciseDetailPage({Key? key, required this.exercise}) : super(key: key);

  @override
  State<ExerciseDetailPage> createState() => _ExerciseDetailPageState();
}

class _ExerciseDetailPageState extends State<ExerciseDetailPage> {
  bool _isComparing = false;
  Exercise? _compareExercise;

  String _getBackendExerciseName(Exercise exercise) {
    final name = exercise.name.toLowerCase();
    if (name.contains('squat')) return 'squat';
    if (name.contains('deadlift')) return 'deadlift';
    if (name.contains('push')) return 'pushup';
    if (name.contains('lateral')) return 'side_lateral_raise';
    return name.replaceAll(' ', '_');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final exercise = widget.exercise;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth > 900;
          return CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: isDesktop ? 400 : 300,
                pinned: true,
                backgroundColor: theme.scaffoldBackgroundColor,
                elevation: 0,
                leading: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: CircleAvatar(
                    backgroundColor: theme.canvasColor.withOpacity(0.5),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  background: Hero(
                    tag: 'exercise_${exercise.id}',
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            theme.primaryColor.withOpacity(0.8),
                            theme.scaffoldBackgroundColor,
                          ],
                        ),
                      ),
                      child: Center(
                        child: Icon(Icons.fitness_center, size: 100, color: Colors.white.withOpacity(0.3)),
                      ),
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isDesktop ? constraints.maxWidth * 0.1 : 24,
                    vertical: 24,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title & Difficulty
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(exercise.name, style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: _getDifficultyColor(exercise.difficulty).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: _getDifficultyColor(exercise.difficulty)),
                            ),
                            child: Text(
                              _getLocalizedDifficulty(context, exercise.difficulty),
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: _getDifficultyColor(exercise.difficulty), fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(_getLocalizedCategory(context, exercise.category),
                        style: theme.textTheme.titleMedium?.copyWith(color: theme.primaryColor, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 32),

                      // Description
                      Text(l10n.descriptionLabel, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      Text(exercise.description, style: theme.textTheme.bodyLarge?.copyWith(height: 1.6, color: theme.textTheme.bodyMedium?.color?.withOpacity(0.8))),
                      const SizedBox(height: 32),

                      // Instructions
                      Text(l10n.instructionsLabel, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      ...exercise.instructions.asMap().entries.map((entry) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: theme.cardColor,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 32, height: 32,
                                  decoration: BoxDecoration(color: theme.primaryColor, borderRadius: BorderRadius.circular(10)),
                                  child: Center(child: Text('${entry.key + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                                ),
                                const SizedBox(width: 16),
                                Expanded(child: Text(entry.value, style: theme.textTheme.bodyLarge?.copyWith(height: 1.5))),
                              ],
                            ),
                          ),
                        );
                      }).toList(),

                      const SizedBox(height: 40),

                      // 3D Title + Compare Button
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(l10n.motionVisualization, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                          ElevatedButton.icon(
                            onPressed: () {
                              setState(() {
                                _isComparing = !_isComparing;
                                if (!_isComparing) _compareExercise = null;
                              });
                            },
                            icon: Icon(_isComparing ? Icons.close : Icons.compare_arrows, size: 18),
                            label: Text(_isComparing ? 'Fermer' : 'Comparer', style: const TextStyle(fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isComparing ? Colors.red : theme.primaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                            ),
                          ),
                        ],
                      ),

                      // Compare dropdown
                      if (_isComparing) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.green.withOpacity(0.2)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.compare, color: Colors.green),
                              const SizedBox(width: 12),
                              const Text('Comparer avec :', style: TextStyle(fontWeight: FontWeight.w600)),
                              const SizedBox(width: 12),
                              PopupMenuButton<Exercise>(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(20)),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(_compareExercise?.name ?? 'Choisir', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                      const SizedBox(width: 8),
                                      const Icon(Icons.arrow_drop_down, color: Colors.white, size: 20),
                                    ],
                                  ),
                                ),
                                onSelected: (ex) => setState(() => _compareExercise = ex),
                                itemBuilder: (ctx) => getMockExercises()
                                    .where((e) => e.name != exercise.name)
                                    .map((e) => PopupMenuItem<Exercise>(value: e, child: Text(e.name)))
                                    .toList(),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 16),

                      // SMPL Viewer(s)
                      if (_isComparing && _compareExercise != null)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(children: [
                                _buildViewerHeader(exercise.name, theme.primaryColor),
                                SizedBox(
                                  height: 420,
                                  child: ClipRRect(
                                    borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(16), bottomRight: Radius.circular(16)),
                                    child: SmplxViewerWidget(key: ValueKey('d_${_getBackendExerciseName(exercise)}'), sessionId: _getBackendExerciseName(exercise)),
                                  ),
                                ),
                              ]),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(children: [
                                _buildViewerHeader(_compareExercise!.name, Colors.green),
                                SizedBox(
                                  height: 420,
                                  child: ClipRRect(
                                    borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(16), bottomRight: Radius.circular(16)),
                                    child: SmplxViewerWidget(key: ValueKey('c_${_getBackendExerciseName(_compareExercise!)}'), sessionId: _getBackendExerciseName(_compareExercise!)),
                                  ),
                                ),
                              ]),
                            ),
                          ],
                        )
                      else
                        Container(
                          width: double.infinity, height: 380,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 15, offset: const Offset(0, 8))],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: SmplxViewerWidget(key: ValueKey('s_${_getBackendExerciseName(exercise)}'), sessionId: _getBackendExerciseName(exercise)),
                          ),
                        ),

                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // Pop detail page to return to dashboard structure
          Navigator.pop(context);
          // Go to 'New Analysis' tab
          context.read<NavigationProvider>().setIndex(3);
        },
        label: Text(l10n.startAnalysis, style: const TextStyle(fontWeight: FontWeight.bold)),
        icon: const Icon(Icons.play_arrow_rounded),
        backgroundColor: theme.primaryColor,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildViewerHeader(String title, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(children: [
        Icon(Icons.accessibility_new, color: color, size: 18),
        const SizedBox(width: 8),
        Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: color, letterSpacing: 0.5)),
      ]),
    );
  }

  String _getLocalizedCategory(BuildContext context, String category) {
    final l10n = AppLocalizations.of(context)!;
    switch (category.toLowerCase()) {
      case 'strength': return l10n.strength;
      case 'mobility': return l10n.mobility;
      case 'bodyweight': return l10n.bodyWeight;
      case 'rehab': return l10n.rehab;
      default: return category;
    }
  }

  String _getLocalizedDifficulty(BuildContext context, String difficulty) {
    final l10n = AppLocalizations.of(context)!;
    switch (difficulty.toLowerCase()) {
      case 'beginner': return l10n.beginner;
      case 'intermediate': return l10n.intermediate;
      case 'advanced': return l10n.advanced;
      default: return difficulty;
    }
  }

  Color _getDifficultyColor(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'beginner': return Colors.green;
      case 'intermediate': return Colors.orange;
      case 'advanced': return Colors.red;
      default: return Colors.blue;
    }
  }
}
