import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/staff_service.dart';
import '../../utils/app_theme.dart';

class AddStaffScreen extends StatefulWidget {
  final Map<String, dynamic>? initialData;
  const AddStaffScreen({Key? key, this.initialData}) : super(key: key);

  @override
  State<AddStaffScreen> createState() => _AddStaffScreenState();
}

class _AddStaffScreenState extends State<AddStaffScreen> {
  final _formKey = GlobalKey<FormState>();
  final _staffService = StaffService();

  final _idController = TextEditingController();
  final _namaController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _alamatController = TextEditingController();
  final _tglMasukController = TextEditingController();
  final _jobdeskController = TextEditingController();
  final _masaKerjaController = TextEditingController();

  String _role = 'karyawan';
  String _statusKerja = 'Fulltime';
  bool _isLoading = false;
  bool _isEdit = false;
  String _idUser = '';

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      _isEdit = true;
      final d = widget.initialData!;
      _idController.text = d['id_staff'] ?? '';
      _namaController.text = d['nama_lengkap'] ?? '';
      _usernameController.text = d['username'] ?? '';
      _alamatController.text = d['alamat'] ?? '';
      _tglMasukController.text = d['tanggal_masuk'] ?? '';
      _jobdeskController.text = d['jobdesk'] ?? '';
      _masaKerjaController.text = d['masa_kerja'] ?? '';
      _role = d['role'] ?? 'karyawan';
      _statusKerja = d['status_kerja'] ?? 'Fulltime';
      _idUser = d['id_user'] ?? '';
    }
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final userId = _isEdit ? _idUser : 'USR${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
    final data = {
      'id_user': userId, 'id_staff': _idController.text.trim(),
      'username': _usernameController.text.trim(), 'password': _passwordController.text,
      'role': _role, 'nama_lengkap': _namaController.text.trim(),
      'alamat': _alamatController.text.trim(), 'status_kerja': _statusKerja,
      'tanggal_masuk': _tglMasukController.text.trim(), 'jobdesk': _jobdeskController.text.trim(),
      'masa_kerja': _masaKerjaController.text.trim(),
    };

    final ok = _isEdit ? await _staffService.updateStaff(data) : await _staffService.addStaff(data);
    setState(() => _isLoading = false);

    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_isEdit ? 'Staff berhasil diubah!' : 'Staff berhasil ditambahkan!'),
          backgroundColor: AppColors.success));
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_isEdit ? 'Gagal mengubah staff.' : 'Gagal menambahkan (username mungkin sudah ada).'),
          backgroundColor: AppColors.error));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: appBarStandard(context, _isEdit ? 'Edit Karyawan' : 'Tambah Staff'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AppSectionTitle('INFORMASI PRIBADI'),
              AppTextField(controller: _idController, label: 'ID Staff'),
              AppTextField(controller: _namaController, label: 'Nama Lengkap'),
              AppTextField(controller: _alamatController, label: 'Alamat'),

              const AppSectionTitle('PEKERJAAN'),
              AppDropdown(label: 'Role', value: _role, items: const ['admin', 'kasir', 'karyawan'], onChanged: (v) => setState(() => _role = v!)),
              AppDropdown(label: 'Status Kerja', value: _statusKerja, items: const ['Fulltime', 'Parttime', 'Freelance'], onChanged: (v) => setState(() => _statusKerja = v!)),
              AppTextField(controller: _jobdeskController, label: 'Jobdesk'),
              AppTextField(controller: _tglMasukController, label: 'Tanggal Masuk', hint: 'DD/MM/YYYY'),
              AppTextField(controller: _masaKerjaController, label: 'Masa Kerja', hint: 'Contoh: 1 Tahun'),

              const AppSectionTitle('AKUN LOGIN'),
              AppTextField(controller: _usernameController, label: 'Username', readOnly: _isEdit),
              AppTextField(
                controller: _passwordController,
                label: 'Password',
                isPassword: true,
                hint: _isEdit ? 'Kosongkan jika tidak ingin mengubah' : null,
                isRequired: !_isEdit,
              ),

              const SizedBox(height: 24),
              AppPrimaryButton(
                label: _isEdit ? 'Update Karyawan' : 'Simpan Karyawan',
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
    _idController.dispose(); _namaController.dispose(); _usernameController.dispose();
    _passwordController.dispose(); _alamatController.dispose(); _tglMasukController.dispose();
    _jobdeskController.dispose(); _masaKerjaController.dispose();
    super.dispose();
  }
}
