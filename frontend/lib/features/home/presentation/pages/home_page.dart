import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/exercise.dart';
import '../widgets/home_sidebar.dart';
import '../widgets/home_header.dart';
import '../widgets/search_filter_bar.dart';
import '../widgets/exercise_grid.dart';

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

  void _filterExercises() {
    setState(() {
      filteredExercises = allExercises.where((exercise) {
        // Filter by search query
        final matchesSearch = exercise.name
            .toLowerCase()
            .contains(searchQuery.toLowerCase());
        
        // Filter by category
        final matchesFilter = selectedFilter == 'All' ||
            exercise.category == selectedFilter;
        
        return matchesSearch && matchesFilter;
      }).toList();
    });
  }

  void _onSearchChanged(String query) {
    searchQuery = query;
    _filterExercises();
  }

  void _onFilterChanged(String filter) {
    selectedFilter = filter;
    _filterExercises();
  }

  void _onExerciseTapped(Exercise exercise) {
    // TODO: Navigate to exercise detail page
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Opening ${exercise.name}...'),
        backgroundColor: AppColors.accentBlue,
      ),
    );
  }

  void _onStartAnalysis() {
    // TODO: Navigate to new analysis page
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Starting new analysis...'),
        backgroundColor: AppColors.accentBlue,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth > 1200;
          final isTablet = constraints.maxWidth > 600 && constraints.maxWidth <= 1200;

          if (isDesktop || isTablet) {
            // Desktop/Tablet: Sidebar + Main Content
            return Row(
              children: [
                // Sidebar
                const HomeSidebar(),
                
                // Main Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      HomeHeader(
                        username: 'User', // TODO: Get from auth
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
              backgroundColor: AppColors.background,
              appBar: AppBar(
                backgroundColor: AppColors.background,
                elevation: 0,
                title: const Text(
                  'MOTION AI',
                  style: TextStyle(
                    color: AppColors.textWhite,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                iconTheme: const IconThemeData(color: AppColors.textWhite),
              ),
              drawer: Drawer(
                backgroundColor: AppColors.background,
                child: const HomeSidebar(),
              ),
              body: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  HomeHeader(
                    username: 'User', // TODO: Get from auth
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
            );
          }
        },
      ),
    );
  }
}
