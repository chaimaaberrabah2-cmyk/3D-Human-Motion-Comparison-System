// ============================================================
// lib/features/analysis/presentation/widgets/smplx_viewer_widget.dart
// ============================================================
// Widget d'affichage du modèle SMPL-X via WebView Three.js.
//
// Comportement :
//   1. Poll toutes les 3s le backend /sessions/{id}/status
//   2. Affiche la progression des 4 phases avec animations
//   3. Quand Phase 4 est complète → charge le viewer Three.js
//   4. La WebView affiche le maillage SMPL-X animé interactif
// ============================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../../data/datasources/analysis_remote_datasource.dart';

class SmplxViewerWidget extends StatefulWidget {
  final String sessionId;

  const SmplxViewerWidget({Key? key, required this.sessionId}) : super(key: key);

  @override
  State<SmplxViewerWidget> createState() => _SmplxViewerWidgetState();
}

class _SmplxViewerWidgetState extends State<SmplxViewerWidget>
    with TickerProviderStateMixin {
  // ── State ──────────────────────────────────────────────────
  bool _isReady = false;
  bool _pollingFailed = false;
  int _progressPercent = 0;
  Map<String, bool> _phases = {
    'phase1_frames_extracted': false,
    'phase2_pose_estimated': false,
    'phase3_triangulated': false,
    'phase4_smplx_fitted': false,
  };

  Timer? _pollTimer;
  InAppWebViewController? _webController;
  final _dataSource = AnalysisRemoteDataSource();

  // ── Animations ─────────────────────────────────────────────
  late AnimationController _pulseCtrl;
  late AnimationController _progressCtrl;
  late Animation<double> _pulse;
  late Animation<double> _progressAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    _progressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _progressAnim = Tween<double>(begin: 0, end: 0).animate(
      CurvedAnimation(parent: _progressCtrl, curve: Curves.easeOut),
    );

    final isReference = !widget.sessionId.contains('-') && widget.sessionId.length <= 20;
    if (isReference) {
      _isReady = true;
      _progressPercent = 100;
    } else {
      _startPolling();
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _pulseCtrl.dispose();
    _progressCtrl.dispose();
    super.dispose();
  }

  // ── Polling ────────────────────────────────────────────────
  void _startPolling() {
    _poll(); // immediate first check
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) => _poll());
  }

  Future<void> _poll() async {
    try {
      final status = await _dataSource.fetchSessionStatus(widget.sessionId);
      if (!mounted) return;

      final pct = (status['progress_percent'] as num).toInt();
      final ready = status['has_smplx_viewer'] == true;
      final phases = Map<String, bool>.from(status['phases'] ?? {});

      // Animate progress bar
      _progressAnim = Tween<double>(
        begin: _progressAnim.value,
        end: pct / 100.0,
      ).animate(CurvedAnimation(parent: _progressCtrl, curve: Curves.easeOut));
      _progressCtrl.forward(from: 0);

      setState(() {
        _progressPercent = pct;
        _phases = phases;
        _pollingFailed = false;
      });

      if (ready && !_isReady) {
        _pollTimer?.cancel();
        _initWebView();
      }
    } catch (_) {
      if (mounted) setState(() => _pollingFailed = true);
    }
  }

  void _initWebView() {
    setState(() {
      _isReady = true;
    });
    _pulseCtrl.stop();
  }

  // ── Build ──────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_isReady) {
      return _buildViewer(theme);
    }

    return _buildLoadingState(theme, isDark);
  }

  // -- 3D Viewer (WebView) -----------------------------------
  Widget _buildViewer(ThemeData theme) {
    final url = _dataSource.getViewerUrl(widget.sessionId);
    
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.primaryColor.withOpacity(0.3)),
      ),
      child: Stack(
        children: [
          InAppWebView(
            initialUrlRequest: URLRequest(url: WebUri(url)),
            initialSettings: InAppWebViewSettings(
              transparentBackground: true,
              javaScriptEnabled: true,
            ),
            onWebViewCreated: (controller) {
              _webController = controller;
            },
            onLoadError: (controller, url, code, message) {
              print('WebView error: $message ($code)');
            },
          ),
          // Badge
          Positioned(
            top: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: theme.primaryColor.withOpacity(0.85),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.view_in_ar_rounded, color: Colors.white, size: 14),
                  SizedBox(width: 4),
                  Text(
                    'SMPL-X Live',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // -- Loading state -----------------------------------------
  Widget _buildLoadingState(ThemeData theme, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0D0D1F) : const Color(0xFFF5F5FF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.primaryColor.withOpacity(0.15)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Animated 3D icon
          FadeTransition(
            opacity: _pulse,
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    theme.primaryColor.withOpacity(0.3),
                    theme.primaryColor.withOpacity(0.05),
                  ],
                ),
              ),
              child: Icon(
                Icons.view_in_ar_rounded,
                size: 44,
                color: theme.primaryColor,
              ),
            ),
          ),

          const SizedBox(height: 20),

          Text(
            _pollingFailed ? 'Connection Error' : 'Building 3D Body Model',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.textTheme.bodyLarge?.color,
            ),
          ),

          const SizedBox(height: 6),

          Text(
            _pollingFailed
                ? 'Cannot reach backend. Is the server running?'
                : 'SMPL-X fitting in progress on GPU...',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.textTheme.bodyMedium?.color?.withOpacity(0.5),
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 24),

          // Progress bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Pipeline',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.textTheme.bodyMedium?.color?.withOpacity(0.5),
                      ),
                    ),
                    Text(
                      '$_progressPercent%',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                AnimatedBuilder(
                  animation: _progressAnim,
                  builder: (_, __) => ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: _progressAnim.value,
                      backgroundColor: theme.dividerColor.withOpacity(0.1),
                      valueColor: AlwaysStoppedAnimation<Color>(theme.primaryColor),
                      minHeight: 6,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Phase chips
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _PhaseChip(
                  label: 'Frames',
                  icon: Icons.video_library_outlined,
                  done: _phases['phase1_frames_extracted'] ?? false,
                  theme: theme,
                ),
                _PhaseChip(
                  label: 'Pose',
                  icon: Icons.accessibility_new_outlined,
                  done: _phases['phase2_pose_estimated'] ?? false,
                  theme: theme,
                ),
                _PhaseChip(
                  label: '3D Triangulation',
                  icon: Icons.grain_outlined,
                  done: _phases['phase3_triangulated'] ?? false,
                  theme: theme,
                ),
                _PhaseChip(
                  label: 'SMPL-X',
                  icon: Icons.view_in_ar_rounded,
                  done: _phases['phase4_smplx_fitted'] ?? false,
                  theme: theme,
                ),
              ],
            ),
          ),

          if (_pollingFailed) ...[
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: () {
                setState(() => _pollingFailed = false);
                _startPolling();
              },
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Retry'),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Phase Chip ─────────────────────────────────────────────
class _PhaseChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool done;
  final ThemeData theme;

  const _PhaseChip({
    required this.label,
    required this.icon,
    required this.done,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: done
            ? theme.primaryColor.withOpacity(0.15)
            : theme.dividerColor.withOpacity(0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: done
              ? theme.primaryColor.withOpacity(0.4)
              : theme.dividerColor.withOpacity(0.15),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            done ? Icons.check_circle_rounded : icon,
            size: 13,
            color: done
                ? theme.primaryColor
                : theme.textTheme.bodyMedium?.color?.withOpacity(0.35),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: done
                  ? theme.primaryColor
                  : theme.textTheme.bodyMedium?.color?.withOpacity(0.4),
            ),
          ),
        ],
      ),
    );
  }
}
