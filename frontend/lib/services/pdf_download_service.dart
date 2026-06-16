import 'dart:typed_data';

import 'pdf_download_stub.dart'
    if (dart.library.html) 'pdf_download_web.dart'
    if (dart.library.io) 'pdf_download_mobile.dart';

Future<void> downloadPdf(Uint8List pdfBytes, String fileName) async {
  await downloadPdfPlatform(pdfBytes, fileName);
}