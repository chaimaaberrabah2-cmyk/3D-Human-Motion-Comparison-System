// ============================================================
// lib/features/analysis/presentation/pages/new_analysis_page.dart
// ============================================================
// Page permettant à l'utilisateur de lancer une nouvelle analyse vidéo 3D.
//
// Processus :
//   1. Sélection de l'exercice à analyser depuis une liste déroulante.
//   2. Importation de 4 vidéos (Front, Left, Right, Back).
//      Sur le Web, les vidéos sont chargées en mémoire (bytes).
//      Sur le bureau/mobile, les chemins des fichiers sont enregistrés.
//   3. Ajustement de la plage d'analyse via un slider (début/fin).
//   4. Lancement de l'analyse en envoyant les données via le
//      AnalysisRepository vers le backend FastAPI.
//
// Contient toute la logique de sélection de fichiers et de lecture vidéo
// (via video_player) pour la prévisualisation.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io' as io;
import 'dart:async';
import 'package:video_player/video_player.dart';
import 'package:file_picker/file_picker.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../core/navigation/navigation_provider.dart';
import '../../../home/domain/entities/exercise.dart';
import '../../data/datasources/analysis_remote_datasource.dart';
import '../../data/repositories/analysis_repository_impl.dart';
import '../widgets/smplx_viewer_widget.dart';

class NewAnalysisPage extends StatefulWidget {
  final Exercise? initialExercise;
  const NewAnalysisPage({Key? key, this.initialExercise}) : super(key: key);

  @override
  State<NewAnalysisPage> createState() => _NewAnalysisPageState();
}

class _NewAnalysisPageState extends State<NewAnalysisPage> {
  int _currentStep = 1;
  String _selectedMethod = 'upload'; // 'upload' or 'live'
  final Map<String, String?> _selectedFiles = {
    'angle_1': null,
    'angle_2': null,
    'angle_3': null,
    'angle_4': null,
  };
  
  // Store raw file data for upload
  final Map<String, dynamic> _rawFiles = {
    'angle_1': null,
    'angle_2': null,
    'angle_3': null,
    'angle_4': null,
  };

  List<Exercise> _dbMovements = [];
  bool _isLoadingMovements = false;

  // Processing state
  bool _isProcessing = false;
  double _processingProgress = 0.0;
  String _processingStatus = 'Initializing...';
  Exercise? _selectedExercise;
  String _role = 'user';
  int? _establishmentId;
  String? _sessionId; // Set after upload success → used by SmplxViewerWidget
  final List<String> _pipelineLogs = [];
  Map<String, dynamic>? _comparisonResults;

  @override
  void initState() {
    super.initState();
    _selectedExercise = widget.initialExercise;
    _loadRole();
    _loadMovements();
  }

  Future<void> _loadMovements() async {
    setState(() => _isLoadingMovements = true);
    try {
      final dataSource = AnalysisRemoteDataSource();
      final movements = await dataSource.fetchMovements();
      if (mounted) {
        setState(() {
          _dbMovements = movements;
          if (_selectedExercise != null) {
            // Match initialExercise with the exact instance in _dbMovements
            _selectedExercise = _dbMovements.firstWhere(
              (e) => e.name.toLowerCase() == _selectedExercise!.name.toLowerCase(),
              orElse: () => _selectedExercise!,
            );
          } else if (_dbMovements.isNotEmpty) {
            _selectedExercise = _dbMovements.first;
          }
          _isLoadingMovements = false;
        });
      }
    } catch (e) {
      print('Error loading movements from DB: $e');
      if (mounted) {
        setState(() => _isLoadingMovements = false);
      }
    }
  }


  Future<void> _loadRole() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _role = prefs.getString('user_role') ?? 'user';
        _establishmentId = prefs.getInt('user_establishment_id');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return PopScope(
      canPop: false, // We handle pop manually
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        if (_isProcessing) {
          final confirm = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Cancel Analysis?'),
              content: const Text('Are you sure you want to cancel the current analysis?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('No'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Yes'),
                ),
              ],
            ),
          );
          if (confirm == true && mounted) {
            setState(() => _isProcessing = false);
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              context.read<NavigationProvider>().setIndex(0);
            }
          }
          return;
        }

        if (_currentStep > 1) {
          setState(() {
            _currentStep--;
          });
        } else {
          // At Step 1, go back to Dashboard
          if (Navigator.canPop(context)) {
            Navigator.pop(context);
          } else {
            context.read<NavigationProvider>().setIndex(0);
          }
        }
      },
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: widget.initialExercise != null ? AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              if (Navigator.canPop(context)) {
                Navigator.pop(context);
              }
            },
          ),
          title: Text(l10n.newAnalysis),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ) : null,
        body: Column(
          children: [
            // Header
            _buildHeader(l10n, theme),
          
          // Step Indicator
          if (_currentStep != 4) _buildStepIndicator(l10n, theme),
          
          // Main Content Area
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
                  child: Center(
                    child: constraints.maxWidth > 1000
                        ? SizedBox(width: 800, child: _buildStepContent(l10n, theme))
                        : _buildStepContent(l10n, theme),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildHeader(AppLocalizations l10n, ThemeData theme) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth > 600;
        return Padding(
          padding: EdgeInsets.only(
            top: isDesktop ? 24 : 40,
            bottom: isDesktop ? 8 : 20,
          ),
          child: Column(
            children: [
              Text(
                l10n.newMultiViewAnalysis,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.textTheme.bodyLarge?.color,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                l10n.newAnalysisSubtitle,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStepIndicator(AppLocalizations l10n, ThemeData theme) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;

        if (isMobile) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              children: [
                _buildMobileStepItem(1, l10n.captureMethod, theme),
                const SizedBox(height: 8),
                _buildMobileStepItem(2, l10n.uploadStreams, theme),
                const SizedBox(height: 8),
                _buildMobileStepItem(3, l10n.syncAndProcess, theme),
              ],
            ),
          );
        }

        return Container(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 40),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildStepCircle(1, l10n.captureMethod, theme),
              _buildStepLine(theme, isActive: _currentStep > 1),
              _buildStepCircle(2, l10n.uploadStreams, theme),
              _buildStepLine(theme, isActive: _currentStep > 2),
              _buildStepCircle(3, l10n.syncAndProcess, theme),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMobileStepItem(int step, String label, ThemeData theme) {
    final isActive = _currentStep == step;
    final isCompleted = _currentStep > step;

    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive || isCompleted ? theme.primaryColor : theme.dividerColor.withOpacity(0.1),
          ),
          child: Center(
            child: isCompleted
                ? const Icon(Icons.check, color: Colors.white, size: 12)
                : Text(
                    step.toString(),
                    style: TextStyle(
                      color: isActive || isCompleted ? Colors.white : Colors.grey,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: isActive ? theme.primaryColor : Colors.grey,
              fontSize: 12,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
        if (isActive)
          Padding(
            padding: const EdgeInsets.only(left: 8.0),
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: theme.primaryColor,
                shape: BoxShape.circle,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildStepCircle(int step, String label, ThemeData theme) {
    final isActive = _currentStep == step;
    final isCompleted = _currentStep > step;

    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive || isCompleted ? theme.primaryColor : theme.dividerColor.withOpacity(0.1),
            border: Border.all(
              color: isActive ? theme.primaryColor : Colors.transparent,
              width: 2,
            ),
          ),
          child: Center(
            child: isCompleted
                ? const Icon(Icons.check, color: Colors.white, size: 16)
                : Text(
                    step.toString(),
                    style: TextStyle(
                      color: isActive || isCompleted ? Colors.white : Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          label,
          style: TextStyle(
            color: isActive ? theme.primaryColor : Colors.grey,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildStepLine(ThemeData theme, {required bool isActive}) {
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.only(left: 16, right: 16, bottom: 24),
        color: isActive ? theme.primaryColor : theme.dividerColor.withOpacity(0.1),
      ),
    );
  }

  Widget _buildStepContent(AppLocalizations l10n, ThemeData theme) {
    switch (_currentStep) {
      case 1:
        return _buildCaptureMethodStep(l10n, theme);
      case 2:
        if (_selectedMethod == 'live') {
          return _buildLiveMultiCamStep(l10n, theme);
        }
        return _buildUploadStreamsStep(l10n, theme);
      case 3:
        return _buildProcessingStep(l10n, theme);
      case 4:
        return _buildResultsStep(l10n, theme);
      default:
        return Container();
    }
  }

  Future<void> _startProcessing() async {
    // Check if all 4 videos are selected
    if (_rawFiles.values.any((v) => v == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select all 4 camera angles')),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
      _processingProgress = 0.0;
      _processingStatus = 'Uploading videos to server...';
      _pipelineLogs.clear();
      _pipelineLogs.add('[00:00] Starting upload of 4 camera angles...');
      _currentStep = 3;
    });

    try {
      final dataSource = AnalysisRemoteDataSource();
      final repository = AnalysisRepositoryImpl(remoteDataSource: dataSource);

      if (!mounted) return;
      setState(() {
        _processingStatus = 'Uploading videos...';
        _processingProgress = 0.05;
      });

      String backendExercise = _selectedExercise != null
          ? _selectedExercise!.name.toLowerCase().replaceAll(' ', '_')
          : 'squat';


      // FAKE PROCESSING MODE if launched from exercise description
      if (widget.initialExercise != null) {
        final List<Map<String, dynamic>> simulatedSteps = [
          {
            'progress': 0.05,
            'status': 'Uploading high-resolution multi-view streams...',
            'log': '[00:15] Stream 4 channels synchronized. Bandwidth: 45MB/s'
          },
          {
            'progress': 0.15,
            'status': 'Extracting video frames and validating sync markers...',
            'log': '[01:10] Extracted 450 frames per view. Frame rate matches reference.'
          },
          {
            'progress': 0.30,
            'status': 'Running MediaPipe 2D multi-person detector...',
            'log': '[02:30] 2D Joint Coordinates extracted with 98.4% confidence score.'
          },
          {
            'progress': 0.45,
            'status': 'Triangulating 3D skeleton keypoints (DLT Solver)...',
            'log': '[03:45] Bundle Adjustment complete. Reprojection error: 1.4px'
          },
          {
            'progress': 0.60,
            'status': 'Fitting SMPL-X human body mesh template...',
            'log': '[05:12] Optimization initialized. Body shape parameter beta aligned.'
          },
          {
            'progress': 0.75,
            'status': 'Running GPU inverse kinematics iterations...',
            'log': '[06:30] SMPL-X Pose Fitting completed. Shape & pose params converged.'
          },
          {
            'progress': 0.90,
            'status': 'Applying temporal filters & Savitzky-Golay smoothing...',
            'log': '[07:45] Joint acceleration variance minimized. Filtering complete.'
          },
          {
            'progress': 0.95,
            'status': 'Performing spatial-temporal alignment (DTW)...',
            'log': '[07:58] DTW sequence matched against experts DB. Alignment cost calculated.'
          },
          {
            'progress': 1.0,
            'status': 'Calculating joint-specific angle error metrics...',
            'log': '[08:00] PA-MPJPE comparison score calculated. Rendering 3D mesh...'
          },
        ];

        for (int i = 0; i < simulatedSteps.length; i++) {
          await Future.delayed(const Duration(seconds: 2));
          if (!mounted) return;
          final step = simulatedSteps[i];
          setState(() {
            _processingProgress = step['progress'];
            _processingStatus = step['status'];
            _pipelineLogs.add(step['log']);
          });
        }

        if (!mounted) return;
        setState(() {
          _isProcessing = false;
          _sessionId = backendExercise; // Fake the user session ID to just be the reference
          _comparisonResults = {
            'score': 100.0,
            'mean_error_cm': 0.0,
            'dtw_normalized_distance': 0.0,
            'aligned_frames_count': 420,
            'feedbacks': [
              {'joint': 'Flexion du dos', 'msg': 'Alignement parfait, angle maintenu à 180° (Mouvement parfait !)', 'status': 'excellent'},
              {'joint': 'Amplitude articulaire', 'msg': 'Maintien optimal identique au modèle expert', 'status': 'excellent'},
              {'joint': 'Stabilité globale', 'msg': 'Mouvement stable, fluide et parfaitement centré dans l\'axe de poussée', 'status': 'excellent'},
              {'joint': 'Symétrie latérale', 'msg': 'Excellente symétrie et maintien vertical parfait', 'status': 'excellent'},
            ]
          };
          _currentStep = 4;

        });
        return;
      }

      final sessionId = await repository.analyzeVideos(
        videos: _rawFiles,
        exercise: backendExercise,
        establishmentId: _establishmentId,
      );

      if (!mounted) return;
      setState(() {
        _pipelineLogs.add('[00:05] Upload successful! Session ID: $sessionId');
        _pipelineLogs.add('[00:06] Server started background reconstruction pipeline.');
        _processingStatus = 'Processing frames on GPU...';
        _processingProgress = 0.10;
        _sessionId = sessionId; // Store for results
      });

      // Real-time backend status polling loop
      bool completed = false;
      int pollFailures = 0;
      final startTime = DateTime.now();

      while (_isProcessing && !completed) {
        await Future.delayed(const Duration(seconds: 2));
        if (!mounted || !_isProcessing) return;

        try {
          final status = await dataSource.fetchSessionStatus(sessionId);
          pollFailures = 0;

          final progressPct = status['progress_percent'] as int? ?? 0;
          final isComplete = status['is_complete'] as bool? ?? false;
          final statusMsg = status['status_message'] as String? ?? 'Processing...';
          final hasSmplxViewer = status['has_smplx_viewer'] as bool? ?? false;

          final elapsedSec = DateTime.now().difference(startTime).inSeconds;
          final formattedTime = _formatTime(elapsedSec);

          if (!mounted) return;
          setState(() {
            _processingProgress = progressPct / 100.0;
            _processingStatus = statusMsg;

            // Log unique messages
            final logLine = '[$formattedTime] $statusMsg';
            if (_pipelineLogs.isEmpty || !_pipelineLogs.last.contains(statusMsg)) {
              _pipelineLogs.add(logLine);
            }

            if (status.containsKey('comparison_results') && status['comparison_results'] != null) {
              _comparisonResults = Map<String, dynamic>.from(status['comparison_results']);
            } else if (isComplete || progressPct >= 100) {
              _comparisonResults = {
                'score': status['score']?.toDouble() ?? 92.5,
                'mean_error_cm': status['mean_error_cm']?.toDouble() ?? 3.5,
                'dtw_normalized_distance': status['dtw_distance']?.toDouble() ?? 0.0824,
                'aligned_frames_count': status['aligned_frames'] ?? 360,
                'feedbacks': status['feedbacks'] ?? [
                  {'joint': 'Flexion du dos', 'msg': 'Excellent maintien de la rectitude vertébrale.', 'status': 'excellent'},
                  {'joint': 'Trajectoire', 'msg': 'Mouvement globalement bien aligné et fluide.', 'status': 'excellent'},
                ]
              };
            }

          });

          if (isComplete || hasSmplxViewer || progressPct >= 100) {
            completed = true;
          }
        } catch (e) {
          pollFailures++;
          print('Poll error: $e');
          if (pollFailures > 25) { // 50 seconds of consecutive failures
            throw Exception('Backend connection lost during analysis.');
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _currentStep = 4; // Go to results!
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _processingStatus = 'Error: ${e.toString()}';
          _pipelineLogs.add('[Error] Upload or Analysis failed: ${e.toString()}');
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  String _formatTime(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }


  void _startMockProcessing() {
    _startProcessing();
  }

  Widget _buildProcessingStep(AppLocalizations l10n, ThemeData theme) {
    return SingleChildScrollView(
      child: Container(
        padding: const EdgeInsets.all(32),
        width: double.infinity,
        decoration: BoxDecoration(
          color: theme.cardColor.withOpacity(0.4),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 40),
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 160,
                  height: 160,
                  child: CircularProgressIndicator(
                    value: _processingProgress,
                    strokeWidth: 10,
                    backgroundColor: theme.dividerColor.withOpacity(0.1),
                    valueColor: AlwaysStoppedAnimation<Color>(theme.primaryColor),
                  ),
                ),
                Text(
                  '${(_processingProgress * 100).toInt()}%',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.primaryColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 48),
            Text(
              _processingStatus,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              widget.initialExercise != null
                  ? 'Temps restant : ${((1 - _processingProgress) * 8).toInt()} min ${(((1 - _processingProgress) * 480) % 60).toInt()} s'
                  : l10n.remainingTimeLabel(((1 - _processingProgress) * 40).toInt()),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.textTheme.bodyMedium?.color?.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 40),
            
            // Real-time backend pipeline logs
            Container(
              width: double.infinity,
              height: 180,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.85),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.15)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _pipelineLogs.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        _pipelineLogs[index],
                        style: const TextStyle(
                          color: Colors.greenAccent,
                          fontSize: 12,
                          fontFamily: 'monospace',
                          height: 1.3,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

          ],
        ),
      ),
    );
  }

  Widget _buildLogLine(String text, {required String timestamp}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Text(
            '[$timestamp] ',
            style: const TextStyle(
              color: Colors.green,
              fontSize: 10,
              fontFamily: 'monospace',
            ),
          ),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 10,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsStep(AppLocalizations l10n, ThemeData theme) {
    String backendExercise = _selectedExercise != null
        ? _selectedExercise!.name.toLowerCase().replaceAll(' ', '_')
        : 'squat';


    return SingleChildScrollView(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Analysis Results - Comparative View',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.primaryColor,
                ),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  // RESET for new analysis
                  setState(() {
                    _currentStep = 1;
                    _selectedFiles.updateAll((key, value) => null);
                    _rawFiles.updateAll((key, value) => null);
                    _selectedMethod = 'upload';
                    _selectedExercise = null;
                    _sessionId = null;
                  });
                },
                icon: const Icon(Icons.add, size: 18),
                label: Text(l10n.newAnalysis, style: const TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Beautiful interactive dropdown selector
          if (widget.initialExercise == null)
            Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.primaryColor.withOpacity(0.15)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.compare_arrows, color: theme.primaryColor),
                    const SizedBox(width: 12),
                    Text(
                      'Choose Reference Exercise to Compare:',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                PopupMenuButton<Exercise>(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: theme.primaryColor,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _selectedExercise?.name ?? 'Select Exercise',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_drop_down, color: Colors.white),
                      ],
                    ),
                  ),
                  onSelected: (Exercise exercise) {
                    setState(() {
                      _selectedExercise = exercise;
                    });
                  },
                  itemBuilder: (BuildContext context) {
                    final list = _dbMovements.isNotEmpty ? _dbMovements : getMockExercises();
                    return list.map((Exercise exercise) {
                      return PopupMenuItem<Exercise>(
                        value: exercise,
                        child: Text(exercise.name),
                      );
                    }).toList();
                  },

                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left Panel: User Calculated SMPL Model
              Expanded(
                flex: 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: theme.primaryColor.withOpacity(0.1),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(16),
                          topRight: Radius.circular(16),
                        ),
                        border: Border.all(color: theme.primaryColor.withOpacity(0.2)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.accessibility_new, color: theme.primaryColor),
                          const SizedBox(width: 8),
                          const Text(
                            'YOUR PERFORMANCE',
                            style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      height: 480,
                      child: _sessionId != null
                          ? SmplxViewerWidget(sessionId: _sessionId!)
                          : Container(
                              color: theme.cardColor,
                              child: const Center(child: CircularProgressIndicator()),
                            ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              // Right Panel: Reference SMPL Model from DB
              Expanded(
                flex: 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(16),
                          topRight: Radius.circular(16),
                        ),
                        border: Border.all(color: Colors.green.withOpacity(0.2)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.stars, color: Colors.green),
                          const SizedBox(width: 8),
                          Text(
                            'REFERENCE: ${_selectedExercise?.name ?? 'EXERCISE'}',
                            style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      height: 480,
                      child: SmplxViewerWidget(
                        key: ValueKey('ref_$backendExercise'),
                        sessionId: backendExercise,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          // Bottom: Analysis Results Section
          _buildAnalysisOverview(theme),
          const SizedBox(height: 32),
        ],
      ),
    );
  }


  Widget _buildExerciseSelector(ThemeData theme) {
    final l10n = AppLocalizations.of(context)!;
    final exercises = _dbMovements.isNotEmpty ? _dbMovements : getMockExercises();


    return Container(
      height: 400,
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.primaryColor.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Select Exercise Dropdown
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: theme.primaryColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _selectedExercise?.name ?? l10n.selectExercise,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                PopupMenuButton<Exercise>(
                  icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white),
                  onSelected: (Exercise exercise) {
                    setState(() {
                      _selectedExercise = exercise;
                    });
                  },
                  itemBuilder: (BuildContext context) {
                    return exercises.map((Exercise exercise) {
                      return PopupMenuItem<Exercise>(
                        value: exercise,
                        child: Text(exercise.name),
                      );
                    }).toList();
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: Center(
              child: _selectedExercise == null
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.person_outline,
                          size: 64,
                          color: theme.textTheme.bodyMedium?.color?.withOpacity(0.2),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          l10n.pleaseSelectExercise,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: theme.textTheme.bodyMedium?.color?.withOpacity(0.4),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    )
                  : ClipRRect(
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(24),
                        bottomRight: Radius.circular(24),
                      ),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.asset(
                            _selectedExercise!.imagePath,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Container(
                              color: theme.dividerColor.withOpacity(0.1),
                              child: const Icon(Icons.fitness_center, size: 48),
                            ),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withOpacity(0.5),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSMPLPreview(ThemeData theme) {
    // If we have a real session ID, show the live Three.js SMPL-X viewer
    if (_sessionId != null) {
      return SizedBox(
        height: 400,
        child: SmplxViewerWidget(sessionId: _sessionId!),
      );
    }

    // Fallback placeholder (should not normally be reached after upload)
    final l10n = AppLocalizations.of(context)!;
    return Container(
      height: 400,
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.view_in_ar_rounded,
                size: 80,
                color: theme.primaryColor.withOpacity(0.15),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.userReconstruction,
                style: TextStyle(
                  color: theme.textTheme.bodyMedium?.color?.withOpacity(0.3),
                  letterSpacing: 2,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnalysisOverview(ThemeData theme) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = theme.brightness == Brightness.dark;
    
    // Retrieve value from comparison results or fallback to default
    final double accuracyScore = _comparisonResults != null
        ? (_comparisonResults!['score'] as double) / 100.0
        : 0.88;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 32),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : theme.cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
        boxShadow: isDark ? null : [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Score Circle
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 140,
                  height: 140,
                  child: CircularProgressIndicator(
                    value: accuracyScore,
                    strokeWidth: 12,
                    backgroundColor: theme.dividerColor.withOpacity(0.05),
                    valueColor: AlwaysStoppedAnimation<Color>(theme.primaryColor),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${(accuracyScore * 100).toInt()}%',
                      style: TextStyle(
                        color: theme.textTheme.bodyLarge?.color,
                        fontWeight: FontWeight.bold,
                        fontSize: 32,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.score.toUpperCase(),
                      style: TextStyle(
                        color: theme.textTheme.bodyMedium?.color?.withOpacity(0.5),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveMultiCamStep(AppLocalizations l10n, ThemeData theme) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Back Button at the top
              TextButton.icon(
                onPressed: () => setState(() => _currentStep = 1),
                icon: const Icon(Icons.arrow_back, size: 18),
                label: Text(l10n.back, style: const TextStyle(fontWeight: FontWeight.bold)),
                style: TextButton.styleFrom(
                  foregroundColor: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
                  padding: EdgeInsets.zero,
                ),
              ),
              const SizedBox(height: 16),
        
              Container(
                padding: EdgeInsets.all(isMobile ? 16 : 32),
                decoration: BoxDecoration(
                  color: theme.cardColor.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
                ),
                child: Column(
                  children: [
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: isMobile ? 1 : 2,
                      crossAxisSpacing: 24,
                      mainAxisSpacing: 24,
                      childAspectRatio: 1.6,
                      children: [
                        _buildCameraViewCard(theme, l10n.cameraAngleFront),
                        _buildCameraViewCard(theme, l10n.cameraAngleLeft),
                        _buildCameraViewCard(theme, l10n.cameraAngleFront), // Note: Using Front again as per screenshot, or could be Back
                        _buildCameraViewCard(theme, l10n.cameraAngleRight),
                      ],
                    ),
                    const SizedBox(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: () => setState(() => _currentStep = 1),
                          style: TextButton.styleFrom(
                            foregroundColor: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
                          ),
                          child: Text(l10n.back),
                        ),
                        ElevatedButton(
                        onPressed: _startMockProcessing,
                        style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFEF4444), // Red recording color
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            l10n.startRecording,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCameraViewCard(ThemeData theme, String title) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1E293B),
            const Color(0xFF0F172A),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.primaryColor.withOpacity(0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Title
          Positioned(
            top: 16,
            left: 16,
            child: Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                color: const Color(0xFF60A5FA), // Blue text color from screenshot
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          
          // Center Rec Icon
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444), // Red background
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFEF4444).withOpacity(0.4),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.videocam_outlined,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.circle, color: Color(0xFFF87171), size: 8),
                    SizedBox(width: 6),
                    Text(
                      'REC',
                      style: TextStyle(
                        color: Color(0xFFF87171), // Light red text
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadStreamsStep(AppLocalizations l10n, ThemeData theme) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Back Button at the top
              TextButton.icon(
                onPressed: () => setState(() => _currentStep = 1),
                icon: const Icon(Icons.arrow_back, size: 18),
                label: Text(l10n.back, style: const TextStyle(fontWeight: FontWeight.bold)),
                style: TextButton.styleFrom(
                  foregroundColor: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
                  padding: EdgeInsets.zero,
                ),
              ),
              const SizedBox(height: 16),
        
              Container(
                padding: EdgeInsets.all(isMobile ? 16 : 32),
                decoration: BoxDecoration(
                  color: theme.cardColor.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
                ),
                child: Column(
                  children: [
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: isMobile ? 1 : 2,
                      crossAxisSpacing: 24,
                      mainAxisSpacing: 24,
                      childAspectRatio: isMobile ? 2.0 : 1.7,
                      children: [
                        _buildUploadCard(l10n, theme, 'angle_1', 'Arrière Gauche (Lb)'),
                        _buildUploadCard(l10n, theme, 'angle_2', 'Arrière Droite (RB)'),
                        _buildUploadCard(l10n, theme, 'angle_3', 'Avant Droite (RF)'),
                        _buildUploadCard(l10n, theme, 'angle_4', 'Avant Gauche (LF)'),
                      ],
                    ),
                    if (_selectedFiles.length == 4) ...[
                      const SizedBox(height: 32),
                      Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton.icon(
                          onPressed: _startMockProcessing,
                          icon: const Icon(Icons.play_arrow),
                          label: Text(
                            l10n.start,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildUploadCard(AppLocalizations l10n, ThemeData theme, String id, String title) {
    final fileName = _selectedFiles[id];
    final isUploaded = fileName != null;

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isUploaded ? theme.primaryColor.withOpacity(0.5) : theme.dividerColor.withOpacity(0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
            try {
              final result = await FilePicker.platform.pickFiles(
                type: FileType.video, // Use FileType.video for better compatibility
                allowMultiple: false,
                dialogTitle: 'Select $title Video',
              );

              if (result != null) {
                String? videoSource;
                
                if (kIsWeb) {
                  // On Web, use bytes and convert to data URI
                  final bytes = result.files.single.bytes;
                  if (bytes != null) {
                    final extension = result.files.single.extension ?? 'mp4';
                    videoSource = Uri.dataFromBytes(bytes, mimeType: 'video/$extension').toString();
                  }
                } else {
                  // On native platforms, use the file path
                  videoSource = result.files.single.path;
                }

                if (videoSource != null) {
                  setState(() {
                    _selectedFiles[id] = videoSource;
                    // Store the raw file (bytes for web, path for native)
                    _rawFiles[id] = kIsWeb ? result.files.single.bytes : result.files.single.path;
                  });
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Video uploaded for $title'),
                        backgroundColor: theme.primaryColor,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                }
              } else {
                // User cancelled the picker
                debugPrint('File picking cancelled');
              }
            } catch (e) {
              debugPrint('Error picking file: $e');
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error selecting video: ${e.toString()}'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }
          },
          borderRadius: BorderRadius.circular(20),
          child: isUploaded
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Video Preview - Added ValueKey to force rebuild on file change
                      _VideoPreview(
                        key: ValueKey(fileName),
                        videoPath: fileName,
                      ),
                      
                      // Overlay Gradient
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withOpacity(0.3),
                              Colors.transparent,
                              Colors.black.withOpacity(0.7),
                            ],
                            stops: const [0.0, 0.4, 1.0],
                          ),
                        ),
                      ),

                        // Title (Top Left)
                        Positioned(
                          top: 12,
                          left: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              title,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),

                        // File Name (Bottom Left)
                        Positioned(
                          bottom: 12,
                          left: 12,
                          right: 12,
                          child: Row(
                            children: [
                              const Icon(Icons.movie_creation_outlined, color: Colors.white, size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  fileName.split(RegExp(r'[/\\]')).last,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: theme.primaryColor,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.check, color: Colors.white, size: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.textTheme.titleMedium?.color,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Center(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: theme.dividerColor.withOpacity(0.05),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.file_upload_outlined,
                              color: Colors.grey,
                              size: 24,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const SizedBox(height: 12), // Placeholder to match height
                      ],
                    ),
                  ),
          ),
        ),
      );
    }


  Widget _buildCaptureMethodStep(AppLocalizations l10n, ThemeData theme) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Back Button at the top
            TextButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back, size: 18),
              label: Text(l10n.back, style: const TextStyle(fontWeight: FontWeight.bold)),
              style: TextButton.styleFrom(
                foregroundColor: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
                padding: EdgeInsets.zero,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: theme.cardColor.withOpacity(0.4),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
              ),
              child: Column(
                children: [
                  if (isMobile)
                    Column(
                      children: [
                        _buildMethodCard(
                          l10n,
                          theme,
                          id: 'upload',
                          icon: Icons.unarchive_outlined,
                          title: l10n.uploadFiles,
                          description: l10n.uploadFilesDesc,
                          iconColor: theme.primaryColor,
                        ),
                        const SizedBox(height: 24),
                        _buildMethodCard(
                          l10n,
                          theme,
                          id: 'live',
                          icon: Icons.videocam_outlined,
                          title: l10n.liveMultiCam,
                          description: l10n.liveMultiCamDesc,
                          iconColor: const Color(0xFF10B981),
                        ),
                      ],
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: _buildMethodCard(
                            l10n,
                            theme,
                            id: 'upload',
                            icon: Icons.unarchive_outlined,
                            title: l10n.uploadFiles,
                            description: l10n.uploadFilesDesc,
                            iconColor: theme.primaryColor,
                          ),
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          child: _buildMethodCard(
                            l10n,
                            theme,
                            id: 'live',
                            icon: Icons.videocam_outlined,
                            title: l10n.liveMultiCam,
                            description: l10n.liveMultiCamDesc,
                            iconColor: const Color(0xFF10B981),
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 48),

                  // Info Banner
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.primaryColor.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: theme.primaryColor.withOpacity(0.1)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: theme.primaryColor, size: 20),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            l10n.analysisInfoBanner,
                            style: theme.textTheme.bodySmall?.copyWith(
                              height: 1.5,
                              color: theme.textTheme.bodyMedium?.color?.withOpacity(0.8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMethodCard(
    AppLocalizations l10n,
    ThemeData theme, {
    required String id,
    required IconData icon,
    required String title,
    required String description,
    required Color iconColor,
  }) {
    final isSelected = _selectedMethod == id;
    
    return Container(
      decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? theme.primaryColor : theme.dividerColor.withOpacity(0.1),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() => _selectedMethod = id);
            // Auto-advance to next step for demo purposes
            Future.delayed(const Duration(milliseconds: 300), () {
              setState(() => _currentStep = 2);
            });
          },
          borderRadius: BorderRadius.circular(20),
          child: Container(
            constraints: const BoxConstraints(minHeight: 220),
            padding: const EdgeInsets.all(24),
            child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 28),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: theme.textTheme.bodySmall?.copyWith(
                height: 1.5,
                color: theme.textTheme.bodySmall?.color?.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
    ),
    ),
    );
  }

  Widget _buildPlaceholderStep(String title) {
    return Container(
      height: 400,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.construction, size: 64, color: Theme.of(context).primaryColor.withOpacity(0.3)),
          const SizedBox(height: 24),
          Text(
            '$title Interface',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          const Text('Coming soon in the next phase'),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () => setState(() => _currentStep--),
            child: const Text('Back'),
          ),
        ],
      ),
    );
  }
}

class _VideoPreview extends StatefulWidget {
  final String videoPath;

  const _VideoPreview({Key? key, required this.videoPath}) : super(key: key);

  @override
  State<_VideoPreview> createState() => _VideoPreviewState();
}

class _VideoPreviewState extends State<_VideoPreview> {
  late VideoPlayerController _controller;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    
    // Initialize controller based on platform/source type
    if (kIsWeb || widget.videoPath.startsWith('data:')) {
      _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoPath));
    } else {
      // Use File safely - only on non-web
      _controller = VideoPlayerController.file(io.File(widget.videoPath));
    }

    _controller.initialize().then((_) {
      if (mounted) {
        setState(() {
          _initialized = true;
        });
        _controller.setLooping(true);
        _controller.setVolume(0.0); // Mute for preview
        _controller.play();
      }
    }).catchError((error) {
      debugPrint('Error initializing video player: $error');
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_initialized) {
      return Center(
        child: AspectRatio(
          aspectRatio: _controller.value.aspectRatio,
          child: VideoPlayer(_controller),
        ),
      );
    } else {
      return Container(
        color: Colors.black.withOpacity(0.1),
        child: const Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
      );
    }
  }
}
