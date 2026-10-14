import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/treatment_service.dart';
import '../../services/inventory_service.dart';
import '../../models/treatment_model.dart';
import '../../models/inventory_model.dart';
import '../../utils/app_theme.dart';
import 'add_treatment_screen.dart';

class TreatmentScreen extends StatefulWidget {
  const TreatmentScreen({Key? key}) : super(key: key);

  @override
  State<TreatmentScreen> createState() => _TreatmentScreenState();
}

class _TreatmentScreenState extends State<TreatmentScreen> {
  final TreatmentService _treatmentService = TreatmentService();
  final InventoryService _inventoryService = InventoryService();
  List<Treatment> _treatments = [];
  List<InventoryItem> _inventory = [];
  bool _isLoading = true;

  @override
  void initState() { super.initState(); _loadData(); }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final results = await Future.wait([_treatmentService.getTreatments(), _inventoryService.getInventory()]);
    setState(() {
      _treatments = results[0] as List<Treatment>;
      _inventory = results[1] as List<InventoryItem>;
      _isLoading = false;
    });
  }

  Map<String, dynamic> _calc(Treatment t) {
    double bahanCost = 0;
    double maxStok = double.infinity;
    for (var b in t.bahanBaku) {
      try {
        final inv = _inventory.firstWhere((i) => i.namaItem.toLowerCase() == b.namaItem.toLowerCase());
        bahanCost += inv.hargaSatuan * b.qty;
        if (b.qty > 0) { final ps = inv.stok / b.qty; if (ps < maxStok) maxStok = ps; }
      } catch (_) {}
    }
    if (maxStok == double.infinity) maxStok = 0;
    final fee = t.tipeFee == 'Persentase' ? (t.nilaiFee / 100) * t.hargaJual : t.nilaiFee;
    final hpp = bahanCost + fee;
    final profit = t.hargaJual - hpp;
    return {
      'hpp': hpp, 'profit': profit,
      'profitPersen': t.hargaJual > 0 ? (profit / t.hargaJual) * 100 : 0.0,
      'stokMaksimal': maxStok.floor(),
      'bahanCost': bahanCost,
      'feeKaryawan': fee,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: appBarStandard(context, 'Kelola Treatment', actions: [
        IconButton(icon: const Icon(Icons.refresh, size: 18, color: AppColors.textSecondary), onPressed: _loadData),
      ]),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
          : _treatments.isEmpty
              ? _emptyState()
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  itemCount: _treatments.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (context, index) {
                    final t = _treatments[index];
                    final c = _calc(t);
                    final profit = c['profit'] as double;
                    return Card(
                      elevation: 0, color: AppColors.surface,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: const BorderSide(color: AppColors.border)),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => _showDetail(t, c),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          child: Row(children: [
                            Expanded(child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(t.namaTreatment, style: GoogleFonts.openSans(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                                const SizedBox(height: 3),
                                Text('Jual: Rp ${t.hargaJual.toInt()}  •  HPP: Rp ${(c['hpp'] as double).toInt()}',
                                    style: GoogleFonts.openSans(fontSize: 11, color: AppColors.textSecondary)),
                              ],
                            )),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: (c['stokMaksimal'] as int) > 0 ? const Color(0xFFE6F4EA) : const Color(0xFFFCE8E6),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text('Stok ${c['stokMaksimal']}',
                                      style: GoogleFonts.openSans(fontSize: 10, fontWeight: FontWeight.bold,
                                          color: (c['stokMaksimal'] as int) > 0 ? AppColors.success : AppColors.error)),
                                ),
                                const SizedBox(height: 4),
                                Text(profit >= 0 ? '+Rp ${profit.toInt()}' : '-Rp ${profit.abs().toInt()}',
                                    style: GoogleFonts.openSans(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                              ],
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.chevron_right, size: 16, color: AppColors.textHint),
                          ]),
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary, elevation: 1,
        onPressed: () async {
          final result = await Navigator.push(context, MaterialPageRoute(builder: (_) =>
            AddTreatmentScreen(inventoryList: _inventory.where((i) => i.jenis == 'Bahan Baku').toList())));
          if (result == true) _loadData();
        },
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  void _showDetail(Treatment t, Map<String, dynamic> c) {
    final bahanCost = c['bahanCost'] as double;
    final feeKaryawan = c['feeKaryawan'] as double;
    final hpp = c['hpp'] as double;
    final profit = c['profit'] as double;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.65,
        maxChildSize: 0.95,
        builder: (_, scrollController) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              sheetHandle(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: Text(t.namaTreatment, style: GoogleFonts.openSans(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: (c['stokMaksimal'] as int) > 0 ? const Color(0xFFE6F4EA) : const Color(0xFFFCE8E6),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text('Stok: ${c['stokMaksimal']}',
                        style: GoogleFonts.openSans(fontSize: 11, fontWeight: FontWeight.bold,
                            color: (c['stokMaksimal'] as int) > 0 ? AppColors.success : AppColors.error)),
                  ),
                ],
              ),
              const Divider(height: 20, color: AppColors.divider),

              _detailRow('Harga Jual', 'Rp ${t.hargaJual.toInt()}'),
              _detailRow('HPP Bahan', 'Rp ${bahanCost.toInt()}'),
              _detailRow('Fee Karyawan (${t.tipeFee == "Persentase" ? "${t.nilaiFee.toInt()}%" : "Nominal"})', 'Rp ${feeKaryawan.toInt()}'),
              _detailRow('Total HPP', 'Rp ${hpp.toInt()}'),
              _detailRow('Profit (${(c['profitPersen'] as double).toStringAsFixed(1)}%)', '${profit >= 0 ? "+" : ""}Rp ${profit.toInt()}'),

              const Divider(height: 20, color: AppColors.divider),
              Text('Bahan Baku', style: GoogleFonts.openSans(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
              const SizedBox(height: 8),

              if (t.bahanBaku.isEmpty)
                Text('Tidak ada bahan baku.', style: GoogleFonts.openSans(fontSize: 12, color: AppColors.textHint))
              else
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    children: t.bahanBaku.map((b) {
                      try {
                        final inv = _inventory.firstWhere((i) => i.namaItem.toLowerCase() == b.namaItem.toLowerCase());
                        final hppBahan = inv.hargaSatuan * b.qty;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          child: Row(children: [
                            Expanded(child: Text(inv.namaItem, style: GoogleFonts.openSans(fontSize: 12, color: AppColors.textPrimary))),
                            Text('${b.qty.toInt()} ${inv.satuan}', style: GoogleFonts.openSans(fontSize: 12, color: AppColors.textSecondary)),
                            const SizedBox(width: 12),
                            SizedBox(width: 80, child: Text('Rp ${hppBahan.toInt()}', style: GoogleFonts.openSans(fontSize: 12, color: AppColors.textPrimary), textAlign: TextAlign.right)),
                          ]),
                        );
                      } catch (_) {
                        return Text('${b.namaItem} (${b.qty})', style: GoogleFonts.openSans(fontSize: 12, color: AppColors.textHint));
                      }
                    }).toList(),
                  ),
                ),

              const Divider(height: 16, color: AppColors.divider),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.error), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                    onPressed: () { Navigator.pop(ctx); _confirmDelete(t); },
                    child: Text('Hapus', style: GoogleFonts.openSans(fontSize: 13, color: AppColors.error)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                    onPressed: () async {
                      Navigator.pop(ctx);
                      final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => AddTreatmentScreen(
                        inventoryList: _inventory.where((i) => i.jenis == 'Bahan Baku').toList(), initialData: t)));
                      if (result == true) _loadData();
                    },
                    child: Text('Edit', style: GoogleFonts.openSans(fontSize: 13, color: Colors.white)),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.openSans(fontSize: 12, color: AppColors.textSecondary)),
          Text(value, style: GoogleFonts.openSans(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        ],
      ),
    );
  }

  void _confirmDelete(Treatment t) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Hapus Treatment?', style: GoogleFonts.openSans(fontWeight: FontWeight.bold, fontSize: 14)),
        content: Text('Hapus "${t.namaTreatment}" secara permanen?', style: GoogleFonts.openSans(fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Batal', style: GoogleFonts.openSans(color: AppColors.textSecondary))),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() => _isLoading = true);
              final ok = await _treatmentService.deleteTreatment(t.idTreatment);
              if (ok) _loadData(); else setState(() => _isLoading = false);
            },
            child: Text('Hapus', style: GoogleFonts.openSans(color: AppColors.error, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
    Icon(Icons.local_offer_outlined, size: 40, color: AppColors.textHint), const SizedBox(height: 8),
    Text('Belum ada treatment', style: GoogleFonts.openSans(fontSize: 13, color: AppColors.textHint)),
  ]));
}
