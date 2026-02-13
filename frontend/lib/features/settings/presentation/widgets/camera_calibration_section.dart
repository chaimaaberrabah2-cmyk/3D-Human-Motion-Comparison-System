import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../../l10n/app_localizations.dart';

class CameraCalibrationSection extends StatefulWidget {
  const CameraCalibrationSection({Key? key}) : super(key: key);

  @override
  State<CameraCalibrationSection> createState() => _CameraCalibrationSectionState();
}

class _CameraCalibrationSectionState extends State<CameraCalibrationSection> {
  String? modifyingCamera;
  List<CameraDescription> _availableCameras = [];
  CameraController? _controller;
  bool _isCameraInitialized = false;
  String? _errorMessage;
  
  // Per-camera settings storage
  // Key: Camera Name (e.g. 'Motion Cam 1'), Value: Map of settings
  final Map<String, Map<String, dynamic>> _cameraSettings = {
    'Motion Cam 1': {'source': 'Camera Source A (FHD)', 'isUploaded': true, 'file': 'calib_001.bin'},
    'Motion Cam 2': {'source': 'Camera Source B (HD)', 'isUploaded': true, 'file': 'calib_002.bin'},
    'Motion Cam 3': {'source': 'External USB Camera', 'isUploaded': false, 'file': null},
    'Motion Cam 4': {'source': 'Virtual Stream 01', 'isUploaded': false, 'file': null},
  };

  // Temporary state for the modify view
  String _tempSelectedSource = '';
  bool _tempIsUploaded = false;
  String? _tempFile;
  
  // Static sources for the UI
  final List<String> _staticSources = [
    'Camera Source A (FHD)',
    'Camera Source B (HD)',
    'External USB Camera',
    'Virtual Stream 01'
  ];

  @override
  void initState() {
    super.initState();
    _discoverCameras();
  }

  Future<void> _discoverCameras() async {
    setState(() {
      _errorMessage = null;
    });

    // Explicitly check/request permission
    final status = await Permission.camera.request();
    if (status.isDenied || status.isPermanentlyDenied) {
      if (mounted) {
        setState(() {
          _errorMessage = "Camera permission is required to use this feature.";
        });
      }
      return;
    }

    try {
      final cameras = await availableCameras();
      if (mounted) {
        setState(() {
          _availableCameras = cameras;
          // We don't automatically set selectedDevice here anymore, 
          // it's managed per camera.
          if (cameras.isEmpty) {
             _errorMessage = "No internal or external cameras were found by the system.";
          }
        });
      }
    } catch (e) {
      debugPrint('Error discovering cameras: $e');
      if (mounted) {
        setState(() {
          if (e.toString().contains('MissingPluginException')) {
             _errorMessage = "Plugin not initialized. Please STOP the app and run 'flutter run' again.";
          } else {
             _errorMessage = "Could not access hardware. Please ensure camera permissions are granted in System Settings.";
          }
        });
      }
    }
  }

  Future<void> _initializeCameraController(CameraDescription camera) async {
    // If we have an existing controller, dispose of it first
    if (_controller != null) {
      await _controller!.dispose();
    }

    _controller = CameraController(
      camera,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    try {
      await _controller!.initialize();
      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
        });
      }
    } catch (e) {
      debugPrint('Error initializing camera: $e');
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    if (modifyingCamera != null) {
      return _buildModifyView(context, l10n, theme);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Title
        Text(
          l10n.deepLearningBackend,
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.textTheme.bodyMedium?.color,
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Cameras Container (Hardcoded for management, but source will be real)
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.dividerColor),
          ),
          child: Column(
            children: [
              _buildCameraManagementItem(context, 'Motion Cam 1'),
              const SizedBox(height: 16),
              _buildCameraManagementItem(context, 'Motion Cam 2'),
              const SizedBox(height: 16),
              _buildCameraManagementItem(context, 'Motion Cam 3'),
              const SizedBox(height: 16),
              _buildCameraManagementItem(context, 'Motion Cam 4'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildModifyView(BuildContext context, AppLocalizations l10n, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Camera Preview Rectangle
        Container(
          width: double.infinity,
          height: 250,
          margin: const EdgeInsets.only(bottom: 24),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.primaryColor, width: 2),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (_isCameraInitialized && _controller != null)
                CameraPreview(_controller!)
              else
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.videocam_off_outlined,
                        color: theme.primaryColor.withOpacity(0.5),
                        size: 48,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'SELECT A SOURCE TO START PREVIEW',
                        style: TextStyle(
                          color: theme.primaryColor.withOpacity(0.7),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              Positioned(
                top: 16,
                left: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: theme.primaryColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'LIVE PREVIEW',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Settings Area
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.dividerColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with Back Button
              Row(
                children: [
                  IconButton(
                    onPressed: () {
                      _controller?.dispose();
                      _controller = null;
                      _isCameraInitialized = false;
                      setState(() => modifyingCamera = null);
                    },
                    icon: const Icon(Icons.arrow_back_ios, size: 18),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.modifyCamera(modifyingCamera!),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          l10n.updateDeviceSource,
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 32),
              
              // 1. CHOOSE CAMERA SOURCE
              Text(
                l10n.chooseCameraSource,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 16),
              
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _staticSources.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final source = _staticSources[index];
                  return _buildStaticSourceItem(context, source);
                },
              ),

              const SizedBox(height: 32),
              const Divider(),
              const SizedBox(height: 32),

              // 2. ADD CALIBRATION DATA
              Text(
                l10n.addCalibrationData,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 16),
              
              // Upload Area
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 32),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: theme.dividerColor,
                    style: BorderStyle.none, // Corrected from typo
                  ),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: theme.dividerColor),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.primaryColor.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.cloud_upload_outlined, color: theme.primaryColor),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        l10n.clickToUpload,
                        style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        l10n.uploadDesc,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),

              if (_tempIsUploaded) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF10B981).withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.videocam_outlined, color: Color(0xFF10B981), size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _tempFile ?? 'calibration.bin',
                          style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.w500),
                        ),
                      ),
                      IconButton(
                        onPressed: () => setState(() => _tempIsUploaded = false),
                        icon: const Icon(Icons.delete_outline, color: Colors.grey, size: 20),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 32),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                         // SAVE changes to the map
                         _cameraSettings[modifyingCamera!] = {
                           'source': _tempSelectedSource,
                           'isUploaded': _tempIsUploaded,
                           'file': _tempIsUploaded ? (_tempFile ?? 'calibration.bin') : null,
                         };

                         _controller?.dispose();
                         _controller = null;
                         _isCameraInitialized = false;
                        setState(() => modifyingCamera = null);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        l10n.applyChanges,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  TextButton(
                    onPressed: () {
                      // DISCARD changes (just close)
                      _controller?.dispose();
                      _controller = null;
                      _isCameraInitialized = false;
                      setState(() => modifyingCamera = null);
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    ),
                    child: Text(
                      l10n.cancel,
                      style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStaticSourceItem(BuildContext context, String sourceName) {
    final theme = Theme.of(context);
    final isSelected = _tempSelectedSource == sourceName;

    return InkWell(
      onTap: () async {
        setState(() {
          _tempSelectedSource = sourceName;
        });
        
        // If we have real hardware discovered, let's use the first one for the preview
        // to keep the "Live Preview" functional as requested.
        if (_availableCameras.isNotEmpty && !_isCameraInitialized) {
          await _initializeCameraController(_availableCameras.first);
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? theme.primaryColor.withOpacity(0.05) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? theme.primaryColor : theme.dividerColor,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.videocam_outlined,
              size: 20,
              color: isSelected ? theme.primaryColor : (theme.textTheme.bodyMedium?.color ?? Colors.grey),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                sourceName,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? theme.primaryColor : theme.textTheme.bodyLarge?.color,
                ),
              ),
            ),
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? theme.primaryColor : theme.dividerColor,
                  width: 2,
                ),
              ),
              child: isSelected ? Center(
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: theme.primaryColor,
                    shape: BoxShape.circle,
                  ),
                ),
              ) : null,
            ),
          ],
        ),
      ),
    );
  }

  String _formatCameraName(CameraDescription camera) {
    String lens = '';
    switch (camera.lensDirection) {
      case CameraLensDirection.front:
        lens = ' (Front)';
        break;
      case CameraLensDirection.back:
        lens = ' (Back)';
        break;
      case CameraLensDirection.external:
        lens = ' (External)';
        break;
    }
    return '${camera.name}$lens';
  }

  Widget _buildCameraManagementItem(BuildContext context, String cameraName) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: theme.cardColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.dividerColor),
            ),
            child: Center(
              child: SvgPicture.asset(
                'assets/icons/video.svg',
                width: 24,
                height: 24,
                colorFilter: ColorFilter.mode(
                  theme.textTheme.bodyMedium?.color ?? Colors.grey,
                  BlendMode.srcIn,
                ),
              ),
            ),
          ),
          
          const SizedBox(width: 16),
          
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cameraName,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      '${l10n.status}: ',
                      style: theme.textTheme.bodySmall?.copyWith(
                         color: theme.textTheme.bodyMedium?.color,
                      ),
                    ),
                    Text(
                      l10n.calibrated,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF10B981),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: theme.primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _cameraSettings[cameraName]?['source'] ?? 'No Source',
                        style: TextStyle(
                          color: theme.primaryColor,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          IconButton(
            onPressed: () {
              _discoverCameras();
              setState(() {
                modifyingCamera = cameraName;
                // Initialize temporary state from current settings
                final settings = _cameraSettings[cameraName]!;
                _tempSelectedSource = settings['source'];
                _tempIsUploaded = settings['isUploaded'];
                _tempFile = settings['file'];
              });
            },
            icon: SvgPicture.asset(
              'assets/icons/edit.svg',
              width: 20,
              height: 20,
              colorFilter: ColorFilter.mode(
                theme.textTheme.bodyMedium?.color ?? Colors.grey,
                BlendMode.srcIn,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
