import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import '../../../../features/authentification/data/datasources/auth_remote_datasource.dart';
import '../../../../features/authentification/data/repositories/auth_repository_impl.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../l10n/app_localizations.dart';

class PersonalInfoSection extends StatefulWidget {
  const PersonalInfoSection({Key? key}) : super(key: key);

  @override
  State<PersonalInfoSection> createState() => _PersonalInfoSectionState();
}

class _PersonalInfoSectionState extends State<PersonalInfoSection> {
  String _username = 'Loading...';
  String _email = 'Loading...';

  String _height = '';
  String _weight = '';
  String _age = '';
  String _gender = '';

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _username = prefs.getString('user_name') ?? 'Utilisateur';
      _email = prefs.getString('user_email') ?? 'user@motionai.com';
      _height = prefs.getString('user_height') ?? '';
      _weight = prefs.getString('user_weight') ?? '';
      _age = prefs.getString('user_age') ?? '';
      _gender = prefs.getString('user_gender') ?? '';
    });
  }

  Future<void> _showEditDialog() async {
    final l10n = AppLocalizations.of(context)!;
    final nameController = TextEditingController(text: _username);
    final emailController = TextEditingController(text: _email);
    bool isLoading = false;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            final theme = Theme.of(context);
            return AlertDialog(
              backgroundColor: theme.cardColor,
              title: Text(l10n.editInformation, style: theme.textTheme.titleLarge),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(labelText: l10n.usernameLabel),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: emailController,
                    decoration: InputDecoration(labelText: l10n.emailLabel),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(l10n.cancel),
                ),
                ElevatedButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                          setStateDialog(() => isLoading = true);
                          try {
                            final authRepo = AuthRepositoryImpl(
                              remoteDataSource: AuthRemoteDataSourceImpl(
                                client: Dio(BaseOptions(baseUrl: 'http://127.0.0.1:8000/api/v1')),
                              ),
                            );
                            await authRepo.updateUser(_email, emailController.text, nameController.text);
                            setState(() {
                              _username = nameController.text;
                              _email = emailController.text;
                            });
                            _loadUserInfo();
                            if (mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(l10n.infoUpdated)),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('${l10n.errorPrefix}${e.toString().replaceAll("Exception: ", "")}')),
                              );
                            }
                          } finally {
                            setStateDialog(() => isLoading = false);
                          }
                        },
                  child: isLoading
                      ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Theme.of(context).colorScheme.onPrimary))
                      : Text(l10n.saveButton),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showBodyMeasurementsDialog() async {
    final heightController = TextEditingController(text: _height);
    final weightController = TextEditingController(text: _weight);
    final ageController = TextEditingController(text: _age);
    String selectedGender = _gender.isNotEmpty ? _gender : 'Not specified';

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            final theme = Theme.of(context);
            return AlertDialog(
              backgroundColor: theme.cardColor,
              title: Row(
                children: [
                  Icon(Icons.monitor_weight_outlined, color: theme.primaryColor, size: 22),
                  const SizedBox(width: 10),
                  Text('Body Measurements', style: theme.textTheme.titleLarge),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: heightController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        labelText: 'Height',
                        hintText: 'e.g. 175',
                        suffixText: 'cm',
                        prefixIcon: const Icon(Icons.height),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: weightController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Weight',
                        hintText: 'e.g. 70',
                        suffixText: 'kg',
                        prefixIcon: const Icon(Icons.monitor_weight_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: ageController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        labelText: 'Age',
                        hintText: 'e.g. 25',
                        suffixText: 'years',
                        prefixIcon: const Icon(Icons.cake_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Gender',
                      style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: ['Male', 'Female', 'Not specified'].map((g) {
                        final isSelected = selectedGender == g;
                        return ChoiceChip(
                          label: Text(g),
                          selected: isSelected,
                          onSelected: (_) => setStateDialog(() => selectedGender = g),
                          selectedColor: theme.primaryColor,
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : theme.textTheme.bodyMedium?.color,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton.icon(
                  onPressed: () async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setString('user_height', heightController.text);
                    await prefs.setString('user_weight', weightController.text);
                    await prefs.setString('user_age', ageController.text);
                    await prefs.setString('user_gender', selectedGender);
                    setState(() {
                      _height = heightController.text;
                      _weight = weightController.text;
                      _age = ageController.text;
                      _gender = selectedGender;
                    });
                    if (mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Body measurements saved!')),
                      );
                    }
                  },
                  icon: const Icon(Icons.save, size: 16),
                  label: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Save body measurements to the backend (profile_json column)
  Future<void> _saveProfileToBackend({String? height, String? weight, String? age, String? gender}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final email = prefs.getString('user_email') ?? _email;
      await Dio(BaseOptions(baseUrl: 'http://127.0.0.1:8000/api/v1')).put(
        '/auth/profile',
        data: {
          'email': email,
          if (height != null) 'height': height,
          if (weight != null) 'weight': weight,
          if (age != null) 'age': age,
          if (gender != null) 'gender': gender,
        },
      );
    } catch (e) {
      debugPrint('Failed to save profile to backend: $e');
      // Silently fail (data is already saved locally)
    }
  }

  Future<void> _editSingleField(String fieldId, String fieldName, String unit, String currentValue, IconData icon, Future<void> Function(String) onSave) async {
    final controller = TextEditingController(text: currentValue);
    await showDialog(
      context: context,
      builder: (ctx) {
        final l10n = AppLocalizations.of(ctx)!;
        final theme = Theme.of(ctx);
        return AlertDialog(
          backgroundColor: theme.cardColor,
          title: Row(
            children: [
              Icon(icon, color: theme.primaryColor, size: 20),
              const SizedBox(width: 10),
              Text(l10n.editField(fieldName), style: theme.textTheme.titleLarge),
            ],
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
            decoration: InputDecoration(
              labelText: fieldName,
              suffixText: unit,
              prefixIcon: Icon(icon),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.cancel)),
            ElevatedButton.icon(
              onPressed: () async {
                await onSave(controller.text);
                // Also persist to backend database
                await _saveProfileToBackend(
                  height: fieldId == 'height' ? controller.text : null,
                  weight: fieldId == 'weight' ? controller.text : null,
                  age: fieldId == 'age' ? controller.text : null,
                );
                if (mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.fieldUpdated(fieldName))),
                  );
                }
              },
              icon: const Icon(Icons.save, size: 16),
              label: Text(l10n.saveButton),
            ),
          ],
        );
      },
    );
  }

  Future<void> _editGender() async {
    String selected = _gender.isNotEmpty ? _gender : 'Not specified';
    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setD) {
            final l10n = AppLocalizations.of(ctx)!;
            final theme = Theme.of(ctx);
            return AlertDialog(
              backgroundColor: theme.cardColor,
              title: Row(
                children: [
                  Icon(Icons.person_outline, color: theme.primaryColor, size: 20),
                  const SizedBox(width: 10),
                  Text(l10n.editGender, style: theme.textTheme.titleLarge),
                ],
              ),
              content: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ['Male', 'Female', 'Not specified'].map((g) {
                  final isSelected = selected == g;
                  // Display translated options but save original English keys
                  final String displayText = g == 'Male' ? l10n.maleLabel : g == 'Female' ? l10n.femaleLabel : l10n.notSpecifiedLabel;
                  return ChoiceChip(
                    label: Text(displayText),
                    selected: isSelected,
                    onSelected: (_) => setD(() => selected = g),
                    selectedColor: theme.primaryColor,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : theme.textTheme.bodyMedium?.color,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  );
                }).toList(),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.cancel)),
                ElevatedButton.icon(
                  onPressed: () async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setString('user_gender', selected);
                    setState(() => _gender = selected);
                    // Also persist to backend database
                    await _saveProfileToBackend(gender: selected);
                    if (mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l10n.fieldUpdated(l10n.genderLabel))),
                      );
                    }
                  },
                  icon: const Icon(Icons.save, size: 16),
                  label: Text(l10n.saveButton),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showPasswordEditDialog() async {
    final l10n = AppLocalizations.of(context)!;
    final oldPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool isLoading = false;
    bool obscureOld = true;
    bool obscureNew = true;
    bool obscureConfirm = true;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            final theme = Theme.of(context);
            return AlertDialog(
              backgroundColor: theme.cardColor,
              title: Text(l10n.editPassword, style: theme.textTheme.titleLarge),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: oldPasswordController,
                    obscureText: obscureOld,
                    decoration: InputDecoration(
                      labelText: l10n.oldPassword,
                      suffixIcon: IconButton(
                        icon: Icon(obscureOld ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setStateDialog(() => obscureOld = !obscureOld),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: newPasswordController,
                    obscureText: obscureNew,
                    decoration: InputDecoration(
                      labelText: l10n.newPassword,
                      suffixIcon: IconButton(
                        icon: Icon(obscureNew ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setStateDialog(() => obscureNew = !obscureNew),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: confirmPasswordController,
                    obscureText: obscureConfirm,
                    decoration: InputDecoration(
                      labelText: l10n.confirmPassword,
                      suffixIcon: IconButton(
                        icon: Icon(obscureConfirm ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setStateDialog(() => obscureConfirm = !obscureConfirm),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(l10n.cancel),
                ),
                ElevatedButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                          if (newPasswordController.text != confirmPasswordController.text) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(l10n.passwordsDoNotMatch)),
                            );
                            return;
                          }
                          if (newPasswordController.text.length < 4) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(l10n.passwordTooShort)),
                            );
                            return;
                          }
                          setStateDialog(() => isLoading = true);
                          try {
                            final authRepo = AuthRepositoryImpl(
                              remoteDataSource: AuthRemoteDataSourceImpl(
                                client: Dio(BaseOptions(baseUrl: 'http://127.0.0.1:8000/api/v1')),
                              ),
                            );
                            await authRepo.updatePassword(
                              _email,
                              oldPasswordController.text,
                              newPasswordController.text,
                            );
                            if (mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(l10n.passwordUpdated)),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('${l10n.errorPrefix}${e.toString().replaceAll("Exception: ", "")}')),
                              );
                            }
                          } finally {
                            setStateDialog(() => isLoading = false);
                          }
                        },
                  child: isLoading
                      ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Theme.of(context).colorScheme.onPrimary))
                      : Text(l10n.saveButton),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Title
        Row(
          children: [
            SvgPicture.asset(
              'assets/icons/user.svg',
              width: 24,
              height: 24,
              colorFilter: ColorFilter.mode(theme.primaryColor, BlendMode.srcIn),
            ),
            const SizedBox(width: 12),
            Text(
              l10n.personalInformation,
              style: theme.textTheme.titleLarge?.copyWith(fontSize: 18),
            ),
          ],
        ),

        const SizedBox(height: 24),

        // Account Info Container
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.dividerColor),
          ),
          child: Column(
            children: [
              _buildInfoField(context, label: _username, onEdit: _showEditDialog),
              const SizedBox(height: 16),
              _buildInfoField(context, label: _email, onEdit: _showEditDialog),
              const SizedBox(height: 16),
              _buildInfoField(context, label: l10n.changePassword, onEdit: _showPasswordEditDialog),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Body Measurements Title
        Row(
          children: [
            Icon(Icons.accessibility_new, color: theme.primaryColor, size: 24),
            const SizedBox(width: 12),
            Text(
              l10n.bodyMeasurements,
              style: theme.textTheme.titleLarge?.copyWith(fontSize: 18),
            ),
          ],
        ),

        const SizedBox(height: 16),

        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.dividerColor),
          ),
          child: Column(
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final isMobile = constraints.maxWidth < 600;
                  final heightCard = _buildStatCard(context, icon: Icons.height, label: l10n.heightLabel, value: _height.isNotEmpty ? '$_height cm' : '— cm', onTap: () => _editSingleField('height', l10n.heightLabel, 'cm', _height, Icons.height, (v) async { final p = await SharedPreferences.getInstance(); await p.setString('user_height', v); setState(() => _height = v); }));
                  final weightCard = _buildStatCard(context, icon: Icons.monitor_weight_outlined, label: l10n.weightLabel, value: _weight.isNotEmpty ? '$_weight kg' : '— kg', onTap: () => _editSingleField('weight', l10n.weightLabel, 'kg', _weight, Icons.monitor_weight_outlined, (v) async { final p = await SharedPreferences.getInstance(); await p.setString('user_weight', v); setState(() => _weight = v); }));
                  final ageCard = _buildStatCard(context, icon: Icons.cake_outlined, label: l10n.ageLabel, value: _age.isNotEmpty ? '$_age yrs' : '— yrs', onTap: () => _editSingleField('age', l10n.ageLabel, 'yrs', _age, Icons.cake_outlined, (v) async { final p = await SharedPreferences.getInstance(); await p.setString('user_age', v); setState(() => _age = v); }));
                  final genderCard = _buildStatCard(context, icon: Icons.person_outline, label: l10n.genderLabel, value: _gender.isNotEmpty ? _gender : '—', onTap: _editGender);

                  if (isMobile) {
                    return Column(
                      children: [
                        Row(children: [Expanded(child: heightCard), const SizedBox(width: 12), Expanded(child: weightCard)]),
                        const SizedBox(height: 12),
                        Row(children: [Expanded(child: ageCard), const SizedBox(width: 12), Expanded(child: genderCard)]),
                      ],
                    );
                  }
                  
                  return Row(
                    children: [
                      Expanded(child: heightCard),
                      const SizedBox(width: 12),
                      Expanded(child: weightCard),
                      const SizedBox(width: 12),
                      Expanded(child: ageCard),
                      const SizedBox(width: 12),
                      Expanded(child: genderCard),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      decoration: BoxDecoration(
        color: theme.primaryColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.primaryColor.withValues(alpha: 0.15)),
      ),
      child: Column(
        children: [
          Icon(icon, color: theme.primaryColor, size: 22),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.primaryColor,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(height: 6),
            Icon(Icons.edit, size: 12, color: theme.primaryColor.withValues(alpha: 0.5)),
          ],
        ],
      ),
    ),   // closes Container
    );   // closes InkWell
  }

  Widget _buildInfoField(BuildContext context, {
    required String label,
    required VoidCallback onEdit,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.textTheme.bodyLarge?.color),
          ),
          IconButton(
            onPressed: onEdit,
            icon: SvgPicture.asset(
              'assets/icons/edit.svg',
              width: 20,
              height: 20,
              colorFilter: ColorFilter.mode(
                theme.textTheme.bodyMedium?.color ?? Colors.grey,
                BlendMode.srcIn,
              ),
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}
