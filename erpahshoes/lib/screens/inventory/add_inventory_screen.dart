import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/inventory_service.dart';
import '../../services/supplier_service.dart';
import '../../models/inventory_model.dart';
import '../../models/supplier_model.dart';
import '../../utils/app_theme.dart';

class AddInventoryScreen extends StatefulWidget {
  final InventoryItem? initialData;
  const AddInventoryScreen({Key? key, this.initialData}) : super(key: key);

  @override
  State<AddInventoryScreen> createState() => _AddInventoryScreenState();
}

class _AddInventoryScreenState extends State<AddInventoryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _inventoryService = InventoryService();
  final _supplierService = SupplierService();
  final _namaController = TextEditingController();
  final _hargaTotalController = TextEditingController();
  final _stokController = TextEditingController();
  final _merkController = TextEditingController();

  String _satuanPembelian = 'Liter';
  bool _isLoading = false;
  bool _isEdit = false;
  String _idItem = '';
  
  List<Supplier> _suppliers = [];
  String? _selectedSupplierId;

  @override
  void initState() {
    super.initState();
    _loadSuppliers();
    if (widget.initialData != null) {
      _isEdit = true;
      final d = widget.initialData!;
      _idItem = d.idItem;
      _namaController.text = d.namaItem;
      _merkController.text = d.merk;
      _selectedSupplierId = d.idSuplier.isNotEmpty ? d.idSuplier : null;
      _satuanPembelian = d.satuan;
      if (!['Liter', 'Kg', 'Pcs', 'ml', 'gram'].contains(_satuanPembelian)) _satuanPembelian = 'Pcs';
      _stokController.text = d.stok.toInt().toString();
      _hargaTotalController.text = (d.hargaSatuan * d.stok).toInt().toString();
    }
  }

  Future<void> _loadSuppliers() async {
    final data = await _supplierService.getSuppliers();
    if (mounted) setState(() {
      _suppliers = data;
      if (_selectedSupplierId != null && !_suppliers.any((s) => s.idSuplier == _selectedSupplierId)) {
        _selectedSupplierId = null;
      }
    });
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final idItem = _isEdit ? _idItem : 'INV${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
    double inputStok = double.parse(_stokController.text.trim());
    double inputHargaTotal = double.parse(_hargaTotalController.text.trim());
    String satuanDb = _satuanPembelian;
    double stokDb = inputStok;

    if (_satuanPembelian == 'Liter') { satuanDb = 'ml'; stokDb = inputStok * 1000; }
    else if (_satuanPembelian == 'Kg') { satuanDb = 'gram'; stokDb = inputStok * 1000; }

    double hargaSatuanDb = stokDb > 0 ? (inputHargaTotal / stokDb) : 0;
    final data = {
      'id_item': idItem, 'nama_item': _namaController.text.trim(),
      'jenis': 'Bahan Baku', 'satuan': satuanDb,
      'harga_satuan': hargaSatuanDb.toStringAsFixed(2), 'stok': stokDb.toString(),
      'merk': _merkController.text.trim(),
      'id_suplier': _selectedSupplierId ?? '',
    };

    final ok = _isEdit ? await _inventoryService.updateInventory(data) : await _inventoryService.addInventory(data);
    setState(() => _isLoading = false);
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_isEdit ? 'Berhasil diupdate!' : 'Berhasil ditambahkan!'), backgroundColor: AppColors.success));
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_isEdit ? 'Gagal update.' : 'Gagal menambahkan.'), backgroundColor: AppColors.error));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: appBarStandard(context, _isEdit ? 'Edit Bahan Baku' : 'Tambah Bahan Baku'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Liter atau Kg akan otomatis dikonversi ke ml / gram agar perhitungan di Treatment lebih akurat.',
                  style: GoogleFonts.openSans(fontSize: 12, color: AppColors.primary),
                ),
              ),
              AppTextField(controller: _namaController, label: 'Nama Bahan Baku', hint: 'Contoh: Sabun Cuci Cair'),
              AppTextField(controller: _merkController, label: 'Merek (Opsional)', hint: 'Contoh: Rinso', isRequired: false),
              
              const SizedBox(height: 16),
              Text('Suplier (Opsional)', style: GoogleFonts.openSans(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: _selectedSupplierId,
                    hint: Text('Pilih Suplier...', style: GoogleFonts.openSans(fontSize: 13, color: AppColors.textHint)),
                    items: [
                      DropdownMenuItem<String>(
                        value: null,
                        child: Text('Tidak ada / Kosong', style: GoogleFonts.openSans(fontSize: 13, color: AppColors.textSecondary)),
                      ),
                      ..._suppliers.map((s) => DropdownMenuItem(
                        value: s.idSuplier,
                        child: Text(s.namaSuplier, style: GoogleFonts.openSans(fontSize: 13, color: AppColors.textPrimary)),
                      )),
                    ],
                    onChanged: (v) => setState(() => _selectedSupplierId = v),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              AppDropdown(
                label: 'Satuan Pembelian',
                value: _satuanPembelian,
                items: const ['Liter', 'Kg', 'Pcs', 'ml', 'gram'],
                onChanged: (v) => setState(() => _satuanPembelian = v!),
              ),
              AppTextField(controller: _stokController, label: 'Jumlah / Volume', hint: 'Contoh: 1 (jika beli 1 Liter)', isNumber: true),
              AppTextField(controller: _hargaTotalController, label: 'Total Harga Pembelian (Rp)', hint: 'Contoh: 15000', isNumber: true),
              const SizedBox(height: 24),
              AppPrimaryButton(label: _isEdit ? 'Update Bahan' : 'Simpan Bahan', isLoading: _isLoading, onPressed: _submit),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() { _namaController.dispose(); _merkController.dispose(); _hargaTotalController.dispose(); _stokController.dispose(); super.dispose(); }
}
