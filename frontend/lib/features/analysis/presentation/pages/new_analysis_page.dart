import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' as io;
import 'dart:async';
import 'package:video_player/video_player.dart';
import 'package:file_picker/file_picker.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../home/presentation/widgets/home_sidebar.dart';
import '../../../home/domain/entities/exercise.dart';
import '../../data/datasources/analysis_remote_datasource.dart';
import '../../data/repositories/analysis_repository_impl.dart';

class NewAnalysisPage extends StatefulWidget {
  const NewAnalysisPage({Key? key}) : super(key: key);

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

  // Processing state
  bool _isProcessing = false;
  double _processingProgress = 0.0;
  String _processingStatus = 'Initializing...';

  Exercise? _selectedExercise;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth > 1200;

          return Row(
            children: [
              if (isDesktop) const HomeSidebar(),
              Expanded(
                child: Column(
                  children: [
                    // Header
                    _buildHeader(l10n, theme),
                    
                    // Step Indicator
                    if (_currentStep != 4) _buildStepIndicator(l10n, theme),
                    
                    // Main Content
                    Expanded(
                      child: isDesktop
                          ? SingleChildScrollView(
                              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
                              child: Center(
                                child: constraints.maxWidth > 1000
                                    ? SizedBox(width: 800, child: _buildStepContent(l10n, theme))
                                    : _buildStepContent(l10n, theme),
                              ),
                            )
                          : SingleChildScrollView(
                              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
                              child: Center(
                                child: _buildStepContent(l10n, theme),
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
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
        Text(
          label,
          style: TextStyle(
            color: isActive ? theme.primaryColor : Colors.grey,
            fontSize: 12,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
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
      _processingStatus = 'Connecting to backend...';
      _currentStep = 3;
    });

    try {
      if (!mounted) return;
      setState(() {
        _processingStatus = 'Connecting to backend...';
        _processingProgress = 0.05;
      });

      // Real API Call to FastAPI Backend
      final dataSource = AnalysisRemoteDataSource();
      final repository = AnalysisRepositoryImpl(remoteDataSource: dataSource);
      
      final sessionId = await repository.analyzeVideos(videos: _rawFiles);

      // Simulation of a realistic extraction process for 4 videos (Total 20% progress)
      for (int i = 1; i <= 4; i++) {
        for (int p = 1; p <= 10; p++) {
          await Future.delayed(const Duration(milliseconds: 300));
          if (!mounted) return;
          setState(() {
            // Each camera angle takes 5% of total progress (4 * 5 = 20%)
            _processingProgress = 0.05 + ((i - 1) * 0.03) + (p * 0.002);
            _processingStatus = 'Extracting frames from Camera Angle $i... (${(_processingProgress * 100).toInt()}%)';
          });
        }
      }

      if (!mounted) return;
      setState(() {
        _processingStatus = 'Extraction complete for all videos ($sessionId)';
        _processingProgress = 0.20; // Correctly stop at 20% for now
        _isProcessing = false;
        // Stay on this screen as requested
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _processingStatus = 'Error: ${e.toString()}';
        });
      }
    }
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
              l10n.remainingTimeLabel(((1 - _processingProgress) * 40).toInt()),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.textTheme.bodyMedium?.color?.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 40),
            
            // Mimic AI logs/activity
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLogLine(l10n.logAnalysisStarted, timestamp: '00:00:00'),
                  if (_processingProgress > 0.1)
                    _buildLogLine(l10n.logSyncOk, timestamp: '00:00:04'),
                  // Future steps hidden as requested
                ],
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
    return SingleChildScrollView(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ElevatedButton.icon(
                onPressed: () {
                  // RESET for demo
                  setState(() {
                    _currentStep = 1;
                    _selectedFiles.updateAll((key, value) => null);
                    _rawFiles.updateAll((key, value) => null);
                    _selectedMethod = 'upload';
                    _selectedExercise = null;
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left: Exercise Selection
              Expanded(
                flex: 1,
                child: _buildExerciseSelector(theme),
              ),
              const SizedBox(width: 24),
              // Right: User SMPL Preview
              Expanded(
                flex: 1,
                child: _buildSMPLPreview(theme),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Bottom: Analysis Results Section
          _buildAnalysisOverview(theme),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildExerciseSelector(ThemeData theme) {
    final l10n = AppLocalizations.of(context)!;
    final exercises = getMockExercises();

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
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Placeholder for SMPL model - using a high-quality stylized image look
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.accessibility_new,
                    size: 120,
                    color: theme.dividerColor.withOpacity(0.1),
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
            // Subtle "PRO" or "LIVE" tag if needed
          ],
        ),
      ),
    );
  }

  Widget _buildAnalysisOverview(ThemeData theme) {
    final l10n = AppLocalizations.of(context)!;
    // Mock score for demo
    const double accuracyScore = 0.85;

    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Score Circle
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 80,
                height: 80,
                child: CircularProgressIndicator(
                  value: accuracyScore,
                  strokeWidth: 8,
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
                      fontSize: 18,
                    ),
                  ),
                  Text(
                    l10n.score,
                    style: TextStyle(
                      color: theme.textTheme.bodyMedium?.color?.withOpacity(0.5),
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(width: 32),
          // Analysis Text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.analysisResultsTitle,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _selectedExercise == null
                      ? l10n.pleaseSelectExercise
                      : l10n.analysisFeedback(_selectedExercise!.name),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  onPressed: () {
                    // Placeholder for PDF export
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l10n.exportingPdfMessage)),
                    );
                  },
                  icon: const Icon(Icons.picture_as_pdf, size: 18),
                  label: Text(l10n.exportPdf),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: theme.primaryColor,
                    side: BorderSide(color: theme.primaryColor.withOpacity(0.2)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ),
        ],
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
                        _buildUploadCard(l10n, theme, 'angle_1', l10n.cameraAngleFront),
                        _buildUploadCard(l10n, theme, 'angle_2', l10n.cameraAngleLeft),
                        _buildUploadCard(l10n, theme, 'angle_3', l10n.cameraAngleBack),
                        _buildUploadCard(l10n, theme, 'angle_4', l10n.cameraAngleRight),
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
    
    return InkWell(
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
