import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/treatment_service.dart';
import '../../models/inventory_model.dart';
import '../../models/treatment_model.dart';
import '../../utils/app_theme.dart';

class AddTreatmentScreen extends StatefulWidget {
  final List<InventoryItem> inventoryList;
  final Treatment? initialData;

  const AddTreatmentScreen({Key? key, required this.inventoryList, this.initialData}) : super(key: key);

  @override
  State<AddTreatmentScreen> createState() => _AddTreatmentScreenState();
}

class _AddTreatmentScreenState extends State<AddTreatmentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _treatmentService = TreatmentService();
  final _namaController = TextEditingController();
  final _hargaJualController = TextEditingController();
  final _nilaiFeeController = TextEditingController();

  String _tipeFee = 'Persentase';
  bool _isLoading = false;
  bool _isEdit = false;
  String _idTreatment = '';
  List<TreatmentIngredient> _selectedIngredients = [];

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      _isEdit = true;
      final d = widget.initialData!;
      _idTreatment = d.idTreatment;
      _namaController.text = d.namaTreatment;
      _hargaJualController.text = d.hargaJual.toInt().toString();
      _tipeFee = d.tipeFee;
      _nilaiFeeController.text = d.nilaiFee.toInt().toString();
      _selectedIngredients = List.from(d.bahanBaku);
    }
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final idTreatment = _isEdit ? _idTreatment : 'TRM${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
    
    final List<String> bahanTextList = [];
    for (int i = 0; i < _selectedIngredients.length; i++) {
      final ing = _selectedIngredients[i];
      bahanTextList.add('${i + 1}. ${ing.namaItem} ${ing.qty}');
    }
    final bahanBakuStr = bahanTextList.join('\n');

    final data = {
      'id_treatment': idTreatment, 'nama_treatment': _namaController.text.trim(),
      'harga_jual': _hargaJualController.text.trim(), 'tipe_fee': _tipeFee,
      'nilai_fee': _nilaiFeeController.text.trim(), 'bahan_baku': bahanBakuStr,
    };

    final ok = _isEdit ? await _treatmentService.updateTreatment(data) : await _treatmentService.addTreatment(data);
    setState(() => _isLoading = false);
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_isEdit ? 'Treatment diupdate!' : 'Treatment ditambahkan!'), backgroundColor: AppColors.success));
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_isEdit ? 'Gagal update.' : 'Gagal menambahkan.'), backgroundColor: AppColors.error));
    }
  }

  void _addIngredientModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: MediaQuery.of(ctx).viewInsets.bottom + 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            sheetHandle(),
            Text('Pilih Bahan Baku', style: GoogleFonts.openSans(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            const SizedBox(height: 12),
            if (widget.inventoryList.isEmpty)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text('Belum ada bahan baku di Inventory.', style: GoogleFonts.openSans(fontSize: 13, color: AppColors.textSecondary)),
              )
            else
              SizedBox(
                height: 280,
                child: ListView.separated(
                  itemCount: widget.inventoryList.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.divider),
                  itemBuilder: (ctx, index) {
                    final item = widget.inventoryList[index];
                    final isSelected = _selectedIngredients.any((e) => e.namaItem.toLowerCase() == item.namaItem.toLowerCase());
                    return InkWell(
                      onTap: isSelected ? null : () {
                        Navigator.pop(ctx);
                        _inputQtyModal(item);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.namaItem, style: GoogleFonts.openSans(fontSize: 13, fontWeight: FontWeight.w600,
                                      color: isSelected ? AppColors.textHint : AppColors.textPrimary)),
                                  Text('Rp ${item.hargaSatuan.toStringAsFixed(2)} / ${item.satuan}',
                                      style: GoogleFonts.openSans(fontSize: 11, color: AppColors.textSecondary)),
                                ],
                              ),
                            ),
                            if (isSelected)
                              Text('Terpilih', style: GoogleFonts.openSans(fontSize: 11, color: AppColors.primary))
                            else
                              const Icon(Icons.add, size: 18, color: AppColors.primary),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _inputQtyModal(InventoryItem item) {
    final qtyController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Takaran ${item.namaItem}', style: GoogleFonts.openSans(fontSize: 14, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: qtyController,
          keyboardType: TextInputType.number,
          autofocus: true,
          style: GoogleFonts.openSans(fontSize: 13),
          decoration: InputDecoration(
            labelText: 'Jumlah digunakan',
            labelStyle: GoogleFonts.openSans(fontSize: 12, color: AppColors.textSecondary),
            suffixText: item.satuan,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx),
              child: Text('Batal', style: GoogleFonts.openSans(color: AppColors.textSecondary))),
          TextButton(
            onPressed: () {
              final qty = double.tryParse(qtyController.text) ?? 0;
              if (qty > 0) {
                setState(() => _selectedIngredients.add(TreatmentIngredient(namaItem: item.namaItem, qty: qty)));
                Navigator.pop(ctx);
              }
            },
            child: Text('Simpan', style: GoogleFonts.openSans(color: AppColors.primary, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: appBarStandard(context, _isEdit ? 'Edit Treatment' : 'Tambah Treatment'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AppSectionTitle('INFORMASI DASAR'),
              AppTextField(controller: _namaController, label: 'Nama Treatment', hint: 'Contoh: Cuci Reguler'),
              AppTextField(controller: _hargaJualController, label: 'Harga Jual (Rp)', isNumber: true),

              const AppSectionTitle('FEE KARYAWAN'),
              AppDropdown(label: 'Tipe Fee', value: _tipeFee, items: const ['Persentase', 'Nominal'],
                onChanged: (v) => setState(() => _tipeFee = v!)),
              AppTextField(
                controller: _nilaiFeeController,
                label: 'Nilai Fee',
                hint: _tipeFee == 'Persentase' ? 'Contoh: 10 (untuk 10%)' : 'Contoh: 5000 (Rp5.000)',
                isNumber: true,
              ),

              const AppSectionTitle('RESEP / BAHAN BAKU'),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_selectedIngredients.isEmpty)
                    Text('Belum ada bahan dipilih', style: GoogleFonts.openSans(fontSize: 12, color: AppColors.textHint))
                  else
                    Text('${_selectedIngredients.length} bahan dipilih', style: GoogleFonts.openSans(fontSize: 12, color: AppColors.textSecondary)),
                  TextButton(
                    onPressed: _addIngredientModal,
                    child: Text('+ Tambah Bahan', style: GoogleFonts.openSans(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary)),
                  ),
                ],
              ),

              if (_selectedIngredients.isNotEmpty)
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _selectedIngredients.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.divider),
                    itemBuilder: (context, index) {
                      final ing = _selectedIngredients[index];
                      try {
                        final invItem = widget.inventoryList.firstWhere((i) => i.namaItem.toLowerCase() == ing.namaItem.toLowerCase());
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                          child: Row(children: [
                            Expanded(child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(invItem.namaItem, style: GoogleFonts.openSans(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
                                Text('${ing.qty} ${invItem.satuan}  •  Rp ${(invItem.hargaSatuan * ing.qty).toInt()}',
                                    style: GoogleFonts.openSans(fontSize: 11, color: AppColors.textSecondary)),
                              ],
                            )),
                            InkWell(
                              onTap: () => setState(() => _selectedIngredients.removeAt(index)),
                              child: const Padding(padding: EdgeInsets.all(4), child: Icon(Icons.close, size: 16, color: AppColors.textHint)),
                            ),
                          ]),
                        );
                      } catch (_) {
                        return ListTile(
                          title: Text(ing.namaItem, style: GoogleFonts.openSans(fontSize: 13, fontWeight: FontWeight.w500)),
                          subtitle: Text('Qty: ${ing.qty}', style: GoogleFonts.openSans(fontSize: 11)),
                          trailing: IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            icon: const Icon(Icons.close, size: 16, color: AppColors.textHint),
                            onPressed: () => setState(() => _selectedIngredients.removeAt(index)),
                          ),
                        );
                      }
                    },
                  ),
                ),

              const SizedBox(height: 24),
              AppPrimaryButton(
                label: _isEdit ? 'Update Treatment' : 'Simpan Treatment',
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
  void dispose() { _namaController.dispose(); _hargaJualController.dispose(); _nilaiFeeController.dispose(); super.dispose(); }
}
