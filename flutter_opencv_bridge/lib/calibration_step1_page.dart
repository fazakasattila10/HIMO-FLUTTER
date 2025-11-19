import 'dart:ffi';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_opencv_bridge/app_colors.dart';
import 'package:flutter_opencv_bridge/app_text_styles.dart';
import 'package:flutter_opencv_bridge/calibration_result_page.dart';
import 'package:lottie/lottie.dart';

class CalibrationStep1Page extends StatefulWidget {
  const CalibrationStep1Page({super.key});

  @override
  State<CalibrationStep1Page> createState() => _CalibrationStep1PageState();
}


class _CalibrationStep1PageState extends State<CalibrationStep1Page> {
  File? _imageFile;
  final ImagePicker _picker = ImagePicker();
  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }
  Future<void> _takePhoto() async {
    final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
    if (photo == null) return;

    setState(() => _imageFile = File(photo.path));


    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CalibrationResultPage(imageFile: _imageFile!),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkgrey_background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: AppColors.darkgrey_background,
        elevation: 0,
        title: const Text("Calibration", style: AppTextStyles.title_top),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
            child: const Text("Close", style: AppTextStyles.navigation_top),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ---------- Info box ----------
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.darkest_background,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                        child: SvgPicture.asset(
                          'assets/info.svg',
                          width: 28,
                          height: 28,
                          color: Colors.white,
                        )
                    ),
                    const SizedBox(width: 12),
                    Text(
                      "The app detects the feet and the movements of the feet based on the color of the socks. "
                          "The role of the calibration process is to identify this color.",
                      style: AppTextStyles.whiteEncodeSans14,textAlign: TextAlign.justify,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              Padding(
                padding: const EdgeInsets.only(left:16.0),
                child: const Text(
                  "Please follow these steps:",
                  style: AppTextStyles.whiteEncodeSansSC14_70,
                ),
              ),

              const SizedBox(height: 12),


              // ---------- Step cards ----------
              Container(

                decoration: BoxDecoration(
                  color: AppColors.darkest_background,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    _stepItem(
                    icon: "camera.svg",
                    text:
                    "Take a picture of the feet wearing the socks on floor level. "
                        "The socks should cover at least half of the picture area.",
                  ),
                  Container(
                    margin: EdgeInsets.only(left:60, right: 5),
                    color: AppColors.grey_line,
                    height: 1,
                    width: double.infinity,
                  ),
                  _stepItem(
                    icon: "recognize.svg",
                    text:
                    "The app will try to recognize the color of the socks based on the dominant colors on the picture.",
                  ),
                    Container(
                      margin: EdgeInsets.only(left:60, right: 5),
                      color: AppColors.grey_line,
                      height: 1,
                      width: double.infinity,
                    ),
                  _stepItem(
                    icon: "pick.svg",
                    text:
                    "If more than one dominant color will be identified, you will be asked to pick the correct one.",
                  ),
                ]),
              ),

              const SizedBox(height: 24),

              Padding(
                padding: const EdgeInsets.only(left:20.0),
                child: const Text(
                  "Expect a result like this image",
                  style: TextStyle(
                    fontFamily: 'EncodeSansSC',
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.white70,
                    letterSpacing: 1,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // ---------- Example image ----------
              Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(0),
                  child: Image.asset(
                    'assets/image.png',
                    width: 260,
                    fit: BoxFit.cover,
                  ),
                ),
              ),

              const SizedBox(height: 40),

              // ---------- Continue button ----------
              Center(
                child: ElevatedButton(
                  onPressed: _takePhoto,
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
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stepItem({required String icon, required String text}) {
    return Container(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.blue_dark,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                    child: SvgPicture.asset(
                      'assets/$icon',
                      width: 28,
                      height: 28,
                      color: Colors.white,
                    )
                ),
              ),],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.whiteEncodeSans14,
            ),
          ),
        ],
      ),
    );
  }
}
