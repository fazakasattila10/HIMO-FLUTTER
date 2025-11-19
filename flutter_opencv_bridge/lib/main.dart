import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_opencv_bridge/app_colors.dart';
import 'package:flutter_opencv_bridge/app_text_styles.dart';
import 'package:flutter_opencv_bridge/calibration_step1_page.dart';
import 'package:flutter_opencv_bridge/exercise_step1_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'qr_scan_page.dart';
import 'package:flutter_svg/flutter_svg.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HIMO',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: AppColors.darkgrey_background,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _hasCalibrationData = false;
  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    // WidgetsBinding.instance.addObserver(this);
    _checkCalibration();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 40),
            // Cím
            Text(
              "H I M O",
              style: AppTextStyles.headline_big,
            ),
            const SizedBox(height: 8),
            const Text(
              "for flatfoot therapy",
              style: AppTextStyles.headline_small,
            ),
            const SizedBox(height: 60),

            // START PLAYING
            Center(
              child: _MenuButton(
                text: "Start playing",
                color: _hasCalibrationData?AppColors.blue_light : AppColors.grey_disabled,
                icon: 'mobile.svg',
                icon2: 'laptop.svg',
                isWhite: true,
                onTap: () {
                  if (_hasCalibrationData) {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const QRScanPage()),
                    ).then((_) => _checkCalibration());
                  }
                },
              ),
            ),

            const SizedBox(height: 20),

            // EXERCISE
            Center(
              child: _MenuButton(
                text: "Exercise",
                color:  _hasCalibrationData?AppColors.blue_light : AppColors.grey_disabled,
                icon:'mobile.svg',
                icon2:'laptop_disabled.svg',
                isWhite: true,
                onTap: () {
                  if (true/*_hasCalibrationData*/) {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const ExerciseStep1Page()),
                    ).then((_) => _checkCalibration());
                  }
                },
              ),
            ),

            const SizedBox(height: 20),

            // CALIBRATE
            Center(
              child: _MenuButton(
                text: "Calibrate",
                color: AppColors.green_button,
                icon: 'foot.svg',
                isWhite: false,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const CalibrationStep1Page()),
                  ).then((_) => _checkCalibration());
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
/*
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
*/
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

  }
/*
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Ha az app újra aktív lesz, frissítjük az értéket
    if (state == AppLifecycleState.resumed) {
      _checkCalibration();
    }
  }*/
  Future<void> _checkCalibration() async {
    final prefs = await SharedPreferences.getInstance();
    final imagePath = prefs.getString('calibration_image_path');
    final hueValue = prefs.getInt('calibration_hue');

    final hasData = imagePath != null && hueValue != null;

    if (mounted && hasData != _hasCalibrationData) {
      setState(() {
        _hasCalibrationData = hasData;
      });
    }
  }
}

class _MenuButton extends StatelessWidget {
  final String text;
  final Color color;
  final String icon;
  final String? icon2;
  final bool isWhite;
  final VoidCallback onTap;

  const _MenuButton({
    required this.text,
    required this.color,
    required this.icon,
    this.icon2,
    required this.isWhite,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 280,
      height: 70,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        onPressed: onTap,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              text,
              style: AppTextStyles.button,
            ),
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isWhite?Colors.white:Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.dark_border,
                  width: 2,
                ),
              ),
              padding: const EdgeInsets.all(8),
              child: icon2 == null?SvgPicture.asset(
                'assets/$icon',
              ):Padding(
                padding: const EdgeInsets.only(right: 4.0,top: 6.0,bottom: 6.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Flexible(
                      child: SizedBox(
                        height: double.infinity,
                        child: FittedBox(
                          fit: BoxFit.fitHeight,
                          child: SvgPicture.asset('assets/$icon'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: SizedBox(
                        height: double.infinity,
                        child: FittedBox(
                          fit: BoxFit.fitHeight,
                          child: SvgPicture.asset('assets/$icon2'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

