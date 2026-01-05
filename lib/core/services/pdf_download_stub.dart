import 'package:flutter/foundation.dart';

/// Stub for non-web platforms
void downloadPdfWeb(Uint8List bytes, String filename) {
  // This should never be called on non-web platforms
  throw UnsupportedError('downloadPdfWeb is only supported on web');
}
