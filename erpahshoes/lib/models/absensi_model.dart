class AbsensiRecord {
  final String idAbsen;
  final String tanggal;
  final String waktuAbsen;
  final String idStaff;
  final String namaStaff;
  final String tipe; // Masuk / Pulang
  final String status; // Tepat Waktu / Terlambat X Mnt / Selesai Kerja
  final double menitTerlambat;
  final double potonganGaji;
  final String lokasi;
  final String linkFoto;
  final String waktuSync;
  final bool isOfflinePending;

  AbsensiRecord({
    required this.idAbsen,
    required this.tanggal,
    required this.waktuAbsen,
    required this.idStaff,
    required this.namaStaff,
    required this.tipe,
    required this.status,
    required this.menitTerlambat,
    required this.potonganGaji,
    required this.lokasi,
    required this.linkFoto,
    required this.waktuSync,
    this.isOfflinePending = false,
  });

  factory AbsensiRecord.fromJson(Map<String, dynamic> json) {
    return AbsensiRecord(
      idAbsen: (json['id_absen'] ?? '').toString(),
      tanggal: (json['tanggal'] ?? '').toString(),
      waktuAbsen: (json['waktu_absen'] ?? '').toString(),
      idStaff: (json['id_staff'] ?? '').toString(),
      namaStaff: (json['nama_staff'] ?? '').toString(),
      tipe: (json['tipe'] ?? 'Masuk').toString(),
      status: (json['status'] ?? 'Tepat Waktu').toString(),
      menitTerlambat: double.tryParse(json['menit_terlambat']?.toString() ?? '0') ?? 0,
      potonganGaji: double.tryParse(json['potongan_gaji']?.toString() ?? '0') ?? 0,
      lokasi: (json['lokasi'] ?? '').toString(),
      linkFoto: (json['link_foto'] ?? '').toString(),
      waktuSync: (json['waktu_sync'] ?? '').toString(),
      isOfflinePending: json['is_offline_pending'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id_absen': idAbsen,
      'tanggal': tanggal,
      'waktu_absen': waktuAbsen,
      'id_staff': idStaff,
      'nama_staff': namaStaff,
      'tipe': tipe,
      'status': status,
      'menit_terlambat': menitTerlambat,
      'potongan_gaji': potonganGaji,
      'lokasi': lokasi,
      'link_foto': linkFoto,
      'waktu_sync': waktuSync,
      'is_offline_pending': isOfflinePending,
    };
  }
}

class PengaturanAbsensi {
  final String jamMasuk;
  final String jamPulang;
  final int toleransiMenit;
  final double dendaPerMenit;
  final double lokasiLat;
  final double lokasiLng;
  final double radiusMeter;
  final String folderDriveId;

  PengaturanAbsensi({
    this.jamMasuk = '08:00',
    this.jamPulang = '17:00',
    this.toleransiMenit = 15,
    this.dendaPerMenit = 1000,
    this.lokasiLat = -8.650000,
    this.lokasiLng = 115.216667,
    this.radiusMeter = 100,
    this.folderDriveId = '',
  });

  static String cleanTime(dynamic val, String fallback) {
    if (val == null) return fallback;
    final str = val.toString().trim();
    if (str.isEmpty) return fallback;
    if (str.contains('T')) {
      try {
        final dt = DateTime.parse(str).toUtc().add(const Duration(hours: 8)); // WITA UTC+8
        final h = dt.hour.toString().padLeft(2, '0');
        final m = dt.minute.toString().padLeft(2, '0');
        return '$h:$m';
      } catch (_) {}
    }
    final match = RegExp(r'(\d{1,2}):(\d{1,2})').firstMatch(str);
    if (match != null) {
      final h = match.group(1)!.padLeft(2, '0');
      final m = match.group(2)!.padLeft(2, '0');
      return '$h:$m';
    }
    return str;
  }

  factory PengaturanAbsensi.fromJson(Map<String, dynamic> json) {
    double rawLat = double.tryParse(json['lokasi_lat']?.toString() ?? '-8.650000') ?? -8.650000;
    if (rawLat.abs() > 90) {
      while (rawLat.abs() > 90) {
        rawLat /= 10.0;
      }
    }

    double rawLng = double.tryParse(json['lokasi_lng']?.toString() ?? '115.216667') ?? 115.216667;
    if (rawLng.abs() > 180) {
      while (rawLng.abs() > 180) {
        rawLng /= 10.0;
      }
    }

    return PengaturanAbsensi(
      jamMasuk: cleanTime(json['jam_masuk'], '08:00'),
      jamPulang: cleanTime(json['jam_pulang'], '17:00'),
      toleransiMenit: int.tryParse(json['toleransi_menit']?.toString() ?? '15') ?? 15,
      dendaPerMenit: double.tryParse(json['denda_per_menit']?.toString() ?? '1000') ?? 1000,
      lokasiLat: rawLat,
      lokasiLng: rawLng,
      radiusMeter: double.tryParse(json['radius_meter']?.toString() ?? '100') ?? 100,
      folderDriveId: (json['folder_drive_id'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'jam_masuk': jamMasuk,
      'jam_pulang': jamPulang,
      'toleransi_menit': toleransiMenit,
      'denda_per_menit': dendaPerMenit,
      'lokasi_lat': lokasiLat,
      'lokasi_lng': lokasiLng,
      'radius_meter': radiusMeter,
      'folder_drive_id': folderDriveId,
    };
  }
}

class AbsensiSyncResult {
  final int syncedCount;
  final int remainingCount;
  final String? lastError;

  AbsensiSyncResult({
    required this.syncedCount,
    required this.remainingCount,
    this.lastError,
  });
}

class LokasiHasil {
  final double? latitude;
  final double? longitude;
  final String statusTeks;
  final bool isBerhasil;
  final String? errorMessage;

  LokasiHasil({
    this.latitude,
    this.longitude,
    required this.statusTeks,
    this.isBerhasil = false,
    this.errorMessage,
  });

  String get koordinatStr => (latitude != null && longitude != null)
      ? '${latitude!.toStringAsFixed(6)}, ${longitude!.toStringAsFixed(6)}'
      : statusTeks;
}
