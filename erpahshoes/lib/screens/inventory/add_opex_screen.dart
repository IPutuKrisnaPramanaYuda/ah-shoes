import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../services/opex_service.dart';
import '../../models/opex_model.dart';
import '../../utils/app_theme.dart';

class AddOpexScreen extends StatefulWidget {
  final CapexItem? initialCapex;
  final OpexItem? initialOpex;
  final String defaultType; // 'OPEX' or 'CAPEX'

  const AddOpexScreen({
    Key? key,
    this.initialCapex,
    this.initialOpex,
    this.defaultType = 'OPEX',
  }) : super(key: key);

  @override
  State<AddOpexScreen> createState() => _AddOpexScreenState();
}

class _AddOpexScreenState extends State<AddOpexScreen> {
  final _formKey = GlobalKey<FormState>();
  final _opexService = OpexService();

  late String _expenseType; // 'OPEX' or 'CAPEX'
  bool _isEdit = false;

  final _namaController = TextEditingController();
  final _hargaController = TextEditingController();
  final _qtyController = TextEditingController(text: '1');
  final _umurController = TextEditingController(text: '12');

  String _kategoriOpex = 'Operasional Toko';
  String _kategoriCapex = 'Peralatan & Mesin';

  static const List<String> _opexCategories = [
    'Operasional Toko',
    'Utilitas (Listrik / Air / WiFi)',
    'Konsumsi & Galon',
    'Packaging & ATK',
    'Kebersihan & Sanitasi',
    'Lain-lain',
  ];

  static const List<String> _capexCategories = [
    'Peralatan & Mesin',
    'Elektronik & Gadget',
    'Renovasi & Tempat',
    'Furnitur & Display',
    'Aset Lainnya',
  ];

  bool _isLoading = false;
  String _itemId = '';

  bool _useCurrentTime = true;
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();

  @override
  void initState() {
    super.initState();
    _expenseType = widget.defaultType;

    if (widget.initialCapex != null) {
      _isEdit = true;
      _expenseType = 'CAPEX';
      final c = widget.initialCapex!;
      _itemId = c.idCapex;
      _namaController.text = c.namaBarang;
      _kategoriCapex = _capexCategories.contains(c.kategori) ? c.kategori : _capexCategories.first;
      _hargaController.text = c.hargaBarang.toInt().toString();
      _umurController.text = c.umurEkonomis.toString();
      _qtyController.text = c.quantity.toString();

      _parseDateTime(c.tanggalMasuk, c.waktuMasuk);
    } else if (widget.initialOpex != null) {
      _isEdit = true;
      _expenseType = 'OPEX';
      final o = widget.initialOpex!;
      _itemId = o.idOpex;
      _namaController.text = o.namaPengeluaran;
      _kategoriOpex = _opexCategories.contains(o.kategori) ? o.kategori : _opexCategories.first;
      _hargaController.text = o.nominal.toInt().toString();
      _qtyController.text = o.quantity.toInt().toString();

      _parseDateTime(o.tanggalMasuk, o.waktuMasuk);
    }
  }

  void _parseDateTime(String tgl, String wkt) {
    if (tgl.isNotEmpty) {
      _useCurrentTime = false;
      try {
        _selectedDate = DateFormat('yyyy-MM-dd').parse(tgl);
      } catch (_) {}
    }
    if (wkt.isNotEmpty) {
      _useCurrentTime = false;
      try {
        final parts = wkt.split(RegExp(r'[:.]'));
        if (parts.length >= 2) {
          _selectedTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
        }
      } catch (_) {}
    }
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    DateTime finalDate = _useCurrentTime ? DateTime.now() : _selectedDate;
    TimeOfDay finalTime = _useCurrentTime ? TimeOfDay.now() : _selectedTime;

    String dateStr = DateFormat('yyyy-MM-dd').format(finalDate);
    String timeStr = '${finalTime.hour.toString().padLeft(2, '0')}.${finalTime.minute.toString().padLeft(2, '0')}';

    bool ok = false;

    if (_expenseType == 'CAPEX') {
      final idCapex = _isEdit ? _itemId : 'CPX${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
      final data = {
        'id_capex': idCapex,
        'nama_barang': _namaController.text.trim(),
        'kategori': _kategoriCapex,
        'harga_barang': _hargaController.text.trim(),
        'umur_ekonomis': _umurController.text.trim(),
        'quantity': _qtyController.text.trim(),
        'tanggal_masuk': dateStr,
        'waktu_masuk': timeStr,
      };
      ok = _isEdit ? await _opexService.updateCapex(data) : await _opexService.addCapex(data);
    } else {
      final idOpex = _isEdit ? _itemId : 'OPX${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
      final data = {
        'id_opex': idOpex,
        'nama_pengeluaran': _namaController.text.trim(),
        'kategori': _kategoriOpex,
        'nominal': _hargaController.text.trim(),
        'quantity': _qtyController.text.trim(),
        'tanggal_masuk': dateStr,
        'waktu_masuk': timeStr,
      };
      ok = _isEdit ? await _opexService.updateOpex(data) : await _opexService.addOpex(data);
    }

    setState(() => _isLoading = false);
    if (!mounted) return;

    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isEdit ? '$_expenseType berhasil diperbarui!' : '$_expenseType berhasil ditambahkan!'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal menyimpan $_expenseType. Silakan periksa koneksi.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      builder: (context, child) => Theme(
        data: ThemeData.light().copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) => Theme(
        data: ThemeData.light().copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  @override
  Widget build(BuildContext context) {
    final isCapex = _expenseType == 'CAPEX';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: appBarStandard(
        context,
        _isEdit ? 'Edit $_expenseType' : 'Tambah Pengeluaran',
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // PILIHAN TIPE PENGELUARAN (CAPEX vs OPEX)
              const AppSectionTitle('JENIS PENGELUARAN'),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: _isEdit ? null : () => setState(() => _expenseType = 'OPEX'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: !isCapex ? AppColors.primary : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.receipt_long_outlined,
                                size: 16,
                                color: !isCapex ? Colors.white : AppColors.textSecondary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'OPEX (Biaya Rutin)',
                                style: GoogleFonts.openSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: !isCapex ? Colors.white : AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: _isEdit ? null : () => setState(() => _expenseType = 'CAPEX'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: isCapex ? AppColors.primary : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.account_balance_wallet_outlined,
                                size: 16,
                                color: isCapex ? Colors.white : AppColors.textSecondary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'CAPEX (Aset Modal)',
                                style: GoogleFonts.openSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: isCapex ? Colors.white : AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isCapex ? const Color(0xFFE8F5E9) : const Color(0xFFE3F2FD),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isCapex ? const Color(0xFFC8E6C9) : const Color(0xFFBBDEFB),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      isCapex ? Icons.info_outline : Icons.lightbulb_outline,
                      size: 18,
                      color: isCapex ? const Color(0xFF2E7D32) : const Color(0xFF1565C0),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isCapex
                            ? 'CAPEX (Capital Expenditure): Pengeluaran aset modal jangka panjang yang memiliki masa pakai & penyusutan (misal: mesin cuci sepatu, dryer, renovasi, etalase).'
                            : 'OPEX (Operational Expenditure): Biaya operasional harian / rutin jangka pendek habis pakai (misal: galon air, deterjen, packaging, listrik toko). Opsi gaji dihitung otomatis via modul Penggajian.',
                        style: GoogleFonts.openSans(
                          fontSize: 11,
                          color: isCapex ? const Color(0xFF1B5E20) : const Color(0xFF0D47A1),
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),
              const AppSectionTitle('INFORMASI WAKTU'),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: CheckboxListTile(
                  title: Text(
                    'Gunakan Waktu Sekarang',
                    style: GoogleFonts.openSans(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  value: _useCurrentTime,
                  activeColor: AppColors.primary,
                  onChanged: (v) => setState(() => _useCurrentTime = v ?? true),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
              if (!_useCurrentTime) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: _pickDate,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                DateFormat('dd MMM yyyy').format(_selectedDate),
                                style: GoogleFonts.openSans(fontSize: 13, color: AppColors.textPrimary),
                              ),
                              const Icon(Icons.calendar_today, size: 16, color: AppColors.primary),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InkWell(
                        onTap: _pickTime,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${_selectedTime.hour.toString().padLeft(2, '0')}.${_selectedTime.minute.toString().padLeft(2, '0')}',
                                style: GoogleFonts.openSans(fontSize: 13, color: AppColors.textPrimary),
                              ),
                              const Icon(Icons.access_time, size: 16, color: AppColors.primary),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 24),
              AppSectionTitle(isCapex ? 'DETAIL ASET (CAPEX)' : 'DETAIL BIAYA (OPEX)'),

              if (isCapex) ...[
                AppDropdown(
                  label: 'Kategori Aset',
                  value: _kategoriCapex,
                  items: _capexCategories,
                  onChanged: (v) => setState(() => _kategoriCapex = v!),
                ),
                AppTextField(
                  controller: _namaController,
                  label: 'Nama Barang / Aset Modal',
                  hint: 'Contoh: Mesin Dryer Sepatu, AC Toko, Meja Kasir...',
                ),
                AppTextField(
                  controller: _hargaController,
                  label: 'Harga Pembelian Satuan (Rp)',
                  isNumber: true,
                ),
                AppTextField(
                  controller: _umurController,
                  label: 'Umur Ekonomis (Bulan)',
                  hint: 'Contoh: 12, 24, 36 bulan (untuk hitung depresiasi)',
                  isNumber: true,
                ),
                AppTextField(
                  controller: _qtyController,
                  label: 'Quantity / Jumlah Unit',
                  isNumber: true,
                ),
              ] else ...[
                AppDropdown(
                  label: 'Kategori Pengeluaran',
                  value: _kategoriOpex,
                  items: _opexCategories,
                  onChanged: (v) => setState(() => _kategoriOpex = v!),
                ),
                AppTextField(
                  controller: _namaController,
                  label: 'Nama Pengeluaran',
                  hint: 'Contoh: Air Galon, Plastik Polymailer, Token Listrik...',
                ),
                AppTextField(
                  controller: _hargaController,
                  label: 'Nominal / Harga Satuan (Rp)',
                  isNumber: true,
                ),
                AppTextField(
                  controller: _qtyController,
                  label: 'Quantity / Jumlah',
                  isNumber: true,
                ),
              ],

              const SizedBox(height: 24),
              AppPrimaryButton(
                label: _isEdit
                    ? 'Update $_expenseType'
                    : (isCapex ? 'Simpan Aset (CAPEX)' : 'Simpan Pengeluaran (OPEX)'),
                isLoading: _isLoading,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _namaController.dispose();
    _hargaController.dispose();
    _umurController.dispose();
    _qtyController.dispose();
    super.dispose();
  }
}
