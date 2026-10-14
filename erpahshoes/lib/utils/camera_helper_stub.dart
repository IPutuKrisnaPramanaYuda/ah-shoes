import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

Future<String?> capturePhotoImpl(BuildContext context, {ImageSource source = ImageSource.camera}) async {
  try {
    final picker = ImagePicker();
    final XFile? photo = await picker.pickImage(
      source: source,
      preferredCameraDevice: CameraDevice.front,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 70,
    );

    if (photo != null) {
      final bytes = await photo.readAsBytes();
      return base64Encode(bytes);
    }
  } catch (e) {
    debugPrint("capturePhoto native error: $e");
  }
  return null;
}
