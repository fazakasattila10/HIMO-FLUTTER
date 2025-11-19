import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_opencv_bridge/app_colors.dart';
import 'package:flutter_opencv_bridge/app_text_styles.dart';
import 'package:flutter_opencv_bridge/exercise_step3_page.dart';
import 'package:flutter_opencv_bridge/progress_bar.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';

class ExerciseStep2Page extends StatefulWidget {
  const ExerciseStep2Page({super.key});

  @override
  State<ExerciseStep2Page> createState() => _ExerciseStep2PageState();
}

class _ExerciseStep2PageState extends State<ExerciseStep2Page> {
  File? calibrationImage;
  int? hue;

  @override
  void initState() {
    super.initState();
    loadCalibrationData();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }
  Future<void> loadCalibrationData() async {
    final prefs = await SharedPreferences.getInstance();
    final imagePath = prefs.getString('calibration_image_path');
    final hueValue = prefs.getInt('calibration_hue');

    if (imagePath != null && hueValue != null && File(imagePath).existsSync()) {
      setState(() {
        calibrationImage = File(imagePath);
        hue = hueValue;
      });
      print('📸 Betöltve: $imagePath');
      print('🎨 Hue: $hueValue');
    } else {
      print('⚠️ Nincs elmentett kalibráció!');
    }
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
              ProgressBar(activeCount: 2),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text(
                    "Step 2:",
                    style: AppTextStyles.whiteEncodeSans16Bold,
                  ),
                  const Text(
                    " Confirm the color of the socks",
                    style: AppTextStyles.whiteEncodeSans16,
                  ),
                ],
              ),

              const SizedBox(height: 60),


              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      if (calibrationImage != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(
                            calibrationImage!,
                            fit: BoxFit.contain,
                          ),
                        )
                      else
                        Column(
                          children: const [
                            SizedBox(height: 60),
                            CircularProgressIndicator(color: Colors.cyan),
                            SizedBox(height: 16),
                            Text(
                              "Loading calibration image...",
                              style:
                              AppTextStyles.whiteEncodeSans14_70,
                            ),
                          ],
                        ),
                      // const SizedBox(height: 12),
                      // Text(
                      //   hue != null
                      //       ? "Dominant hue value: $hue"
                      //       : "No hue data found.",
                      //   style: const TextStyle(
                      //       color: Colors.white70, fontSize: 14),
                      // ),
                      // const SizedBox(height: 20),
                      const Text(
                        "This is the color you selected after the last calibration. If this is not correct, please go back to the main screen and start a calibration.",
                        style:
                        AppTextStyles.whiteEncodeSans14,
                        textAlign: TextAlign.justify,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),
              Center(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const ExerciseStep3Page()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.blue_light,
                    disabledBackgroundColor: AppColors.darkgrey_background,
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
}
