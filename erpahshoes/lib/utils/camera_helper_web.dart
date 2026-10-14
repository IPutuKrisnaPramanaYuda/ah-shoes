import 'dart:convert';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

Future<String?> capturePhotoImpl(BuildContext context, {ImageSource source = ImageSource.camera}) async {
  // Jika memilih galeri / file di browser
  if (source == ImageSource.gallery) {
    return _pickFileInWeb();
  }

  // Jika memilih kamera: buka WebRTC live webcam
  try {
    final mediaDevices = html.window.navigator.mediaDevices;
    if (mediaDevices == null) {
      return _pickFileInWeb();
    }

    // Memicu prompt izin kamera Chrome ("Allow Camera")
    final stream = await mediaDevices.getUserMedia({'video': true, 'audio': false});

    final video = html.VideoElement()
      ..autoplay = true
      ..muted = true
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.objectFit = 'cover';
    video.srcObject = stream;

    final viewId = 'webcam-view-${DateTime.now().millisecondsSinceEpoch}';
    ui_web.platformViewRegistry.registerViewFactory(viewId, (int id) => video);

    if (!context.mounted) {
      stream.getTracks().forEach((track) => track.stop());
      return null;
    }

    final String? base64Result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Kamera Selfie', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: () => Navigator.pop(ctx, null),
              ),
            ],
          ),
          content: SizedBox(
            width: 400,
            height: 300,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: HtmlElementView(viewType: viewId),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: const Text('Batal'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              icon: const Icon(Icons.camera_alt, size: 16),
              label: const Text('Jepret Foto'),
              onPressed: () {
                final w = video.videoWidth > 0 ? video.videoWidth : 640;
                final h = video.videoHeight > 0 ? video.videoHeight : 480;
                final canvas = html.CanvasElement(width: w, height: h);
                final ctx2d = canvas.context2D;
                ctx2d.drawImage(video, 0, 0);

                final dataUrl = canvas.toDataUrl('image/jpeg', 0.7);
                final b64 = dataUrl.split(',').last;
                Navigator.pop(ctx, b64);
              },
            ),
          ],
        );
      },
    );

    // Matikan stream kamera setelah dialog ditutup
    stream.getTracks().forEach((track) => track.stop());
    return base64Result;
  } catch (e) {
    debugPrint("Webcam getUserMedia error: $e, falling back to file picker");
    return _pickFileInWeb();
  }
}

Future<String?> _pickFileInWeb() async {
  try {
    final picker = ImagePicker();
    final XFile? photo = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 70,
    );
    if (photo != null) {
      final bytes = await photo.readAsBytes();
      return base64Encode(bytes);
    }
  } catch (e) {
    debugPrint("Pick file error: $e");
  }
  return null;
}
