import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_opencv_bridge/app_colors.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_opencv_bridge/app_text_styles.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _ev = EventChannel('opencv_event_channel');
const _mc = MethodChannel('opencv_channel');

class Exercise extends StatefulWidget {
  const Exercise({super.key});

  @override
  State<Exercise> createState() => _ExerciseState();
}

class _ExerciseState extends State<Exercise> {
  StreamSubscription? sub;
  int rectCount = 0;
  int lastSentMs = 0;

  // ikonok
  String icon = "foot_up.svg";
  String? icon2 = "arrow_up_down.svg";

  // aktuális feladat indexe
  int currentTask = 1;

  // pihenő timerhez
  Timer? restTimer;
  int restSeconds = 15;

  // 🆕 visszaszámlálóhoz
  int startCountdown = 3;
  bool showStartOverlay = true;
  Timer? startTimer;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    // 🔸 csak a 3...2...1 után indul minden
    _startInitialCountdown();
  }

  void _startInitialCountdown() {
    setState(() {
      startCountdown = 3;
      showStartOverlay = true;
    });

    startTimer?.cancel();
    startTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        startCountdown--;
      });
      if (startCountdown <= 0) {
        timer.cancel();
        setState(() {
          showStartOverlay = false;
        });
        _initializeLogic(); // itt indul a kamera logika
      }
    });
  }

  void _initializeLogic() {
    setLandscape();
    _sendCalibratedHueToAndroid();

    sub = _ev.receiveBroadcastStream().listen((dynamic e) {
      try {
        final Map<String, dynamic> m = e is Map
            ? Map<String, dynamic>.from(e as Map)
            : Map<String, dynamic>.from(json.decode(e as String));

        if (m['type'] == 'rect' && !_isRestTask(currentTask) && currentTask <= 5) {
          final now = DateTime.now().millisecondsSinceEpoch;
          if (now - lastSentMs >= 2000 && rectCount > -1) {
            setState(() => rectCount++);
            lastSentMs = now;

            _checkTaskProgress();
          }
        }
      } catch (e) {
        print("EVENT ERROR: $e");
      }
    });
  }

  bool _isRestTask(int task) => task == 2 || task == 4 || task == 5;

  Future<void> _sendCalibratedHueToAndroid() async {
    final prefs = await SharedPreferences.getInstance();
    final hue = prefs.getInt('calibration_hue');
    if (hue != null) {
      try {
        await _mc.invokeMethod('setHue', {'hue': hue});
      } catch (e) {
        print(' Hiba hue küldésekor: $e');
      }
    }
  }

  void _checkTaskProgress() {
    if (currentTask == 1 && rectCount >= 5) {
      Future.delayed(const Duration(seconds: 1), () => _startRest(2));
    } else if (currentTask == 3 && rectCount >= 5) {
      Future.delayed(const Duration(seconds: 1), () => _startRest(4));
    }
  }

  void _startRest(int nextTask) {
    setState(() {
      currentTask = nextTask;
      if (nextTask != 5) {
        icon = "clock.svg";
        icon2 = null;
      } else {
        icon = "foot_up.svg";
        icon2 = "arrow_up.svg";
      }
      restSeconds = 15;
      rectCount = restSeconds;
    });

    restTimer?.cancel();
    restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        restSeconds--;
        rectCount = restSeconds;
      });

      if (restSeconds <= 0) {
        timer.cancel();
        if (currentTask == 5) {
          setState(() {
            icon = "foot_up.svg";
            icon2 = "arrow_up.svg";
            rectCount = -1; // kész
            showStartOverlay = true; // kész
          });
        } else {
          Future.delayed(const Duration(seconds: 1), _moveToNextExercise);
        }
      }
    });
  }

  void _moveToNextExercise() {
    setState(() {
      if (currentTask == 2) {
        currentTask = 3;
        icon = "foot_in.svg";
        icon2 = "arrow_left_right.svg";
        rectCount = 0;
      } else if (currentTask == 4) {
        _startRest(5);
      }
    });
  }

  @override
  void dispose() {
    sub?.cancel();
    restTimer?.cancel();
    startTimer?.cancel();
    super.dispose();
  }

  Future<void> setLandscape() async {
    const platform = MethodChannel('orientation_channel');
    await platform.invokeMethod('setLandscape');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final mq = MediaQuery.of(context);
    final cameraWidth = mq.size.width * 88 / 100;
    final cameraHeight = mq.size.height;

    _mc.invokeMethod("setCameraSize", {
      'width': (cameraWidth * mq.devicePixelRatio).toInt(),
      'height': (cameraHeight * mq.devicePixelRatio).toInt(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final displayValue = rectCount == -1 ? "" : rectCount.toString();

    return WillPopScope(
      onWillPop: () async {
        // Itt kezeled a back gombot
        _mc.invokeMethod('stopCamera');
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
        ]);
        Navigator.of(context).popUntil((route) => route.isFirst);
        return false; // false = ne a default visszalépést csinálja
      },
      child: SafeArea(
        child: Stack(
          children: [
            Row(
              children: [
                // BAL oldali sáv: Flutter UI
                Expanded(
                  flex: 12,
                  child: Container(),
                ),

                // JOBB oldali sáv: Android preview (natív)
                Expanded(
                  flex: 88,
                  child: Container(
                    color: Colors.blueGrey,
                    child: const AndroidView(viewType: 'camera_preview'),
                  ),
                ),
              ],
            ),

            // 🆕 VISSZASZÁMLÁLÓ OVERLAY
              Row(
                children: [
                  Expanded(
                    flex: 12,
                    child:Container(
                      color: AppColors.darkgrey_background,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const SizedBox(height: 20),
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                            decoration: BoxDecoration(
                              color: AppColors.darkest_background,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: Colors.cyan.withOpacity(0.2),
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
                                        : icon2!.contains("right")
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
                                const SizedBox(height: 18),
                                Text(
                                  displayValue,
                                  style: AppTextStyles.counter,
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          Center(
                            child: ElevatedButton(
                              onPressed: () {
                                _mc.invokeMethod('stopCamera');
                                SystemChrome.setPreferredOrientations([
                                  DeviceOrientation.portraitUp,
                                  DeviceOrientation.portraitDown,
                                ]);
                                Navigator.of(context).popUntil((route) => route.isFirst);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.blue_light,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: const Text(
                                "Exit",
                                style: AppTextStyles.button_text,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 88,
                    child: showStartOverlay?Container(
                      color: Colors.black.withOpacity(0.6),
                      child: Center(
                        child: rectCount==-1?Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              "Nice work!",
                              style: const TextStyle(
                                fontFamily: 'EncodeSans',
                                fontSize: 40,
                                fontWeight: FontWeight.w400,
                                color: AppColors.white,
                              ),
                            ),
                            Text("You can close this screen now",
                              style: const TextStyle(
                                fontSize: 25,
                                fontFamily: 'EncodeSans',
                                color: Colors.white,
                                fontWeight: FontWeight.normal,
                              ),
                            ),
                          ],
                        ):Text(
                          startCountdown.toString(),
                          style: const TextStyle(
                            fontSize: 150,
                            fontFamily: 'EncodeSans',
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ):Container(),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
