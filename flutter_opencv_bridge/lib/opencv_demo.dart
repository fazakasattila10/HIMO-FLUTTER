import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'ws_client.dart';

const _ev = EventChannel('opencv_event_channel');
const _mc = MethodChannel('opencv_channel');

class OpenCVDemo extends StatefulWidget {
  final WSClient wsClient;
  const OpenCVDemo({super.key, required this.wsClient});

  @override
  State<OpenCVDemo> createState() => _OpenCVDemoState();
}

class _OpenCVDemoState extends State<OpenCVDemo> {
  StreamSubscription? sub;
  int rectCount = 0;
  String status = '—';
  int hue = 60;
  double areaMin = 15000;

  int lastSentMs = 0; // utolsó elküldött találat időbélyege (ms)

  @override
  void initState() {
    super.initState();
    sub = _ev.receiveBroadcastStream().listen((e) {
      try {
        final m = json.decode(e as String);
        if (m['type'] == 'rect') {


          final now = DateTime.now().millisecondsSinceEpoch;
          if (now - lastSentMs >= 2000) {
            setState(() => rectCount++);
            // 2 mp eltelt, küldünk a desktopnak
            final msg = jsonEncode({
              'type': 'result',
              'ts': now,
              'rectCount': rectCount,
            });
            widget.wsClient.send(msg);
            lastSentMs = now;
          }
        }
      } catch (err) {
        // ignore parse errors
      }
    });
  }

  @override
  void dispose() {
    sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(status, style: const TextStyle(color: Colors.white)),
                  const SizedBox(height: 8),
                  Text(
                    "Találatok száma: $rectCount",
                    style: const TextStyle(color: Colors.green, fontSize: 20),
                  ),
                ],
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text("Hue", style: TextStyle(color: Colors.white)),
                Slider(
                  min: 0,
                  max: 179,
                  divisions: 179,
                  value: hue.toDouble(),
                  onChanged: (v) => setState(() => hue = v.toInt()),
                  onChangeEnd: (v) =>
                      _mc.invokeMethod('setHue', {'hue': v.toInt()}),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text("Area min", style: TextStyle(color: Colors.white)),
                Slider(
                  min: 1000,
                  max: 60000,
                  divisions: 59,
                  value: areaMin,
                  onChanged: (v) => setState(() => areaMin = v),
                  onChangeEnd: (v) =>
                      _mc.invokeMethod('setAreaMin', {'area': v}),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => _mc.invokeMethod('stopCamera'),
              child: const Text('Stop camera'),
            ),
            Expanded(
              child: Container(
                color: Colors.black,
                child: const AndroidView(
                  viewType: 'camera_preview',
                ),
              ),
            ) // preview marad natív overlay
          ],
        ),
      ),
    );
  }
}
