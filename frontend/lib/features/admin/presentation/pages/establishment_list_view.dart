import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../../../core/theme/app_colors.dart';
import 'patient_list_view.dart';
import 'calibration_editor_view.dart';

class EstablishmentListView extends StatefulWidget {
  const EstablishmentListView({Key? key}) : super(key: key);

  @override
  State<EstablishmentListView> createState() => _EstablishmentListViewState();
}

class _EstablishmentListViewState extends State<EstablishmentListView> {
  List<dynamic> _establishments = [];
  bool _isLoading = true;
  String? _error;
  
  // To handle the "Detail" view when an establishment is clicked
  Map<String, dynamic>? _selectedEstablishment;

  @override
  void initState() {
    super.initState();
    _fetchEstablishments();
  }

  Future<void> _fetchEstablishments() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final dio = Dio(BaseOptions(baseUrl: 'http://127.0.0.1:8000/api/v1'));
      final response = await dio.get('/auth/establishments');

      if (response.statusCode == 200) {
        setState(() {
          _establishments = response.data;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = "Erreur lors de la récupération des établissements : $e";
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedEstablishment != null) {
      return _buildDetailView();
    }

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
                    'Gestion des Établissements',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: AppColors.textWhite,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Visualisez et gérez les cliniques utilisant MOTION AI.',
                    style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textGray),
                  ),
                ],
              ),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _showCreateEstablishmentDialog(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Créer un Établissement'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accentBlue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _fetchEstablishments,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Actualiser'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accentBlue.withOpacity(0.1),
                      foregroundColor: AppColors.accentBlue,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 32),

          
          if (_isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator(color: AppColors.accentBlue)))
          else if (_error != null)
            Expanded(child: Center(child: Text(_error!, style: const TextStyle(color: Colors.redAccent))))
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
                      showCheckboxColumn: false,
                      columns: const [
                        DataColumn(label: Text('Nom', style: TextStyle(color: AppColors.textWhite, fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Code', style: TextStyle(color: AppColors.textWhite, fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Contact', style: TextStyle(color: AppColors.textWhite, fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Actions', style: TextStyle(color: AppColors.textWhite, fontWeight: FontWeight.bold))),
                      ],
                      rows: _establishments.map((est) => DataRow(
                        onSelectChanged: (_) {
                          setState(() {
                            _selectedEstablishment = est;
                          });
                        },
                        cells: [
                          DataCell(Text(est['name'], style: const TextStyle(color: AppColors.textWhite))),
                          DataCell(Text(est['code'], style: const TextStyle(color: AppColors.accentBlue, fontWeight: FontWeight.bold))),
                          DataCell(Text(est['contact_email'] ?? '-', style: const TextStyle(color: AppColors.textGray))),
                          DataCell(const Icon(Icons.chevron_right, color: AppColors.textGray)),
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

  Widget _buildDetailView() {
    return DefaultTabController(
      length: 2,
      child: Container(
        padding: const EdgeInsets.all(40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with Back button and Create Admin button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: AppColors.textWhite),
                      onPressed: () => setState(() => _selectedEstablishment = null),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedEstablishment!['name'],
                          style: const TextStyle(color: AppColors.textWhite, fontSize: 28, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Code: ${_selectedEstablishment!['code']}',
                          style: const TextStyle(color: AppColors.accentBlue, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () => _showCreateAdminDialog(context, _selectedEstablishment!['establishment_id']),
                  icon: const Icon(Icons.person_add_alt_1_rounded),
                  label: const Text("Créer un Administrateur"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            
            // Tabs
            const TabBar(
              isScrollable: true,
              labelColor: AppColors.accentBlue,
              unselectedLabelColor: AppColors.textGray,
              indicatorColor: AppColors.accentBlue,
              tabs: [
                Tab(text: "Patients"),
                Tab(text: "Calibration"),
              ],
            ),
            const SizedBox(height: 24),
            
            // Tab Content
            Expanded(
              child: TabBarView(
                children: [
                  PatientListView(establishmentId: _selectedEstablishment!['establishment_id']),
                  CalibrationEditorView(establishmentId: _selectedEstablishment!['establishment_id']),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateAdminDialog(BuildContext context, int establishmentId) {
    final pseudoController = TextEditingController();
    final emailController = TextEditingController();
    final passController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.accentDark1,
        title: const Text("Créer un Administrateur de Clinique", style: TextStyle(color: AppColors.textWhite)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: pseudoController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: "Pseudo", labelStyle: TextStyle(color: AppColors.textGray)),
            ),
            TextField(
              controller: emailController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: "Email", labelStyle: TextStyle(color: AppColors.textGray)),
            ),
            TextField(
              controller: passController,
              obscureText: true,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: "Mot de passe", labelStyle: TextStyle(color: AppColors.textGray)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Annuler", style: TextStyle(color: AppColors.textGray)),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                final dio = Dio(BaseOptions(baseUrl: 'http://127.0.0.1:8000/api/v1'));
                await dio.post('/auth/establishments/$establishmentId/admin', data: {
                  'pseudo': pseudoController.text,
                  'email': emailController.text,
                  'password': passController.text,
                  'establishment_code': _selectedEstablishment!['code'], // Required by schema even if ignored
                });
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Administrateur créé avec succès !"), backgroundColor: Colors.green),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Erreur : $e"), backgroundColor: Colors.redAccent),
                  );
                }
              }
            },
            child: const Text("Créer"),
          ),
        ],
      ),
    );
  }

  void _showCreateEstablishmentDialog(BuildContext context) {
    final nameController = TextEditingController();
    final codeController = TextEditingController();
    final emailController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.accentDark1,
        title: const Text("Créer un Établissement", style: TextStyle(color: AppColors.textWhite)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: "Nom de la Clinique",
                labelStyle: TextStyle(color: AppColors.textGray),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.cardStroke)),
              ),
            ),
            TextField(
              controller: codeController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: "Code Unique (ex: KINE-01)",
                labelStyle: TextStyle(color: AppColors.textGray),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.cardStroke)),
              ),
            ),
            TextField(
              controller: emailController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: "Email de Contact",
                labelStyle: TextStyle(color: AppColors.textGray),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.cardStroke)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Annuler", style: TextStyle(color: AppColors.textGray)),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                final dio = Dio(BaseOptions(baseUrl: 'http://127.0.0.1:8000/api/v1'));
                await dio.post('/auth/establishments', data: {
                  'name': nameController.text,
                  'code': codeController.text,
                  'contact_email': emailController.text.isNotEmpty ? emailController.text : null,
                });
                if (mounted) {
                  Navigator.pop(context);
                  _fetchEstablishments(); // Refresh the list
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Établissement créé avec succès !"), backgroundColor: Colors.green),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Erreur : $e"), backgroundColor: Colors.redAccent),
                  );
                }
              }
            },
            child: const Text("Créer"),
          ),
        ],
      ),
    );
  }
}


