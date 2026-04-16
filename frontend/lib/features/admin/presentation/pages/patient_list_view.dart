import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../features/authentification/domain/entities/auth_user.dart';

class PatientListView extends StatefulWidget {
  final int? establishmentId; // If null, load from SharedPreferences
  const PatientListView({Key? key, this.establishmentId}) : super(key: key);

  @override
  State<PatientListView> createState() => _PatientListViewState();
}

class _PatientListViewState extends State<PatientListView> {
  List<AuthUser> _patients = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchPatients();
  }

  Future<void> _fetchPatients() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final estId = widget.establishmentId ?? prefs.getInt('user_establishment_id');
      
      if (estId == null) {
        setState(() {
          _error = "ID d'établissement introuvable.";
          _isLoading = false;
        });
        return;
      }

      final dio = Dio(BaseOptions(baseUrl: 'http://127.0.0.1:8000/api/v1')); // Consistent with existing app base URL
      final response = await dio.get('/auth/establishments/$estId/users');

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        setState(() {
          _patients = data.map((json) => AuthUser(
            id: json['user_id'].toString(),
            displayName: json['pseudo'],
            email: json['email'],
            role: json['role'],
            establishmentId: json['establishment_id'],
          )).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = "Erreur lors de la récupération des patients : $e";
        _isLoading = false;
      });
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
                    'Liste des Patients',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: AppColors.textWhite,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Gérez les dossiers et visualisez les analyses de vos patients.',
                    style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textGray),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: _fetchPatients,
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
            const Expanded(child: Center(child: CircularProgressIndicator(color: AppColors.accentBlue)))
          else if (_error != null)
            Expanded(child: Center(child: Text(_error!, style: const TextStyle(color: Colors.redAccent))))
          else if (_patients.isEmpty)
            const Expanded(child: Center(child: Text("Aucun patient trouvé.", style: TextStyle(color: AppColors.textGray))))
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
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(AppColors.accentDark2),
                      columns: const [
                        DataColumn(label: Text('Pseudo', style: TextStyle(color: AppColors.textWhite, fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Email', style: TextStyle(color: AppColors.textWhite, fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Rôle', style: TextStyle(color: AppColors.textWhite, fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Actions', style: TextStyle(color: AppColors.textWhite, fontWeight: FontWeight.bold))),
                      ],
                      rows: _patients.map((patient) => DataRow(
                        cells: [
                          DataCell(Text(patient.displayName ?? '-', style: const TextStyle(color: AppColors.textWhite))),
                          DataCell(Text(patient.email, style: const TextStyle(color: AppColors.textGray))),
                          DataCell(Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.accentBlue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text('Patient', style: TextStyle(color: AppColors.accentBlue, fontSize: 12)),
                          )),
                          DataCell(Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.analytics_outlined, color: AppColors.accentBlue, size: 20),
                                onPressed: () {},
                                tooltip: 'Voir Analyses',
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, color: AppColors.textGray, size: 20),
                                onPressed: () {},
                                tooltip: 'Modifier',
                              ),
                            ],
                          )),
                        ],
                      )).toList(),
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
