import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_opencv_bridge/app_colors.dart';
import 'package:flutter_opencv_bridge/exercise.dart';
import 'package:flutter_opencv_bridge/progress_bar.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_text_styles.dart';

class ExerciseStep3Page extends StatefulWidget {
  const ExerciseStep3Page({super.key});

  @override
  State<ExerciseStep3Page> createState() => _ExerciseStep3PageState();
}

class _ExerciseStep3PageState extends State<ExerciseStep3Page> {
  bool isRightSelected = false; // 👈 alapértelmezett: bal oldali kiválasztva

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  Future<void> _saveSelection() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('foot_orientation', isRightSelected ? 'right' : 'left');
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        await SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
        ]);
        return true;
      },
      child: Scaffold(
        backgroundColor: AppColors.darkgrey_background,
        appBar: AppBar(

            automaticallyImplyLeading: false,
            backgroundColor: AppColors.darkgrey_background,
            elevation: 0,
            leadingWidth: 120,
            leading: TextButton(
              onPressed: () {
                SystemChrome.setPreferredOrientations([
                  DeviceOrientation.portraitUp,
                  DeviceOrientation.portraitDown,
                ]);
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
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
            child:  Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ProgressBar(activeCount: 4),
                Row(
                  children: [
                    const Text(
                      "Step 3:",
                      style: AppTextStyles.whiteEncodeSans16Bold,
                    ),
                    const Text(
                      " Select the orientation of the feet",
                      style: AppTextStyles.whiteEncodeSans16,
                    ),
                  ],
                ),
                const SizedBox(height: 4),

                // központi doboz
                Expanded(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF222222),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          "Please rotate your device to have the camera on the upper right corner.",
                          style: TextStyle(color: Colors.white, fontSize: 14),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  isRightSelected = false;
                                });
                              },
                              child: _orientationIcon("foot_normal.svg", false, !isRightSelected),
                            ),
                            const SizedBox(width: 20),
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  isRightSelected = true;
                                });
                              },
                              child: _orientationIcon("foot_normal.svg", true, isRightSelected),
                            ),
                          ],
                        ),

                        const SizedBox(height: 4),
                        const Text(
                          "Tap one of the icons above to select the orientation of the feet.",
                          style: TextStyle(color: Colors.white, fontSize: 14),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                Center(
                  child: ElevatedButton(

                    onPressed: ()  async {
                      await _saveSelection();
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (_) => const Exercise(),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.blue_light,
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 80),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      "Start",
                      style: AppTextStyles.whiteEncodeSans14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _orientationIcon(String asset, bool right, bool selected) {
    return Container(
      width: 70,
      height: 70,
      decoration: BoxDecoration(
        color: Colors.cyan.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: selected ? Colors.cyan : Colors.transparent,
          width: 3,
        ),
      ),
      child: Center(
        child: !right
            ? SvgPicture.asset(
          'assets/$asset',
          width: 40,
          height: 40,
          color: Colors.white,
        )
            : Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()..scale(-1.0, 1.0),
          child: SvgPicture.asset(
            'assets/$asset',
            width: 40,
            height: 40,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
