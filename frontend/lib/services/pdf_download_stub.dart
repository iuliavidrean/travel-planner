import 'dart:typed_data';

Future<void> downloadPdfPlatform(Uint8List pdfBytes, String fileName) async {
  throw UnsupportedError('PDF download is not available on this platform.');
}