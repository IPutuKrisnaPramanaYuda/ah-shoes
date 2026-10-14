import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/supplier_service.dart';
import '../../models/supplier_model.dart';
import '../../utils/app_theme.dart';
import 'add_supplier_screen.dart';

class SupplierScreen extends StatefulWidget {
  const SupplierScreen({Key? key}) : super(key: key);

  @override
  State<SupplierScreen> createState() => _SupplierScreenState();
}

class _SupplierScreenState extends State<SupplierScreen> {
  final SupplierService _supplierService = SupplierService();
  List<Supplier> _supplierList = [];
  List<Supplier> _filtered = [];
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSuppliers();
    _searchController.addListener(_onSearch);
  }

  void _onSearch() {
    final q = _searchController.text.toLowerCase();
    setState(() {
      _filtered = _supplierList.where((s) =>
        s.namaSuplier.toLowerCase().contains(q) ||
        s.kontak.toLowerCase().contains(q)).toList();
    });
  }

  Future<void> _loadSuppliers() async {
    setState(() => _isLoading = true);
    final data = await _supplierService.getSuppliers();
    setState(() { _supplierList = data; _filtered = data; _isLoading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: appBarStandard(context, 'Daftar Suplier', actions: [
        IconButton(icon: const Icon(Icons.refresh, size: 18), onPressed: _loadSuppliers, color: AppColors.textSecondary),
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
                  hintText: 'Cari nama atau kontak...',
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
                    ? _emptyState('Belum ada data suplier')
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                        itemCount: _filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 6),
                        itemBuilder: (context, index) {
                          final supplier = _filtered[index];
                          return _SupplierTile(
                            supplier: supplier,
                            onTap: () => _showDetail(supplier),
                            onEdit: () async {
                              final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => AddSupplierScreen(initialData: supplier)));
                              if (result == true) _loadSuppliers();
                            },
                            onDelete: () => _confirmDelete(supplier),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => const AddSupplierScreen()));
          if (result == true) _loadSuppliers();
        },
        backgroundColor: AppColors.primary,
        elevation: 1,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  void _confirmDelete(Supplier supplier) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Hapus Suplier?', style: GoogleFonts.openSans(fontWeight: FontWeight.bold, fontSize: 14)),
        content: Text('Hapus ${supplier.namaSuplier} dari daftar suplier?',
            style: GoogleFonts.openSans(fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context),
              child: Text('Batal', style: GoogleFonts.openSans(color: AppColors.textSecondary))),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              setState(() => _isLoading = true);
              final ok = await _supplierService.deleteSupplier(supplier.idSuplier);
              if (ok) _loadSuppliers();
              else { setState(() => _isLoading = false); if (!mounted) return; ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gagal menghapus'))); }
            },
            child: Text('Hapus', style: GoogleFonts.openSans(color: AppColors.error, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showDetail(Supplier supplier) {
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
            Text(supplier.namaSuplier, style: GoogleFonts.openSans(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            Text('ID: ${supplier.idSuplier}',
                style: GoogleFonts.openSans(fontSize: 12, color: AppColors.textSecondary)),
            const Divider(height: 20, color: AppColors.divider),
            AppDetailRow('Kontak', supplier.kontak),
            AppDetailRow('Alamat', supplier.alamat),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.error), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                    onPressed: () { Navigator.pop(context); _confirmDelete(supplier); },
                    child: Text('Hapus', style: GoogleFonts.openSans(fontSize: 13, color: AppColors.error)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                    onPressed: () async {
                      Navigator.pop(context);
                      final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => AddSupplierScreen(initialData: supplier)));
                      if (result == true) _loadSuppliers();
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
    Icon(Icons.local_shipping_outlined, size: 40, color: AppColors.textHint), const SizedBox(height: 8),
    Text(msg, style: GoogleFonts.openSans(fontSize: 13, color: AppColors.textHint)),
  ]));

  @override
  void dispose() { _searchController.dispose(); super.dispose(); }
}

class _SupplierTile extends StatelessWidget {
  final Supplier supplier;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _SupplierTile({required this.supplier, required this.onTap, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final initial = supplier.namaSuplier.isNotEmpty ? supplier.namaSuplier.substring(0, 1).toUpperCase() : 'S';
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
                    Text(supplier.namaSuplier,
                        style: GoogleFonts.openSans(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                    Text(supplier.kontak,
                        style: GoogleFonts.openSans(fontSize: 11, color: AppColors.textSecondary)),
                  ],
                ),
              ),
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
