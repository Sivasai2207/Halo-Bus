import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/primary_button.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  final List<Map<String, String>> _onboardingData = [
    {
      "title": "Welcome to HaloBus",
      "description": "The smartest way to track your college bus in real-time.",
      "image": "assets/logo_themed.png",
    },
    {
      "title": "Live Tracking",
      "description": "Never miss your bus again. Get live updates and accurate ETAs.",
      "image": "assets/onboarding_2.png",
    },
    {
      "title": "Stay Informed",
      "description": "Receive instant notifications for delays and route changes.",
      "image": "assets/onboarding_3.png",
    },
  ];

  void _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_onboarding', true);
    if (!mounted) return;
    context.go('/college-selection');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      body: SafeArea(
        child: Column(
          children: [
            // Skip button
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: _completeOnboarding,
                child: Text("Skip", style: AppTypography.h3.copyWith(color: AppColors.primary)),
              ),
            ),
            
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _onboardingData.length,
                onPageChanged: (index) {
                  setState(() {
                    _currentIndex = index;
                  });
                },
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Placeholder for illustration
                        Container(
                          height: 250,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: AppColors.bgSurface,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: AppColors.borderSubtle),
                            boxShadow: [AppShadows.cardShadow],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: Image.asset(
                              _onboardingData[index]["image"]!,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                        const SizedBox(height: 48),
                        Text(
                          _onboardingData[index]["title"]!,
                          style: AppTypography.h1,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _onboardingData[index]["description"]!,
                          style: AppTypography.bodyLg,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            
            // Bottom controls
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Dots
                  Row(
                    children: List.generate(
                      _onboardingData.length,
                      (index) => buildDot(index, context),
                    ),
                  ),
                  // Next / Get Started button
                  SizedBox(
                    width: 140,
                    height: 52,
                    child: PrimaryButton(
                      text: _currentIndex == _onboardingData.length - 1 ? "Get Started" : "Next",
                      onPressed: () {
                        if (_currentIndex == _onboardingData.length - 1) {
                          _completeOnboarding();
                        } else {
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildDot(int index, BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(right: 8),
      height: 8,
      width: _currentIndex == index ? 24 : 8,
      decoration: BoxDecoration(
        color: _currentIndex == index ? AppColors.primary : AppColors.borderMid,
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}
