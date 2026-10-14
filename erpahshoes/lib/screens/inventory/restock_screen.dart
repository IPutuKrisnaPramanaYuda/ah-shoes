import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/inventory_service.dart';
import '../../services/supplier_service.dart';
import '../../models/inventory_model.dart';
import '../../models/supplier_model.dart';
import '../../utils/app_theme.dart';

class RestockScreen extends StatefulWidget {
  final List<InventoryItem> bahanBakuList;
  final List<Supplier> suppliers;

  const RestockScreen({
    Key? key,
    required this.bahanBakuList,
    required this.suppliers,
  }) : super(key: key);

  @override
  State<RestockScreen> createState() => _RestockScreenState();
}

class _RestockScreenState extends State<RestockScreen> {
  final _inventoryService = InventoryService();
  final _supplierService = SupplierService();

  // Step 1: pilih item
  InventoryItem? _selectedItem;

  // Form controllers
  final _namaController = TextEditingController();
  final _merkController = TextEditingController();
  final _jumlahBeliController = TextEditingController();
  final _hargaTotalController = TextEditingController();

  String _satuanPembelian = 'Liter'; // satuan tampilan (Liter, Kg, Pcs, ml, gram)
  String? _selectedSupplierId;
  List<Supplier> _suppliers = [];

  bool _isLoading = false;

  // Satuan DB dari item yang dipilih
  String get _satuanDb => _selectedItem?.satuan ?? 'ml';

  // Konversi jumlah beli ke satuan DB
  double get _stokTambahan {
    final raw = double.tryParse(_jumlahBeliController.text.trim()) ?? 0;
    if (_satuanPembelian == 'Liter') return raw * 1000;
    if (_satuanPembelian == 'Kg') return raw * 1000;
    return raw;
  }

  double get _stokLama => _selectedItem?.stok ?? 0;
  double get _stokAkhir => _stokLama + _stokTambahan;

  // Harga satuan baru berdasarkan pembelian ini
  double get _hargaSatuanBaru {
    final hargaTotal = double.tryParse(_hargaTotalController.text.trim()) ?? 0;
    if (_stokTambahan <= 0) return _selectedItem?.hargaSatuan ?? 0;
    return hargaTotal / _stokTambahan;
  }

  @override
  void initState() {
    super.initState();
    _suppliers = widget.suppliers;
    _jumlahBeliController.addListener(() => setState(() {}));
    _hargaTotalController.addListener(() => setState(() {}));
    _loadSuppliers();
  }

  Future<void> _loadSuppliers() async {
    final data = await _supplierService.getSuppliers();
    if (mounted) setState(() => _suppliers = data);
  }

  void _selectItem(InventoryItem item) {
    setState(() {
      _selectedItem = item;
      _namaController.text = item.namaItem;
      _merkController.text = item.merk;
      _selectedSupplierId = item.idSuplier.isNotEmpty ? item.idSuplier : null;

      // Sesuaikan satuan pembelian berdasarkan satuan DB
      if (item.satuan == 'ml') {
        _satuanPembelian = 'Liter';
      } else if (item.satuan == 'gram') {
        _satuanPembelian = 'Kg';
      } else {
        _satuanPembelian = item.satuan;
      }

      _jumlahBeliController.clear();
      _hargaTotalController.clear();
    });
  }

  String _formatSatuan(String satuanDb) {
    if (satuanDb == 'ml') return 'Liter (disimpan sbg ml)';
    if (satuanDb == 'gram') return 'Kg (disimpan sbg gram)';
    return satuanDb;
  }

  void _submit() async {
    if (_selectedItem == null) return;
    if (_jumlahBeliController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Masukkan jumlah yang dibeli'), backgroundColor: AppColors.error),
      );
      return;
    }
    if (_stokTambahan <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Jumlah harus lebih dari 0'), backgroundColor: AppColors.error),
      );
      return;
    }

    setState(() => _isLoading = true);

    final ok = await _inventoryService.restockInventory(
      idItem: _selectedItem!.idItem,
      namaItem: _namaController.text.trim(),
      jenis: _selectedItem!.jenis,
      satuan: _satuanDb,
      hargaSatuan: _hargaSatuanBaru > 0 ? _hargaSatuanBaru : _selectedItem!.hargaSatuan,
      stokLama: _stokLama,
      stokTambahan: _stokTambahan,
      merk: _merkController.text.trim(),
      idSuplier: _selectedSupplierId ?? '',
    );

    setState(() => _isLoading = false);
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Restok berhasil! Stok akhir: ${_stokAkhir.toInt()} $_satuanDb'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal menyimpan restok'), backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: appBarStandard(context, 'Restok Bahan Baku'),
      body: _selectedItem == null
          ? _buildItemPicker()
          : _buildRestockForm(),
      bottomNavigationBar: _selectedItem != null
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: AppPrimaryButton(
                  label: 'Simpan Restok',
                  isLoading: _isLoading,
                  onPressed: _submit,
                ),
              ),
            )
          : null,
    );
  }

  // ─── Step 1: Pilih Bahan Baku ───
  Widget _buildItemPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          color: AppColors.primaryLight,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              const Icon(Icons.info_outline, size: 16, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Pilih bahan baku yang ingin direstok',
                  style: GoogleFonts.openSans(fontSize: 12, color: AppColors.primary),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: AppColors.divider),
        Expanded(
          child: widget.bahanBakuList.isEmpty
              ? Center(
                  child: Text('Tidak ada bahan baku', style: GoogleFonts.openSans(color: AppColors.textHint)),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: widget.bahanBakuList.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 4),
                  itemBuilder: (context, index) {
                    final item = widget.bahanBakuList[index];
                    return Card(
                      elevation: 0,
                      color: AppColors.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: const BorderSide(color: AppColors.border),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => _selectItem(item),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(item.namaItem,
                                        style: GoogleFonts.openSans(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.textPrimary)),
                                    if (item.merk.isNotEmpty)
                                      Text(item.merk,
                                          style: GoogleFonts.openSans(
                                              fontSize: 11, color: AppColors.textSecondary)),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '${item.stok.toInt()} ${item.satuan}',
                                    style: GoogleFonts.openSans(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: item.stok <= 0 ? AppColors.error : AppColors.primary),
                                  ),
                                  Text('stok saat ini',
                                      style: GoogleFonts.openSans(
                                          fontSize: 10, color: AppColors.textHint)),
                                ],
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.chevron_right, size: 18, color: AppColors.textHint),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // ─── Step 2: Form Restok ───
  Widget _buildRestockForm() {
    final item = _selectedItem!;
    final stokTambahan = _stokTambahan;
    final stokAkhir = _stokAkhir;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Item terpilih — banner
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.primary.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.inventory_2, size: 18, color: AppColors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Item Dipilih:', style: GoogleFonts.openSans(fontSize: 11, color: AppColors.primary)),
                      Text(item.namaItem,
                          style: GoogleFonts.openSans(
                              fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary)),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() {
                    _selectedItem = null;
                    _jumlahBeliController.clear();
                    _hargaTotalController.clear();
                  }),
                  child: Text('Ganti', style: GoogleFonts.openSans(fontSize: 12, color: AppColors.primary)),
                ),
              ],
            ),
          ),

          // Stok Summary Card
          Container(
            padding: const EdgeInsets.all(14),
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                _stokCell('Stok Lama', '${_stokLama.toInt()}', AppColors.textSecondary),
                _dividerV(),
                _stokCell('+ Dibeli', '${stokTambahan.toInt()}', AppColors.primary),
                _dividerV(),
                _stokCell('= Stok Akhir', '${stokAkhir.toInt()}',
                    stokAkhir > _stokLama ? AppColors.success : AppColors.textPrimary,
                    bold: true),
              ],
            ),
          ),

          const AppSectionTitle('DETAIL PEMBELIAN'),

          AppTextField(
            controller: _jumlahBeliController,
            label: 'Jumlah Dibeli (${_satuanPembelian})',
            hint: 'Contoh: 2 (artinya 2 ${_satuanPembelian})',
            isNumber: true,
          ),

          AppTextField(
            controller: _hargaTotalController,
            label: 'Total Harga Pembelian Ini (Rp) — Opsional',
            hint: 'Isi jika harga berubah dari sebelumnya',
            isNumber: true,
            isRequired: false,
          ),

          // Harga satuan baru (preview)
          if (_hargaTotalController.text.isNotEmpty && _stokTambahan > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '💡 Harga satuan baru: Rp ${_hargaSatuanBaru.toStringAsFixed(2)} / ${_satuanDb}',
                style: GoogleFonts.openSans(fontSize: 12, color: AppColors.primary),
              ),
            ),

          const AppSectionTitle('INFO BAHAN BAKU (OPSIONAL)'),

          AppTextField(
            controller: _namaController,
            label: 'Nama Bahan Baku',
            hint: 'Bisa diubah jika ada pembaruan',
          ),

          AppTextField(
            controller: _merkController,
            label: 'Merek',
            hint: 'Bisa diubah jika ada pembaruan',
            isRequired: false,
          ),

          const SizedBox(height: 4),
          Text('Suplier (Opsional)',
              style: GoogleFonts.openSans(
                  fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value: _selectedSupplierId,
                hint: Text('Pilih Suplier...',
                    style: GoogleFonts.openSans(fontSize: 13, color: AppColors.textHint)),
                items: [
                  DropdownMenuItem<String>(
                    value: null,
                    child: Text('Tidak ada / Kosong',
                        style: GoogleFonts.openSans(
                            fontSize: 13, color: AppColors.textSecondary)),
                  ),
                  ..._suppliers.map(
                    (s) => DropdownMenuItem(
                      value: s.idSuplier,
                      child: Text(s.namaSuplier,
                          style: GoogleFonts.openSans(
                              fontSize: 13, color: AppColors.textPrimary)),
                    ),
                  ),
                ],
                onChanged: (v) => setState(() => _selectedSupplierId = v),
              ),
            ),
          ),

          const SizedBox(height: 70), // padding bawah untuk BottomBar
        ],
      ),
    );
  }

  Widget _stokCell(String label, String value, Color color, {bool bold = false}) {
    return Expanded(
      child: Column(
        children: [
          Text(label,
              textAlign: TextAlign.center,
              style: GoogleFonts.openSans(fontSize: 10, color: AppColors.textHint)),
          const SizedBox(height: 4),
          Text(value,
              textAlign: TextAlign.center,
              style: GoogleFonts.openSans(
                  fontSize: 18,
                  fontWeight: bold ? FontWeight.bold : FontWeight.w600,
                  color: color)),
        ],
      ),
    );
  }

  Widget _dividerV() => Container(
        width: 1, height: 40, color: AppColors.border, margin: const EdgeInsets.symmetric(horizontal: 8));

  @override
  void dispose() {
    _namaController.dispose();
    _merkController.dispose();
    _jumlahBeliController.dispose();
    _hargaTotalController.dispose();
    super.dispose();
  }
}
