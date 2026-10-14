import 'file_download_helper_stub.dart'
    if (dart.library.html) 'file_download_helper_web.dart' as helper;
import 'dart:typed_data';

void downloadFile(Uint8List bytes, String fileName, {String mimeType = 'application/pdf'}) {
  helper.downloadFileImpl(bytes, fileName, mimeType: mimeType);
}

void printPdf(Uint8List bytes) {
  helper.printPdfImpl(bytes);
}

Future<bool> openWhatsApp(String phoneNumber, String message) async {
  return await helper.openWhatsAppImpl(phoneNumber, message);
}

Future<bool> shareFileOrOpenWhatsApp(
  Uint8List bytes,
  String fileName,
  String phoneNumber,
  String message,
) async {
  return await helper.shareFileOrOpenWhatsAppImpl(bytes, fileName, phoneNumber, message);
}
