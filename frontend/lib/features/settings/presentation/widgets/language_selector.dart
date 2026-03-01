import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../../core/l10n/locale_provider.dart';
import '../../../../l10n/app_localizations.dart';

class LanguageSelector extends StatefulWidget {
  final Function(Locale)? onLanguageChanged;
  final Function(bool)? onThemeChanged;
  
  const LanguageSelector({
    Key? key,
    this.onLanguageChanged,
    this.onThemeChanged,
  }) : super(key: key);

  @override
  State<LanguageSelector> createState() => _LanguageSelectorState();
}

class _LanguageSelectorState extends State<LanguageSelector> {

  void _showLanguagePicker(BuildContext context) {
    final localeProvider = Provider.of<LocaleProvider>(context, listen: false);
    final theme = Theme.of(context);
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: theme.cardColor,
          title: Text(
            'Select Language',
            style: theme.textTheme.titleLarge,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: L10n.all.map((locale) {
              final isSelected = localeProvider.locale == locale;
              return ListTile(
                title: Text(
                  L10n.getLanguageName(locale.languageCode),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isSelected ? theme.primaryColor : theme.textTheme.bodyLarge?.color,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
                trailing: isSelected
                    ? Icon(Icons.check, color: theme.primaryColor)
                    : null,
                onTap: () {
                  // Apply immediately to provider
                  localeProvider.setLocale(locale);
                  
                  // Notify parent of change
                  widget.onLanguageChanged?.call(locale);
                  
                  Navigator.pop(context);
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final localeProvider = Provider.of<LocaleProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    
    return Column(
      children: [
        const SizedBox(height: 32),
        Divider(color: theme.dividerColor),
        const SizedBox(height: 32),
        
        // Language Selector
        InkWell(
          onTap: () => _showLanguagePicker(context),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    SvgPicture.asset(
                      'assets/icons/language.svg',
                      width: 24,
                      height: 24,
                      colorFilter: ColorFilter.mode(
                        theme.iconTheme.color!,
                        BlendMode.srcIn,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${l10n.language} ${l10n.languageLabel}',
                      style: theme.textTheme.bodyLarge,
                    ),
                  ],
                ),
                Row(
                  children: [
                    Text(
                      L10n.getLanguageName(localeProvider.locale.languageCode),
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.chevron_right,
                      color: theme.textTheme.bodyMedium?.color,
                      size: 20,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        
        const SizedBox(height: 24),
        
        // Light/Dark Mode Toggle
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l10n.light, // "Clair" or "Light Mode"
              style: theme.textTheme.bodyLarge,
            ),
            Switch(
              value: !themeProvider.isDarkMode, // Validating meaning: 'Light' label means switch ON = Light?
              // Usually Switches are: "Dark Mode" -> ON=Dark.
              // Here the label is "Light" (Clair).
              // So if value is TRUE, it implies Light Mode is Active.
              // themeProvider.isDarkMode is true -> Light Mode is false.
              onChanged: (value) {
                // If value is true (Light Mode requested), isDark should be false.
                themeProvider.toggleTheme(!value);
                
                // Notify parent of change
                widget.onThemeChanged?.call(!value);
              },
              activeColor: theme.primaryColor,
              inactiveThumbColor: theme.textTheme.bodyMedium?.color,
              inactiveTrackColor: theme.dividerColor,
            ),
          ],
        ),
      ],
    );
  }
}
