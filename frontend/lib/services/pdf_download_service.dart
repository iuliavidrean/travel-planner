import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import 'pdf_download_stub.dart' if (dart.library.html) 'pdf_download_web.dart';
import 'pdf_download_mobile.dart';

Future<void> downloadPdf(Uint8List pdfBytes, String fileName) async {
  if (kIsWeb) {
    downloadPdfWeb(pdfBytes, fileName);
    return;
  }

  await downloadPdfMobile(pdfBytes, fileName);
}