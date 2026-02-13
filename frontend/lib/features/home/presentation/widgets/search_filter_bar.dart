import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../l10n/app_localizations.dart';

class SearchFilterBar extends StatefulWidget {
  final Function(String) onSearchChanged;
  final Function(String) onFilterChanged;
  
  const SearchFilterBar({
    Key? key,
    required this.onSearchChanged,
    required this.onFilterChanged,
  }) : super(key: key);

  @override
  State<SearchFilterBar> createState() => _SearchFilterBarState();
}

class _SearchFilterBarState extends State<SearchFilterBar> {
  String selectedFilter = 'All';
  final List<String> filters = ['All', 'Strength', 'Mobility', 'BodyWeight', 'Rehab'];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        children: [
          // Search Bar
          Container(
            height: 50,
            decoration: BoxDecoration(
              color: AppColors.cardFill,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.cardStroke),
            ),
            child: TextField(
              onChanged: widget.onSearchChanged,
              style: const TextStyle(color: AppColors.textWhite),
              decoration: InputDecoration(
                hintText: l10n.searchExercises,
                hintStyle: const TextStyle(color: AppColors.textGray),
                prefixIcon: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: SvgPicture.asset(
                    'assets/icons/search.svg',
                    width: 20,
                    height: 20,
                    colorFilter: const ColorFilter.mode(
                      AppColors.textGray,
                      BlendMode.srcIn,
                    ),
                  ),
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Filter Chips
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: filters.length,
              separatorBuilder: (context, index) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final filter = filters[index];
                final isSelected = selectedFilter == filter;
                
                // Get translated filter name
                String getFilterName(String filter) {
                  switch (filter) {
                    case 'All':
                      return l10n.all;
                    case 'Strength':
                      return l10n.strength;
                    case 'Mobility':
                      return l10n.mobility;
                    case 'BodyWeight':
                      return l10n.bodyWeight;
                    case 'Rehab':
                      return l10n.rehab;
                    default:
                      return filter;
                  }
                }
                
                return FilterChip(
                  label: Text(getFilterName(filter)),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      selectedFilter = filter;
                    });
                    widget.onFilterChanged(filter);
                  },
                  backgroundColor: const Color(0xFF0E172B),
                  selectedColor: const Color(0xFF165DFC),
                  labelStyle: TextStyle(
                    color: isSelected ? AppColors.textWhite : AppColors.textGray,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                  side: BorderSide(
                    color: const Color(0xFF1C293D),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
