import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_opencv_bridge/app_colors.dart';
import 'package:flutter_opencv_bridge/app_text_styles.dart';
import 'package:flutter_opencv_bridge/exercise_step2_page.dart';
import 'package:flutter_opencv_bridge/progress_bar.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ExerciseStep1Page extends StatefulWidget {
  const ExerciseStep1Page({super.key});

  @override
  State<ExerciseStep1Page> createState() => _ExerciseStep1PageState();
}

class _ExerciseStep1PageState extends State<ExerciseStep1Page> {
  int _selectedRepetitions = 5; // alapértelmezett érték
  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkgrey_background,
      appBar: AppBar(

        automaticallyImplyLeading: false,
        backgroundColor: AppColors.darkgrey_background,
        elevation: 0,
        leadingWidth: 120,
        leading: TextButton(
          onPressed: () => Navigator.pop(context),
          child: Row(
            children: [
              SvgPicture.asset(
                'assets/back.svg',
                width: 16,
                height: 20,
                color: Colors.white,
              ),
              SizedBox(width: 10,),
              const Text("Back", style: AppTextStyles.navigation_top),
            ],
          ),
        ),
        title: const Text("Exercise", style: AppTextStyles.title_top),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            child: const Text("Close", style: AppTextStyles.navigation_top),
          )
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ProgressBar(activeCount: 1),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Text(
                            "Step 1:",
                            style: AppTextStyles.whiteEncodeSans16Bold,
                          ),
                          const Text(
                            " Setting up the exercise",
                            style: AppTextStyles.whiteEncodeSans16,
                          ),
                        ],
                      ),
                      const SizedBox(height: 60),

                      Padding(
                        padding: const EdgeInsets.only( left:20.0),
                        child: const Text(
                          "Select the number of repetitions",
                          style: AppTextStyles.whiteEncodeSansSC14_70,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Dropdown
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.darkest_background,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.refresh, color: Colors.white),
                            const SizedBox(width: 8),
                            const Text("Repetitions",
                                style: AppTextStyles.button_text),
                            const Spacer(),
                            DropdownButton<int>(
                              value: _selectedRepetitions,
                              dropdownColor: AppColors.blue_dark,
                              underline: const SizedBox(),
                              style: AppTextStyles.button_text,
                              items: [5, 10, 15].map((e) {
                                return DropdownMenuItem(
                                  value: e,
                                  child: Text("$e", style: AppTextStyles.button_text,)
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() {
                                    _selectedRepetitions = val;
                                  });
                                }
                              },
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      Padding(
                        padding: const EdgeInsets.only(left:20),
                        child: const Text("Your exercise:",
                            style: AppTextStyles.whiteEncodeSansSC14_70,),
                      ),
                      const SizedBox(height: 12),

                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.darkest_background,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _exerciseRow("foot_up.svg", "arrow_up_down.svg",
                                "Calf raise", "$_selectedRepetitions times"),
                            _exerciseRow(
                                "clock.svg", null, "Rest", "15 seconds"),
                            _exerciseRow("foot_in.svg", "arrow_left_right.svg",
                                "Toe fists", "$_selectedRepetitions times"),
                            _exerciseRow(
                                "clock.svg", null, "Rest", "15 seconds"),
                            _exerciseRow("foot_up.svg", "arrow_up.svg",
                                "Stay on toes", "15 seconds"),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // --------- Continue gomb ----------
              Center(
                child: ElevatedButton(
                  onPressed: _saveAndContinue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.blue_light,
                    padding: const EdgeInsets.symmetric(
                        vertical: 10, horizontal: 80),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    "Continue",
                    style: AppTextStyles.whiteEncodeSans14,
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
  Widget _progressBar() {
    return Row(
      children: [
        // Aktív
        Expanded(
          child: Container(
            height: 14,
            decoration: BoxDecoration(
              color: AppColors.blue_light,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
        const SizedBox(width: 2),

        // Inaktív — csak border
        Expanded(
          child: Container(
            height: 14,
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: AppColors.blue_light,
                width: 1, // 👈 vékony border
              ),
            ),
          ),
        ),
        const SizedBox(width: 2),

        // Inaktív — csak border
        Expanded(
          child: Container(
            height: 14,
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: AppColors.blue_light,
                width: 1,
              ),
            ),
          ),
        ),
      ],
    );
  }


  Widget _exerciseRow(String icon, String? icon2, String title, String detail) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.blue_dark,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: icon2 == null
                  ? SvgPicture.asset(
                'assets/$icon',
                width: 28,
                height: 28,
                color: Colors.white,
              )
                  : icon2.contains("right")
                  ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SvgPicture.asset(
                    'assets/$icon',
                    width: 23,
                    height: 23,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 2),
                  SvgPicture.asset(
                    'assets/$icon2',
                    height: 8,
                    color: Colors.white,
                  ),
                ],
              )
                  : Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SvgPicture.asset(
                    'assets/$icon',
                    width: 25,
                    height: 25,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 3),
                  SvgPicture.asset(
                    'assets/$icon2',
                    width: 8,
                    color: Colors.white,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(title,
                style:  AppTextStyles.whiteEncodeSans14),
          ),
          Text(detail,
              style: AppTextStyles.whiteEncodeSans14_70),
        ],
      ),
    );
  }

  Future<void> _saveAndContinue() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('selectedRepetitions', _selectedRepetitions);

    if (mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const ExerciseStep2Page()),
      );
    }
  }
}
