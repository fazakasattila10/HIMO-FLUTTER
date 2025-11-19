import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_opencv_bridge/app_colors.dart';
import 'package:flutter_opencv_bridge/app_text_styles.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image/image.dart' as img;
import 'package:lottie/lottie.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'image_color_analyzer.dart';

class CalibrationResultPage extends StatefulWidget {
  final File imageFile;
  const CalibrationResultPage({super.key, required this.imageFile});

  @override
  State<CalibrationResultPage> createState() => _CalibrationResultPageState();
}

class _CalibrationResultPageState extends State<CalibrationResultPage> {
  List<File> processedFiles = [];
  List<int> dominantHues = [];
  int? selectedHue;
  int? selectedIndex;
  late final LottieComposition _composition;
  bool resultNegative = false;
  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    _process();
  }

  Future<void> _process() async {
    final bytes = await widget.imageFile.readAsBytes();
    final decoded = img.decodeImage(bytes)!;

    final result = await ImageColorAnalyzer.analyze(decoded);

    final dir = await getTemporaryDirectory();
    List<File> tempFiles = [];

    for (int i = 0; i < result.processedImages.length; i++) {
      final outPath = '${dir.path}/processed_$i.png';
      final png = img.encodePng(result.processedImages[i]);
      final file = File(outPath);
      await file.writeAsBytes(png);
      tempFiles.add(file);
    }

    setState(() {
      processedFiles = tempFiles;
      dominantHues = result.dominantHues;
      if (processedFiles.isEmpty && dominantHues.isEmpty){
        resultNegative = true;
      }
    });
  }

  Future<void> _finishCalibration() async {
    if (selectedIndex == null) return;

    final selectedFile = processedFiles[selectedIndex!];
    final selectedHueValue = selectedHue!;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('calibration_image_path', selectedFile.path);
    await prefs.setInt('calibration_hue', selectedHueValue);



    if (mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }
  Future<void> _closeScreen() async {

    if (mounted) {
      Navigator.pop(context);
    }
  }
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // _loadAnimation();
  }
  Future<void> _loadAnimation() async {
    _composition = await AssetLottie('assets/imageload.json').load();
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(

      backgroundColor:  AppColors.darkgrey_background,
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
        child: resultNegative?Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Spacer(),
              Text("Something went wrong...", style: AppTextStyles.whiteEncodeSans24,),
              SizedBox(height: 20,),
              SvgPicture.asset(
                'assets/wrong.svg',
                width: 100,
                height: 100,
                color: Colors.white,
              ),
              SizedBox(height: 10,),
              Center(child: Text("The app was unable to find a dominant color. Please restart calibration with a new image", style: AppTextStyles.whiteEncodeSans14,textAlign: TextAlign.center)),
              const Spacer(),
              Center(
                child: ElevatedButton(
                  onPressed: _closeScreen,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.blue_light,
                    padding: const EdgeInsets.symmetric(
                        vertical: 10, horizontal: 80),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    "Close",
                    style: AppTextStyles.whiteEncodeSans14,
                  ),
                ),
              ),

              const SizedBox(height: 30),
            ],
          ),
        ):
        processedFiles.isEmpty
            ?Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [

              Text("Searching for dominant color areas...", style: AppTextStyles.whiteEncodeSans14,textAlign: TextAlign.center),
              SizedBox(height: 20,),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.darkest_background,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Lottie.asset(
                    'assets/imageload.json',
                    width: 150,
                    height: 150,
                    repeat: true,
                  ),
                ),
              ),

            ],
          ),
        )
            : Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [

              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [

                    SizedBox(height: 20),
                    Text(
                      "PLEASE SELECT THE RIGHT COLOR.",
                      style:  AppTextStyles.whiteEncodeSansSC14_70,
                      textAlign: TextAlign.left
                    ),
                    SizedBox(height: 4),
                    Text(
                      "Tap on the correct image to select.",
                      style:  TextStyle(
                        fontFamily: 'EncodeSans',
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.white70,
                      ),
                        textAlign: TextAlign.left
                    ),
                  ],
                ),
              ),


              Expanded(
                child: ListView.builder(
                  itemCount: processedFiles.length,
                  itemBuilder: (context, i) {
                    final hue = dominantHues[i];
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          selectedHue = hue;
                          selectedIndex = i;
                        });
                      },
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: selectedIndex == i
                                ? Colors.cyanAccent
                                : Colors.grey,
                            width: 3,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(
                            processedFiles[i],
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),


              // Center(
              //   child: Padding(
              //     padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 60),
              //     child: ElevatedButton(
              //       onPressed: selectedIndex == null ? null : _finishCalibration,
              //       style: ElevatedButton.styleFrom(
              //         backgroundColor: Colors.lightBlueAccent,
              //         foregroundColor: Colors.white,
              //         padding: const EdgeInsets.symmetric(
              //             vertical: 10, horizontal: 18),
              //         disabledBackgroundColor: Colors.grey,
              //         minimumSize: const Size(double.infinity, 48),
              //         shape: RoundedRectangleBorder(
              //           borderRadius: BorderRadius.circular(24),
              //         ),
              //       ),
              //       child: Text(
              //         "Finish calibration",
              //         style: TextStyle(fontSize: 16),
              //       ),
              //     ),
              //   ),
              // ),
              Center(
                child: ElevatedButton(
                  onPressed: selectedIndex == null ? null : _finishCalibration,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.blue_light,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.grey_disabled,
                    padding: const EdgeInsets.symmetric(
                        vertical: 10, horizontal: 80),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    "Finish calibration",
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
}
