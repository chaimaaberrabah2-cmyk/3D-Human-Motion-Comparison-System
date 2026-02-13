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
    final theme = Theme.of(context);
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        children: [
          // Search Bar
          Container(
            height: 50,
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.dividerColor),
            ),
            child: TextField(
              onChanged: widget.onSearchChanged,
              style: theme.textTheme.bodyLarge,
              decoration: InputDecoration(
                hintText: l10n.searchExercises,
                hintStyle: theme.textTheme.bodyMedium,
                prefixIcon: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: SvgPicture.asset(
                    'assets/icons/search.svg',
                    width: 20,
                    height: 20,
                    colorFilter: ColorFilter.mode(
                      theme.iconTheme.color ?? Colors.grey,
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
                  backgroundColor: theme.cardColor,
                  selectedColor: theme.primaryColor,
                  checkmarkColor: theme.colorScheme.onPrimary,
                  labelStyle: TextStyle(
                    color: isSelected ? theme.colorScheme.onPrimary : theme.textTheme.bodyMedium?.color,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                  side: BorderSide(
                    color: isSelected ? Colors.transparent : theme.dividerColor,
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
