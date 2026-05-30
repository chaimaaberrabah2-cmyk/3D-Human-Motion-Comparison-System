import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../features/authentication/domain/entities/auth_user.dart';

/// URL de base API (identique au reste de l'app).
const String _kApiBaseUrl = 'http://127.0.0.1:8000/api/v1';

class AdherentListView extends StatefulWidget {
  final int? establishmentId;

  const AdherentListView({Key? key, this.establishmentId}) : super(key: key);

  @override
  State<AdherentListView> createState() => _AdherentListViewState();
}

class _AdherentListViewState extends State<AdherentListView> {
  List<AuthUser> _adherents = [];
  bool _isLoading = true;
  String? _error;
  int? _resolvedEstablishmentId;

  @override
  void initState() {
    super.initState();
    _fetchAdherents();
  }

  @override
  void didUpdateWidget(AdherentListView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.establishmentId != widget.establishmentId) {
      _fetchAdherents();
    }
  }

  Future<int?> _resolveEstablishmentId() async {
    if (widget.establishmentId != null && widget.establishmentId! > 0) {
      return widget.establishmentId;
    }
    final prefs = await SharedPreferences.getInstance();
    final fromPrefs = prefs.getInt('user_establishment_id');
    if (fromPrefs != null && fromPrefs > 0) return fromPrefs;
    return null;
  }

  Future<void> _fetchAdherents() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final estId = await _resolveEstablishmentId();
      _resolvedEstablishmentId = estId;

      if (estId == null) {
        if (!mounted) return;
        setState(() {
          _error =
              "ID d'établissement introuvable. Reconnectez-vous ou sélectionnez un établissement.";
          _isLoading = false;
          _adherents = [];
        });
        return;
      }

      final dio = Dio(BaseOptions(
        baseUrl: _kApiBaseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
      ));

      final response = await dio.get(
        '/auth/establishments/$estId/users',
        queryParameters: {'role': 'user'},
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final raw = response.data;
        final List<dynamic> data = raw is List
            ? raw
            : (raw is Map ? (raw['users'] ?? raw['items'] ?? []) as List : []);

        setState(() {
          _adherents = data.map((json) {
            final map = json as Map<String, dynamic>;
            return AuthUser(
              id: (map['user_id'] ?? map['id']).toString(),
              displayName: map['pseudo'] as String?,
              email: map['email'] as String? ?? '',
              role: map['role'] as String? ?? 'user',
              establishmentId: map['establishment_id'] as int? ?? estId,
            );
          }).toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Réponse serveur inattendue (${response.statusCode})';
          _isLoading = false;
        });
      }
    } on DioException catch (e) {
      if (!mounted) return;
      final detail = e.response?.data;
      String msg = e.message ?? 'Erreur réseau';
      if (detail is Map && detail['detail'] != null) {
        msg = detail['detail'].toString();
      }
      setState(() {
        _error = 'Impossible de charger les adhérents : $msg';
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Erreur lors de la récupération des adhérents : $e';
        _isLoading = false;
      });
    }
  }

  String _roleLabel(String? role) {
    switch (role) {
      case 'admin':
        return 'Administrateur';
      case 'super_admin':
        return 'Super Admin';
      default:
        return 'Adhérent';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Liste des Adhérents',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: AppColors.textWhite,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _resolvedEstablishmentId != null
                        ? 'Établissement #$_resolvedEstablishmentId — ${_adherents.length} adhérent(s)'
                        : 'Gérez les dossiers et visualisez les analyses de vos adhérents.',
                    style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textGray),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _fetchAdherents,
                icon: const Icon(Icons.refresh),
                label: const Text('Actualiser'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentBlue.withOpacity(0.1),
                  foregroundColor: AppColors.accentBlue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          if (_isLoading)
            const Expanded(
              child: Center(
                child: CircularProgressIndicator(color: AppColors.accentBlue),
              ),
            )
          else if (_error != null)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      _error!,
                      style: const TextStyle(color: Colors.redAccent),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _fetchAdherents,
                      child: const Text('Réessayer'),
                    ),
                  ],
                ),
              ),
            )
          else if (_adherents.isEmpty)
            const Expanded(
              child: Center(
                child: Text(
                  'Aucun adhérent trouvé pour cet établissement.',
                  style: TextStyle(color: AppColors.textGray),
                ),
              ),
            )
          else
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.accentDark1,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.cardStroke),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(AppColors.accentDark2),
                        columns: const [
                          DataColumn(
                            label: Text(
                              'Pseudo',
                              style: TextStyle(
                                color: AppColors.textWhite,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'Email',
                              style: TextStyle(
                                color: AppColors.textWhite,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'Rôle',
                              style: TextStyle(
                                color: AppColors.textWhite,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'Actions',
                              style: TextStyle(
                                color: AppColors.textWhite,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                        rows: _adherents.map((adherent) {
                          return DataRow(
                            cells: [
                              DataCell(
                                Text(
                                  adherent.displayName ?? '-',
                                  style: const TextStyle(color: AppColors.textWhite),
                                ),
                              ),
                              DataCell(
                                Text(
                                  adherent.email,
                                  style: const TextStyle(color: AppColors.textGray),
                                ),
                              ),
                              DataCell(
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.accentBlue.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    _roleLabel(adherent.role),
                                    style: const TextStyle(
                                      color: AppColors.accentBlue,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                              DataCell(
                                Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(
                                        Icons.analytics_outlined,
                                        color: AppColors.accentBlue,
                                        size: 20,
                                      ),
                                      onPressed: () {},
                                      tooltip: 'Voir Analyses',
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.edit_outlined,
                                        color: AppColors.textGray,
                                        size: 20,
                                      ),
                                      onPressed: () {},
                                      tooltip: 'Modifier',
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
