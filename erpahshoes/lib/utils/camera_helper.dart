import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'camera_helper_stub.dart'
    if (dart.library.html) 'camera_helper_web.dart' as impl;

Future<String?> capturePhoto(BuildContext context, {ImageSource source = ImageSource.camera}) async {
  return await impl.capturePhotoImpl(context, source: source);
}
