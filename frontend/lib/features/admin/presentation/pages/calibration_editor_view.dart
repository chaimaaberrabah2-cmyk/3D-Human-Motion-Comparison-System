import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:desktop_drop/desktop_drop.dart';
import '../../../../core/theme/app_colors.dart';

class CalibrationEditorView extends StatefulWidget {
  final int establishmentId;
  const CalibrationEditorView({Key? key, required this.establishmentId}) : super(key: key);

  @override
  State<CalibrationEditorView> createState() => _CalibrationEditorViewState();
}

class _CalibrationEditorViewState extends State<CalibrationEditorView> {
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isDragging = false;
  String? _error;
  Map<String, dynamic>? _currentCalibration;

  @override
  void initState() {
    super.initState();
    _fetchCalibration();
  }

  Future<void> _fetchCalibration() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final dio = Dio(BaseOptions(baseUrl: 'http://127.0.0.1:8000/api/v1'));
      final response = await dio.get('/cameras/calibration/${widget.establishmentId}');

      if (response.statusCode == 200) {
        setState(() {
          _currentCalibration = response.data['calibration'];
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = "Erreur lors de la récupération de la calibration : $e";
        _isLoading = false;
      });
    }
  }

  Future<void> _processFile(File file) async {
    try {
      final String content = await file.readAsString();
      final Map<String, dynamic> jsonData = json.decode(content);
      await _uploadCalibration(jsonData);
    } catch (e) {
      _showError("Erreur de format de fichier : $e");
    }
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );

    if (result != null && result.files.single.path != null) {
      await _processFile(File(result.files.single.path!));
    }
  }

  Future<void> _uploadCalibration(Map<String, dynamic> data) async {
    setState(() => _isSaving = true);
    try {
      final dio = Dio(BaseOptions(baseUrl: 'http://127.0.0.1:8000/api/v1'));
      await dio.put(
        '/cameras/calibration/${widget.establishmentId}',
        data: data,
      );
      await _fetchCalibration();
      _showSuccess("Fichier de calibration mis à jour avec succès !");
    } catch (e) {
      _showError("Erreur lors de l'envoi : $e");
    } finally {
      setState(() => _isSaving = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.redAccent),
    );
  }

  void _showSuccess(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.green),
    );
  }

  Future<void> _downloadCurrent() async {
    if (_currentCalibration == null) return;
    
    final String? outputFile = await FilePicker.platform.saveFile(
      dialogTitle: 'Enregistrer la calibration',
      fileName: 'calibration_${widget.establishmentId}.json',
    );

    if (outputFile != null) {
      final file = File(outputFile);
      const encoder = JsonEncoder.withIndent('  ');
      await file.writeAsString(encoder.convert(_currentCalibration));
      _showSuccess("Fichier enregistré sous : $outputFile");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.accentBlue));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "Calibration des Caméras",
              style: TextStyle(color: AppColors.textWhite, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Row(
              children: [
                TextButton.icon(
                  onPressed: _currentCalibration != null ? _downloadCurrent : null,
                  icon: const Icon(Icons.download_rounded),
                  label: const Text("Télécharger la config actuelle"),
                  style: TextButton.styleFrom(foregroundColor: AppColors.accentBlue),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _fetchCalibration,
                  icon: const Icon(Icons.refresh, color: AppColors.textGray),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        
        Expanded(
          child: DropTarget(
            onDragDone: (detail) {
              if (detail.files.isNotEmpty) {
                _processFile(File(detail.files.first.path));
              }
            },
            onDragEntered: (detail) => setState(() => _isDragging = true),
            onDragExited: (detail) => setState(() => _isDragging = false),
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: _isDragging 
                  ? AppColors.accentBlue.withOpacity(0.1) 
                  : Colors.black.withOpacity(0.3),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: _isDragging ? AppColors.accentBlue : AppColors.cardStroke,
                  width: _isDragging ? 2 : 1,
                  style: BorderStyle.solid,
                ),
              ),
              child: _isSaving 
                ? const Center(child: CircularProgressIndicator(color: AppColors.accentBlue))
                : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.cloud_upload_outlined,
                    size: 64,
                    color: _isDragging ? AppColors.accentBlue : AppColors.textGray,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    "Faites glisser votre fichier de calibration ici",
                    style: TextStyle(
                      color: AppColors.textWhite,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Seulement les fichiers .json au format spécifique (K, R, T)",
                    style: TextStyle(color: AppColors.textGray, fontSize: 13),
                  ),
                  const SizedBox(height: 32),
                  const Text("Ou", style: TextStyle(color: AppColors.textGray)),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _pickFile,
                    icon: const Icon(Icons.file_open_rounded),
                    label: const Text("Choisir un fichier"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accentBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (_error != null)
          Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
      ],
    );
  }
}

