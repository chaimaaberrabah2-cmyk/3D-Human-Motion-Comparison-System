import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/exercise.dart';
import '../widgets/home_sidebar.dart';
import '../widgets/home_header.dart';
import '../widgets/search_filter_bar.dart';
import '../widgets/exercise_grid.dart';
import 'exercise_detail_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Exercise> allExercises = getMockExercises();
  List<Exercise> filteredExercises = [];
  String searchQuery = '';
  String selectedFilter = 'All';

  @override
  void initState() {
    super.initState();
    filteredExercises = allExercises;
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
//fun quand on clique sur new analysis
  void _onStartAnalysis() {
    Navigator.pushNamed(context, '/new_analysis');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth > 1200;
          final isTablet = constraints.maxWidth > 600 && constraints.maxWidth <= 1200;

          if (isDesktop || isTablet) {
            // Desktop/Tablet: Sidebar + Main Content
            return Row(
              children: [
                // Sidebar menu
                const HomeSidebar(),
                
                // Main Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      HomeHeader(
                        username: 'User', 
                        onStartAnalysis: _onStartAnalysis,
                      ),
                      
                      SearchFilterBar(
                        onSearchChanged: _onSearchChanged,
                        onFilterChanged: _onFilterChanged,
                      ),
                      
                      const SizedBox(height: 24),
                      
                      Expanded(
                        child: ExerciseGrid(
                          exercises: filteredExercises,
                          onExerciseTapped: _onExerciseTapped,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          } else {
            // Mobile: Drawer + Main Content
            return Scaffold(
              backgroundColor: theme.scaffoldBackgroundColor,
              appBar: AppBar(
                backgroundColor: theme.scaffoldBackgroundColor,
                elevation: 0,
                title: Text(
                  'MOTION AI',
                  style: TextStyle(
                    color: theme.textTheme.bodyLarge?.color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                iconTheme: IconThemeData(color: theme.iconTheme.color),
              ),
              drawer: Drawer(
                backgroundColor: theme.scaffoldBackgroundColor,
                child: const HomeSidebar(),
              ),
              body: SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    HomeHeader(
                      username: 'User', 
                      onStartAnalysis: _onStartAnalysis,
                    ),
                    
                    SearchFilterBar(
                      onSearchChanged: _onSearchChanged,
                      onFilterChanged: _onFilterChanged,
                    ),
                    
                    const SizedBox(height: 24),
                    
                    Expanded(
                      child: ExerciseGrid(
                        exercises: filteredExercises,
                        onExerciseTapped: _onExerciseTapped,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
        },
      ),
    );
  }
}
