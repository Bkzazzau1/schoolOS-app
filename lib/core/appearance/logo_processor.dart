import 'dart:typed_data';
import 'dart:ui' as ui;

/// Shrinks a picture chosen as the school logo so it is small enough to keep and to send to every phone in the school.
///
/// The longest side becomes at most [maxSide] pixels and the result is a PNG. Throws a [StateError] with words for the
/// owner when the file is not a picture that can be used.
Future<Uint8List> shrinkLogo(Uint8List input, {int maxSide = 256, int maxOutputBytes = 140 * 1024, int maxInputBytes = 8 * 1024 * 1024}) async {
  for (var side = maxSide; ; side = (side * 3) ~/ 4) {
    final result = await _shrinkTo(input, side, maxInputBytes);
    if (result.length <= maxOutputBytes || side <= 64) return result;
  }
}

Future<Uint8List> _shrinkTo(Uint8List input, int maxSide, int maxInputBytes) async {
  if (input.length > maxInputBytes) {
    throw StateError('That picture is too large. Choose one under 8 MB.');
  }
  ui.Image image;
  try {
    final codec = await ui.instantiateImageCodec(input);
    final frame = await codec.getNextFrame();
    image = frame.image;
    codec.dispose();
  } catch (_) {
    throw StateError('That file is not a picture that can be used as a logo. Choose a PNG or JPEG.');
  }

  final width = image.width, height = image.height;
  if (width > maxSide || height > maxSide) {
    final wide = width >= height;
    final codec = await ui.instantiateImageCodec(
      input,
      targetWidth: wide ? maxSide : null,
      targetHeight: wide ? null : maxSide,
    );
    final frame = await codec.getNextFrame();
    image.dispose();
    image = frame.image;
    codec.dispose();
  }

  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  if (data == null) throw StateError('That picture could not be prepared. Try another one.');
  return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
}
