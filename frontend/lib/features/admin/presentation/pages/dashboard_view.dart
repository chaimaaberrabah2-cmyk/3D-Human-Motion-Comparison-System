import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:provider/provider.dart';
import '../../../../core/navigation/navigation_provider.dart';
import '../../../../core/theme/app_colors.dart';

class AdminDashboardView extends StatelessWidget {
  final String role;
  const AdminDashboardView({Key? key, required this.role}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            role == 'super_admin' ? 'Tableau de Bord Global' : 'Tableau de Bord Clinique',
            style: theme.textTheme.headlineMedium?.copyWith(
              color: AppColors.textWhite,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            role == 'super_admin' 
              ? 'Gérez l\'ensemble des cliniques et la configuration moteur.' 
              : 'Gérez vos patients et consultez les analyses du cabinet.',
            style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textGray),
          ),
          const SizedBox(height: 48),
          
          // Stats Row with Wrap to fix overflow
          Wrap(
            spacing: 24,
            runSpacing: 24,
            children: [
              _buildStatCard(
                context,
                title: role == 'super_admin' ? 'Cliniques Actives' : 'Mes Patients',
                value: role == 'super_admin' ? '12' : '24',
                icon: role == 'super_admin' ? Icons.business : Icons.people,
                color: AppColors.accentBlue,
              ),
              _buildStatCard(
                context,
                title: 'Analyses Totales',
                value: '1,248',
                icon: Icons.bolt,
                color: Colors.amber,
              ),
              _buildStatCard(
                context,
                title: 'Santé Système',
                value: '98%',
                icon: Icons.dns,
                color: Colors.green,
              ),
            ],
          ),
          
          const SizedBox(height: 48),
          Text(
            'Actions Rapides',
            style: theme.textTheme.titleLarge?.copyWith(
              color: AppColors.textWhite,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              if (role == 'super_admin')
                _buildActionButton(
                  context,
                  label: 'Créer un Établissement',
                  icon: Icons.add,
                  onPressed: () => _showCreateEstablishmentDialog(context),
                ),
              if (role != 'super_admin')
                _buildActionButton(
                  context,
                  label: 'Lancer une Analyse',
                  icon: Icons.play_arrow,
                  onPressed: () {
                    // Navigate to Analysis index 3
                    context.read<NavigationProvider>().setIndex(3);
                  },
                ),
              if (role != 'super_admin')
                _buildActionButton(
                  context,
                  label: 'Modifier Calibration',
                  icon: Icons.settings_input_component,
                  onPressed: () {
                    // Navigate to Calibration index 6
                    context.read<NavigationProvider>().setIndex(6);
                  },
                ),
            ],
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
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Établissement créé avec succès !"), backgroundColor: Colors.green),
                  );
                }
              } catch (e) {
                if (context.mounted) {
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


  Widget _buildStatCard(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.accentDark1,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.cardStroke),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: const TextStyle(color: AppColors.textGray, fontSize: 13, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textWhite,
              fontSize: 28,
              fontWeight: FontWeight.bold,
              letterSpacing: -1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context, {
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.accentDark2,
        foregroundColor: AppColors.textWhite,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.cardStroke),
        ),
        elevation: 0,
      ),
      icon: Icon(icon, size: 20, color: AppColors.accentBlue),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
      onPressed: onPressed,
    );
  }
}
