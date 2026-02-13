import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/l10n/locale_provider.dart';
import '../../../../l10n/app_localizations.dart';

class LanguageSelector extends StatefulWidget {
  final Function(Locale)? onLanguageChanged;
  
  const LanguageSelector({Key? key, this.onLanguageChanged}) : super(key: key);

  @override
  State<LanguageSelector> createState() => _LanguageSelectorState();
}

class _LanguageSelectorState extends State<LanguageSelector> {
  bool isDarkMode = true;
  Locale? _selectedLocale;

  void _showLanguagePicker(BuildContext context) {
    final localeProvider = Provider.of<LocaleProvider>(context, listen: false);
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0E172B),
          title: const Text(
            'Select Language',
            style: TextStyle(color: AppColors.textWhite),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: L10n.all.map((locale) {
              final isSelected = (_selectedLocale ?? localeProvider.locale) == locale;
              return ListTile(
                title: Text(
                  L10n.getLanguageName(locale.languageCode),
                  style: TextStyle(
                    color: isSelected ? AppColors.accentBlue : AppColors.textWhite,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
                trailing: isSelected
                    ? const Icon(Icons.check, color: AppColors.accentBlue)
                    : null,
                onTap: () {
                  setState(() {
                    _selectedLocale = locale;
                  });
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
    
    return Column(
      children: [
        const SizedBox(height: 32),
        const Divider(color: Color(0xFF1C293D)),
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
                      colorFilter: const ColorFilter.mode(
                        AppColors.textWhite,
                        BlendMode.srcIn,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      AppLocalizations.of(context)!.language,
                      style: const TextStyle(
                        color: AppColors.textWhite,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Text(
                      L10n.getLanguageName((_selectedLocale ?? localeProvider.locale).languageCode),
                      style: const TextStyle(
                        color: AppColors.textGray,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.chevron_right,
                      color: AppColors.textGray,
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
              AppLocalizations.of(context)!.light,
              style: const TextStyle(
                color: AppColors.textWhite,
                fontSize: 14,
              ),
            ),
            Switch(
              value: isDarkMode,
              onChanged: (value) {
                setState(() {
                  isDarkMode = value;
                });
              },
              activeColor: AppColors.accentBlue,
              inactiveThumbColor: AppColors.textGray,
              inactiveTrackColor: const Color(0xFF1C293D),
            ),
          ],
        ),
      ],
    );
  }
}
