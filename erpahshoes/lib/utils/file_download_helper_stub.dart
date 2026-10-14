import 'dart:typed_data';
import 'package:url_launcher/url_launcher.dart';

void downloadFileImpl(Uint8List bytes, String fileName, {String mimeType = 'application/pdf'}) {}

void printPdfImpl(Uint8List bytes) {}

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

  // 1. Coba aplikasi native WhatsApp di Android/iOS
  final appUri = Uri.parse('whatsapp://send?phone=$cleanPhone&text=$encoded');
  try {
    final launched = await launchUrl(appUri, mode: LaunchMode.externalNonBrowserApplication);
    if (launched) return true;
  } catch (_) {}

  // 2. Fallback ke URL web WhatsApp
  final webUri = Uri.parse('https://api.whatsapp.com/send?phone=$cleanPhone&text=$encoded');
  try {
    return await launchUrl(webUri, mode: LaunchMode.externalApplication);
  } catch (_) {
    try {
      return await launchUrl(webUri);
    } catch (_) {
      return false;
    }
  }
}

Future<bool> shareFileOrOpenWhatsAppImpl(
  Uint8List bytes,
  String fileName,
  String phoneNumber,
  String message,
) async {
  return false;
}
