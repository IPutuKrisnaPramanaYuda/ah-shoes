import 'package:geolocator/geolocator.dart';
import '../models/absensi_model.dart';

Future<LokasiHasil> ambilLokasiPlatformImpl() async {
  try {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return LokasiHasil(
        statusTeks: 'GPS Perangkat Mati',
        errorMessage: 'Nyalakan GPS pada perangkat Anda.',
      );
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return LokasiHasil(
          statusTeks: 'Izin Lokasi Ditolak',
          errorMessage: 'Berikan izin akses lokasi pada aplikasi.',
        );
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return LokasiHasil(
        statusTeks: 'Izin Lokasi Ditolak Permanen',
        errorMessage: 'Buka pengaturan HP / perangkat untuk mengizinkan lokasi.',
      );
    }

    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
        timeLimit: Duration(seconds: 15),
      ),
    );

    return LokasiHasil(
      latitude: pos.latitude,
      longitude: pos.longitude,
      statusTeks: '${pos.latitude.toStringAsFixed(6)}, ${pos.longitude.toStringAsFixed(6)}',
      isBerhasil: true,
    );
  } catch (e) {
    return LokasiHasil(
      statusTeks: 'Gagal Membaca GPS',
      errorMessage: e.toString(),
    );
  }
}
