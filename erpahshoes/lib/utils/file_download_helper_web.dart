import 'dart:html' as html;
import 'dart:typed_data';

void downloadFileImpl(Uint8List bytes, String fileName, {String mimeType = 'application/pdf'}) {
  final blob = html.Blob([bytes], mimeType);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..setAttribute('download', fileName)
    ..style.display = 'none';
  html.document.body?.children.add(anchor);
  anchor.click();
  html.document.body?.children.remove(anchor);
  html.Url.revokeObjectUrl(url);
}

void printPdfImpl(Uint8List bytes) {
  final blob = html.Blob([bytes], 'application/pdf');
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.window.open(url, '_blank');
}

Future<bool> openWhatsAppImpl(String phoneNumber, String message) async {
  String cleanPhone = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
  if (cleanPhone.startsWith('620')) {
    cleanPhone = '62${cleanPhone.substring(3)}';
  } else if (cleanPhone.startsWith('0')) {
    cleanPhone = '62${cleanPhone.substring(1)}';
  } else if (cleanPhone.startsWith('8')) {
    cleanPhone = '62$cleanPhone';
  }

  if (cleanPhone.length < 8) return false;

  final encoded = Uri.encodeComponent(message);
  final url = 'https://api.whatsapp.com/send?phone=$cleanPhone&text=$encoded';

  try {
    html.window.open(url, '_blank');
    return true;
  } catch (_) {}

  // Fallback: gunakan simulasi klik AnchorElement untuk mem-bypass popup blocker Chrome
  try {
    final anchor = html.AnchorElement(href: url)
      ..target = '_blank'
      ..rel = 'noopener noreferrer'
      ..style.display = 'none';
    html.document.body?.children.add(anchor);
    anchor.click();
    html.document.body?.children.remove(anchor);
    return true;
  } catch (_) {
    return false;
  }
}

Future<bool> shareFileOrOpenWhatsAppImpl(
  Uint8List bytes,
  String fileName,
  String phoneNumber,
  String message,
) async {
  String cleanPhone = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
  if (cleanPhone.startsWith('0')) {
    cleanPhone = '62${cleanPhone.substring(1)}';
  } else if (cleanPhone.startsWith('8')) {
    cleanPhone = '62$cleanPhone';
  }

  // 1. Coba gunakan Web Share API untuk langsung melampirkan file PDF ke WhatsApp
  try {
    final blob = html.Blob([bytes], 'application/pdf');
    final file = html.File([blob], fileName, {'type': 'application/pdf'});
    final nav = html.window.navigator;

    final dynamic canShare = (nav as dynamic).canShare;
    if (canShare != null) {
      final bool isAllowed = (nav as dynamic).canShare({'files': [file]});
      if (isAllowed) {
        await (nav as dynamic).share({
          'files': [file],
          'title': 'Slip Gaji $fileName',
          'text': message,
        });
        return true;
      }
    }
  } catch (e) {
    // Jika user cancel atau tidak didukung oleh browser, lanjutkan ke alur WhatsApp Web
  }

  // 2. Download PDF dan buka WhatsApp Web langsung ke chat nomor staf
  downloadFileImpl(bytes, fileName, mimeType: 'application/pdf');
  final encoded = Uri.encodeComponent(message);
  final url = 'https://api.whatsapp.com/send?phone=$cleanPhone&text=$encoded';
  html.window.open(url, '_blank');
  return false;
}
