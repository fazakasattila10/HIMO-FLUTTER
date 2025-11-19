import 'dart:math' as math;
import 'package:image/image.dart' as img;

class ImageColorAnalysisResultJo {
  final img.Image processedImage;
  final int dominantHue;

  ImageColorAnalysisResultJo(this.processedImage, this.dominantHue);
}

class ImageColorAnalyzerJo {
  static Future<ImageColorAnalysisResultJo> analyze(img.Image image) async {
    if (image.width > 800) {
      image = img.copyResize(image, width: 800);
    }
    final width = image.width;
    final height = image.height;
    Map<int, int> hueHistogram = {};

    // -------- 1️⃣ HUE HISTOGRAM (domináns szín keresése) --------
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

        if (saturation > 0.3 && value > 0.2) {
          // csak élénk, nem fehér/szürke/fekete színek
          int hBin = (hue / 15).floor();
          hueHistogram[hBin] = (hueHistogram[hBin] ?? 0) + 1;
        }

        // int hBin = (hue / 15).floor();
        // hueHistogram[hBin] = (hueHistogram[hBin] ?? 0) + 1;
      }
    }

    // -------- 2️⃣ Domináns hue meghatározása --------
    final dominantHueBin =
        hueHistogram.entries.reduce((a, b) => a.value > b.value ? a : b).key;
    final dominantHue = dominantHueBin * 15;
    final hueLow = (dominantHue - 15).clamp(0, 360);
    final hueHigh = (dominantHue + 15).clamp(0, 360);

    // -------- 3️⃣ Mask létrehozása a domináns hue alapján --------
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

        double hue;
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


        if (saturation > 0.3 && value > 0.2) {
          if (hue >= hueLow && hue <= hueHigh) {
            mask[y][x] = 1;
          }
        }

      }
    }

    // -------- 4️⃣ Maszk zajszűrés (morfológiai erózió + dilatáció) --------
    int window = 2; // szomszédság méret
    List<List<int>> cleaned = List.generate(height, (_) => List.filled(width, 0));

    for (int y = window; y < height - window; y++) {
      for (int x = window; x < width - window; x++) {
        int sum = 0;
        for (int dy = -window; dy <= window; dy++) {
          for (int dx = -window; dx <= window; dx++) {
            sum += mask[y + dy][x + dx];
          }
        }
        // ha a környezet legalább 60%-a ilyen színű → megtartjuk
        cleaned[y][x] = sum > (window * window * 4) ? 1 : 0;
      }
    }

    // -------- 5️⃣ Bounding box keresése a tisztított mask alapján --------
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
    print('🖼️aaaaaa Kép méret: ${width}x${height}');
    print('🎨aaaaaa Domináns hue: $dominantHue ($hueLow - $hueHigh)');

// --- bounding box számítás után ---
    print('📦aaaaaa Bounding box koordináták: '
        'minX=$minX, minY=$minY, maxX=$maxX, maxY=$maxY, '
        'count=$count, total=${width * height}');
    // -------- 6️⃣ Rajzolás a kimeneti képre --------
    final processed = img.copyResize(image, width: width, height: height);

    if (count > width * height * 0.005) {
      print('✅ aaaaaa Rajzolunk keretet, mert $count pixelt találtunk.');
      // csak akkor rajzolunk, ha valóban sok színes pixel van
      final green = img.ColorRgb8(0, 255, 0);
      img.drawRect(
        processed,
        x1: minX,
        y1: minY,
        x2: maxX,
        y2: maxY,
        color: green,
        thickness: 4,
      );
    } else {
      print('⚠️ aaaaaa Nem rajzolunk, túl kevés pixel ($count)');
    }

    // -------- 7️⃣ Domináns szín kis négyzet --------
    final hsv = HSVtoRGB(dominantHue.toDouble(), 1.0, 1.0);
    final swatchColor = img.ColorRgb8(hsv[0], hsv[1], hsv[2]);
    img.fillRect(
      processed,
      x1: width - 80,
      y1: 20,
      x2: width - 20,
      y2: 80,
      color: swatchColor,
    );
    img.drawRect(
      processed,
      x1: width - 80,
      y1: 20,
      x2: width - 20,
      y2: 80,
      color: img.ColorRgb8(255, 255, 255),
      thickness: 2,
    );

    return ImageColorAnalysisResultJo(processed, dominantHue);
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
