import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/treatment_model.dart';
import '../../services/treatment_service.dart';
import '../../services/staff_service.dart';
import '../../services/kasir_service.dart';
import '../../services/bluetooth_printer_service.dart';
import '../../services/printer_models.dart';
import '../../utils/app_theme.dart';
import 'riwayat_screen.dart';
import 'printer_settings_dialog.dart';

// ─── Model Item Keranjang ────────────────────────────────────
class _CartItem {
  final String uid;
  final Treatment treatment;
  final String jenisItem;  // e.g. Sneakers, Tas, Topi, atau custom
  final String merek;      // e.g. Nike, Adidas, Ventela, dsb.
  final String warna;
  final String ukuran;
  final String staffId;    // id staff yang menangani item ini
  final String staffNama;  // nama staff yang menangani item ini

  _CartItem({
    required this.uid,
    required this.treatment,
    required this.jenisItem,
    required this.merek,
    required this.warna,
    required this.ukuran,
    required this.staffId,
    required this.staffNama,
  });
}

// ─── Main Screen ─────────────────────────────────────────────
class KasirScreen extends StatefulWidget {
  const KasirScreen({Key? key}) : super(key: key);

  @override
  State<KasirScreen> createState() => _KasirScreenState();
}

class _KasirScreenState extends State<KasirScreen> {
  final TreatmentService _treatmentService = TreatmentService();
  final StaffService _staffService = StaffService();
  final KasirService _kasirService = KasirService();
  final BluetoothPrinterService _printerService = BluetoothPrinterService();

  List<Treatment> _treatments = [];
  List<Map<String, dynamic>> _staffList = [];
  final List<_CartItem> _cart = [];

  String? _selectedKasirId;
  final _namaController = TextEditingController();
  final _noHpController = TextEditingController();
  final _uangDiterimaController = TextEditingController();
  final _kodeUnikController = TextEditingController();

  String _metodeBayar = 'Cash';
  String _statusBayar = 'Bayar Sekarang';

  bool _isLoading = true;
  bool _isProcessing = false;

  void _generateKodeUnik() {
    final code = (1000 + Random().nextInt(9000)).toString();
    _kodeUnikController.text = code;
  }

  // Pilihan jenis item — umum, tidak hanya sepatu
  static const List<String> _jenisOptions = [
    'Sneakers',
    'Running Shoes',
    'Boots',
    'Sepatu Formal',
    'Sandal / Slop',
    'Tas',
    'Topi',
    'Lainnya',
  ];

  @override
  void initState() {
    super.initState();
    _generateKodeUnik();
    _loadData();
    _printerService.autoConnect();
  }

  Future<void> _loadData({bool forceRefresh = false}) async {
    setState(() => _isLoading = true);
    final results = await Future.wait([
      _treatmentService.getTreatments(forceRefresh: forceRefresh),
      _staffService.getStaffList(forceRefresh: forceRefresh),
    ]);
    if (!mounted) return;
    setState(() {
      _treatments = results[0] as List<Treatment>;
      _staffList = results[1] as List<Map<String, dynamic>>;
      _isLoading = false;
    });
  }

  // ─── Computed ───────────────────────────────────────────────
  double get _total => _cart.fold(0, (sum, item) => sum + item.treatment.hargaJual);

  String _staffName(String? id) {
    if (id == null) return '';
    try {
      final s = _staffList.firstWhere((s) => s['id_staff']?.toString() == id);
      return s['nama_lengkap']?.toString() ?? '';
    } catch (_) {
      return '';
    }
  }

  String _formatPhone(String raw) {
    final clean = raw.trim();
    if (clean.startsWith('+62')) return clean;
    if (clean.startsWith('62')) return '+$clean';
    if (clean.startsWith('0') && clean.length > 1) return '+62${clean.substring(1)}';
    return clean;
  }

  String _hitungKembalian() {
    final uang = double.tryParse(_uangDiterimaController.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    if (uang < _total) return '0';
    return (uang - _total).toInt().toString();
  }

  void _removeFromCart(String uid) => setState(() => _cart.removeWhere((i) => i.uid == uid));

  void _clearAll() {
    setState(() {
      _cart.clear();
      _namaController.clear();
      _noHpController.clear();
      _uangDiterimaController.clear();
      _selectedKasirId = null;
      _metodeBayar = 'Cash';
      _statusBayar = 'Bayar Sekarang';
      _generateKodeUnik();
    });
  }

  // ─── Dialog tambah item ke keranjang ─────────────────────────
  void _showAddItemDialog(Treatment treatment) {
    String jenisSelected = _jenisOptions[0];
    bool isLainnya = false;
    final merekController = TextEditingController();
    final warnaController = TextEditingController();
    final ukuranController = TextEditingController();
    final lainnyaController = TextEditingController();

    // Hanya tampilkan staff dengan role karyawan
    final staffKaryawan = _staffList.where((s) =>
        (s['role']?.toString().toLowerCase() ?? '') == 'karyawan').toList();
    String? staffItemId;
    String staffItemNama = '';


    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
              left: 20, right: 20, top: 16,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              sheetHandle(),

              // Info Treatment
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(10)),
                child: Row(children: [
                  const Icon(Icons.local_offer, size: 16, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(treatment.namaTreatment,
                        style: GoogleFonts.openSans(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary)),
                    Text('Rp ${treatment.hargaJual.toInt()}',
                        style: GoogleFonts.openSans(fontSize: 12, color: AppColors.primary)),
                  ])),
                ]),
              ),
              const SizedBox(height: 16),

              Text('DETAIL ITEM',
                  style: GoogleFonts.openSans(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textHint, letterSpacing: 0.5)),
              const SizedBox(height: 10),

              // Jenis Item
              Text('Jenis Item *',
                  style: GoogleFonts.openSans(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border)),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: jenisSelected,
                    items: _jenisOptions.map((j) => DropdownMenuItem(
                        value: j,
                        child: Text(j, style: GoogleFonts.openSans(fontSize: 13)))).toList(),
                    onChanged: (v) {
                      if (v == null) return;
                      setModalState(() {
                        jenisSelected = v;
                        isLainnya = (v == 'Lainnya');
                        if (!isLainnya) lainnyaController.clear();
                      });
                    },
                  ),
                ),
              ),

              // Jika "Lainnya", tampilkan text field
              if (isLainnya) ...[
                const SizedBox(height: 8),
                TextFormField(
                  controller: lainnyaController,
                  autofocus: true,
                  style: GoogleFonts.openSans(fontSize: 13),
                  textCapitalization: TextCapitalization.words,
                  decoration: _inputDeco('Ketik jenis item, contoh: Helm, Jaket...'),
                ),
              ],
              const SizedBox(height: 12),

              // Merek Item
              Text('Merek Item *',
                  style: GoogleFonts.openSans(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
              const SizedBox(height: 6),
              TextFormField(
                controller: merekController,
                style: GoogleFonts.openSans(fontSize: 13),
                textCapitalization: TextCapitalization.words,
                decoration: _inputDeco('Contoh: Nike, Adidas, Ventela'),
              ),
              const SizedBox(height: 12),

              // Warna & Ukuran
              Row(children: [
                Expanded(
                  flex: 3,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Warna *',
                        style: GoogleFonts.openSans(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: warnaController,
                      style: GoogleFonts.openSans(fontSize: 13),
                      textCapitalization: TextCapitalization.words,
                      decoration: _inputDeco('Contoh: Putih, Hitam'),
                    ),
                  ]),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Ukuran *',
                        style: GoogleFonts.openSans(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: ukuranController,
                      style: GoogleFonts.openSans(fontSize: 13),
                      keyboardType: TextInputType.text,
                      decoration: _inputDeco('42 / M / L'),
                    ),
                  ]),
                ),
              ],
              ),
              const SizedBox(height: 12),

              // Staff Bertugas
              Text('Staff Bertugas',
                  style: GoogleFonts.openSans(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border)),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: staffItemId,
                    hint: Text('— Pilih Staff —',
                        style: GoogleFonts.openSans(fontSize: 12, color: AppColors.textHint)),
                    items: [
                      DropdownMenuItem<String>(
                          value: null,
                          child: Text('— Tidak Ditentukan —',
                              style: GoogleFonts.openSans(fontSize: 12, color: AppColors.textHint))),
                      ...staffKaryawan.map((s) => DropdownMenuItem<String>(
                            value: s['id_staff']?.toString(),
                            child: Text(s['nama_lengkap']?.toString() ?? '-',
                                style: GoogleFonts.openSans(fontSize: 13)),
                          )),
                    ],
                    onChanged: (v) {
                      setModalState(() {
                        staffItemId = v;
                        if (v != null) {
                          final found = staffKaryawan.firstWhere(
                              (s) => s['id_staff']?.toString() == v,
                              orElse: () => {});
                          staffItemNama = found['nama_lengkap']?.toString() ?? '';
                        } else {
                          staffItemNama = '';
                        }
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Tombol Tambah
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton.icon(
                  onPressed: () {
                    final isJenisLainnya = jenisSelected == 'Lainnya';
                    final jenisVal = isJenisLainnya ? lainnyaController.text.trim() : jenisSelected;
                    final merekVal = merekController.text.trim();
                    final warnaVal = warnaController.text.trim();
                    final ukuranVal = ukuranController.text.trim();

                    if (isJenisLainnya && jenisVal.isEmpty) {
                      _snack('Ketik jenis item terlebih dahulu', isError: true);
                      return;
                    }
                    if (merekVal.isEmpty) {
                      _snack('Merek item wajib diisi (contoh: Nike, Ventela)', isError: true);
                      return;
                    }
                    if (warnaVal.isEmpty) {
                      _snack('Warna item wajib diisi (contoh: Putih, Hitam)', isError: true);
                      return;
                    }
                    if (ukuranVal.isEmpty) {
                      _snack('Ukuran item wajib diisi (contoh: 42, M, L)', isError: true);
                      return;
                    }

                    setState(() {
                      _cart.add(_CartItem(
                        uid: '${treatment.idTreatment}_${DateTime.now().millisecondsSinceEpoch}',
                        treatment: treatment,
                        jenisItem: jenisVal,
                        merek: merekVal,
                        warna: warnaVal,
                        ukuran: ukuranVal,
                        staffId: staffItemId ?? '',
                        staffNama: staffItemNama,
                      ));
                    });
                    Navigator.pop(ctx);
                    _snack('${treatment.namaTreatment} ditambahkan ke keranjang');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.add_shopping_cart, size: 18, color: Colors.white),
                  label: Text('Tambah ke Keranjang',
                      style: GoogleFonts.openSans(fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Dialog edit item yang sudah ada di keranjang ─────────────
  void _showEditItemDialog(_CartItem item) {
    bool isKnownJenis = _jenisOptions.contains(item.jenisItem);
    String jenisSelected = isKnownJenis ? item.jenisItem : 'Lainnya';
    bool isLainnya = !isKnownJenis || item.jenisItem == 'Lainnya';

    final merekController = TextEditingController(text: item.merek);
    final warnaController = TextEditingController(text: item.warna);
    final ukuranController = TextEditingController(text: item.ukuran);
    final lainnyaController = TextEditingController(
        text: isKnownJenis && item.jenisItem != 'Lainnya' ? '' : item.jenisItem);

    final staffKaryawan = _staffList.where((s) =>
        (s['role']?.toString().toLowerCase() ?? '') == 'karyawan').toList();
    String? staffItemId = item.staffId.isNotEmpty && staffKaryawan.any((s) => s['id_staff']?.toString() == item.staffId)
        ? item.staffId
        : null;
    String staffItemNama = item.staffNama;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
              left: 20, right: 20, top: 16,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              sheetHandle(),

              // Info Treatment
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(10)),
                child: Row(children: [
                  const Icon(Icons.edit_note, size: 20, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Edit Item: ${item.treatment.namaTreatment}',
                        style: GoogleFonts.openSans(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary)),
                    Text('Rp ${item.treatment.hargaJual.toInt()}',
                        style: GoogleFonts.openSans(fontSize: 12, color: AppColors.primary)),
                  ])),
                ]),
              ),
              const SizedBox(height: 16),

              Text('DETAIL ITEM',
                  style: GoogleFonts.openSans(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textHint, letterSpacing: 0.5)),
              const SizedBox(height: 10),

              // Jenis Item
              Text('Jenis Item *',
                  style: GoogleFonts.openSans(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border)),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: jenisSelected,
                    items: _jenisOptions.map((j) => DropdownMenuItem(
                        value: j,
                        child: Text(j, style: GoogleFonts.openSans(fontSize: 13)))).toList(),
                    onChanged: (v) {
                      if (v == null) return;
                      setModalState(() {
                        jenisSelected = v;
                        isLainnya = (v == 'Lainnya');
                        if (!isLainnya) lainnyaController.clear();
                      });
                    },
                  ),
                ),
              ),

              if (isLainnya) ...[
                const SizedBox(height: 8),
                TextFormField(
                  controller: lainnyaController,
                  autofocus: true,
                  style: GoogleFonts.openSans(fontSize: 13),
                  textCapitalization: TextCapitalization.words,
                  decoration: _inputDeco('Ketik jenis item, contoh: Helm, Jaket...'),
                ),
              ],
              const SizedBox(height: 12),

              // Merek Item
              Text('Merek Item *',
                  style: GoogleFonts.openSans(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
              const SizedBox(height: 6),
              TextFormField(
                controller: merekController,
                style: GoogleFonts.openSans(fontSize: 13),
                textCapitalization: TextCapitalization.words,
                decoration: _inputDeco('Contoh: Nike, Adidas, Ventela'),
              ),
              const SizedBox(height: 12),

              // Warna & Ukuran
              Row(children: [
                Expanded(
                  flex: 3,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Warna *',
                        style: GoogleFonts.openSans(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: warnaController,
                      style: GoogleFonts.openSans(fontSize: 13),
                      textCapitalization: TextCapitalization.words,
                      decoration: _inputDeco('Contoh: Putih, Hitam'),
                    ),
                  ]),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Ukuran *',
                        style: GoogleFonts.openSans(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: ukuranController,
                      style: GoogleFonts.openSans(fontSize: 13),
                      keyboardType: TextInputType.text,
                      decoration: _inputDeco('42 / M / L'),
                    ),
                  ]),
                ),
              ]),
              const SizedBox(height: 12),

              // Staff Bertugas
              Text('Staff Bertugas',
                  style: GoogleFonts.openSans(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border)),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: staffItemId,
                    hint: Text('— Pilih Staff —',
                        style: GoogleFonts.openSans(fontSize: 12, color: AppColors.textHint)),
                    items: [
                      DropdownMenuItem<String>(
                          value: null,
                          child: Text('— Tidak Ditentukan —',
                              style: GoogleFonts.openSans(fontSize: 12, color: AppColors.textHint))),
                      ...staffKaryawan.map((s) => DropdownMenuItem<String>(
                            value: s['id_staff']?.toString(),
                            child: Text(s['nama_lengkap']?.toString() ?? '-',
                                style: GoogleFonts.openSans(fontSize: 13)),
                          )),
                    ],
                    onChanged: (v) {
                      setModalState(() {
                        staffItemId = v;
                        if (v != null) {
                          final found = staffKaryawan.firstWhere(
                              (s) => s['id_staff']?.toString() == v,
                              orElse: () => {});
                          staffItemNama = found['nama_lengkap']?.toString() ?? '';
                        } else {
                          staffItemNama = '';
                        }
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Tombol Simpan Perubahan
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton.icon(
                  onPressed: () {
                    final isJenisLainnya = jenisSelected == 'Lainnya';
                    final jenisVal = isJenisLainnya ? lainnyaController.text.trim() : jenisSelected;
                    final merekVal = merekController.text.trim();
                    final warnaVal = warnaController.text.trim();
                    final ukuranVal = ukuranController.text.trim();

                    if (isJenisLainnya && jenisVal.isEmpty) {
                      _snack('Ketik jenis item terlebih dahulu', isError: true);
                      return;
                    }
                    if (merekVal.isEmpty) {
                      _snack('Merek item wajib diisi (contoh: Nike, Ventela)', isError: true);
                      return;
                    }
                    if (warnaVal.isEmpty) {
                      _snack('Warna item wajib diisi (contoh: Putih, Hitam)', isError: true);
                      return;
                    }
                    if (ukuranVal.isEmpty) {
                      _snack('Ukuran item wajib diisi (contoh: 42, M, L)', isError: true);
                      return;
                    }

                    final idx = _cart.indexWhere((c) => c.uid == item.uid);
                    if (idx != -1) {
                      setState(() {
                        _cart[idx] = _CartItem(
                          uid: item.uid,
                          treatment: item.treatment,
                          jenisItem: jenisVal,
                          merek: merekVal,
                          warna: warnaVal,
                          ukuran: ukuranVal,
                          staffId: staffItemId ?? '',
                          staffNama: staffItemNama,
                        );
                      });
                    }
                    Navigator.pop(ctx);
                    _snack('Item berhasil diperbarui');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.check, size: 18, color: Colors.white),
                  label: Text('Simpan Perubahan',
                      style: GoogleFonts.openSans(fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDeco(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.openSans(fontSize: 12, color: AppColors.textHint),
        filled: true, fillColor: AppColors.background,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
      );

  // ─── Process Order — Header & Detail ─────────────────────────
  Future<void> _processOrder() async {
    if (_cart.isEmpty) { _snack('Pilih minimal 1 item', isError: true); return; }
    if (_namaController.text.trim().isEmpty) { _snack('Nama pelanggan harus diisi', isError: true); return; }
    if (_selectedKasirId == null) { _snack('Pilih kasir yang bertugas', isError: true); return; }
    
    if (_statusBayar == 'Bayar Sekarang' && _metodeBayar == 'Cash') {
      final uang = double.tryParse(_uangDiterimaController.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
      if (uang < _total) { _snack('Nominal uang tidak cukup', isError: true); return; }
    }

    setState(() => _isProcessing = true);

    final now = DateTime.now();
    final idTrx = 'TRX${now.millisecondsSinceEpoch.toString().substring(5)}';
    final kodeUnik = _kodeUnikController.text.trim().isNotEmpty
        ? _kodeUnikController.text.trim()
        : (1000 + Random().nextInt(9000)).toString();
    final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final timeStr = '${now.hour.toString().padLeft(2, '0')}.${now.minute.toString().padLeft(2, '0')}';
    final hp = _noHpController.text.trim().isNotEmpty ? _formatPhone(_noHpController.text.trim()) : '';
    final kasir = _staffName(_selectedKasirId);
    final totalStr = _total.toInt().toString();

    // Serialisasi item ke JSON array (sertakan nama_staff per item)
    final itemsJson = jsonEncode(_cart.map((item) => {
      'nama_treatment': item.treatment.namaTreatment,
      'harga_treatment': item.treatment.hargaJual.toInt(),
      'jenis_item': item.jenisItem,
      'merek': item.merek,
      'warna': item.warna,
      'ukuran': item.ukuran,
      'nama_staff': item.staffNama,
    }).toList());

    final ok = await _kasirService.addTransaksi({
      'id_transaksi': idTrx,
      'kode_unik': kodeUnik,
      'tanggal': dateStr,
      'waktu': timeStr,
      'nama_pelanggan': _namaController.text.trim(),
      'no_hp': hp,
      'nama_kasir': kasir,
      'total_item': _cart.length.toString(),
      'total_harga': totalStr,
      'metode_bayar': _statusBayar == 'Bayar Saat Selesai' ? '' : _metodeBayar,
      'status_bayar': _statusBayar,
      'items': itemsJson,
    });

    setState(() => _isProcessing = false);
    if (!mounted) return;
    if (ok) {
      _showSuccessDialog(idTrx, hp, kodeUnik, dateStr, timeStr);
    } else {
      _snack('Gagal menyimpan transaksi. Coba lagi.', isError: true);
    }
  }

  void _snack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.openSans(fontSize: 13)),
      backgroundColor: isError ? AppColors.error : AppColors.success,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      margin: const EdgeInsets.all(12),
    ));
  }

  void _showSuccessDialog(String idTrx, String hp, String kodeUnik, String dateStr, String timeStr) {
    final cartSnap = List<_CartItem>.from(_cart);
    final kasir = _staffName(_selectedKasirId);
    final uangDiterima = double.tryParse(_uangDiterimaController.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? _total;
    final kembalianInt = int.tryParse(_hitungKembalian()) ?? 0;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        contentPadding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(color: AppColors.success.withOpacity(0.1), shape: BoxShape.circle),
              child: const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 36),
            ),
            const SizedBox(height: 10),
            Text('Transaksi Berhasil!', style: GoogleFonts.openSans(fontSize: 15, fontWeight: FontWeight.bold)),
            Text(idTrx, style: GoogleFonts.openSans(fontSize: 11, color: AppColors.textHint)),
            
            // BANNER KODE UNIK SEPATU
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.primary.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  Text('KODE UNIK SEPATU',
                      style: GoogleFonts.openSans(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary, letterSpacing: 0.5)),
                  const SizedBox(height: 2),
                  Text('#$kodeUnik',
                      style: GoogleFonts.openSans(fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.primary)),
                  const SizedBox(height: 2),
                  Text('Tulis di label sepatu & cocokkan saat pengambilan',
                      style: GoogleFonts.openSans(fontSize: 10, color: AppColors.textSecondary), textAlign: TextAlign.center),
                ],
              ),
            ),

            const Divider(color: AppColors.divider, height: 1),
            const SizedBox(height: 10),
            ...cartSnap.asMap().entries.map((e) {
              final idx = e.key + 1;
              final item = e.value;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(4)),
                      child: Text('#$idx', style: GoogleFonts.openSans(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary)),
                    ),
                    const SizedBox(width: 6),
                    Expanded(child: Text(item.treatment.namaTreatment, style: GoogleFonts.openSans(fontSize: 12, fontWeight: FontWeight.bold))),
                    Text('Rp ${item.treatment.hargaJual.toInt()}', style: GoogleFonts.openSans(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary)),
                  ]),
                  const SizedBox(height: 3),
                  Text(
                    '${item.jenisItem}${item.merek.isNotEmpty ? " • ${item.merek}" : ""}${item.warna.isNotEmpty ? " • ${item.warna}" : ""}${item.ukuran.isNotEmpty ? " • Ukuran ${item.ukuran}" : ""}',
                    style: GoogleFonts.openSans(fontSize: 11, color: AppColors.textSecondary),
                  ),
                  if (item.staffNama.isNotEmpty)
                    Row(children: [
                      const Icon(Icons.person_pin_circle_outlined, size: 11, color: AppColors.textHint),
                      const SizedBox(width: 3),
                      Text(item.staffNama,
                          style: GoogleFonts.openSans(fontSize: 10, color: AppColors.textHint,
                              fontStyle: FontStyle.italic)),
                    ]),
                ]),
              );
            }),
            const Divider(color: AppColors.divider, height: 14),
            Row(children: [
              Text('TOTAL ${cartSnap.length} Item', style: GoogleFonts.openSans(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
              const Spacer(),
              Text('Rp ${_total.toInt()}', style: GoogleFonts.openSans(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary)),
            ]),
            const SizedBox(height: 6),
            _rcRow('Waktu Bayar', _statusBayar),
            if (_statusBayar == 'Bayar Sekarang') _rcRow('Metode Bayar', _metodeBayar),
            if (_statusBayar == 'Bayar Sekarang' && _metodeBayar == 'Cash') ...[
              _rcRow('Tunai', 'Rp ${_uangDiterimaController.text.isEmpty ? _total.toInt() : _uangDiterimaController.text}'),
              _rcRow('Kembalian', 'Rp ${_hitungKembalian()}'),
            ],
            if (kasir.isNotEmpty) _rcRow('Kasir', kasir),
            if (hp.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(children: [
                  const Icon(Icons.phone_android, size: 13, color: AppColors.textHint),
                  const SizedBox(width: 4),
                  Text(hp, style: GoogleFonts.openSans(fontSize: 12, color: AppColors.textSecondary)),
                ]),
              ),
          ]),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        actions: [
          // Tombol Cetak Struk Bluetooth
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                final receiptData = ReceiptData(
                  idTransaksi: idTrx,
                  kodeUnik: kodeUnik,
                  tanggal: dateStr,
                  waktu: timeStr,
                  namaPelanggan: _namaController.text.trim(),
                  noHp: hp,
                  namaKasir: kasir,
                  metodeBayar: _statusBayar == 'Bayar Saat Selesai' ? '-' : _metodeBayar,
                  statusBayar: _statusBayar,
                  totalHarga: _total.toInt(),
                  totalItem: cartSnap.length,
                  nominalUang: _statusBayar == 'Bayar Sekarang' && _metodeBayar == 'Cash'
                      ? uangDiterima.toInt()
                      : null,
                  kembalian: _statusBayar == 'Bayar Sekarang' && _metodeBayar == 'Cash'
                      ? kembalianInt
                      : null,
                  items: cartSnap.map((item) => ReceiptItemData(
                    namaTreatment: item.treatment.namaTreatment,
                    harga: item.treatment.hargaJual.toInt(),
                    jenisItem: item.jenisItem,
                    merek: item.merek,
                    warna: item.warna,
                    ukuran: item.ukuran,
                    staffNama: item.staffNama,
                  )).toList(),
                );

                bool connected = await _printerService.isConnected();
                if (!connected) {
                  connected = await _printerService.autoConnect();
                }

                if (!connected) {
                  if (context.mounted) {
                    _snack('Printer belum terhubung. Silakan sambungkan printer Iware.', isError: true);
                    PrinterSettingsDialog.show(context);
                  }
                  return;
                }

                final printOk = await _printerService.printReceipt(receiptData);
                if (context.mounted) {
                  if (printOk) {
                    _snack('Struk berhasil dicetak!');
                  } else {
                    _snack('Gagal mencetak struk. Cek koneksi printer.', isError: true);
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.print, color: Colors.white, size: 18),
              label: Text('Cetak Struk (Bluetooth)',
                  style: GoogleFonts.openSans(fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => PrinterSettingsDialog.show(context),
                  icon: const Icon(Icons.settings_bluetooth, size: 14),
                  label: Text('Atur Printer', style: GoogleFonts.openSans(fontSize: 11)),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _clearAll();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text('Transaksi Baru',
                      style: GoogleFonts.openSans(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 12)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _rcRow(String label, String value) => Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(children: [
        Expanded(child: Text(label, style: GoogleFonts.openSans(fontSize: 12, color: AppColors.textSecondary))),
        Text(value, style: GoogleFonts.openSans(fontSize: 12, fontWeight: FontWeight.w500)),
      ]));

  // ─── Build ──────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        title: Text('Kasir', style: GoogleFonts.openSans(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        bottom: const PreferredSize(preferredSize: Size.fromHeight(1), child: Divider(height: 1, color: AppColors.divider)),
        actions: [
          IconButton(
            icon: const Icon(Icons.print, color: AppColors.primary),
            tooltip: 'Pengaturan Printer Bluetooth',
            onPressed: () => PrinterSettingsDialog.show(context),
          ),
          IconButton(
            icon: const Icon(Icons.history, color: AppColors.primary),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RiwayatScreen())),
          ),
          if (_cart.isNotEmpty)
            TextButton.icon(
              onPressed: () => showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text('Reset Order?', style: GoogleFonts.openSans(fontWeight: FontWeight.bold, fontSize: 14)),
                  content: Text('Semua item dan data pelanggan akan dikosongkan.', style: GoogleFonts.openSans(fontSize: 13)),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Batal', style: GoogleFonts.openSans(color: AppColors.textSecondary))),
                    TextButton(onPressed: () { Navigator.pop(ctx); _clearAll(); },
                        child: Text('Reset', style: GoogleFonts.openSans(color: AppColors.error, fontWeight: FontWeight.bold))),
                  ],
                ),
              ),
              icon: const Icon(Icons.refresh, size: 16, color: AppColors.error),
              label: Text('Reset', style: GoogleFonts.openSans(fontSize: 12, color: AppColors.error)),
            ),
          IconButton(
            icon: const Icon(Icons.refresh, size: 18, color: AppColors.textSecondary),
            tooltip: 'Segarkan data',
            onPressed: () => _loadData(forceRefresh: true),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
          : LayoutBuilder(builder: (context, constraints) {
              if (constraints.maxWidth >= 600) return _buildTablet();
              return _buildPhone();
            }),
    );
  }

  Widget _buildPhone() => Column(children: [
        Expanded(child: _buildTreatmentGrid(crossAxisCount: 2)),
        Flexible(child: _buildOrderPanel(isPhone: true)),
      ]);

  Widget _buildTablet() => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(flex: 6, child: _buildTreatmentGrid(crossAxisCount: 3)),
        const VerticalDivider(width: 1, color: AppColors.divider),
        SizedBox(width: 360, child: _buildOrderPanel(isPhone: false)),
      ]);

  Widget _buildTreatmentGrid({required int crossAxisCount}) {
    if (_treatments.isEmpty) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.local_offer_outlined, size: 40, color: AppColors.textHint),
        const SizedBox(height: 8),
        Text('Belum ada treatment', style: GoogleFonts.openSans(fontSize: 13, color: AppColors.textHint)),
      ]));
    }
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1.15),
      itemCount: _treatments.length,
      itemBuilder: (_, i) => _buildTreatmentCard(_treatments[i]),
    );
  }

  Widget _buildTreatmentCard(Treatment t) {
    final count = _cart.where((c) => c.treatment.idTreatment == t.idTreatment).length;
    final inCart = count > 0;
    final isOutOfStock = t.stok <= 0;
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: inCart ? AppColors.primaryLight : (isOutOfStock ? Colors.grey.shade100 : AppColors.surface),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: inCart ? AppColors.primary : AppColors.border, width: inCart ? 1.5 : 1),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: isOutOfStock ? () => _snack('Stok treatment habis!', isError: true) : () => _showAddItemDialog(t),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (inCart)
                Align(alignment: Alignment.topRight,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(10)),
                    child: Text('$count', style: GoogleFonts.openSans(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                  ))
              else
                const SizedBox(height: 16),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(t.namaTreatment,
                    style: GoogleFonts.openSans(fontSize: 12, fontWeight: FontWeight.bold,
                        color: inCart ? AppColors.primary : (isOutOfStock ? AppColors.textHint : AppColors.textPrimary)),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text('Rp ${t.hargaJual.toInt()} • Stok: ${t.stok >= 999 ? '∞' : t.stok.toInt()}',
                    style: GoogleFonts.openSans(fontSize: 11, fontWeight: FontWeight.w600,
                        color: inCart ? AppColors.primary : AppColors.textSecondary)),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: isOutOfStock ? Colors.grey : AppColors.primary, borderRadius: BorderRadius.circular(6)),
                    child: Text(isOutOfStock ? 'Habis' : '+ Tambah', style: GoogleFonts.openSans(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOrderPanel({required bool isPhone}) {
    return Container(
      constraints: isPhone ? const BoxConstraints(maxHeight: 420) : const BoxConstraints(),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: isPhone ? const Border(top: BorderSide(color: AppColors.divider)) : const Border(left: BorderSide(color: AppColors.divider)),
        boxShadow: isPhone ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -3))] : null,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _sectionLabel('DATA PELANGGAN'),
          Row(children: [
            Expanded(child: _inputField(controller: _namaController, label: 'Nama Pelanggan *', icon: Icons.person_outline)),
            const SizedBox(width: 8),
            Expanded(child: _inputField(
              controller: _noHpController, label: 'No. HP (+62)', icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
              onEditingComplete: () {
                final fmt = _formatPhone(_noHpController.text);
                _noHpController.text = fmt;
                _noHpController.selection = TextSelection.fromPosition(TextPosition(offset: fmt.length));
              },
            )),
          ]),
          const SizedBox(height: 12),

          _sectionLabel('KASIR BERTUGAS'),
          _staffDropdown('Kasir Bertugas *', _selectedKasirId, (v) => setState(() => _selectedKasirId = v)),
          const SizedBox(height: 12),

          _sectionLabel('ITEM DALAM TRANSAKSI (${_cart.length})'),
          if (_cart.isEmpty)
            Center(child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text('Ketuk kartu treatment di atas\nlalu isi detail itemnya',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.openSans(fontSize: 12, color: AppColors.textHint)),
            ))
          else ...[
            ..._cart.asMap().entries.map((e) {
              final item = e.value;
              final idx = e.key + 1;
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border)),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => _showEditItemDialog(item),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      child: Row(children: [
                        Container(
                          width: 22, height: 22,
                          decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(5)),
                          child: Center(child: Text('$idx', style: GoogleFonts.openSans(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary))),
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(item.treatment.namaTreatment,
                              style: GoogleFonts.openSans(fontSize: 12, fontWeight: FontWeight.bold)),
                          Text(
                            '${item.jenisItem}${item.merek.isNotEmpty ? " • ${item.merek}" : ""}${item.warna.isNotEmpty ? " • ${item.warna}" : ""}${item.ukuran.isNotEmpty ? " • Ukuran ${item.ukuran}" : ""}',
                            style: GoogleFonts.openSans(fontSize: 11, color: AppColors.textSecondary),
                          ),
                          if (item.staffNama.isNotEmpty)
                            Row(children: [
                              const Icon(Icons.person_pin_circle_outlined, size: 11, color: AppColors.textHint),
                              const SizedBox(width: 3),
                              Text(item.staffNama,
                                  style: GoogleFonts.openSans(fontSize: 10, color: AppColors.textHint,
                                      fontStyle: FontStyle.italic)),
                            ]),
                        ])),
                        const SizedBox(width: 6),
                        Text('Rp ${item.treatment.hargaJual.toInt()}',
                            style: GoogleFonts.openSans(fontSize: 12, fontWeight: FontWeight.w600)),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => _showEditItemDialog(item),
                          child: const Tooltip(
                            message: 'Edit Item',
                            child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              child: Icon(Icons.edit_outlined, size: 17, color: AppColors.primary),
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => _removeFromCart(item.uid),
                          child: const Tooltip(
                            message: 'Hapus',
                            child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              child: Icon(Icons.close, size: 17, color: AppColors.error),
                            ),
                          ),
                        ),
                      ]),
                    ),
                  ),
                ),
              );
            }),
            const Divider(height: 14, color: AppColors.divider),
            Row(children: [
              Text('TOTAL ${_cart.length} Item', style: GoogleFonts.openSans(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
              const Spacer(),
              Text('Rp ${_total.toInt()}', style: GoogleFonts.openSans(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary)),
            ]),
            const SizedBox(height: 12),
          ],

          _sectionLabel('WAKTU PEMBAYARAN'),
          _toggleRow(['Bayar Sekarang', 'Bayar Saat Selesai'], _statusBayar, (v) => setState(() {
            _statusBayar = v;
            if (v == 'Bayar Saat Selesai') _uangDiterimaController.clear();
          })),
          const SizedBox(height: 16),
          
          if (_statusBayar == 'Bayar Sekarang') ...[
            _sectionLabel('METODE PEMBAYARAN'),
            _toggleRow(['Cash', 'QRIS'], _metodeBayar, (v) => setState(() {
              _metodeBayar = v;
              if (v != 'Cash') _uangDiterimaController.clear();
            })),
            const SizedBox(height: 10),
            if (_metodeBayar == 'Cash') ...[
              _inputField(
                controller: _uangDiterimaController,
                label: 'Nominal Uang (Rp)',
                icon: Icons.money,
                keyboardType: TextInputType.number,
                onChanged: (v) => setState((){}),
              ),
              const SizedBox(height: 8),
              if (_uangDiterimaController.text.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Kembalian', style: GoogleFonts.openSans(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                      Text('Rp ${_hitungKembalian()}', style: GoogleFonts.openSans(fontSize: 14, fontWeight: FontWeight.bold, color: double.parse(_hitungKembalian()) >= 0 ? AppColors.success : AppColors.error)),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
            ]
          ],

          SizedBox(
            width: double.infinity, height: 46,
            child: ElevatedButton(
              onPressed: _isProcessing ? null : _processOrder,
              style: ElevatedButton.styleFrom(
                backgroundColor: _cart.isEmpty ? AppColors.textHint : AppColors.primary,
                elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              child: _isProcessing
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text(
                      _cart.isEmpty ? 'Proses Order' : 'Proses ${_cart.length} Item  •  Rp ${_total.toInt()}',
                      style: GoogleFonts.openSans(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  Widget _sectionLabel(String label) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(label, style: GoogleFonts.openSans(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textHint, letterSpacing: 0.5)));

  Widget _inputField({required TextEditingController controller, required String label, required IconData icon, TextInputType? keyboardType, VoidCallback? onEditingComplete, void Function(String)? onChanged}) {
    return TextFormField(
      controller: controller, keyboardType: keyboardType, onEditingComplete: onEditingComplete, onChanged: onChanged,
      style: GoogleFonts.openSans(fontSize: 12, color: AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.openSans(fontSize: 11, color: AppColors.textHint),
        prefixIcon: Icon(icon, size: 16, color: AppColors.textHint),
        filled: true, fillColor: AppColors.background,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
      ),
    );
  }

  Widget _staffDropdown(String label, String? selectedId, void Function(String?) onChanged) {
    return Container(
      height: 46, padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true, value: selectedId,
          hint: Text(label, style: GoogleFonts.openSans(fontSize: 11, color: AppColors.textHint), overflow: TextOverflow.ellipsis),
          items: [
            DropdownMenuItem<String>(value: null, child: Text('— Kosong —', style: GoogleFonts.openSans(fontSize: 12, color: AppColors.textHint))),
            ..._staffList.map((s) => DropdownMenuItem<String>(
              value: s['id_staff']?.toString(),
              child: Text(s['nama_lengkap']?.toString() ?? '-', style: GoogleFonts.openSans(fontSize: 12), overflow: TextOverflow.ellipsis),
            )),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _toggleRow(List<String> opts, String selected, void Function(String) onSelect) {
    return Row(children: opts.asMap().entries.map((e) {
      final isSelected = e.value == selected;
      return Expanded(
        child: GestureDetector(
          onTap: () => onSelect(e.value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin: EdgeInsets.only(right: e.key < opts.length - 1 ? 6 : 0),
            padding: const EdgeInsets.symmetric(vertical: 9),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primary : AppColors.background,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isSelected ? AppColors.primary : AppColors.border),
            ),
            child: Text(e.value, textAlign: TextAlign.center,
                style: GoogleFonts.openSans(fontSize: 11, fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : AppColors.textSecondary)),
          ),
        ),
      );
    }).toList());
  }

  @override
  void dispose() {
    _namaController.dispose();
    _noHpController.dispose();
    super.dispose();
  }

}
