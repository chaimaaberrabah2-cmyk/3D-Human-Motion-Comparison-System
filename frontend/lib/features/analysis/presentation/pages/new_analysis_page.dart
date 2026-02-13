import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:file_picker/file_picker.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../home/presentation/widgets/home_sidebar.dart';

class NewAnalysisPage extends StatefulWidget {
  const NewAnalysisPage({Key? key}) : super(key: key);

  @override
  State<NewAnalysisPage> createState() => _NewAnalysisPageState();
}

class _NewAnalysisPageState extends State<NewAnalysisPage> {
  int _currentStep = 1;
  String? _selectedMethod;
  final Map<String, String?> _selectedFiles = {};

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
                    _buildStepIndicator(l10n, theme),
                    
                    // Main Content
                    Expanded(
                      child: isDesktop
                          ? Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 0),
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
        return _buildUploadStreamsStep(l10n, theme);
      case 3:
        return _buildPlaceholderStep(l10n.syncAndProcess);
      default:
        return Container();
    }
  }

  Widget _buildUploadStreamsStep(AppLocalizations l10n, ThemeData theme) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;

        return Column(
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
                ],
              ),
            ),
          ],
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
                type: FileType.video,
                allowMultiple: false,
              );

              if (result != null && result.files.single.name.isNotEmpty) {
                setState(() {
                  _selectedFiles[id] = result.files.single.name;
                });

                // If all 4 are selected, auto-advance for demo
                if (_selectedFiles.length == 4) {
                  Future.delayed(const Duration(seconds: 1), () {
                    if (mounted) setState(() => _currentStep = 3);
                  });
                }
              }
            } catch (e) {
              debugPrint('Error picking file: $e');
              // Optionally show a snackbar to the user
            }
          },
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isUploaded ? theme.primaryColor : theme.textTheme.titleMedium?.color,
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
                      color: isUploaded ? theme.primaryColor.withOpacity(0.1) : theme.dividerColor.withOpacity(0.05),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isUploaded ? Icons.check : Icons.file_upload_outlined,
                      color: isUploaded ? theme.primaryColor : Colors.grey,
                      size: 24,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                if (isUploaded)
                  Center(
                    child: Text(
                      fileName,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.primaryColor,
                        fontWeight: FontWeight.w500,
                        fontSize: 10,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  )
                else
                  const SizedBox(height: 12),
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
