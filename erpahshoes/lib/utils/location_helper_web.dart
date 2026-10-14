import 'dart:html' as html;
import '../models/absensi_model.dart';

Future<LokasiHasil> ambilLokasiPlatformImpl() async {
  try {
    final geo = html.window.navigator.geolocation;

    // Langsung memicu prompt izin browser ("Allow location")
    final pos = await geo.getCurrentPosition(
      enableHighAccuracy: false, // medium network/wifi accuracy
      timeout: const Duration(seconds: 15),
      maximumAge: const Duration(minutes: 5),
    );

    final lat = pos.coords?.latitude?.toDouble();
    final lng = pos.coords?.longitude?.toDouble();

    if (lat != null && lng != null) {
      return LokasiHasil(
        latitude: lat,
        longitude: lng,
        statusTeks: '${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}',
        isBerhasil: true,
      );
    }

    return LokasiHasil(
      statusTeks: 'Koordinat Tidak Terbaca',
      errorMessage: 'Browser mengembalikan koordinat kosong.',
    );
  } catch (e) {
    if (e is html.PositionError) {
      if (e.code == 1) { // PERMISSION_DENIED
        return LokasiHasil(
          statusTeks: 'Izin Lokasi Ditolak di Browser',
          errorMessage: 'Izin lokasi belum diberikan. Klik ikon gembok / setelan di sebelah kiri URL Chrome, lalu pilih "Izinkan" (Allow) pada bagian Lokasi.',
        );
      } else if (e.code == 2) { // POSITION_UNAVAILABLE
        return LokasiHasil(
          statusTeks: 'Layanan Lokasi Windows / PC Tidak Aktif',
          errorMessage: 'Layanan lokasi pada Windows belum diaktifkan (Buka Windows Settings > Privacy & security > Location > Turn ON), atau gunakan pengaturan koordinat manual.',
        );
      } else if (e.code == 3) { // TIMEOUT
        return LokasiHasil(
          statusTeks: 'Waktu Habis (GPS Timeout)',
          errorMessage: 'Pencarian lokasi terlalu lama. Silakan coba klik tombol refresh lokasi lagi.',
        );
      }
    }
    return LokasiHasil(
      statusTeks: 'Gagal Membaca GPS',
      errorMessage: e.toString(),
    );
  }
}
