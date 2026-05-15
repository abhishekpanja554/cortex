import 'package:cortex/core/constants/colors.dart';
import 'package:cortex/core/constants/string_constants.dart';
import 'package:cortex/features/app_core/presentation/screens/app_base.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToHome();
  }

  _navigateToHome() async {
    await Future.delayed(const Duration(milliseconds: 2000), () {});
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const AppBase()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          children: [
            const Spacer(flex: 5),
            RichText(
              text: TextSpan(
                style: GoogleFonts.roboto(
                  fontSize: 42,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1.0,
                ),
                children: const [
                  TextSpan(
                    text: AppStrings.inotes,
                    style: TextStyle(color: Color(0xFF333333)),
                  ),
                  TextSpan(
                    text: AppStrings.ai,
                    style: TextStyle(color: AppColors.primary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              AppStrings.tagline,
              style: GoogleFonts.roboto(
                fontSize: 22,
                fontWeight: FontWeight.w400,
                color: const Color(0xFF333333),
              ),
            ),
            const Spacer(flex: 2),
          ],
        ),
      ),
    );
  }
}
