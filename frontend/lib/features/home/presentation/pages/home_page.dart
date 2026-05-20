// ============================================================
// lib/features/home/presentation/pages/home_page.dart
// ============================================================
// Page d'accueil principale de l'application (Tableau de bord).
//
// Cette page affiche :
//   - Un en-tête (HomeHeader) avec un message de bienvenue
//   - Une barre de recherche et de filtres par catégorie (SearchFilterBar)
//   - Une grille d'exercices (ExerciseGrid)
//
// Disposition :
//   - Utilise un "drawer" pour la barre latérale sur mobile
//   - Affiche directement la barre latérale sur grand écran
//   - Filtre la liste des exercices affichés en fonction du texte
//     de recherche et du filtre sélectionné.
// ============================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/navigation/navigation_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/exercise.dart';
import '../widgets/home_header.dart';
import '../widgets/search_filter_bar.dart';
import '../widgets/exercise_grid.dart';
import 'exercise_detail_page.dart';
import '../../../analysis/data/datasources/analysis_remote_datasource.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Exercise> allExercises = [];
  List<Exercise> filteredExercises = [];
  String searchQuery = '';
  String selectedFilter = 'All';
  String _username = 'User';
  String _role = 'user';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUsernameAndRole();
    _fetchDatabaseExercises();
  }

  Future<void> _fetchDatabaseExercises() async {
    final dataSource = AnalysisRemoteDataSource();
    final list = await dataSource.fetchMovements();
    if (mounted) {
      setState(() {
        allExercises = list;
        filteredExercises = list;
        _isLoading = false;
      });
    }
  }


  Future<void> _loadUsernameAndRole() async {
    final prefs = await SharedPreferences.getInstance();
    final newName = prefs.getString('user_name') ?? 'Utilisateur';
    final newRole = prefs.getString('user_role') ?? 'user';
    if (mounted) {
      setState(() {
        _username = newName;
        _role = newRole;
      });
    }
  }

  void _loadUsername() {
    _loadUsernameAndRole();
  }

//filtre exos 
  void _filterExercises() {
    setState(() {
      filteredExercises = allExercises.where((exercise) {
        
        final matchesSearch = exercise.name
            .toLowerCase()
            .contains(searchQuery.toLowerCase());
        
        final matchesFilter = selectedFilter == 'All' ||
            exercise.category == selectedFilter;
        
        return matchesSearch && matchesFilter;
      }).toList();
    });
  }
//change dans search
  void _onSearchChanged(String query) {
    searchQuery = query;
    _filterExercises();
  }
//filltre change
  void _onFilterChanged(String filter) {
    selectedFilter = filter;
    _filterExercises();
  }
  //fun quand on clique sur play de l'exo
  void _onExerciseTapped(Exercise exercise) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ExerciseDetailPage(exercise: exercise),
      ),
    );
  }
  void _onStartAnalysis() {
    context.read<NavigationProvider>().setIndex(3);
  }

  @override
  Widget build(BuildContext context) {
    // Ecouter les changements d'onglets pour recharger dynamiquement le nom
    final navIndex = context.watch<NavigationProvider>().currentIndex;
    if (navIndex == 0) {
      _loadUsername();
    }

    return _buildMainContent();
  }

  Widget _buildMainContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HomeHeader(
          username: _username, 
          onStartAnalysis: _onStartAnalysis,
        ),
        
        SearchFilterBar(
          onSearchChanged: _onSearchChanged,
          onFilterChanged: _onFilterChanged,
        ),
        
        const SizedBox(height: 24),
        
        Expanded(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(),
                )
              : ExerciseGrid(
                  exercises: filteredExercises,
                  onExerciseTapped: _onExerciseTapped,
                ),
        ),
      ],
    );
  }
}
