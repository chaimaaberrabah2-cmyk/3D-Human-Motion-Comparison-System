import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

class LanguageSelector extends StatefulWidget {
  const LanguageSelector({Key? key}) : super(key: key);

  @override
  State<LanguageSelector> createState() => _LanguageSelectorState();
}

class _LanguageSelectorState extends State<LanguageSelector> {
  bool isDarkMode = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 32),
        const Divider(color: Color(0xFF1C293D)),
        const SizedBox(height: 32),
        
        // Language Selector
        InkWell(
          onTap: () {
            // TODO: Show language picker
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: const [
                    Icon(
                      Icons.language,
                      color: AppColors.textWhite,
                      size: 24,
                    ),
                    SizedBox(width: 12),
                    Text(
                      'Language',
                      style: TextStyle(
                        color: AppColors.textWhite,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: const [
                    Text(
                      'English',
                      style: TextStyle(
                        color: AppColors.textGray,
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(
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
            const Text(
              'Light',
              style: TextStyle(
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
