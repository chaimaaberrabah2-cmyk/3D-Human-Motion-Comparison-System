import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../../core/theme/app_colors.dart';

class BodyProfilePage extends StatefulWidget {
  const BodyProfilePage({Key? key}) : super(key: key);

  @override
  State<BodyProfilePage> createState() => _BodyProfilePageState();
}

class _BodyProfilePageState extends State<BodyProfilePage> {
  final PageController _pageController = PageController();
  int _currentStep = 0;

  // Profile Data
  String? _selectedGender;
  int _heightCm = 175; // Default middle
  int _weightKg = 75; // Default middle

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _finishSetup();
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _finishSetup() async {
    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: AppColors.accentBlue)),
    );

    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Save locally
      await prefs.setString('user_gender', _selectedGender ?? 'Not specified');
      await prefs.setString('user_height', _heightCm.toString());
      await prefs.setString('user_weight', _weightKg.toString());
      
      final email = prefs.getString('user_email') ?? '';
      final age = prefs.getString('user_age');

      if (email.isNotEmpty) {
        // Send to backend
        await Dio(BaseOptions(baseUrl: 'http://127.0.0.1:8000/api/v1')).put(
          '/auth/profile',
          data: {
            'email': email,
            'gender': _selectedGender ?? 'Male',
            'height': _heightCm.toString(),
            'weight': _weightKg.toString(),
            if (age != null) 'age': age,
          },
        );
      }
    } catch (e) {
      debugPrint("Failed to save profile on backend: $e");
    } finally {
      if (mounted) {
        Navigator.pop(context); // pop loading
        Navigator.pushReplacementNamed(context, '/success'); // go to success page
      }
    }
  }

  Widget _buildProgressBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
      child: Row(
        children: List.generate(3, (index) {
          final isActive = index <= _currentStep;
          return Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              height: 4,
              decoration: BoxDecoration(
                color: isActive ? AppColors.accentBlue : Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
                boxShadow: isActive ? [
                  BoxShadow(color: AppColors.accentBlue.withValues(alpha: 0.5), blurRadius: 8)
                ] : [],
              ),
            ),
          );
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 10),
            Stack(
              alignment: Alignment.center,
              children: [
                if (_currentStep > 0)
                  Positioned(
                    left: 20,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
                      onPressed: _previousStep,
                    ),
                  )
                else
                  const SizedBox(height: 20), // Placeholder to maintain height
                
                Align(
                  alignment: Alignment.center,
                  child: Text(
                    'Step ${_currentStep + 1} of 3',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 14),
                  ),
                ),
              ],
            ),
            _buildProgressBar(),
            const SizedBox(height: 10),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(), // Disable swipe to enforce validation
                onPageChanged: (idx) => setState(() => _currentStep = idx),
                children: [
                  _buildGenderStep(),
                  _buildHeightStep(),
                  _buildWeightStep(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(30.0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (_currentStep == 0 && _selectedGender == null) ? null : _nextStep,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentBlue,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.accentBlue.withValues(alpha: 0.3),
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text(
                    _currentStep == 2 ? 'Finish →' : 'Next →',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Step 1: Gender ────────────────────────────────────────────────────────
  Widget _buildGenderStep() {
    return Column(
      children: [
        const Text(
          'Select your gender',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        const Spacer(),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _genderCard('Male', true, AppColors.accentBlue),
            const SizedBox(width: 20),
            _genderCard('Female', false, Colors.pinkAccent.shade200),
          ],
        ),
        const Spacer(flex: 2),
      ],
    );
  }

  Widget _genderCard(String gender, bool isMale, Color activeColor) {
    final isSelected = _selectedGender == gender;
    return GestureDetector(
      onTap: () => setState(() => _selectedGender = gender),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 150,
        height: 380,
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? activeColor : Colors.white.withValues(alpha: 0.1),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected ? [
            BoxShadow(color: activeColor.withValues(alpha: 0.2), blurRadius: 20)
          ] : [],
        ),
        child: Column(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: ColorFiltered(
                  colorFilter: ColorFilter.mode(
                    isSelected ? activeColor : Colors.white.withValues(alpha: 0.3),
                    BlendMode.srcIn,
                  ),
                  child: isMale
                      ? SvgPicture.asset(
                          'assets/svg/man.svg',
                          fit: BoxFit.contain,
                        )
                      : Transform.scale(
                          // MODIFY THIS NUMBER TO CHANGE THE FEMALE SVG SIZE IN STEP 1
                          scale: 2, 
                          child: SvgPicture.asset(
                            'assets/svg/female.svg',
                            fit: BoxFit.contain,
                          ),
                        ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Text(
                gender,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? activeColor : Colors.white.withValues(alpha: 0.6),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  // ── Step 2: Height ────────────────────────────────────────────────────────
  Widget _buildHeightStep() {
    return Column(
      children: [
        const Text(
          'How tall are you?',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        Expanded(
          child: Row(
            children: [
              // Silhouette
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: _selectedGender == 'Female'
                      ? Transform.scale(
                          // MODIFY THIS NUMBER TO CHANGE THE FEMALE SVG SIZE IN STEP 2
                          scale: 2,
                          child: SvgPicture.asset(
                            'assets/svg/female.svg',
                            fit: BoxFit.contain,
                            colorFilter: ColorFilter.mode(
                              Colors.pinkAccent.shade200,
                              BlendMode.srcIn,
                            ),
                          ),
                        )
                      : SvgPicture.asset(
                          'assets/svg/man.svg',
                          fit: BoxFit.contain,
                          colorFilter: const ColorFilter.mode(
                            AppColors.accentBlue,
                            BlendMode.srcIn,
                          ),
                        ),
                ),
              ),
              // Ruler
              SizedBox(
                width: 130, // Increased to prevent horizontal RenderFlex overflow
                child: DefaultTextStyle(
                  style: const TextStyle(color: Colors.white),
                  child: ListWheelScrollView.useDelegate(
                    itemExtent: 50,
                    perspective: 0.005,
                    diameterRatio: 1.5,
                    physics: const FixedExtentScrollPhysics(),
                    onSelectedItemChanged: (idx) => setState(() => _heightCm = 140 + idx),
                    childDelegate: ListWheelChildBuilderDelegate(
                      childCount: 71, // 140 to 210
                      builder: (context, index) {
                        final h = 140 + index;
                        final isSelected = h == _heightCm;
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(width: isSelected ? 20 : 10, height: 2, color: isSelected ? AppColors.accentBlue : Colors.white.withValues(alpha: 0.3)),
                            const SizedBox(width: 10),
                            Text(
                              '$h cm',
                              style: TextStyle(
                                fontSize: isSelected ? 24 : 16,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                color: isSelected ? AppColors.accentBlue : Colors.white.withValues(alpha: 0.4),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Text(
          '$_heightCm cm',
          style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: Colors.white),
        ),
      ],
    );
  }

  // ── Step 3: Weight ────────────────────────────────────────────────────────
  Widget _buildWeightStep() {
    return Column(
      children: [
        const Text(
          'What is your weight?',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: _selectedGender == 'Female'
                ? Transform.scale(
                    // MODIFY THIS NUMBER TO CHANGE THE FEMALE SVG SIZE IN STEP 3
                    scale: 2,
                    child: SvgPicture.asset(
                      'assets/svg/female.svg',
                      fit: BoxFit.contain,
                      colorFilter: ColorFilter.mode(
                        Colors.pinkAccent.shade200,
                        BlendMode.srcIn,
                      ),
                    ),
                  )
                : SvgPicture.asset(
                    'assets/svg/man.svg',
                    fit: BoxFit.contain,
                    colorFilter: const ColorFilter.mode(
                      AppColors.accentBlue,
                      BlendMode.srcIn,
                    ),
                  ),
          ),
        ),
        // Horizontal Scroller
        SizedBox(
          height: 100,
          child: DefaultTextStyle(
            style: const TextStyle(color: Colors.white),
            child: RotatedBox(
              quarterTurns: -1,
              child: ListWheelScrollView.useDelegate(
                itemExtent: 80,
                perspective: 0.005,
                diameterRatio: 2.0,
                physics: const FixedExtentScrollPhysics(),
                onSelectedItemChanged: (idx) => setState(() => _weightKg = 40 + idx),
                childDelegate: ListWheelChildBuilderDelegate(
                  childCount: 111, // 40 to 150
                  builder: (context, index) {
                    final w = 40 + index;
                    final isSelected = w == _weightKg;
                    return RotatedBox(
                      quarterTurns: 1,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFF06B6D4).withValues(alpha: 0.2) : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border: isSelected ? Border.all(color: const Color(0xFF06B6D4), width: 2) : null,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '$w',
                              style: TextStyle(
                                fontSize: isSelected ? 32 : 20,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                color: isSelected ? const Color(0xFF06B6D4) : Colors.white.withValues(alpha: 0.4),
                              ),
                            ),
                            if (isSelected) 
                              const Text('kg', style: TextStyle(color: Color(0xFF06B6D4), fontSize: 12))
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          '$_weightKg kg',
          style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: Colors.white),
        ),
      ],
    );
  }
}
