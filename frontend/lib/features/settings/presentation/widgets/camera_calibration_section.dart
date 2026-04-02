import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:camera/camera.dart';
import 'package:camera_macos/camera_macos.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:file_picker/file_picker.dart';
import 'package:desktop_drop/desktop_drop.dart';
import '../../../../l10n/app_localizations.dart';

class CameraCalibrationSection extends StatefulWidget {
  const CameraCalibrationSection({Key? key}) : super(key: key);

  @override
  CameraCalibrationSectionState createState() =>
      CameraCalibrationSectionState();
}

class CameraCalibrationSectionState extends State<CameraCalibrationSection> {
  String? modifyingCamera;

  void resetView() {
    if (modifyingCamera != null) {
      setState(() {
        modifyingCamera = null;
        _controller?.dispose();
        _controller = null;
        _macOsController?.destroy();
        _macOsController = null;
        _isCameraInitialized = false;
      });
    }
  }

  // --- EXPLICATION POUR LA COMMISSION (ARCHITECTURE HYBRIDE) ---
  // Nous utilisons deux listes et deux contrôleurs différents car Flutter ne gère pas
  // la caméra macOS nativement. Cette séparation permet à l'application de fonctionner 
  // sur toutes les plateformes de façon transparente (Mac, iOS, Android).

  // 1. Liste et Contrôleur standards (pour Android, iOS, Web) issus du plugin officiel
  List<CameraDescription> _availableCameras = [];
  CameraController? _controller;

  // 2. Liste et Contrôleur spécifiques pour macOS (via le plugin 'camera_macos' AVFoundation)
  List<CameraMacOSDevice> _availableMacOsCameras = [];
  CameraMacOSController? _macOsController;

  bool _isCameraInitialized = false;
  String? _errorMessage;

  // Counter to add new cameras
  int _cameraCounter = 4;
  bool _isDiscovering = false;

  // Initial 4 fake camera slots
  List<Map<String, dynamic>> _cameras = [
    {
      'id': '1',
      'name': 'Motion Cam 1',
      'source': 'Unassigned',
      'isUploaded': true,
      'file': 'calib_001.bin'
    },
    {
      'id': '2',
      'name': 'Motion Cam 2',
      'source': 'Unassigned',
      'isUploaded': true,
      'file': 'calib_002.bin'
    },
    {
      'id': '3',
      'name': 'Motion Cam 3',
      'source': 'Unassigned',
      'isUploaded': false,
      'file': null
    },
    {
      'id': '4',
      'name': 'Motion Cam 4',
      'source': 'Unassigned',
      'isUploaded': false,
      'file': null
    },
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
      _isDiscovering = true; // Affiche l'icône de chargement circulaire
    });

    // --- BRANCHE DÉCOUVERTE 1 : EXÉCUTION SUR MACOS ---
    // La méthode Platform.isMacOS retourne 'true' si l'app tourne sur un Mac.
    if (Platform.isMacOS) {
      try {
        // Au lieu d'utiliser availableCameras() (optimisé Mobile), on lance
        // notre propre pont natif (créé dans Swift) car le plugin camera_macos a un bug avec les iPhone et virtuels.
        const channel = MethodChannel('com.ikram.camera/discovery');
        final List<dynamic> resultDevices = await channel.invokeMethod('getModernCameras');
        
        final List<CameraMacOSDevice> devices = resultDevices.map((data) => CameraMacOSDevice(
          deviceId: data['deviceId'],
          localizedName: data['localizedName'],
          deviceType: CameraMacOSDeviceType.video,
        )).toList();

        if (mounted) {
          setState(() {
            _availableMacOsCameras = devices; // Sauvegarde des résultats hardware
            if (devices.isEmpty) {
              _errorMessage = "Aucune caméra matérielle touvée par le système macOS.";
            }
          });
        }
      } catch (e) {
        debugPrint('Error discovering macOS cameras: $e');
        if (mounted) {
          setState(() {
             _errorMessage = "Impossible d'accéder au matériel macOS.";
          });
        }
      } finally {
        if (mounted) setState(() => _isDiscovering = false);
      }
      return; // Fin de la procédure pour le Mac
    }

    // --- BRANCHE DÉCOUVERTE 2 : EXÉCUTION SUR ANDROID / IOS ---
    if (!Platform.isMacOS) {
      final status = await Permission.camera.request();
      if (status.isDenied || status.isPermanentlyDenied) {
        if (mounted) {
          setState(() {
            _errorMessage = "Camera permission is required to use this feature.";
            _isDiscovering = false;
          });
        }
        return;
      }
    }

    try {
      final cameras = await availableCameras();
      if (mounted) {
        setState(() {
          _availableCameras = cameras;
          if (cameras.isEmpty) {
            _errorMessage = "No hardware cameras found by the system.";
          }
        });
      }
    } catch (e) {
      debugPrint('Error discovering cameras: $e');
      if (mounted) {
        setState(() {
          if (e.toString().contains('MissingPluginException')) {
            _errorMessage = "MissingPluginException. Run 'flutter clean' and 'flutter run macos' in terminal.";
          } else {
            _errorMessage = "Could not access hardware.";
          }
        });
      }
    } finally {
      if (mounted) setState(() => _isDiscovering = false);
    }
  }

  Future<void> _initializeCameraController(CameraDescription camera) async {
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
        setState(() => _isCameraInitialized = true);
      }
    } catch (e) {
      debugPrint('Error initializing camera: $e');
    }
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

  @override
  void dispose() {
    _controller?.dispose();
    _macOsController?.destroy();
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

        // Cameras Container
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
        'source': 'Unassigned',
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

  Widget _buildModifyView(
      BuildContext context, AppLocalizations l10n, ThemeData theme) {
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
              // --- AFFICHAGE NATIVITÉ DU RETOUR VIDÉO (LIVE PREVIEW) ---
              // L'interface choisit dynamiquement quel composant dessiner pour afficher le flux 
              if (Platform.isMacOS && _tempSelectedSource.isNotEmpty && _tempSelectedSource != 'Unassigned')
                // 1. Sur Mac : CameraMacOSView convertit le flux AVFoundation en Texture graphique.
                CameraMacOSView(
                  key: ObjectKey(_tempSelectedSource), // Force la réinitialisation graphique de la vue si on change de caméra
                  deviceId: _availableMacOsCameras.firstWhere((c) => (c.localizedName ?? c.deviceId) == _tempSelectedSource, orElse: () => _availableMacOsCameras.first).deviceId,
                  cameraMode: CameraMacOSMode.video,
                  onCameraInizialized: (CameraMacOSController c) {
                    setState(() {
                      _macOsController = c;
                      _isCameraInitialized = true;
                    });
                  },
                )
              else if (!Platform.isMacOS && _isCameraInitialized && _controller != null)
                // 2. Sur Mobile : On dessine le composant CameraPreview fourni par Google.
                CameraPreview(_controller!)
              else
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.videocam_off_outlined,
                        color: theme.primaryColor.withValues(alpha: 0.5),
                        size: 48,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'SELECT A SOURCE TO START PREVIEW',
                        style: TextStyle(
                          color: theme.primaryColor.withValues(alpha: 0.7),
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                      _macOsController?.destroy();
                      _macOsController = null;
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

              // 1. CHOOSE CAMERA SOURCE — Real Cameras
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l10n.chooseCameraSource,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _discoverCameras,
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Refresh'),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              if (_isDiscovering)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if ((Platform.isMacOS && _availableMacOsCameras.isEmpty) || (!Platform.isMacOS && _availableCameras.isEmpty))
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_outlined, color: Colors.orange, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'No cameras detected',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.orange,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Connect a USB or built-in camera and tap Refresh.',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )
              else if (Platform.isMacOS)
                // --- BOUCLAGE D'AFFICHAGE MACOS ---
                // On boucle sur tous les périphériques matériels trouvés, et on crée un conteneur UI (bouton) pour chacun
                Column(
                  children: [
                    ..._availableMacOsCameras.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final cam = entry.value;
                      // Extraction du nom de l'appareil (ex: 'Facetime HD Camera') ou de son ID technique en secours.
                      final displayName = cam.localizedName ?? cam.deviceId ?? 'Unknown Camera';
                      final isSelected = _tempSelectedSource == displayName;
                      return Padding(
                        padding: EdgeInsets.only(bottom: idx < _availableMacOsCameras.length - 1 ? 8 : 0),
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _tempSelectedSource = displayName;
                              _isCameraInitialized = false;
                              _macOsController?.destroy();
                              _macOsController = null;
                            });
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? theme.primaryColor.withValues(alpha: 0.05)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected ? theme.primaryColor : theme.dividerColor,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.camera_alt_outlined,
                                  size: 20,
                                  color: isSelected
                                      ? theme.primaryColor
                                      : (theme.textTheme.bodyMedium?.color ?? Colors.grey),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        displayName,
                                        style: theme.textTheme.bodyMedium?.copyWith(
                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                          color: isSelected
                                              ? theme.primaryColor
                                              : theme.textTheme.bodyLarge?.color,
                                        ),
                                      ),
                                      Text(
                                        'macOS Camera Device',
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
                                        ),
                                      ),
                                    ],
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
                                  child: isSelected
                                      ? Center(
                                          child: Container(
                                            width: 10,
                                            height: 10,
                                            decoration: BoxDecoration(
                                              color: theme.primaryColor,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                        )
                                      : null,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                )
              else
                Column(
                  children: [
                    ..._availableCameras.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final cam = entry.value;
                      final displayName = _formatCameraName(cam);
                      final isSelected = _tempSelectedSource == displayName;
                      return Padding(
                        padding: EdgeInsets.only(bottom: idx < _availableCameras.length - 1 ? 8 : 0),
                        child: InkWell(
                          onTap: () async {
                            setState(() {
                              _tempSelectedSource = displayName;
                              _isCameraInitialized = false;
                            });
                            await _initializeCameraController(cam);
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? theme.primaryColor.withValues(alpha: 0.05)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected ? theme.primaryColor : theme.dividerColor,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  cam.lensDirection == CameraLensDirection.external
                                      ? Icons.usb
                                      : Icons.videocam_outlined,
                                  size: 20,
                                  color: isSelected
                                      ? theme.primaryColor
                                      : (theme.textTheme.bodyMedium?.color ?? Colors.grey),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        displayName,
                                        style: theme.textTheme.bodyMedium?.copyWith(
                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                          color: isSelected
                                              ? theme.primaryColor
                                              : theme.textTheme.bodyLarge?.color,
                                        ),
                                      ),
                                      Text(
                                        cam.lensDirection == CameraLensDirection.external
                                            ? 'External Camera'
                                            : cam.lensDirection == CameraLensDirection.front
                                                ? 'Built-in Front Camera'
                                                : 'Built-in Back Camera',
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
                                        ),
                                      ),
                                    ],
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
                                  child: isSelected
                                      ? Center(
                                          child: Container(
                                            width: 10,
                                            height: 10,
                                            decoration: BoxDecoration(
                                              color: theme.primaryColor,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                        )
                                      : null,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 12),
                    // Refresh button
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: _discoverCameras,
                        icon: const Icon(Icons.refresh, size: 16),
                        label: const Text('Refresh cameras'),
                        style: TextButton.styleFrom(
                          foregroundColor: theme.primaryColor,
                        ),
                      ),
                    ),
                  ],
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
                        final cameraIndex = _cameras
                            .indexWhere((c) => c['name'] == modifyingCamera);
                        if (cameraIndex != -1) {
                          _cameras[cameraIndex] = {
                            ..._cameras[cameraIndex],
                            'source': _tempSelectedSource,
                          };
                        }

                        _controller?.dispose();
                        _controller = null;
                        _macOsController?.destroy();
                        _macOsController = null;
                        _isCameraInitialized = false;
                        setState(() => modifyingCamera = null);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
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
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 16),
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



  Widget _buildCameraManagementItem(
      BuildContext context, Map<String, dynamic> camera) {
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
              ? theme.dividerColor.withValues(alpha: 0.5)
              : theme.dividerColor,
        ),
      ),
      child: Row(
        children: [
          // Camera Icon on the left
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: theme.primaryColor.withValues(alpha: 0.1),
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
                color:
                    theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.5),
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

  Widget _buildSharedCalibrationSection(
      AppLocalizations l10n, ThemeData theme) {
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
                    color: const Color(0xFF10B981).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.2),
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
                      padding: const EdgeInsets.symmetric(
                          vertical: 48, horizontal: 24),
                      decoration: BoxDecoration(
                        color: theme.brightness == Brightness.dark
                            ? theme.scaffoldBackgroundColor
                                .withValues(alpha: 0.5)
                            : theme
                                .scaffoldBackgroundColor, // Solid background for light mode
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
                              color: theme.primaryColor.withValues(alpha: 0.1),
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
                              color: theme.textTheme.bodyMedium?.color
                                  ?.withValues(alpha: 0.6),
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  _isCalibrationUploaded
                      ? l10n.applyChanges
                      : l10n.uploadCalibration,
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
