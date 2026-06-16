import 'dart:io';
import 'dart:typed_data';

import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

Future<void> downloadPdfPlatform(Uint8List pdfBytes, String fileName) async {
  final directory = await getApplicationDocumentsDirectory();
  final filePath = '${directory.path}/$fileName';

  final file = File(filePath);
  await file.writeAsBytes(pdfBytes, flush: true);

  final result = await OpenFilex.open(filePath);

  if (result.type != ResultType.done) {
    throw Exception('PDF file was saved, but could not be opened.');
  }
}