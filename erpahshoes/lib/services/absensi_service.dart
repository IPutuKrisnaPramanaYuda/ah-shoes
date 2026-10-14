import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/absensi_model.dart';
import '../utils/constants.dart';
import '../utils/location_helper.dart';

class AbsensiService {
  final String scriptUrl = Constants.scriptUrl;
  static const String _keyOfflineQueue = 'kunci_antrean_absensi_offline';
  static const String _keyCachedConfig = 'kunci_cached_pengaturan_absensi';

  final ImagePicker _picker = ImagePicker();

  // ==========================================
  // 1. PENGATURAN ABSENSI
  // ==========================================
  Future<PengaturanAbsensi> getPengaturan() async {
    final prefs = await SharedPreferences.getInstance();

    // Coba load dari server
    try {
      final url = Uri.parse('$scriptUrl?action=get_pengaturan_absensi');
      final res = await http.get(url).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200 || res.statusCode == 302) {
        final data = jsonDecode(res.body);
        if (data['status'] == 'success') {
          final config = PengaturanAbsensi.fromJson(data['data']);
          await prefs.setString(_keyCachedConfig, jsonEncode(config.toJson()));
          return config;
        }
      }
    } catch (e) {
      debugPrint("Offline/Error getPengaturan: $e");
    }

    // Fallback dari cache lokal
    final cached = prefs.getString(_keyCachedConfig);
    if (cached != null) {
      try {
        return PengaturanAbsensi.fromJson(jsonDecode(cached));
      } catch (_) {}
    }

    return PengaturanAbsensi();
  }

  Future<bool> updatePengaturan(Map<String, dynamic> configData) async {
    final prefs = await SharedPreferences.getInstance();
    // Simpan dulu ke lokal
    final cached = await getPengaturan();
    final updatedMap = {...cached.toJson(), ...configData};
    await prefs.setString(_keyCachedConfig, jsonEncode(updatedMap));

    try {
      final url = Uri.parse(scriptUrl);
      final res = await http.post(
        url,
        body: jsonEncode({
          'action': 'update_pengaturan_absensi',
          ...configData,
        }),
      ).timeout(const Duration(seconds: 12));

      if (res.statusCode == 200 || res.statusCode == 302) {
        final data = jsonDecode(res.body);
        return data['status'] == 'success';
      }
    } catch (e) {
      debugPrint("Error updatePengaturan ke server: $e");
    }
    return true; // Berhasil tersimpan di lokal
  }

  // ==========================================
  // 2. FOTO SELFIE (TERKOMPRESI RINGAN)
  // ==========================================
  Future<String?> ambilFotoSelfie({ImageSource source = ImageSource.camera}) async {
    try {
      final XFile? photo = await _picker.pickImage(
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
      debugPrint("Error ambilFotoSelfie ($source): $e");
      // Fallback jika kamera perangkat/web tidak dapat diakses
      if (source == ImageSource.camera) {
        try {
          final XFile? fallback = await _picker.pickImage(
            source: ImageSource.gallery,
            maxWidth: 800,
            maxHeight: 800,
            imageQuality: 70,
          );
          if (fallback != null) {
            final bytes = await fallback.readAsBytes();
            return base64Encode(bytes);
          }
        } catch (e2) {
          debugPrint("Fallback gallery error: $e2");
        }
      }
    }
    return null;
  }

  bool _isSyncingProcess = false;

  // ==========================================
  // 3. AKSES LOKASI (GPS GEOLOCATION)
  // ==========================================
  Future<LokasiHasil> ambilLokasiDetail() async {
    return await ambilLokasiPerangkat();
  }

  Future<String> ambilLokasi() async {
    final hasil = await ambilLokasiDetail();
    return hasil.koordinatStr;
  }

  double hitungJarakKeToko(double latStaff, double lngStaff, double latToko, double lngToko) {
    return Geolocator.distanceBetween(latStaff, lngStaff, latToko, lngToko);
  }

  // ==========================================
  // 4. PROSES ABSEN HYBRID (OFFLINE-FIRST)
  // ==========================================
  Future<AbsensiRecord> simpanAbsen({
    required String idStaff,
    required String namaStaff,
    required String tipe, // Masuk / Pulang
    required String? fotoBase64,
    required String lokasi,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    // 1. Ambil WAKTU LOKAL ASLI saat tombol ditekan (Presisi 100%)
    final now = DateTime.now();
    final waktuAbsenAsli = DateFormat('yyyy-MM-dd HH:mm:ss').format(now);
    final tanggal = DateFormat('yyyy-MM-dd').format(now);
    final idAbsen = 'ABS-${now.millisecondsSinceEpoch}';

    // 2. Kalkulasi lokal sementara berdasarkan setting jam masuk
    final config = await getPengaturan();
    int menitTerlambat = 0;
    double denda = 0;
    String status = 'Tepat Waktu';

    if (tipe == 'Masuk') {
      try {
        final parts = config.jamMasuk.split(':');
        final targetMenit = (int.parse(parts[0]) * 60) + (int.parse(parts[1]));
        final actualMenit = (now.hour * 60) + now.minute;
        if (actualMenit > (targetMenit + config.toleransiMenit)) {
          menitTerlambat = actualMenit - (targetMenit + config.toleransiMenit);
          denda = menitTerlambat * config.dendaPerMenit;
          status = 'Terlambat $menitTerlambat Mnt';
        }
      } catch (_) {}
    } else {
      status = 'Selesai Kerja';
    }

    final localRecord = AbsensiRecord(
      idAbsen: idAbsen,
      tanggal: tanggal,
      waktuAbsen: waktuAbsenAsli,
      idStaff: idStaff,
      namaStaff: namaStaff,
      tipe: tipe,
      status: status,
      menitTerlambat: menitTerlambat.toDouble(),
      potonganGaji: denda,
      lokasi: lokasi,
      linkFoto: '',
      waktuSync: 'Offline Pending',
      isOfflinePending: true,
    );

    // 3. Masukkan ke Antrean Lokal (SharedPreferences) seketika
    final queue = await _getOfflineQueue(prefs);
    queue.add({
      'id_absen': idAbsen,
      'id_staff': idStaff,
      'nama_staff': namaStaff,
      'tipe': tipe,
      'waktu_absen': waktuAbsenAsli,
      'lokasi': lokasi,
      'foto_base64': fotoBase64 ?? '',
    });
    await prefs.setString(_keyOfflineQueue, jsonEncode(queue));

    return localRecord;
  }

  // ==========================================
  // 5. AUTO-SYNC ANTREAN OFFLINE KE GAS / DRIVE
  // ==========================================
  Future<AbsensiSyncResult> syncOfflineQueue() async {
    if (_isSyncingProcess) {
      // Mencegah dua proses sync berjalan bersamaan (cegah duplikasi)
      final prefs = await SharedPreferences.getInstance();
      final currentQueue = await _getOfflineQueue(prefs);
      return AbsensiSyncResult(syncedCount: 0, remainingCount: currentQueue.length);
    }

    _isSyncingProcess = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final queue = await _getOfflineQueue(prefs);
      if (queue.isEmpty) {
        return AbsensiSyncResult(syncedCount: 0, remainingCount: 0);
      }

      int syncedCount = 0;
      String? lastError;
      final remainingQueue = <Map<String, dynamic>>[];

      for (var item in queue) {
        try {
          final url = Uri.parse(scriptUrl);
          final res = await http.post(
            url,
            headers: {'Content-Type': 'text/plain;charset=utf-8'},
            body: jsonEncode({
              'action': 'absen',
              ...item,
            }),
          ).timeout(const Duration(seconds: 25));

          if (res.statusCode == 200 || res.statusCode == 302) {
            final data = jsonDecode(res.body);
            if (data['status'] == 'success') {
              syncedCount++;
              continue; // Berhasil tersinkron
            } else {
              lastError = data['message']?.toString() ?? 'Error dari Apps Script';
              debugPrint("Server error sync item ${item['id_absen']}: $lastError");
            }
          } else {
            lastError = 'HTTP status ${res.statusCode}';
          }
          remainingQueue.add(item);
        } catch (e) {
          lastError = e.toString();
          debugPrint("Gagal sinkron item ${item['id_absen']}: $e");
          remainingQueue.add(item);
        }
      }

      await prefs.setString(_keyOfflineQueue, jsonEncode(remainingQueue));
      return AbsensiSyncResult(
        syncedCount: syncedCount,
        remainingCount: remainingQueue.length,
        lastError: lastError,
      );
    } finally {
      _isSyncingProcess = false;
    }
  }

  Future<int> getPendingOfflineCount() async {
    final prefs = await SharedPreferences.getInstance();
    final queue = await _getOfflineQueue(prefs);
    return queue.length;
  }

  Future<List<Map<String, dynamic>>> _getOfflineQueue(SharedPreferences prefs) async {
    final str = prefs.getString(_keyOfflineQueue);
    if (str != null) {
      try {
        final List list = jsonDecode(str);
        return list.map((e) => Map<String, dynamic>.from(e)).toList();
      } catch (_) {}
    }
    return [];
  }

  // ==========================================
  // 6. AMBIL RIWAYAT ABSENSI
  // ==========================================
  Future<List<AbsensiRecord>> getRiwayatAbsensi() async {
    final List<AbsensiRecord> results = [];
    final Set<String> seenIds = {};
    final Set<String> seenStaffTimestamps = {};

    // 1. Ambil antrean offline yang belum tersinkron
    final prefs = await SharedPreferences.getInstance();
    final queue = await _getOfflineQueue(prefs);
    for (var q in queue) {
      final id = (q['id_absen'] ?? '').toString();
      final staff = (q['nama_staff'] ?? '').toString();
      final waktu = (q['waktu_absen'] ?? '').toString();
      final staffTimeKey = '$staff|$waktu';

      if (id.isNotEmpty && !seenIds.contains(id) && !seenStaffTimestamps.contains(staffTimeKey)) {
        seenIds.add(id);
        seenStaffTimestamps.add(staffTimeKey);
        results.add(AbsensiRecord(
          idAbsen: id,
          tanggal: waktu.split(' ')[0],
          waktuAbsen: waktu,
          idStaff: (q['id_staff'] ?? '').toString(),
          namaStaff: staff,
          tipe: (q['tipe'] ?? 'Masuk').toString(),
          status: 'Menunggu Sinkronisasi',
          menitTerlambat: 0,
          potonganGaji: 0,
          lokasi: (q['lokasi'] ?? '').toString(),
          linkFoto: '',
          waktuSync: 'Offline (Belum Ada Sinyal)',
          isOfflinePending: true,
        ));
      }
    }

    // 2. Ambil data tersinkron dari Google Sheets
    try {
      final url = Uri.parse('$scriptUrl?action=get_riwayat_absensi');
      final res = await http.get(url).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200 || res.statusCode == 302) {
        final data = jsonDecode(res.body);
        if (data['status'] == 'success') {
          final List list = data['data'] ?? [];
          for (var item in list) {
            final rec = AbsensiRecord.fromJson(item);
            final staffTimeKey = '${rec.namaStaff}|${rec.waktuAbsen}';
            // Hindari duplikat baik berdasarkan id_absen maupun nama_staff + waktu_absen
            if (rec.idAbsen.isNotEmpty && !seenIds.contains(rec.idAbsen) && !seenStaffTimestamps.contains(staffTimeKey)) {
              seenIds.add(rec.idAbsen);
              seenStaffTimestamps.add(staffTimeKey);
              results.add(rec);
            }
          }
        }
      }
    } catch (e) {
      debugPrint("Error getRiwayatAbsensi dari server: $e");
    }

    return results;
  }
}
