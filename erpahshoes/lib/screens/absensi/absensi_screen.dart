import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/absensi_model.dart';
import '../../services/absensi_service.dart';
import '../../services/staff_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/camera_helper.dart';

class AbsensiScreen extends StatefulWidget {
  const AbsensiScreen({super.key});

  @override
  State<AbsensiScreen> createState() => _AbsensiScreenState();
}

class _AbsensiScreenState extends State<AbsensiScreen> with SingleTickerProviderStateMixin {
  final AbsensiService _absensiService = AbsensiService();
  final StaffService _staffService = StaffService();

  late TabController _tabController;
  Timer? _clockTimer;
  DateTime _currentTime = DateTime.now();

  bool _isLoading = true;
  bool _isSyncing = false;
  int _pendingOfflineCount = 0;

  // Staf
  List<Map<String, dynamic>> _staffList = [];
  Map<String, dynamic>? _selectedStaff;

  // Absen Form State
  String? _capturedFotoBase64;
  String _currentLokasi = 'Menghubungkan GPS...';
  LokasiHasil? _lokasiHasil;
  double? _jarakKeTokoMeter;
  bool _isGettingLocation = false;
  bool _isSavingAbsen = false;

  // Pengaturan & Riwayat
  PengaturanAbsensi _pengaturan = PengaturanAbsensi();
  List<AbsensiRecord> _riwayatList = [];
  String _filterStaffQuery = '';

  // Controller Settings
  final _jamMasukCtrl = TextEditingController(text: '08:00');
  final _jamPulangCtrl = TextEditingController(text: '17:00');
  final _toleransiCtrl = TextEditingController(text: '15');
  final _dendaCtrl = TextEditingController(text: '1000');
  final _driveFolderCtrl = TextEditingController();
  final _latTokoCtrl = TextEditingController(text: '-8.650000');
  final _lngTokoCtrl = TextEditingController(text: '115.216667');
  final _radiusTokoCtrl = TextEditingController(text: '100');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    // Live clock timer (WITA UTC+8)
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() => _currentTime = DateTime.now());
    });

    _loadInitialData();
    _fetchLocation();
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _tabController.dispose();
    _jamMasukCtrl.dispose();
    _jamPulangCtrl.dispose();
    _toleransiCtrl.dispose();
    _dendaCtrl.dispose();
    _driveFolderCtrl.dispose();
    _latTokoCtrl.dispose();
    _lngTokoCtrl.dispose();
    _radiusTokoCtrl.dispose();
    super.dispose();
  }

  // Waktu Bali (WITA UTC+8)
  DateTime get _witaTime {
    return _currentTime.toUtc().add(const Duration(hours: 8));
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);

    try {
      final results = await Future.wait([
        _staffService.getStaffList(),
        _absensiService.getPengaturan(),
        _absensiService.getRiwayatAbsensi(),
        _absensiService.getPendingOfflineCount(),
      ]);

      final staffs = results[0] as List<Map<String, dynamic>>;
      final config = results[1] as PengaturanAbsensi;
      final riwayat = results[2] as List<AbsensiRecord>;
      final pendingCount = results[3] as int;

      if (mounted) {
        setState(() {
          _staffList = staffs.where((s) {
            final n = (s['nama_lengkap'] ?? '').toString().trim();
            return n.isNotEmpty && n != 'NAMA_STAFF';
          }).toList();

          if (_staffList.isNotEmpty && _selectedStaff == null) {
            _selectedStaff = _staffList.first;
          }

          _pengaturan = config;
          _jamMasukCtrl.text = config.jamMasuk;
          _jamPulangCtrl.text = config.jamPulang;
          _toleransiCtrl.text = config.toleransiMenit.toString();
          _dendaCtrl.text = config.dendaPerMenit.toInt().toString();
          _driveFolderCtrl.text = config.folderDriveId;
          _latTokoCtrl.text = config.lokasiLat.toStringAsFixed(6);
          _lngTokoCtrl.text = config.lokasiLng.toStringAsFixed(6);
          _radiusTokoCtrl.text = config.radiusMeter.toInt().toString();

          _riwayatList = riwayat;
          _pendingOfflineCount = pendingCount;
          _isLoading = false;
        });

        // Hitung ulang jarak ke toko jika lokasi GPS staf sudah didapatkan
        if (_lokasiHasil != null && _lokasiHasil!.isBerhasil && _lokasiHasil!.latitude != null && _lokasiHasil!.longitude != null) {
          final dist = _absensiService.hitungJarakKeToko(
            _lokasiHasil!.latitude!,
            _lokasiHasil!.longitude!,
            config.lokasiLat,
            config.lokasiLng,
          );
          setState(() {
            _jarakKeTokoMeter = dist;
            final dalamRadius = dist <= config.radiusMeter;
            final statusRadius = dalamRadius ? 'Di Toko' : 'Luar Toko';
            _currentLokasi = '${_lokasiHasil!.koordinatStr} (Jarak: ${dist.round()}m - $statusRadius)';
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchLocation() async {
    if (_isGettingLocation) return;
    setState(() => _isGettingLocation = true);
    final hasil = await _absensiService.ambilLokasiDetail();
    if (mounted) {
      setState(() {
        _lokasiHasil = hasil;
        _isGettingLocation = false;
        if (hasil.isBerhasil && hasil.latitude != null && hasil.longitude != null) {
          final dist = _absensiService.hitungJarakKeToko(
            hasil.latitude!,
            hasil.longitude!,
            _pengaturan.lokasiLat,
            _pengaturan.lokasiLng,
          );
          _jarakKeTokoMeter = dist;
          final dalamRadius = dist <= _pengaturan.radiusMeter;
          final statusRadius = dalamRadius ? 'Di Toko' : 'Luar Toko';
          _currentLokasi = '${hasil.koordinatStr} (Jarak: ${dist.round()}m - $statusRadius)';
        } else {
          _currentLokasi = hasil.statusTeks;
          _jarakKeTokoMeter = null;
        }
      });
    }
  }

  Future<void> _ambilTitikTokoDariLokasiSaya() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Mendeteksi lokasi saat ini untuk titik toko...'), duration: Duration(seconds: 1)),
    );
    final hasil = await _absensiService.ambilLokasiDetail();
    if (hasil.isBerhasil && hasil.latitude != null && hasil.longitude != null) {
      setState(() {
        _latTokoCtrl.text = hasil.latitude!.toStringAsFixed(6);
        _lngTokoCtrl.text = hasil.longitude!.toStringAsFixed(6);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Koordinat toko berhasil diset ke: ${hasil.koordinatStr}'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal deteksi GPS: ${hasil.errorMessage ?? hasil.statusTeks}'),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  void _parseGoogleMapsInput(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return;

    final regex = RegExp(r'(-?\d+(?:\.\d+)?)\s*,\s*(-?\d+(?:\.\d+)?)');
    final match = regex.firstMatch(trimmed);
    if (match != null) {
      final lat = double.tryParse(match.group(1)!);
      final lng = double.tryParse(match.group(2)!);
      if (lat != null && lng != null && lat.abs() <= 90 && lng.abs() <= 180) {
        setState(() {
          _latTokoCtrl.text = lat.toStringAsFixed(6);
          _lngTokoCtrl.text = lng.toStringAsFixed(6);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Koordinat toko terisi dari Google Maps: ${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}'),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _ambilSelfie(ImageSource source) async {
    final b64 = await capturePhoto(context, source: source);
    if (b64 != null && mounted) {
      setState(() => _capturedFotoBase64 = b64);
    }
  }

  Future<void> _pilihJamMasuk() async {
    final parts = _jamMasukCtrl.text.split(':');
    final initialH = int.tryParse(parts[0]) ?? 8;
    final initialM = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;

    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: initialH, minute: initialM),
      helpText: 'Pilih Jam Masuk Kerja (WITA)',
    );

    if (picked != null) {
      final h = picked.hour.toString().padLeft(2, '0');
      final m = picked.minute.toString().padLeft(2, '0');
      setState(() => _jamMasukCtrl.text = '$h:$m');
    }
  }

  Future<void> _pilihJamPulang() async {
    final parts = _jamPulangCtrl.text.split(':');
    final initialH = int.tryParse(parts[0]) ?? 17;
    final initialM = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;

    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: initialH, minute: initialM),
      helpText: 'Pilih Jam Pulang Kerja (WITA)',
    );

    if (picked != null) {
      final h = picked.hour.toString().padLeft(2, '0');
      final m = picked.minute.toString().padLeft(2, '0');
      setState(() => _jamPulangCtrl.text = '$h:$m');
    }
  }

  Future<void> _submitAbsen(String tipe) async {
    if (_selectedStaff == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih nama staf terlebih dahulu'), backgroundColor: AppColors.error),
      );
      return;
    }

    if (_capturedFotoBase64 == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Wajib sertakan foto selfie kehadiran'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isSavingAbsen = true);

    final idStaff = (_selectedStaff!['id_staff'] ?? '').toString();
    final namaStaff = (_selectedStaff!['nama_lengkap'] ?? '').toString();

    final newRecord = await _absensiService.simpanAbsen(
      idStaff: idStaff,
      namaStaff: namaStaff,
      tipe: tipe,
      fotoBase64: _capturedFotoBase64,
      lokasi: _currentLokasi,
    );

    if (mounted) {
      setState(() {
        _riwayatList.insert(0, newRecord);
        _capturedFotoBase64 = null;
        _isSavingAbsen = false;
        _pendingOfflineCount++;
      });

      final isLate = newRecord.menitTerlambat > 0;
      final formatDenda = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text('Konfirmasi Kehadiran', style: GoogleFonts.openSans(fontWeight: FontWeight.bold, fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Karyawan: $namaStaff', style: GoogleFonts.openSans(fontSize: 13, fontWeight: FontWeight.w600)),
              Text('Tipe: Absen $tipe', style: GoogleFonts.openSans(fontSize: 12, color: AppColors.textSecondary)),
              Text('Waktu: ${newRecord.waktuAbsen} WITA', style: GoogleFonts.openSans(fontSize: 12, color: AppColors.textSecondary)),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isLate ? Colors.orange.shade50 : Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isLate ? Colors.orange.shade200 : Colors.green.shade200),
                ),
                child: Text(
                  isLate
                      ? 'Status: Terlambat ${newRecord.menitTerlambat.toInt()} menit\nDenda: ${formatDenda.format(newRecord.potonganGaji)}'
                      : 'Status: Tepat Waktu',
                  style: GoogleFonts.openSans(fontSize: 12, fontWeight: FontWeight.w600, color: isLate ? Colors.orange.shade900 : Colors.green.shade900),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Selesai', style: GoogleFonts.openSans(fontWeight: FontWeight.bold, color: AppColors.primary)),
            ),
          ],
        ),
      );

      _syncAntrean();
    }
  }

  Future<void> _syncAntrean() async {
    if (_isSyncing) return;
    setState(() => _isSyncing = true);

    try {
      final res = await _absensiService.syncOfflineQueue();
      if (!mounted) return;

      setState(() {
        _isSyncing = false;
        _pendingOfflineCount = res.remainingCount;
      });

      if (res.syncedCount > 0) {
        final refreshed = await _absensiService.getRiwayatAbsensi();
        if (!mounted) return;
        setState(() => _riwayatList = refreshed);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${res.syncedCount} data absensi berhasil masuk ke Google Sheets & Drive!'),
            backgroundColor: AppColors.success,
          ),
        );
      } else if (res.remainingCount > 0) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sinkronisasi belum berhasil: ${res.lastError ?? "Pastikan Google Apps Script sudah di-deploy versi terbaru"}'),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSyncing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Kendala saat sinkron: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _simpanPengaturan() async {
    final ok = await _absensiService.updatePengaturan({
      'jam_masuk': _jamMasukCtrl.text.trim(),
      'jam_pulang': _jamPulangCtrl.text.trim(),
      'toleransi_menit': int.tryParse(_toleransiCtrl.text.trim()) ?? 15,
      'denda_per_menit': double.tryParse(_dendaCtrl.text.trim()) ?? 1000,
      'lokasi_lat': double.tryParse(_latTokoCtrl.text.trim()) ?? _pengaturan.lokasiLat,
      'lokasi_lng': double.tryParse(_lngTokoCtrl.text.trim()) ?? _pengaturan.lokasiLng,
      'radius_meter': double.tryParse(_radiusTokoCtrl.text.trim()) ?? _pengaturan.radiusMeter,
      'folder_drive_id': _driveFolderCtrl.text.trim(),
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok ? 'Pengaturan absensi berhasil disimpan' : 'Gagal menyimpan pengaturan'),
          backgroundColor: ok ? AppColors.success : AppColors.error,
        ),
      );
      _loadInitialData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final timeStr = DateFormat('HH:mm:ss').format(_witaTime);
    String dateStr;
    try {
      dateStr = DateFormat('EEEE, dd MMMM yyyy', 'id_ID').format(_witaTime);
    } catch (_) {
      dateStr = DateFormat('yyyy-MM-dd').format(_witaTime);
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        title: Text(
          'Absensi & Kehadiran',
          style: GoogleFonts.openSans(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
        actions: [
          if (_pendingOfflineCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  backgroundColor: const Color(0xFFFEF3C7),
                  foregroundColor: const Color(0xFF92400E),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                icon: _isSyncing
                    ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF92400E)))
                    : const Icon(Icons.cloud_upload_outlined, size: 14),
                label: Text(
                  'Sync ($_pendingOfflineCount)',
                  style: GoogleFonts.openSans(fontSize: 11, fontWeight: FontWeight.w600),
                ),
                onPressed: _syncAntrean,
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            tooltip: 'Perbarui Data',
            onPressed: _loadInitialData,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textHint,
          indicatorColor: AppColors.primary,
          indicatorWeight: 2.5,
          labelStyle: GoogleFonts.openSans(fontWeight: FontWeight.w600, fontSize: 13),
          tabs: const [
            Tab(text: 'Absen Masuk/Pulang'),
            Tab(text: 'Riwayat Kehadiran'),
            Tab(text: 'Pengaturan Jam'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildTabAbsen(timeStr, dateStr),
                _buildTabRiwayat(),
                _buildTabPengaturan(),
              ],
            ),
    );
  }

  // ==========================================
  // TAB 1: FORM ABSEN
  // ==========================================
  Widget _buildTabAbsen(String timeStr, String dateStr) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 1. Minimalist Clock Card
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        timeStr,
                        style: GoogleFonts.openSans(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'WITA (Bali)',
                          style: GoogleFonts.openSans(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    dateStr,
                    style: GoogleFonts.openSans(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Shift: ${_pengaturan.jamMasuk} - ${_pengaturan.jamPulang}',
                    style: GoogleFonts.openSans(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                  ),
                  Text(
                    'Toleransi: ${_pengaturan.toleransiMenit} mnt',
                    style: GoogleFonts.openSans(fontSize: 11, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // 2. Staff Selector Dropdown
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<Map<String, dynamic>>(
              value: _selectedStaff,
              isExpanded: true,
              hint: Text('Pilih Karyawan', style: GoogleFonts.openSans(fontSize: 13)),
              items: _staffList.map((s) {
                return DropdownMenuItem<Map<String, dynamic>>(
                  value: s,
                  child: Text(
                    '${s['nama_lengkap']} (${s['id_staff']})',
                    style: GoogleFonts.openSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                  ),
                );
              }).toList(),
              onChanged: (val) => setState(() => _selectedStaff = val),
            ),
          ),
        ),

        const SizedBox(height: 14),

        // 3. Foto Selfie Area
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Foto Selfie Kehadiran',
                    style: GoogleFonts.openSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                  ),
                  Text(
                    'Tersimpan di Google Drive',
                    style: GoogleFonts.openSans(fontSize: 11, color: AppColors.textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_capturedFotoBase64 != null)
                Stack(
                  alignment: Alignment.topRight,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(
                        base64Decode(_capturedFotoBase64!),
                        width: double.infinity,
                        height: 200,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.white,
                          side: const BorderSide(color: AppColors.border),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        ),
                        onPressed: () => setState(() => _capturedFotoBase64 = null),
                        child: Text('Ganti Foto', style: GoogleFonts.openSans(fontSize: 11, color: AppColors.textPrimary)),
                      ),
                    ),
                  ],
                )
              else
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: AppColors.border),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.camera_alt_outlined, size: 18, color: AppColors.textPrimary),
                    label: Text(
                      'Ambil Foto Selfie (Buka Kamera)',
                      style: GoogleFonts.openSans(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                    ),
                    onPressed: () => _ambilSelfie(ImageSource.camera),
                  ),
                ),
              const SizedBox(height: 12),
              // Location info container
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _lokasiHasil?.isBerhasil == true ? Icons.location_on : Icons.location_off_outlined,
                          size: 15,
                          color: _lokasiHasil?.isBerhasil == true ? AppColors.primary : Colors.orange.shade700,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _lokasiHasil?.isBerhasil == true
                                ? 'GPS: ${_lokasiHasil!.koordinatStr}'
                                : 'GPS: $_currentLokasi',
                            style: GoogleFonts.openSans(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                          ),
                        ),
                        InkWell(
                          onTap: _fetchLocation,
                          borderRadius: BorderRadius.circular(4),
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: _isGettingLocation
                                ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(Icons.refresh, size: 16, color: AppColors.textSecondary),
                          ),
                        ),
                      ],
                    ),
                    if (_jarakKeTokoMeter != null) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: (_jarakKeTokoMeter! <= _pengaturan.radiusMeter) ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              (_jarakKeTokoMeter! <= _pengaturan.radiusMeter) ? '✓ DI DALAM RADIUS TOKO' : '⚠ DI LUAR RADIUS TOKO',
                              style: GoogleFonts.openSans(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: (_jarakKeTokoMeter! <= _pengaturan.radiusMeter) ? const Color(0xFF166534) : const Color(0xFF92400E),
                              ),
                            ),
                          ),
                          Text(
                            'Jarak: ${_jarakKeTokoMeter!.round()} meter (Batas radius: ${_pengaturan.radiusMeter.round()} m)',
                            style: GoogleFonts.openSans(fontSize: 11, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ],
                    if (_lokasiHasil?.isBerhasil != true) ...[
                      const SizedBox(height: 6),
                      Text(
                        _lokasiHasil?.errorMessage ?? 'Pastikan akses lokasi (Location) diizinkan pada browser Chrome (klik ikon gembok di sebelah URL).',
                        style: GoogleFonts.openSans(fontSize: 11, color: Colors.orange.shade900),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '💡 Info: Absensi tetap dapat disimpan meski GPS tidak terdeteksi pada PC/Laptop desktop.',
                        style: GoogleFonts.openSans(fontSize: 10, color: AppColors.textSecondary),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // 4. Action Buttons
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
                onPressed: _isSavingAbsen ? null : () => _submitAbsen('Masuk'),
                child: Text(
                  _isSavingAbsen ? 'Menyimpan...' : 'Absen Masuk',
                  style: GoogleFonts.openSans(fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDC2626),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
                onPressed: _isSavingAbsen ? null : () => _submitAbsen('Pulang'),
                child: Text(
                  _isSavingAbsen ? 'Menyimpan...' : 'Absen Pulang',
                  style: GoogleFonts.openSans(fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ==========================================
  // TAB 2: RIWAYAT KEHADIRAN
  // ==========================================
  Widget _buildTabRiwayat() {
    final filtered = _riwayatList.where((r) {
      if (_filterStaffQuery.isEmpty) return true;
      return r.namaStaff.toLowerCase().contains(_filterStaffQuery.toLowerCase());
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Cari nama staf...',
              prefixIcon: const Icon(Icons.search, size: 18),
              filled: true,
              fillColor: AppColors.surface,
              contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 14),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
            ),
            onChanged: (val) => setState(() => _filterStaffQuery = val),
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? Center(child: Text('Belum ada riwayat absensi.', style: GoogleFonts.openSans(fontSize: 12, color: AppColors.textHint)))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filtered.length,
                  itemBuilder: (ctx, i) {
                    final item = filtered[i];
                    final isMasuk = item.tipe == 'Masuk';
                    final isLate = item.menitTerlambat > 0;
                    final formatRp = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          InkWell(
                            onTap: () {
                              if (item.linkFoto.isNotEmpty) {
                                _showFotoPreviewDialog(item.linkFoto, item.namaStaff);
                              }
                            },
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: item.linkFoto.isNotEmpty && item.linkFoto.startsWith('http')
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(6),
                                      child: Image.network(item.linkFoto, fit: BoxFit.cover, errorBuilder: (c, e, s) => const Icon(Icons.person, size: 18, color: Colors.grey)),
                                    )
                                  : const Icon(Icons.person, size: 18, color: Colors.grey),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(item.namaStaff, style: GoogleFonts.openSans(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textPrimary)),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: isMasuk ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        item.tipe,
                                        style: GoogleFonts.openSans(fontSize: 10, fontWeight: FontWeight.bold, color: isMasuk ? const Color(0xFF166534) : const Color(0xFF991B1B)),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${item.waktuAbsen} WITA',
                                  style: GoogleFonts.openSans(fontSize: 11, color: AppColors.textSecondary),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Text(
                                      item.status,
                                      style: GoogleFonts.openSans(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: isLate ? const Color(0xFFD97706) : (item.isOfflinePending ? const Color(0xFFB45309) : const Color(0xFF16A34A)),
                                      ),
                                    ),
                                    if (isLate) ...[
                                      const SizedBox(width: 6),
                                      Text('• Denda: ${formatRp.format(item.potonganGaji)}', style: GoogleFonts.openSans(fontSize: 11, color: Colors.red.shade700)),
                                    ],
                                  ],
                                ),
                                if (item.lokasi.isNotEmpty) ...[
                                  const SizedBox(height: 3),
                                  Text(
                                    '📍 ${item.lokasi}',
                                    style: GoogleFonts.openSans(fontSize: 10, color: AppColors.textSecondary),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _showFotoPreviewDialog(String url, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Foto: $name', style: GoogleFonts.openSans(fontSize: 14, fontWeight: FontWeight.bold)),
            IconButton(icon: const Icon(Icons.open_in_new, size: 16), onPressed: () => launchUrl(Uri.parse(url))),
          ],
        ),
        content: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Image.network(url, fit: BoxFit.contain, errorBuilder: (c, e, s) => const Text('Gagal memuat foto dari Drive')),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Tutup')),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 3: PENGATURAN JAM KERJA & DENDA
  // ==========================================
  Widget _buildTabPengaturan() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Jadwal Kerja & Waktu (WITA - Bali)', style: GoogleFonts.openSans(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary)),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: _pilihJamMasuk,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Jam Masuk', style: GoogleFonts.openSans(fontSize: 11, color: AppColors.textSecondary)),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('${_jamMasukCtrl.text} WITA', style: GoogleFonts.openSans(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                                const Icon(Icons.access_time, size: 16, color: AppColors.textSecondary),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: InkWell(
                      onTap: _pilihJamPulang,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Jam Pulang', style: GoogleFonts.openSans(fontSize: 11, color: AppColors.textSecondary)),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('${_jamPulangCtrl.text} WITA', style: GoogleFonts.openSans(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                                const Icon(Icons.access_time, size: 16, color: AppColors.textSecondary),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _toleransiCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Toleransi Keterlambatan (Menit)',
                  helperText: 'Staf tidak didenda jika masuk sebelum batas toleransi ini',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _dendaCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Denda Per Menit Terlambat (Rp)',
                  prefixText: 'Rp ',
                  helperText: 'Denda otomatis memotong slip gaji di modul Penggajian',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _driveFolderCtrl,
                decoration: const InputDecoration(
                  labelText: 'ID Folder Google Drive (Opsional)',
                  helperText: 'Default otomatis menggunakan folder "Foto_Absensi_AhShoes"',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
              ),
              const SizedBox(height: 18),
              const Divider(color: AppColors.border),
              const SizedBox(height: 14),

              // Pengaturan Lokasi Titik Toko & Radius
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Titik Lokasi Toko & Radius Presensi',
                    style: GoogleFonts.openSans(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      side: const BorderSide(color: AppColors.border),
                    ),
                    icon: const Icon(Icons.my_location, size: 14, color: AppColors.primary),
                    label: Text(
                      'Set dari GPS Saya',
                      style: GoogleFonts.openSans(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary),
                    ),
                    onPressed: _ambilTitikTokoDariLokasiSaya,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Digunakan untuk mengetahui jarak karyawan dari toko saat melakukan absensi.',
                style: GoogleFonts.openSans(fontSize: 11, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              TextField(
                onChanged: _parseGoogleMapsInput,
                decoration: const InputDecoration(
                  labelText: 'Atau Tempel Koordinat Google Maps',
                  hintText: 'Contoh: -8.651234, 115.214567',
                  helperText: 'Ketik atau paste koordinat dari Google Maps untuk mengisi otomatis',
                  prefixIcon: Icon(Icons.content_paste_go, size: 16),
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _latTokoCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                      decoration: const InputDecoration(
                        labelText: 'Latitude Toko',
                        hintText: '-8.650000',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _lngTokoCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                      decoration: const InputDecoration(
                        labelText: 'Longitude Toko',
                        hintText: '115.216667',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _radiusTokoCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Batas Radius Toko (Meter)',
                  helperText: 'Batas jarak wajar karyawan berada di toko (misal: 100 meter)',
                  suffixText: 'Meter',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                  onPressed: _simpanPengaturan,
                  child: Text('Simpan Pengaturan', style: GoogleFonts.openSans(fontSize: 13, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
