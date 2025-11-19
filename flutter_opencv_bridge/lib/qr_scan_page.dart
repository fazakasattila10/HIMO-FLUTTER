import 'dart:convert';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'ws_client.dart';
import 'opencv_demo.dart';

class QRScanPage extends StatefulWidget {
  const QRScanPage({super.key});

  @override
  State createState() => _QRScanPageState();
}

class _QRScanPageState extends State {
  String status = 'Waiting for scan...';
  WSClient? wsClient;
  MobileScannerController cameraController = MobileScannerController();

  @override
  void initState() {
    super.initState();
    _checkCameraPermission();
  }

  Future _checkCameraPermission() async {
    var camStatus = await Permission.camera.status;
    if (!camStatus.isGranted) {
      camStatus = await Permission.camera.request();
      if (!camStatus.isGranted) {
        setState(() => status = 'Camera permission denied');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan QR')),
      body: Column(
        children: [
          Expanded(
            flex: 4,
            child: MobileScanner(
              controller: cameraController,
              onDetect: (BarcodeCapture capture) {
                for (final barcode in capture.barcodes) {
                  onScan(barcode.rawValue);
                }
              },
            ),
          ),
          Expanded(
            flex: 2,
            child: Center(child: Text("Status: $status")),
          )
        ],
      ),
    );
  }

  void onScan(String? raw) async {
    if (raw == null) return;
    try {
      cameraController.stop();
      log('Scanned: $raw');
      final Map parsed = jsonDecode(raw);
      final addr = parsed['addr'];
      final port = parsed['port'];
      final token = parsed['token'];
      final uri = 'ws://$addr:$port';

      setState(() => status = 'Connecting to $uri');
      wsClient = WSClient(uri: uri, token: token.toString());
      wsClient!.onStatus = (s) => setState(() => status = s);
      wsClient!.onMessage = (m) => log("Received: $m");

      await wsClient!.connect();
      wsClient!.send(jsonEncode({'type': 'auth', 'token': token}));

      // ha sikerült, menjünk tovább az OpenCV képernyőre
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => OpenCVDemo(wsClient: wsClient!),
          ),
        );
      }
    } catch (e) {
      setState(() => status = 'Scan error: $e');
      cameraController.start();
    }
  }

  @override
  void dispose() {
    cameraController.dispose();
    // wsClient?.dispose();
    super.dispose();
  }
}
