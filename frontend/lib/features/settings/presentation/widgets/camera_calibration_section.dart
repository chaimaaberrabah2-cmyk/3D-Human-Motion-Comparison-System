import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:file_picker/file_picker.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:cross_file/cross_file.dart';
import '../../../../l10n/app_localizations.dart';

class CameraCalibrationSection extends StatefulWidget {
  const CameraCalibrationSection({Key? key}) : super(key: key);

  @override
  CameraCalibrationSectionState createState() => CameraCalibrationSectionState();
}

class CameraCalibrationSectionState extends State<CameraCalibrationSection> {
  String? modifyingCamera;

  void resetView() {
    if (modifyingCamera != null) {
      setState(() {
        modifyingCamera = null;
        _controller?.dispose();
        _controller = null;
        _isCameraInitialized = false;
      });
    }
  }
  List<CameraDescription> _availableCameras = [];
  CameraController? _controller;
  bool _isCameraInitialized = false;
  String? _errorMessage;
  
  // Camera model class for better structure
  int _cameraCounter = 4; // Start from 5 for new cameras
  
  // Dynamic camera list
  List<Map<String, dynamic>> _cameras = [
    {'id': '1', 'name': 'Motion Cam 1', 'source': 'Camera Source A (FHD)', 'isUploaded': true, 'file': 'calib_001.bin'},
    {'id': '2', 'name': 'Motion Cam 2', 'source': 'Camera Source B (HD)', 'isUploaded': true, 'file': 'calib_002.bin'},
    {'id': '3', 'name': 'Motion Cam 3', 'source': 'External USB Camera', 'isUploaded': false, 'file': null},
    {'id': '4', 'name': 'Motion Cam 4', 'source': 'Virtual Stream 01', 'isUploaded': false, 'file': null},
  ];

  // Temporary state for the modify view
  String _tempSelectedSource = '';
  bool _tempIsUploaded = false;
  String? _tempFile;
  
  // Shared calibration state (applies to all cameras)
  String _selectedSource = 'Camera Source A (FHD)';
  bool _isCalibrationUploaded = false;
  String? _calibrationFile;
  
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
        // Section Title with Add Button
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l10n.deepLearningBackend,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.textTheme.bodyMedium?.color,
              ),
            ),
            ElevatedButton.icon(
              onPressed: _addNewCamera,
              icon: const Icon(Icons.add, size: 18),
              label: Text(l10n.addNewCamera),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 16),
        
        // Cameras Container (Dynamic)
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.dividerColor),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _cameras.length,
            separatorBuilder: (_, __) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final camera = _cameras[index];
              return _buildCameraManagementItem(context, camera);
            },
          ),
        ),
        
        const SizedBox(height: 32),
        
        // Shared Calibration Section
        _buildSharedCalibrationSection(l10n, theme),
      ],
    );
  }

  void _addNewCamera() {
    setState(() {
      _cameraCounter++;
      _cameras.add({
        'id': _cameraCounter.toString(),
        'name': 'Motion Cam $_cameraCounter',
        'source': 'Camera Source A (FHD)',
        'isUploaded': false,
        'file': null,
      });
    });
  }

  Future<void> _deleteCamera(Map<String, dynamic> camera) async {
    final l10n = AppLocalizations.of(context)!;
    
    // Check minimum cameras
    if (_cameras.length <= 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.minimumCamerasWarning),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteCameraTitle),
        content: Text(l10n.deleteCameraMessage(camera['name'])),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        _cameras.remove(camera);
      });
    }
  }

  Widget _buildModifyView(BuildContext context, AppLocalizations l10n, ThemeData theme) {
    // Find the camera being modified
    final camera = _cameras.firstWhere(
      (c) => c['name'] == modifyingCamera,
      orElse: () => _cameras.first,
    );

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
              /* 
               * Calibration section removed as per new design request.
               * Calibration is now handled globally in the main view.
               */

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                         // SAVE changes to the camera source only
                         final cameraIndex = _cameras.indexWhere((c) => c['name'] == modifyingCamera);
                         if (cameraIndex != -1) {
                           _cameras[cameraIndex] = {
                             ..._cameras[cameraIndex],
                             'source': _tempSelectedSource,
                           };
                         }

                         _controller?.dispose();
                         _controller = null;
                         _isCameraInitialized = false;
                        setState(() => modifyingCamera = null);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        l10n.applyChanges,
                        style: const TextStyle(fontWeight: FontWeight.bold),
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
                      foregroundColor: theme.textTheme.bodyMedium?.color,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    ),
                    child: Text(
                      l10n.cancel,
                      style: const TextStyle(fontWeight: FontWeight.bold),
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

  Widget _buildCameraManagementItem(BuildContext context, Map<String, dynamic> camera) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final canDelete = _cameras.length > 4;

    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
         // Use dark slate for dark mode, white/card color for light mode
        color: isDark ? const Color(0xFF1E293B) : theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark 
              ? theme.dividerColor.withOpacity(0.5) 
              : theme.dividerColor,
        ),
      ),
      child: Row(
        children: [
          // Camera Icon on the left
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: theme.primaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: SvgPicture.asset(
              'assets/icons/video.svg',
              width: 20,
              height: 20,
              colorFilter: ColorFilter.mode(
                theme.primaryColor,
                BlendMode.srcIn,
              ),
            ),
          ),
          
          const SizedBox(width: 16),
          
          // Name and Status
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  camera['name'],
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                Text(
                  l10n.statusCalibrated,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF10B981), // Green text
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          
          // Delete Button (subtle)
          if (canDelete)
            IconButton(
              onPressed: () => _deleteCamera(camera),
              icon: Icon(
                Icons.delete_outline,
                size: 20,
                color: theme.textTheme.bodyMedium?.color?.withOpacity(0.5),
              ),
              tooltip: l10n.delete,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            ),
          
          const SizedBox(width: 4),
          
          // Edit Icon (pencil) on the right
          IconButton(
            onPressed: () {
              _discoverCameras();
              setState(() {
                modifyingCamera = camera['name'];
                _tempSelectedSource = camera['source'];
                _tempIsUploaded = camera['isUploaded'];
                _tempFile = camera['file'];
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
            tooltip: l10n.modifyCamera(camera['name']),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          ),
        ],
      ),
    );
  }

  Widget _buildSharedCalibrationSection(AppLocalizations l10n, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header
          Text(
            '2. ${l10n.addCalibrationData}',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Drag and Drop Upload Area
          _isCalibrationUploaded
              ? Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.insert_drive_file,
                          color: Color(0xFF10B981),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _calibrationFile ?? 'calib_001.bin',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.textTheme.bodyLarge?.color,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 20),
                        onPressed: () {
                          setState(() {
                            _isCalibrationUploaded = false;
                            _calibrationFile = null;
                          });
                        },
                        color: theme.textTheme.bodyMedium?.color,
                        tooltip: l10n.delete,
                      ),
                    ],
                  ),
                )
              : DropTarget(
                  onDragDone: (detail) {
                    if (detail.files.isNotEmpty) {
                      setState(() {
                        _isCalibrationUploaded = true;
                        _calibrationFile = detail.files.first.name;
                      });
                    }
                  },
                  onDragEntered: (detail) {
                    setState(() {
                      // optional: add visual feedback state
                    });
                  },
                  onDragExited: (detail) {
                    setState(() {
                      // optional: remove visual feedback state
                    });
                  },
                  child: InkWell(
                    onTap: _pickCalibrationFile,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
                      decoration: BoxDecoration(
                        color: theme.brightness == Brightness.dark 
                            ? theme.scaffoldBackgroundColor.withOpacity(0.5)
                            : theme.scaffoldBackgroundColor, // Solid background for light mode
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: theme.dividerColor,
                          width: 2,
                          strokeAlign: BorderSide.strokeAlignInside,
                        ),
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: theme.primaryColor.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.cloud_upload_outlined,
                              size: 32,
                              color: theme.primaryColor,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            l10n.clickToUpload,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.textTheme.bodyLarge?.color,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            l10n.dragDropHint,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
          
          const SizedBox(height: 24),
          
          // Action Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () {
                  setState(() {
                    _isCalibrationUploaded = false;
                    _calibrationFile = null;
                  });
                },
                style: TextButton.styleFrom(
                  foregroundColor: theme.textTheme.bodyMedium?.color,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: Text(l10n.cancel),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: _isCalibrationUploaded
                    ? () {
                        // Simulate file upload
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(l10n.saveSettings)),
                        );
                      }
                    : () {
                        // Simulate file selection
                        setState(() {
                          _isCalibrationUploaded = true;
                          _calibrationFile = 'calib_001.bin';
                        });
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  _isCalibrationUploaded ? l10n.applyChanges : l10n.uploadCalibration,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _pickCalibrationFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['bin', 'json', 'yml', 'yaml'],
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (mounted) {
          setState(() {
            _isCalibrationUploaded = true;
            _calibrationFile = file.name;
          });
        }
      }
    } catch (e) {
      debugPrint('Error picking file: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking file: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
