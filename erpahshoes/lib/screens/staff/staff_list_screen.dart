import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/staff_service.dart';
import '../../utils/app_theme.dart';
import 'add_staff_screen.dart';

class StaffListScreen extends StatefulWidget {
  const StaffListScreen({Key? key}) : super(key: key);

  @override
  State<StaffListScreen> createState() => _StaffListScreenState();
}

class _StaffListScreenState extends State<StaffListScreen> {
  final StaffService _staffService = StaffService();
  List<Map<String, dynamic>> _staffList = [];
  List<Map<String, dynamic>> _filtered = [];
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStaff();
    _searchController.addListener(_onSearch);
  }

  void _onSearch() {
    final q = _searchController.text.toLowerCase();
    setState(() {
      _filtered = _staffList.where((s) =>
        (s['nama_lengkap'] ?? '').toString().toLowerCase().contains(q) ||
        (s['jobdesk'] ?? '').toString().toLowerCase().contains(q) ||
        (s['role'] ?? '').toString().toLowerCase().contains(q)).toList();
    });
  }

  Future<void> _loadStaff() async {
    setState(() => _isLoading = true);
    final data = await _staffService.getStaffList();
    setState(() { _staffList = data; _filtered = data; _isLoading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: appBarStandard(context, 'App Staff', actions: [
        IconButton(icon: const Icon(Icons.refresh, size: 18), onPressed: _loadStaff, color: AppColors.textSecondary),
      ]),
      body: Column(
        children: [
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: SizedBox(
              height: 36,
              child: TextField(
                controller: _searchController,
                style: GoogleFonts.openSans(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Cari nama atau jabatan...',
                  hintStyle: GoogleFonts.openSans(fontSize: 12, color: AppColors.textHint),
                  prefixIcon: const Icon(Icons.search, size: 16, color: AppColors.textHint),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.primary)),
                ),
              ),
            ),
          ),
          const Divider(height: 1, color: AppColors.divider),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
                : _filtered.isEmpty
                    ? _emptyState('Belum ada data staff')
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                        itemCount: _filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 6),
                        itemBuilder: (context, index) {
                          final staff = _filtered[index];
                          return _StaffTile(
                            staff: staff,
                            onTap: () => _showDetail(staff),
                            onEdit: () async {
                              final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => AddStaffScreen(initialData: staff)));
                              if (result == true) _loadStaff();
                            },
                            onDelete: () => _confirmDelete(staff),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => const AddStaffScreen()));
          if (result == true) _loadStaff();
        },
        backgroundColor: AppColors.primary,
        elevation: 1,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  void _confirmDelete(Map<String, dynamic> staff) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Hapus Karyawan?', style: GoogleFonts.openSans(fontWeight: FontWeight.bold, fontSize: 14)),
        content: Text('Hapus ${staff['nama_lengkap']}? Akun loginnya juga terhapus.',
            style: GoogleFonts.openSans(fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context),
              child: Text('Batal', style: GoogleFonts.openSans(color: AppColors.textSecondary))),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              setState(() => _isLoading = true);
              final ok = await _staffService.deleteStaff(staff['id_user'].toString(), staff['id_staff'].toString());
              if (ok) _loadStaff();
              else { setState(() => _isLoading = false); if (!mounted) return; ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gagal menghapus'))); }
            },
            child: Text('Hapus', style: GoogleFonts.openSans(color: AppColors.error, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showDetail(Map<String, dynamic> staff) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(left: 20, right: 20, top: 16, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            sheetHandle(),
            Text(staff['nama_lengkap'] ?? '-', style: GoogleFonts.openSans(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            Text('${staff['jobdesk'] ?? '-'} • ${staff['role'] ?? '-'}',
                style: GoogleFonts.openSans(fontSize: 12, color: AppColors.textSecondary)),
            const Divider(height: 20, color: AppColors.divider),
            AppDetailRow('ID Staff', staff['id_staff'] ?? '-'),
            AppDetailRow('Username', staff['username'] ?? '-'),
            AppDetailRow('Status', staff['status_kerja'] ?? '-'),
            AppDetailRow('Tgl Masuk', staff['tanggal_masuk'] ?? '-'),
            AppDetailRow('Masa Kerja', staff['masa_kerja'] ?? '-'),
            AppDetailRow('Alamat', staff['alamat'] ?? '-'),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.error), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                    onPressed: () { Navigator.pop(context); _confirmDelete(staff); },
                    child: Text('Hapus', style: GoogleFonts.openSans(fontSize: 13, color: AppColors.error)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                    onPressed: () async {
                      Navigator.pop(context);
                      final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => AddStaffScreen(initialData: staff)));
                      if (result == true) _loadStaff();
                    },
                    child: Text('Edit', style: GoogleFonts.openSans(fontSize: 13, color: Colors.white)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState(String msg) => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
    Icon(Icons.people_outline, size: 40, color: AppColors.textHint), const SizedBox(height: 8),
    Text(msg, style: GoogleFonts.openSans(fontSize: 13, color: AppColors.textHint)),
  ]));

  @override
  void dispose() { _searchController.dispose(); super.dispose(); }
}

class _StaffTile extends StatelessWidget {
  final Map<String, dynamic> staff;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _StaffTile({required this.staff, required this.onTap, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final initial = (staff['nama_lengkap'] ?? 'S').toString().substring(0, 1).toUpperCase();
    return Card(
      elevation: 0,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: const BorderSide(color: AppColors.border)),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              CircleAvatar(
                radius: 16, backgroundColor: AppColors.primaryLight,
                child: Text(initial, style: GoogleFonts.openSans(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(staff['nama_lengkap'] ?? '-',
                        style: GoogleFonts.openSans(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                    Text('${staff['jobdesk'] ?? '-'} • ${staff['role'] ?? '-'}',
                        style: GoogleFonts.openSans(fontSize: 11, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              Text(staff['status_kerja'] ?? '',
                  style: GoogleFonts.openSans(fontSize: 11, color: AppColors.textHint)),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 16, color: AppColors.textHint),
                padding: EdgeInsets.zero,
                onSelected: (v) { if (v == 'edit') onEdit(); else if (v == 'delete') onDelete(); },
                itemBuilder: (_) => [
                  PopupMenuItem(value: 'edit', child: Text('Edit', style: GoogleFonts.openSans(fontSize: 13))),
                  PopupMenuItem(value: 'delete', child: Text('Hapus', style: GoogleFonts.openSans(fontSize: 13, color: AppColors.error))),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
