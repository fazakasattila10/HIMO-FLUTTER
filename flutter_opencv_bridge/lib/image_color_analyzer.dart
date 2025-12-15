import 'dart:math' as math;
import 'package:image/image.dart' as img;

class ImageColorAnalysisResult {
  final List<img.Image> processedImages;
  final List<int> dominantHues;

  ImageColorAnalysisResult(this.processedImages, this.dominantHues);
}

class ImageColorAnalyzer {
  static Future<ImageColorAnalysisResult> analyze(img.Image image) async {
    if (image.width > 800) {
      image = img.copyResize(image, width: 800);
    }
    final width = image.width;
    final height = image.height;
    Map<int, int> hueHistogram = {};

    // -------- 1️⃣ HUE HISTOGRAM --------
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final pixel = image.getPixel(x, y);
        final r = pixel.r / 255.0;
        final g = pixel.g / 255.0;
        final b = pixel.b / 255.0;

        final max = [r, g, b].reduce(math.max);
        final min = [r, g, b].reduce(math.min);
        final delta = max - min;

        double hue = 0;
        double saturation = max == 0 ? 0 : delta / max;
        double value = max;

        if (delta == 0) {
          hue = 0;
        } else if (max == r) {
          hue = 60 * (((g - b) / delta) % 6);
        } else if (max == g) {
          hue = 60 * (((b - r) / delta) + 2);
        } else {
          hue = 60 * (((r - g) / delta) + 4);
        }

        hue = (hue + 360) % 360;

        // csak élénk, nem szürke/fehér/fekete színek
        if (saturation > 0.3 && value > 0.2) {
          int hBin = (hue / 15).floor();
          hueHistogram[hBin] = (hueHistogram[hBin] ?? 0) + 1;
        }
      }
    }

    // -------- 2️⃣ Domináns hue-k (TOP 2, de különböző színekből) --------
    final sorted = hueHistogram.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    const hueSeparation = 30; // minimum különbség (°)
    List<int> dominantBins = [];
    for (final entry in sorted) {
      final h = entry.key * 15;
      if (dominantBins.every((existing) => (h - existing).abs() > hueSeparation)) {
        dominantBins.add(h);
      }
      if (dominantBins.length >= 2) break;
    }

    if (dominantBins.isEmpty && sorted.isNotEmpty) {
      dominantBins.add(sorted.first.key * 15);
    }

    print('🎨 Domináns (különböző) hue-k (jelöltek): $dominantBins');

    // -------- 3️⃣ Mindkettő feldolgozása, de csak ha értelmes bbox van --------
    final List<img.Image> processedImages = [];
    final List<int> acceptedHues = [];

    for (final hue in dominantBins) {
      final processed = _processSingleHue(image, hue);
      if (processed != null) {
        processedImages.add(processed);
        acceptedHues.add(hue);
      } else {
        print('🚫 Hue=$hue → eldobva (túl nagy / túl kicsi / nincs értelmes régió)');
      }
    }

    print('✅ Elfogadott hue-k: $acceptedHues');

    return ImageColorAnalysisResult(processedImages, acceptedHues);
  }

  // -------- Feldolgozás egy adott hue-ra --------
  // Ha nincs értelmes bbox (pl. gyakorlatilag az egész kép vagy alig pár pixel),
  // akkor null-t adunk vissza, így ez a találat nem kerül bele az eredménybe.
  static img.Image? _processSingleHue(img.Image image, int dominantHue) {
    final width = image.width;
    final height = image.height;
    final frameArea = (width * height).toDouble();

    final hueLow = (dominantHue - 15).clamp(0, 360);
    final hueHigh = (dominantHue + 15).clamp(0, 360);

    List<List<int>> mask = List.generate(height, (_) => List.filled(width, 0));

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final pixel = image.getPixel(x, y);
        final r = pixel.r / 255.0;
        final g = pixel.g / 255.0;
        final b = pixel.b / 255.0;

        final max = [r, g, b].reduce(math.max);
        final min = [r, g, b].reduce(math.min);
        final delta = max - min;
        final s = max == 0 ? 0 : delta / max;
        final v = max;

        if (s < 0.3 || v < 0.2) continue;

        double hue;
        if (delta == 0) {
          hue = 0;
        } else if (max == r) {
          hue = 60 * (((g - b) / delta) % 6);
        } else if (max == g) {
          hue = 60 * (((b - r) / delta) + 2);
        } else {
          hue = 60 * (((r - g) / delta) + 4);
        }
        hue = (hue + 360) % 360;

        if (hue >= hueLow && hue <= hueHigh) {
          mask[y][x] = 1;
        }
      }
    }

    // -------- Zajszűrés --------
    const int window = 2;
    List<List<int>> cleaned =
    List.generate(height, (_) => List.filled(width, 0));
    for (int y = window; y < height - window; y++) {
      for (int x = window; x < width - window; x++) {
        int sum = 0;
        for (int dy = -window; dy <= window; dy++) {
          for (int dx = -window; dx <= window; dx++) {
            sum += mask[y + dy][x + dx];
          }
        }
        final area = (2 * window + 1) * (2 * window + 1);
        cleaned[y][x] = sum > (area * 0.6) ? 1 : 0;
      }
    }

    // -------- Bounding box --------
    int minX = width, minY = height, maxX = 0, maxY = 0, count = 0;
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        if (cleaned[y][x] == 1) {
          count++;
          if (x < minX) minX = x;
          if (x > maxX) maxX = x;
          if (y < minY) minY = y;
          if (y > maxY) maxY = y;
        }
      }
    }

    if (count == 0 || minX >= maxX || minY >= maxY) {
      print('📦 Hue=$dominantHue → nincs érdemi pixeltalálat');
      return null;
    }

    final bboxWidth = maxX - minX + 1;
    final bboxHeight = maxY - minY + 1;
    final bboxArea = (bboxWidth * bboxHeight).toDouble();
    final areaRatio = bboxArea / frameArea;          // bbox a teljes képhez képest
    final fillRatio = bboxArea == 0 ? 0.0 : count / bboxArea; // maszk kitöltöttség a bboxon belül

    print(
      '📦 Hue=$dominantHue → box: ($minX,$minY)-($maxX,$maxY), '
          'pixels=$count, areaRatio=${areaRatio.toStringAsFixed(3)}, '
          'fillRatio=${fillRatio.toStringAsFixed(3)}',
    );

    // -------- Szűrés: túl nagy / túl kicsi / túl üres bbox eldobása --------
    const double minAreaRatio = 0.01;  // < 1% → túl kicsi, zaj
    const double maxAreaRatio = 0.80;  // > 80% → kvázi teljes kép
    const double minFillRatio = 0.20;  // ha bboxban alig van maszk, ne fogadjuk el

    if (areaRatio < minAreaRatio ||
        areaRatio > maxAreaRatio ||
        fillRatio < minFillRatio) {
      print(
        '🚫 Hue=$dominantHue → bbox elutasítva '
            '(areaRatio=${areaRatio.toStringAsFixed(3)}, '
            'fillRatio=${fillRatio.toStringAsFixed(3)})',
      );
      return null;
    }

    // -------- Rajzolás csak akkor, ha a bbox érvényes --------
    final processed = img.copyResize(image, width: width, height: height);

    img.drawRect(
      processed,
      x1: minX,
      y1: minY,
      x2: maxX,
      y2: maxY,
      color: img.ColorRgb8(0, 255, 0),
      thickness: 4,
    );

    // -------- Színkocka --------
    final hsv = HSVtoRGB(dominantHue.toDouble(), 1.0, 1.0);
    final swatchColor = img.ColorRgb8(hsv[0], hsv[1], hsv[2]);
    img.fillRect(processed,
        x1: width - 80, y1: 20, x2: width - 20, y2: 80, color: swatchColor);
    img.drawRect(processed,
        x1: width - 80,
        y1: 20,
        x2: width - 20,
        y2: 80,
        color: img.ColorRgb8(255, 255, 255),
        thickness: 2);

    return processed;
  }

  // -------- Helper: HSV → RGB --------
  static List<int> HSVtoRGB(double h, double s, double v) {
    double c = v * s;
    double x = c * (1 - ((h / 60) % 2 - 1).abs());
    double m = v - c;
    double r = 0, g = 0, b = 0;

    if (h < 60) {
      r = c;
      g = x;
    } else if (h < 120) {
      r = x;
      g = c;
    } else if (h < 180) {
      g = c;
      b = x;
    } else if (h < 240) {
      g = x;
      b = c;
    } else if (h < 300) {
      r = x;
      b = c;
    } else {
      r = c;
      b = x;
    }

    return [
      ((r + m) * 255).round(),
      ((g + m) * 255).round(),
      ((b + m) * 255).round(),
    ];
  }
}
