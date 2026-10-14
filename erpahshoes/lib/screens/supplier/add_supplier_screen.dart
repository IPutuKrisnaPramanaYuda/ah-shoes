import 'package:flutter/material.dart';
import '../../services/supplier_service.dart';
import '../../models/supplier_model.dart';
import '../../utils/app_theme.dart';

class AddSupplierScreen extends StatefulWidget {
  final Supplier? initialData;
  const AddSupplierScreen({Key? key, this.initialData}) : super(key: key);

  @override
  State<AddSupplierScreen> createState() => _AddSupplierScreenState();
}

class _AddSupplierScreenState extends State<AddSupplierScreen> {
  final _formKey = GlobalKey<FormState>();
  final _supplierService = SupplierService();
  final _namaController = TextEditingController();
  final _kontakController = TextEditingController();
  final _alamatController = TextEditingController();

  bool _isLoading = false;
  bool _isEdit = false;
  String _idSuplier = '';

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      _isEdit = true;
      final d = widget.initialData!;
      _idSuplier = d.idSuplier;
      _namaController.text = d.namaSuplier;
      _kontakController.text = d.kontak;
      _alamatController.text = d.alamat;
    }
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final idSuplier = _isEdit ? _idSuplier : 'SUP${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
    
    final data = {
      'id_suplier': idSuplier, 
      'nama_suplier': _namaController.text.trim(),
      'kontak': _kontakController.text.trim(), 
      'alamat': _alamatController.text.trim(),
    };

    final ok = _isEdit ? await _supplierService.updateSupplier(data) : await _supplierService.addSupplier(data);
    setState(() => _isLoading = false);
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_isEdit ? 'Suplier diupdate!' : 'Suplier ditambahkan!'), backgroundColor: AppColors.success));
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_isEdit ? 'Gagal update.' : 'Gagal menambahkan.'), backgroundColor: AppColors.error));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: appBarStandard(context, _isEdit ? 'Edit Suplier' : 'Tambah Suplier'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppTextField(controller: _namaController, label: 'Nama Suplier', hint: 'Contoh: PT. Bintang Jaya'),
              AppTextField(controller: _kontakController, label: 'Kontak (No HP / Telp)', hint: 'Contoh: 08123456789', isNumber: true),
              AppTextField(controller: _alamatController, label: 'Alamat', hint: 'Contoh: Jl. Sudirman No 1'),
              const SizedBox(height: 24),
              AppPrimaryButton(label: _isEdit ? 'Update Suplier' : 'Simpan Suplier', isLoading: _isLoading, onPressed: _submit),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() { 
    _namaController.dispose(); 
    _kontakController.dispose(); 
    _alamatController.dispose(); 
    super.dispose(); 
  }
}
