import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/inventory_service.dart';
import '../../services/opex_service.dart';
import '../../models/inventory_model.dart';
import '../../models/opex_model.dart';
import '../../models/supplier_model.dart';
import '../../services/supplier_service.dart';
import '../../utils/app_theme.dart';
import 'add_inventory_screen.dart';
import 'add_opex_screen.dart';
import 'restock_screen.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({Key? key}) : super(key: key);

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final InventoryService _inventoryService = InventoryService();
  final OpexService _opexService = OpexService();
  final SupplierService _supplierService = SupplierService();

  List<InventoryItem> _bahanBaku = [];
  List<InventoryItem> _filteredBahanBaku = [];
  List<CapexItem> _capex = [];
  List<OpexItem> _opex = [];
  List<Supplier> _suppliers = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() => setState(() {}));
    _searchController.addListener(_onSearch);
    _loadData();
  }

  void _onSearch() {
    final q = _searchController.text.toLowerCase();
    setState(() {
      _filteredBahanBaku = _bahanBaku.where((item) =>
          item.namaItem.toLowerCase().contains(q) ||
          item.merk.toLowerCase().contains(q)).toList();
    });
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final results = await Future.wait([
      _inventoryService.getInventory(),
      _opexService.getCapex(),
      _opexService.getOpex(),
      _supplierService.getSuppliers(),
    ]);
    setState(() {
      _bahanBaku = (results[0] as List<InventoryItem>).where((i) => i.jenis == 'Bahan Baku').toList();
      _filteredBahanBaku = List.from(_bahanBaku);
      _capex = results[1] as List<CapexItem>;
      _opex = results[2] as List<OpexItem>;
      _suppliers = results[3] as List<Supplier>;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        title: Text(
          'Inventory, CAPEX & OPEX',
          style: GoogleFonts.openSans(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.shopping_cart_outlined, size: 20, color: AppColors.primary),
            tooltip: 'Pembelian / Restok',
            onPressed: _showPembelianPicker,
          ),
          IconButton(
            icon: const Icon(Icons.refresh, size: 18, color: AppColors.textSecondary),
            onPressed: _loadData,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(49),
          child: Column(
            children: [
              const Divider(height: 1, color: AppColors.divider),
              TabBar(
                controller: _tabController,
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textHint,
                indicatorColor: AppColors.primary,
                indicatorWeight: 2,
                labelStyle: GoogleFonts.openSans(fontWeight: FontWeight.bold, fontSize: 13),
                unselectedLabelStyle: GoogleFonts.openSans(fontSize: 13),
                tabs: const [
                  Tab(text: 'Bahan Baku'),
                  Tab(text: 'CAPEX (Aset)'),
                  Tab(text: 'OPEX (Rutin)'),
                ],
              ),
            ],
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildBahanBakuList(),
                _buildCapexTab(),
                _buildOpexTab(),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          bool? result;
          if (_tabController.index == 0) {
            result = await Navigator.push(context, MaterialPageRoute(builder: (_) => const AddInventoryScreen()));
          } else if (_tabController.index == 1) {
            result = await Navigator.push(context, MaterialPageRoute(builder: (_) => const AddOpexScreen(defaultType: 'CAPEX')));
          } else {
            result = await Navigator.push(context, MaterialPageRoute(builder: (_) => const AddOpexScreen(defaultType: 'OPEX')));
          }
          if (result == true) _loadData();
        },
        backgroundColor: AppColors.primary,
        elevation: 1,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  void _showPembelianPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            sheetHandle(),
            Text(
              'Pembelian / Pengeluaran',
              style: GoogleFonts.openSans(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 4),
            Text(
              'Pilih jenis pengeluaran atau restok yang ingin dicatat',
              style: GoogleFonts.openSans(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            _pembelianOption(
              ctx: ctx,
              icon: Icons.inventory_2_outlined,
              title: 'Restok Bahan Baku',
              subtitle: 'Tambah stok bahan baku untuk treatment',
              onTap: () async {
                Navigator.pop(ctx);
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RestockScreen(
                      bahanBakuList: _bahanBaku,
                      suppliers: _suppliers,
                    ),
                  ),
                );
                if (result == true) _loadData();
              },
            ),
            const SizedBox(height: 10),
            _pembelianOption(
              ctx: ctx,
              icon: Icons.account_balance_wallet_outlined,
              title: 'Beli Aset Modal (CAPEX)',
              subtitle: 'Mesin, alat kerja, renovasi, inventaris jangka panjang',
              onTap: () async {
                Navigator.pop(ctx);
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AddOpexScreen(defaultType: 'CAPEX')),
                );
                if (result == true) _loadData();
              },
            ),
            const SizedBox(height: 10),
            _pembelianOption(
              ctx: ctx,
              icon: Icons.receipt_long_outlined,
              title: 'Biaya Operasional Rutin (OPEX)',
              subtitle: 'Galon air, utilitas listrik, packaging, konsumsi harian',
              onTap: () async {
                Navigator.pop(ctx);
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AddOpexScreen(defaultType: 'OPEX')),
                );
                if (result == true) _loadData();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _pembelianOption({
    required BuildContext ctx,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 20, color: AppColors.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.openSans(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.openSans(fontSize: 11, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 18, color: AppColors.textHint),
          ],
        ),
      ),
    );
  }

  Widget _buildBahanBakuList() {
    return Column(
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
                hintText: 'Cari bahan baku atau merek...',
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
          child: _filteredBahanBaku.isEmpty
              ? _emptyState('Belum ada bahan baku')
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  itemCount: _filteredBahanBaku.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 4),
                  itemBuilder: (context, index) {
                    final item = _filteredBahanBaku[index];
                    return Card(
                      elevation: 0,
                      color: AppColors.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: const BorderSide(color: AppColors.border),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => _showDetailBahan(item),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.namaItem,
                                      style: GoogleFonts.openSans(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Rp ${item.hargaSatuan.toStringAsFixed(2)} / ${item.satuan}',
                                      style: GoogleFonts.openSans(fontSize: 11, color: AppColors.textSecondary),
                                    ),
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
                                      color: item.stok <= 0 ? AppColors.error : AppColors.textPrimary,
                                    ),
                                  ),
                                  Text('stok', style: GoogleFonts.openSans(fontSize: 10, color: AppColors.textHint)),
                                ],
                              ),
                              PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert, size: 16, color: AppColors.textHint),
                                padding: EdgeInsets.zero,
                                onSelected: (v) async {
                                  if (v == 'edit') {
                                    final r = await Navigator.push(context, MaterialPageRoute(builder: (_) => AddInventoryScreen(initialData: item)));
                                    if (r == true) _loadData();
                                  } else {
                                    _confirmDeleteBahan(item);
                                  }
                                },
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
                  },
                ),
        ),
      ],
    );
  }

  // ==========================================
  // TAB CAPEX (Capital Expenditure / Aset Modal)
  // ==========================================
  Widget _buildCapexTab() {
    double totalDepresiasi = _capex.fold(0, (s, c) => s + c.biayaPerBulan);
    double depresiasiPerHari = totalDepresiasi / 26;
    double totalNilaiAset = _capex.fold(0, (s, c) => s + (c.hargaBarang * c.quantity));

    return Column(
      children: [
        // Summary Bar
        Container(
          color: AppColors.surface,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Expanded(child: _summaryCell('Total Nilai Aset', 'Rp ${totalNilaiAset.toInt()}')),
              Container(width: 1, height: 32, color: AppColors.divider),
              Expanded(child: _summaryCell('Penyusutan/Bulan', 'Rp ${totalDepresiasi.toInt()}')),
              Container(width: 1, height: 32, color: AppColors.divider),
              Expanded(child: _summaryCell('Beban/Hari (26h)', 'Rp ${depresiasiPerHari.toInt()}')),
            ],
          ),
        ),
        const Divider(height: 1, color: AppColors.divider),

        if (_capex.isEmpty)
          Expanded(child: _emptyState('Belum ada data CAPEX (Aset Modal)'))
        else
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SingleChildScrollView(
                child: DataTable(
                  headingRowHeight: 40,
                  dataRowMinHeight: 48,
                  dataRowMaxHeight: 56,
                  columnSpacing: 20,
                  headingRowColor: MaterialStateProperty.all(AppColors.background),
                  columns: [
                    DataColumn(label: Text('Nama Aset', style: GoogleFonts.openSans(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textHint))),
                    DataColumn(label: Text('Tgl Masuk', style: GoogleFonts.openSans(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textHint))),
                    DataColumn(label: Text('Harga (Rp)', style: GoogleFonts.openSans(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textHint)), numeric: true),
                    DataColumn(label: Text('Umur', style: GoogleFonts.openSans(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textHint)), tooltip: 'Umur Ekonomis (Bulan)'),
                    DataColumn(label: Text('Sisa', style: GoogleFonts.openSans(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textHint)), tooltip: 'Sisa Umur (Bulan)'),
                    DataColumn(label: Text('Qty', style: GoogleFonts.openSans(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textHint))),
                    DataColumn(label: Text('Penyusutan/Bln', style: GoogleFonts.openSans(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textHint)), numeric: true),
                    const DataColumn(label: Text('')),
                  ],
                  rows: _capex.map((item) => DataRow(
                    cells: [
                      DataCell(Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(item.namaBarang, style: GoogleFonts.openSans(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                          Text(item.kategori, style: GoogleFonts.openSans(fontSize: 10, color: AppColors.textSecondary)),
                        ],
                      )),
                      DataCell(Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(item.tanggalMasuk.isNotEmpty ? item.tanggalMasuk : '-', style: GoogleFonts.openSans(fontSize: 12, color: AppColors.textSecondary)),
                          if (item.waktuMasuk.isNotEmpty)
                            Text(item.waktuMasuk, style: GoogleFonts.openSans(fontSize: 10, color: AppColors.textHint)),
                        ],
                      )),
                      DataCell(Text('Rp ${item.hargaBarang.toInt()}', style: GoogleFonts.openSans(fontSize: 12, color: AppColors.textSecondary))),
                      DataCell(Text('${item.umurEkonomis} bln', style: GoogleFonts.openSans(fontSize: 12, color: AppColors.textSecondary))),
                      DataCell(Text(
                        item.sisaUmur.isNotEmpty ? '${item.sisaUmur} bln' : '-',
                        style: GoogleFonts.openSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: item.sisaUmur.startsWith('-') || item.sisaUmur == '0' ? AppColors.error : AppColors.primary,
                        ),
                      )),
                      DataCell(Text('${item.quantity}', style: GoogleFonts.openSans(fontSize: 12, color: AppColors.textSecondary))),
                      DataCell(Text('Rp ${item.biayaPerBulan.toInt()}', style: GoogleFonts.openSans(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary))),
                      DataCell(
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert, size: 16, color: AppColors.textHint),
                          padding: EdgeInsets.zero,
                          onSelected: (v) async {
                            if (v == 'edit') {
                              final r = await Navigator.push(context, MaterialPageRoute(builder: (_) => AddOpexScreen(initialCapex: item)));
                              if (r == true) _loadData();
                            } else {
                              _confirmDeleteCapex(item);
                            }
                          },
                          itemBuilder: (_) => [
                            PopupMenuItem(value: 'edit', child: Text('Edit', style: GoogleFonts.openSans(fontSize: 13))),
                            PopupMenuItem(value: 'delete', child: Text('Hapus', style: GoogleFonts.openSans(fontSize: 13, color: AppColors.error))),
                          ],
                        ),
                      ),
                    ],
                  )).toList(),
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ==========================================
  // TAB OPEX (Operational Expenditure / Biaya Rutin)
  // ==========================================
  Widget _buildOpexTab() {
    double totalBiaya = _opex.fold(0, (s, o) => s + o.totalBiaya);

    return Column(
      children: [
        // Summary Bar
        Container(
          color: AppColors.surface,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Expanded(child: _summaryCell('Total Biaya Rutin', 'Rp ${totalBiaya.toInt()}')),
              Container(width: 1, height: 32, color: AppColors.divider),
              Expanded(child: _summaryCell('Jumlah Transaksi', '${_opex.length}')),
            ],
          ),
        ),
        const Divider(height: 1, color: AppColors.divider),

        if (_opex.isEmpty)
          Expanded(child: _emptyState('Belum ada data OPEX (Biaya Rutin)'))
        else
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: _opex.length,
              separatorBuilder: (_, __) => const SizedBox(height: 6),
              itemBuilder: (context, index) {
                final item = _opex[index];
                return Card(
                  elevation: 0,
                  color: AppColors.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: const BorderSide(color: AppColors.border),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.receipt_long, size: 20, color: Color(0xFF2563EB)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.namaPengeluaran,
                                style: GoogleFonts.openSans(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Text(
                                    item.kategori,
                                    style: GoogleFonts.openSans(fontSize: 11, color: AppColors.textSecondary),
                                  ),
                                  if (item.tanggalMasuk.isNotEmpty) ...[
                                    const Text(' • ', style: TextStyle(color: AppColors.textHint, fontSize: 11)),
                                    Text(
                                      '${item.tanggalMasuk} ${item.waktuMasuk}',
                                      style: GoogleFonts.openSans(fontSize: 11, color: AppColors.textHint),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Rp ${item.totalBiaya.toInt()}',
                              style: GoogleFonts.openSans(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                            ),
                            if (item.quantity > 1)
                              Text(
                                '${item.quantity.toInt()} x Rp ${item.nominal.toInt()}',
                                style: GoogleFonts.openSans(fontSize: 10, color: AppColors.textHint),
                              ),
                          ],
                        ),
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert, size: 16, color: AppColors.textHint),
                          padding: EdgeInsets.zero,
                          onSelected: (v) async {
                            if (v == 'edit') {
                              final r = await Navigator.push(context, MaterialPageRoute(builder: (_) => AddOpexScreen(initialOpex: item)));
                              if (r == true) _loadData();
                            } else {
                              _confirmDeleteOpex(item);
                            }
                          },
                          itemBuilder: (_) => [
                            PopupMenuItem(value: 'edit', child: Text('Edit', style: GoogleFonts.openSans(fontSize: 13))),
                            PopupMenuItem(value: 'delete', child: Text('Hapus', style: GoogleFonts.openSans(fontSize: 13, color: AppColors.error))),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _summaryCell(String label, String value) => Column(
        children: [
          Text(label, style: GoogleFonts.openSans(fontSize: 11, color: AppColors.textSecondary)),
          const SizedBox(height: 2),
          Text(value, style: GoogleFonts.openSans(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        ],
      );

  Widget _emptyState(String msg) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.inventory_2_outlined, size: 40, color: AppColors.textHint),
            const SizedBox(height: 8),
            Text(msg, style: GoogleFonts.openSans(fontSize: 13, color: AppColors.textHint)),
          ],
        ),
      );

  void _confirmDeleteBahan(InventoryItem item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Hapus Bahan?', style: GoogleFonts.openSans(fontWeight: FontWeight.bold, fontSize: 14)),
        content: Text('Hapus "${item.namaItem}" secara permanen?', style: GoogleFonts.openSans(fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Batal', style: GoogleFonts.openSans(color: AppColors.textSecondary))),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() => _isLoading = true);
              final ok = await _inventoryService.deleteInventory(item.idItem);
              if (ok) _loadData(); else setState(() => _isLoading = false);
            },
            child: Text('Hapus', style: GoogleFonts.openSans(color: AppColors.error, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteCapex(CapexItem item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Hapus CAPEX?', style: GoogleFonts.openSans(fontWeight: FontWeight.bold, fontSize: 14)),
        content: Text('Hapus aset "${item.namaBarang}" secara permanen?', style: GoogleFonts.openSans(fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Batal', style: GoogleFonts.openSans(color: AppColors.textSecondary))),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() => _isLoading = true);
              final ok = await _opexService.deleteCapex(item.idCapex);
              if (ok) _loadData(); else setState(() => _isLoading = false);
            },
            child: Text('Hapus', style: GoogleFonts.openSans(color: AppColors.error, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteOpex(OpexItem item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Hapus OPEX?', style: GoogleFonts.openSans(fontWeight: FontWeight.bold, fontSize: 14)),
        content: Text('Hapus biaya "${item.namaPengeluaran}" secara permanen?', style: GoogleFonts.openSans(fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Batal', style: GoogleFonts.openSans(color: AppColors.textSecondary))),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() => _isLoading = true);
              final ok = await _opexService.deleteOpex(item.idOpex);
              if (ok) _loadData(); else setState(() => _isLoading = false);
            },
            child: Text('Hapus', style: GoogleFonts.openSans(color: AppColors.error, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showDetailBahan(InventoryItem item) {
    String suplierName = '-';
    if (item.idSuplier.isNotEmpty) {
      try {
        final supplier = _suppliers.firstWhere((s) => s.idSuplier == item.idSuplier);
        suplierName = supplier.namaSuplier;
      } catch (e) {
        suplierName = 'ID Suplier tidak ditemukan';
      }
    }

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
            Text(item.namaItem, style: GoogleFonts.openSans(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            Text('ID: ${item.idItem}', style: GoogleFonts.openSans(fontSize: 12, color: AppColors.textSecondary)),
            const Divider(height: 20, color: AppColors.divider),
            AppDetailRow('Merek', item.merk.isNotEmpty ? item.merk : '-'),
            AppDetailRow('Harga Satuan', 'Rp ${item.hargaSatuan.toStringAsFixed(2)} / ${item.satuan}'),
            AppDetailRow('Stok Saat Ini', '${item.stok.toInt()} ${item.satuan}'),
            AppDetailRow('Total Aset', 'Rp ${(item.hargaSatuan * item.stok).toInt()}'),
            AppDetailRow('Suplier', suplierName),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.error), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                    onPressed: () {
                      Navigator.pop(context);
                      _confirmDeleteBahan(item);
                    },
                    child: Text('Hapus', style: GoogleFonts.openSans(fontSize: 13, color: AppColors.error)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                    onPressed: () async {
                      Navigator.pop(context);
                      final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => AddInventoryScreen(initialData: item)));
                      if (result == true) _loadData();
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

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }
}
