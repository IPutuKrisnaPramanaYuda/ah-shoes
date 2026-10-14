import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../services/penggajian_service.dart';
import '../../services/staff_service.dart';
import '../../services/slip_gaji_pdf_service.dart';
import '../../utils/app_theme.dart';
import 'slip_gaji_preview_dialog.dart';

class PenggajianScreen extends StatefulWidget {
  const PenggajianScreen({Key? key}) : super(key: key);

  @override
  State<PenggajianScreen> createState() => _PenggajianScreenState();
}

class _PenggajianScreenState extends State<PenggajianScreen> with SingleTickerProviderStateMixin {
  final PenggajianService _penggajianService = PenggajianService();
  final StaffService _staffService = StaffService();
  late TabController _tabController;

  static final Map<String, Map<String, dynamic>> _staffMap = {};

  List<Map<String, dynamic>> _staffEarnings = [];
  List<Map<String, dynamic>> _filteredEarnings = [];
  List<Map<String, dynamic>> _paymentLogs = [];
  List<Map<String, dynamic>> _filteredLogs = [];

  bool _isLoading = true;
  bool _isRefreshing = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  final NumberFormat _currencyFormat = NumberFormat('#,##0', 'en_US');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // Ambil dari cache jika sudah ada agar layar terbuka dalam 0 ms
    final cached = PenggajianService.cachedPenggajian;
    final cachedLogs = PenggajianService.cachedLogs;
    if (cached != null) {
      _staffEarnings = List.from(cached);
      _filteredEarnings = List.from(cached);
      _isLoading = false;
    }
    if (cachedLogs != null) {
      _paymentLogs = List.from(cachedLogs);
      _filteredLogs = List.from(cachedLogs);
    }

    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData({bool forceRefresh = false}) async {
    if (_staffEarnings.isEmpty && _paymentLogs.isEmpty) {
      setState(() => _isLoading = true);
    } else {
      setState(() => _isRefreshing = true);
    }

    try {
      final results = await Future.wait([
        _penggajianService.getPenggajian(forceRefresh: forceRefresh),
        _penggajianService.getLogPenggajian(forceRefresh: forceRefresh),
        _staffService.getStaffList(),
      ]);

      final earnings = results[0] as List<Map<String, dynamic>>;
      final rawLogs = results[1] as List<Map<String, dynamic>>;
      final staffList = results[2] as List<Map<String, dynamic>>;

      // Buat mapping staff lengkap (nama_lengkap -> ID Staff & No Telp)
      for (var s in staffList) {
        final name = (s['nama_lengkap'] ?? '').toString().trim().toLowerCase();
        if (name.isNotEmpty) {
          _staffMap[name] = s;
        }
      }

      // Pastikan setiap earning punya id_staff dan no_telp dari mapping staff
      for (var e in earnings) {
        final name = (e['nama_staff'] ?? '').toString().trim().toLowerCase();
        final s = _staffMap[name];
        if (s != null) {
          if (e['id_staff'] == null || e['id_staff'].toString().isEmpty) {
            e['id_staff'] = s['id_staff'] ?? '';
          }
          if (e['no_telp'] == null || e['no_telp'].toString().isEmpty) {
            e['no_telp'] = s['no_telp'] ?? '';
          }
        }
      }

      // Filter log agar baris header seperti 'ID_Gaji' / 'NAMA_STAFF' tidak ikut tampil
      final validLogs = rawLogs.where((l) {
        final idLog = (l['id_log'] ?? '').toString();
        final nama = (l['nama_staff'] ?? '').toString();
        return idLog != 'ID_Gaji' && nama != 'NAMA_STAFF' && idLog.isNotEmpty;
      }).toList();

      if (mounted) {
        setState(() {
          _staffEarnings = earnings;
          _paymentLogs = validLogs;
          _applyFilter(_searchQuery);
          _isLoading = false;
          _isRefreshing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isRefreshing = false;
        });
      }
    }
  }

  void _applyFilter(String query) {
    _searchQuery = query.toLowerCase();
    setState(() {
      if (_searchQuery.isEmpty) {
        _filteredEarnings = List.from(_staffEarnings);
        _filteredLogs = List.from(_paymentLogs);
      } else {
        _filteredEarnings = _staffEarnings.where((e) {
          final name = (e['nama_staff'] ?? '').toString().toLowerCase();
          final id = (e['id_staff'] ?? '').toString().toLowerCase();
          return name.contains(_searchQuery) || id.contains(_searchQuery);
        }).toList();

        _filteredLogs = _paymentLogs.where((l) {
          final name = (l['nama_staff'] ?? '').toString().toLowerCase();
          final idLog = (l['id_log'] ?? '').toString().toLowerCase();
          return name.contains(_searchQuery) || idLog.contains(_searchQuery);
        }).toList();
      }
    });
  }

  String _formatRp(double val) {
    return 'Rp ${_currencyFormat.format(val.round())}';
  }

  Future<void> _cairkanGaji(String namaStaff, double totalBayar) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        title: Text(
          'Konfirmasi Pencairan Gaji',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16, color: const Color(0xFF0F172A)),
        ),
        content: Text(
          'Cairkan gaji sebesar ${_formatRp(totalBayar)} untuk $namaStaff?\n\nTransaksi treatment yang sudah diambil pelanggan akan ditandai Lunas / Sudah Dibayar dan dicatat ke Log Riwayat.',
          style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF475569), height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Batal', style: GoogleFonts.inter(color: const Color(0xFF64748B), fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F172A),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              elevation: 0,
            ),
            child: Text('Cairkan & Catat', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isRefreshing = true);
    final ok = await _penggajianService.bayarGaji(namaStaff, totalBayar);
    if (mounted) {
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gaji $namaStaff berhasil dicairkan & masuk riwayat.', style: GoogleFonts.inter(fontSize: 13)),
            backgroundColor: const Color(0xFF16A34A),
          ),
        );
        _loadData(forceRefresh: true);
      } else {
        setState(() => _isRefreshing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mencairkan gaji. Periksa koneksi data.', style: GoogleFonts.inter(fontSize: 13)),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    }
  }

  void _showEditModal(Map<String, dynamic> data) {
    final tunjanganCtrl = TextEditingController(text: (data['tunjangan'] ?? 0).toString());
    final bpjstkCtrl = TextEditingController(text: (data['tunjangan_bpjstk'] ?? 0).toString());
    final thrCtrl = TextEditingController(text: (data['thr'] ?? 0).toString());
    final terlambatCtrl = TextEditingController(text: (data['potongan_keterlambatan'] ?? 0).toString());
    final cashbonCtrl = TextEditingController(text: (data['cashbon'] ?? 0).toString());
    final namaStaff = data['nama_staff'] ?? '-';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Sesuaikan Tunjangan & Potongan',
                            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A))),
                        Text('Karyawan: $namaStaff',
                            style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B))),
                      ],
                    ),
                    IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(height: 1, color: Color(0xFFE2E8F0)),
                const SizedBox(height: 16),
                _buildSimpleField(tunjanganCtrl, 'Tunjangan Operasional (Rp)'),
                _buildSimpleField(bpjstkCtrl, 'Tunjangan BPJSTK (Rp)'),
                _buildSimpleField(thrCtrl, 'Tunjangan THR / Bonus (Rp)'),
                _buildSimpleField(terlambatCtrl, 'Potongan Keterlambatan (Rp)'),
                _buildSimpleField(cashbonCtrl, 'Potongan Kasbon (Rp)'),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F172A),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () async {
                      Navigator.pop(ctx);
                      setState(() => _isRefreshing = true);
                      final ok = await _penggajianService.updatePenggajianMaster(
                        namaStaff,
                        double.tryParse(bpjstkCtrl.text) ?? 0,
                        double.tryParse(thrCtrl.text) ?? 0,
                        double.tryParse(terlambatCtrl.text) ?? 0,
                        tunjangan: double.tryParse(tunjanganCtrl.text) ?? 0,
                        cashbon: double.tryParse(cashbonCtrl.text) ?? 0,
                      );
                      if (ok) {
                        _loadData(forceRefresh: true);
                      } else {
                        setState(() => _isRefreshing = false);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Gagal menyimpan penyesuaian.'), backgroundColor: Color(0xFFDC2626)),
                          );
                        }
                      }
                    },
                    child: Text('Simpan Perubahan', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSimpleField(TextEditingController ctrl, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: ctrl,
        keyboardType: TextInputType.number,
        style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF0F172A)),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF0F172A), width: 1.4)),
        ),
      ),
    );
  }

  void _openSlipGajiDialog(Map<String, dynamic> data) {
    final namaStaff = data['nama_staff'] ?? '-';
    final staffInfo = _staffMap[namaStaff.toString().trim().toLowerCase()] ?? {};
    final idStaff = (data['id_staff'] != null && data['id_staff'].toString().isNotEmpty)
        ? data['id_staff'].toString()
        : (staffInfo['id_staff'] ?? '').toString();
    final noTelp = (data['no_telp'] != null && data['no_telp'].toString().isNotEmpty)
        ? data['no_telp'].toString()
        : (staffInfo['no_telp'] ?? '').toString();

    final gajiPokok = double.tryParse(data['gaji_pokok'].toString()) ?? 0;
    final uangReal = double.tryParse(data['uang_real'].toString()) ?? 0;
    final tunjangan = double.tryParse(data['tunjangan']?.toString() ?? '0') ?? 0;
    final bpjstk = double.tryParse(data['tunjangan_bpjstk']?.toString() ?? '0') ?? 0;
    final thr = double.tryParse(data['thr']?.toString() ?? '0') ?? 0;
    final keterlambatan = double.tryParse(data['potongan_keterlambatan']?.toString() ?? '0') ?? 0;
    final cashbon = double.tryParse(data['cashbon']?.toString() ?? '0') ?? 0;
    final totalGaji = double.tryParse(data['total_gaji']?.toString() ?? '0') ?? 0;

    final slipData = SlipGajiData(
      idStaff: idStaff,
      namaStaff: namaStaff,
      noTelp: noTelp,
      gajiPokok: uangReal > 0 ? uangReal : gajiPokok,
      tunjangan: tunjangan,
      bpjstk: bpjstk,
      thr: thr,
      keterlambatan: keterlambatan,
      cashbon: cashbon,
    );

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => SlipGajiPreviewDialog(
        slipData: slipData,
        onBayarGaji: totalGaji > 0
            ? () {
                Navigator.pop(ctx);
                _cairkanGaji(namaStaff, totalGaji);
              }
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    double totalSiapBayarSemua = 0;
    double totalPiutangSemua = 0;
    for (var s in _staffEarnings) {
      totalSiapBayarSemua += double.tryParse(s['total_gaji']?.toString() ?? '0') ?? 0;
      totalPiutangSemua += double.tryParse(s['uang_piutang']?.toString() ?? '0') ?? 0;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sistem Penggajian',
                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A))),
            Text('Ah! Shoes Care • Manajemen Komisi & Slip Gaji',
                style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B))),
          ],
        ),
        actions: [
          if (_isRefreshing)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0F172A))),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh, size: 20),
              tooltip: 'Perbarui Data',
              onPressed: () => _loadData(forceRefresh: true),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: const Color(0xFF0F172A),
              unselectedLabelColor: const Color(0xFF64748B),
              indicatorColor: const Color(0xFF0F172A),
              indicatorWeight: 2.5,
              labelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
              tabs: [
                Tab(text: 'Gaji Berjalan (${_staffEarnings.length})'),
                Tab(text: 'Riwayat Pencairan (${_paymentLogs.length})'),
              ],
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF0F172A)))
          : TabBarView(
              controller: _tabController,
              children: [
                // TAB 1: Gaji Berjalan
                _buildGajiBerjalanTab(totalSiapBayarSemua, totalPiutangSemua),

                // TAB 2: Riwayat Pencairan
                _buildRiwayatTab(),
              ],
            ),
    );
  }

  Widget _buildGajiBerjalanTab(double totalSiapBayarSemua, double totalPiutangSemua) {
    return RefreshIndicator(
      color: const Color(0xFF0F172A),
      onRefresh: () => _loadData(forceRefresh: true),
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        children: [
          // 1. KPI Summary Cards (Clean & Simple)
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  'Total Siap Cair',
                  _formatRp(totalSiapBayarSemua),
                  const Color(0xFF16A34A),
                  Icons.check_circle_outline,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMetricCard(
                  'Piutang Berjalan',
                  _formatRp(totalPiutangSemua),
                  const Color(0xFFD97706),
                  Icons.schedule,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMetricCard(
                  'Karyawan Aktif',
                  '${_staffEarnings.length} Orang',
                  const Color(0xFF0F172A),
                  Icons.people_outline,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 2. Search Field
          Container(
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: TextField(
              controller: _searchController,
              style: GoogleFonts.inter(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Cari nama staf atau ID...',
                hintStyle: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
                prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF94A3B8)),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.only(top: 8),
              ),
              onChanged: _applyFilter,
            ),
          ),
          const SizedBox(height: 14),

          // 3. Staff List
          if (_filteredEarnings.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  children: [
                    const Icon(Icons.done_all, size: 40, color: Color(0xFF94A3B8)),
                    const SizedBox(height: 12),
                    Text(
                      _searchQuery.isNotEmpty ? 'Karyawan tidak ditemukan' : 'Semua Komisi Telah Dicairkan',
                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            )
          else
            ..._filteredEarnings.map((data) => _buildStaffCard(data)).toList(),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, Color valueColor, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 13, color: const Color(0xFF64748B)),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF64748B), fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: valueColor),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildStaffCard(Map<String, dynamic> data) {
    final namaStaff = data['nama_staff'] ?? '-';
    final idStaff = (data['id_staff'] ?? '').toString();
    final noTelp = (data['no_telp'] ?? '').toString();

    final gajiPokok = double.tryParse(data['gaji_pokok'].toString()) ?? 0;
    final uangReal = double.tryParse(data['uang_real'].toString()) ?? 0;
    final uangPiutang = double.tryParse(data['uang_piutang'].toString()) ?? 0;
    final tunjangan = double.tryParse(data['tunjangan']?.toString() ?? '0') ?? 0;
    final bpjstk = double.tryParse(data['tunjangan_bpjstk']?.toString() ?? '0') ?? 0;
    final thr = double.tryParse(data['thr']?.toString() ?? '0') ?? 0;
    final keterlambatan = double.tryParse(data['potongan_keterlambatan']?.toString() ?? '0') ?? 0;
    final cashbon = double.tryParse(data['cashbon']?.toString() ?? '0') ?? 0;
    final totalGaji = double.tryParse(data['total_gaji']?.toString() ?? '0') ?? 0;
    final items = (data['items'] as List?) ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Card
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        namaStaff.isNotEmpty ? namaStaff.substring(0, 1).toUpperCase() : '?',
                        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(namaStaff,
                            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A))),
                        Row(
                          children: [
                            if (idStaff.isNotEmpty)
                              Text('ID: $idStaff', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B))),
                            if (idStaff.isNotEmpty && noTelp.isNotEmpty)
                              Text(' • ', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8))),
                            if (noTelp.isNotEmpty)
                              Text('WA: $noTelp', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B))),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.tune, size: 18, color: Color(0xFF475569)),
                  tooltip: 'Sesuaikan Tunjangan/Potongan',
                  onPressed: () => _showEditModal(data),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          // Breakdown Rincian Gaji
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Column(
              children: [
                _buildRowDetail('Gaji Pokok (Total Treatment)', _formatRp(gajiPokok)),
                _buildRowDetail('- Piutang (Belum Selesai / Belum Diambil)', _formatRp(uangPiutang), isNegative: true),
                _buildRowDetail('= Uang Real (Siap Dicairkan)', _formatRp(uangReal), isBold: true, color: const Color(0xFF16A34A)),
                if (tunjangan > 0) _buildRowDetail('+ Tunjangan Operasional', _formatRp(tunjangan)),
                if (bpjstk > 0) _buildRowDetail('+ Tunjangan BPJSTK', _formatRp(bpjstk)),
                if (thr > 0) _buildRowDetail('+ Tunjangan THR / Bonus', _formatRp(thr)),
                if (keterlambatan > 0) _buildRowDetail('- Potongan Keterlambatan', _formatRp(keterlambatan), isNegative: true),
                if (cashbon > 0) _buildRowDetail('- Potongan Kasbon', _formatRp(cashbon), isNegative: true),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          // Footer Card: Total Gaji & Actions
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total Siap Bayar', style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF64748B))),
                    Text(_formatRp(totalGaji),
                        style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A))),
                  ],
                ),
                Row(
                  children: [
                    // Tombol Lihat Rincian (Modal / Dialog Rinci)
                    OutlinedButton.icon(
                      icon: const Icon(Icons.visibility_outlined, size: 14, color: Color(0xFF2563EB)),
                      label: Text('Lihat Rincian', style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600, color: const Color(0xFF2563EB))),
                      onPressed: () => _showRincianGajiBerjalanDialog(data),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFBFDBFE)),
                        backgroundColor: const Color(0xFFEFF6FF),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Tombol Cetak Slip Gaji (Outlined Clean)
                    OutlinedButton.icon(
                      icon: const Icon(Icons.receipt_long, size: 14, color: Color(0xFF0F172A)),
                      label: Text('Cetak Slip', style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A))),
                      onPressed: () => _openSlipGajiDialog(data),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Tombol Cairkan Gaji (Solid Dark)
                    ElevatedButton(
                      onPressed: totalGaji > 0 ? () => _cairkanGaji(namaStaff, totalGaji) : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F172A),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      child: Text('Cairkan', style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600, color: Colors.white)),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Detail Sepatu Accordion (Dropdown Inline Cepat)
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
              title: Text(
                'Buka dropdown rincian ${items.length} pekerjaan / sepatu',
                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF2563EB)),
              ),
              children: items.map((item) {
                final bool isReal = item['is_real'] == true;
                final String statusTrx = item['status_trx']?.toString() ?? 'Dikerjakan';
                final String namaPelanggan = item['nama_pelanggan']?.toString() ?? '-';
                final String merek = item['merek']?.toString() ?? '';
                final String jenisItem = item['jenis_item']?.toString() ?? 'Sepatu';
                final String namaTreatment = item['nama_treatment']?.toString() ?? '-';
                final double fee = double.tryParse(item['fee']?.toString() ?? '0') ?? 0;

                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('$namaPelanggan • ${merek.isNotEmpty ? "$merek " : ""}$jenisItem',
                                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A))),
                            Text('$namaTreatment (Status: $statusTrx)',
                                style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF64748B))),
                          ],
                        ),
                      ),
                      Text(
                        _formatRp(fee),
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isReal ? const Color(0xFF16A34A) : const Color(0xFFD97706),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  void _showRincianGajiBerjalanDialog(Map<String, dynamic> data) {
    final namaStaff = data['nama_staff'] ?? '-';
    final staffInfo = _staffMap[namaStaff.toString().trim().toLowerCase()] ?? {};
    final idStaff = (data['id_staff'] != null && data['id_staff'].toString().isNotEmpty)
        ? data['id_staff'].toString()
        : (staffInfo['id_staff'] ?? '').toString();
    final noTelp = (data['no_telp'] != null && data['no_telp'].toString().isNotEmpty)
        ? data['no_telp'].toString()
        : (staffInfo['no_telp'] ?? '').toString();

    final gajiPokok = double.tryParse(data['gaji_pokok'].toString()) ?? 0;
    final uangReal = double.tryParse(data['uang_real'].toString()) ?? 0;
    final uangPiutang = double.tryParse(data['uang_piutang'].toString()) ?? 0;
    final tunjangan = double.tryParse(data['tunjangan']?.toString() ?? '0') ?? 0;
    final bpjstk = double.tryParse(data['tunjangan_bpjstk']?.toString() ?? '0') ?? 0;
    final thr = double.tryParse(data['thr']?.toString() ?? '0') ?? 0;
    final keterlambatan = double.tryParse(data['potongan_keterlambatan']?.toString() ?? '0') ?? 0;
    final cashbon = double.tryParse(data['cashbon']?.toString() ?? '0') ?? 0;
    final totalGaji = double.tryParse(data['total_gaji']?.toString() ?? '0') ?? 0;
    final items = (data['items'] as List?) ?? [];

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 720, maxHeight: 680),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header Modal
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Rincian Gaji Berjalan',
                            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A))),
                        Text('$namaStaff ${idStaff.isNotEmpty ? "• ID: $idStaff" : ""} ${noTelp.isNotEmpty ? "• WA: $noTelp" : ""}',
                            style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),

              // Body: Scrollable Breakdown + Table of items
              Flexible(
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    // Ringkasan Keuangan
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Ringkasan Finansial',
                              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A))),
                          const SizedBox(height: 8),
                          _buildRowDetail('Gaji Pokok (Total Treatment)', _formatRp(gajiPokok)),
                          _buildRowDetail('- Piutang (Menunggu Pelanggan Ambil)', _formatRp(uangPiutang), isNegative: true),
                          _buildRowDetail('= Uang Real (Pekerjaan Selesai & Diambil)', _formatRp(uangReal), isBold: true, color: const Color(0xFF16A34A)),
                          if (tunjangan > 0) _buildRowDetail('+ Tunjangan Operasional', _formatRp(tunjangan)),
                          if (bpjstk > 0) _buildRowDetail('+ Tunjangan BPJSTK', _formatRp(bpjstk)),
                          if (thr > 0) _buildRowDetail('+ Tunjangan THR / Bonus', _formatRp(thr)),
                          if (keterlambatan > 0) _buildRowDetail('- Potongan Keterlambatan', _formatRp(keterlambatan), isNegative: true),
                          if (cashbon > 0) _buildRowDetail('- Potongan Kasbon', _formatRp(cashbon), isNegative: true),
                          const Divider(height: 16, color: Color(0xFFE2E8F0)),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Total Bersih Siap Bayar',
                                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A))),
                              Text(_formatRp(totalGaji),
                                  style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A))),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Daftar Pekerjaan Sepatu
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Daftar Pekerjaan / Sepatu (${items.length})',
                            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A))),
                        Text('${items.where((i) => i['is_real'] == true).length} Siap Cair • ${items.where((i) => i['is_real'] != true).length} Piutang',
                            style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B))),
                      ],
                    ),
                    const SizedBox(height: 10),

                    if (items.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(24),
                        alignment: Alignment.center,
                        child: Text('Belum ada data pekerjaan/sepatu pada periode ini.',
                            style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF94A3B8))),
                      )
                    else
                      ...items.asMap().entries.map((entry) {
                        final idx = entry.key + 1;
                        final item = entry.value;
                        final isReal = item['is_real'] == true;
                        final statusTrx = item['status_trx']?.toString() ?? 'Dikerjakan';
                        final pelanggan = item['nama_pelanggan']?.toString() ?? '-';
                        final merek = item['merek']?.toString() ?? '';
                        final jenisItem = item['jenis_item']?.toString() ?? 'Sepatu';
                        final treatment = item['nama_treatment']?.toString() ?? '-';
                        final fee = double.tryParse(item['fee']?.toString() ?? '0') ?? 0;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text('$idx', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF475569))),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('$pelanggan • ${merek.isNotEmpty ? "$merek " : ""}$jenisItem',
                                        style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A))),
                                    const SizedBox(height: 2),
                                    Text('Layanan: $treatment',
                                        style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B))),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(_formatRp(fee),
                                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A))),
                                  const SizedBox(height: 3),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isReal ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      isReal ? 'Siap Cair' : 'Piutang ($statusTrx)',
                                      style: GoogleFonts.inter(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w600,
                                        color: isReal ? const Color(0xFF16A34A) : const Color(0xFFB45309),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                  ],
                ),
              ),

              // Footer Modal
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text('Tutup', style: GoogleFonts.inter(color: const Color(0xFF64748B), fontWeight: FontWeight.w600)),
                    ),
                    Row(
                      children: [
                        OutlinedButton.icon(
                          icon: const Icon(Icons.receipt_long, size: 15, color: Color(0xFF0F172A)),
                          label: Text('Cetak Slip Gaji', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A))),
                          onPressed: () {
                            Navigator.pop(ctx);
                            _openSlipGajiDialog(data);
                          },
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                        ),
                        if (totalGaji > 0) ...[
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.pop(ctx);
                              _cairkanGaji(namaStaff, totalGaji);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0F172A),
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            ),
                            child: Text('Cairkan Gaji', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRincianRiwayatDialog(Map<String, dynamic> log) {
    final idLog = (log['id_log'] ?? '-').toString();
    final tgl = (log['tanggal'] ?? '-').toString();
    final nama = (log['nama_staff'] ?? '-').toString();
    final total = double.tryParse(log['total_bayar']?.toString() ?? '0') ?? 0;
    final items = (log['items'] as List?) ?? [];

    final staffInfo = _staffMap[nama.toLowerCase().trim()] ?? {};
    final idStaff = (staffInfo['id_staff'] ?? '').toString();
    final noTelp = (staffInfo['no_telp'] ?? '').toString();

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 680, maxHeight: 650),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header Modal
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Rincian Riwayat Pencairan',
                            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A))),
                        Text('ID: $idLog • Tanggal: $tgl',
                            style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),

              // Body: Scrollable Breakdown
              Flexible(
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    // Box Ringkasan Transaksi
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(nama,
                                      style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A))),
                                  if (idStaff.isNotEmpty || noTelp.isNotEmpty)
                                    Text('${idStaff.isNotEmpty ? "ID: $idStaff " : ""}${noTelp.isNotEmpty ? "• WA: $noTelp" : ""}',
                                        style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B))),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDCFCE7),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text('LUNAS',
                                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF16A34A))),
                              ),
                            ],
                          ),
                          const Divider(height: 18, color: Color(0xFFE2E8F0)),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Total Dana Dicairkan',
                                  style: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFF64748B))),
                              Text(_formatRp(total),
                                  style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A))),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Daftar Item yang Dicairkan
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Rincian Pekerjaan yang Dicairkan (${items.length})',
                            style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A))),
                        Text('Status: Lunas Terbayar',
                            style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF16A34A), fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: 10),

                    if (items.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline, size: 20, color: Color(0xFF64748B)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Transaksi pencairan sebesar ${_formatRp(total)} berhasil dicatat pada $tgl. Rincian per item sepatu tersimpan otomatis pada sistem versi terbaru.',
                                style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF475569), height: 1.4),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      ...items.asMap().entries.map((entry) {
                        final idx = entry.key + 1;
                        final item = entry.value;
                        final pelanggan = (item['pelanggan'] ?? item['nama_pelanggan'] ?? '-').toString();
                        final merek = (item['merek'] ?? '').toString();
                        final jenisItem = (item['jenis_item'] ?? 'Sepatu').toString();
                        final treatment = (item['nama_treatment'] ?? '-').toString();
                        final fee = double.tryParse(item['fee']?.toString() ?? '0') ?? 0;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text('$idx', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF475569))),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('$pelanggan • ${merek.isNotEmpty ? "$merek " : ""}$jenisItem',
                                        style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A))),
                                    const SizedBox(height: 2),
                                    Text('Treatment: $treatment',
                                        style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B))),
                                  ],
                                ),
                              ),
                              Text(_formatRp(fee),
                                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF16A34A))),
                            ],
                          ),
                        );
                      }).toList(),
                  ],
                ),
              ),

              // Footer Modal
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text('Tutup', style: GoogleFonts.inter(color: const Color(0xFF64748B), fontWeight: FontWeight.w600)),
                    ),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.receipt_long, size: 15, color: Colors.white),
                      label: Text('Cetak Slip Gaji', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F172A),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        final slipData = SlipGajiData(
                          idStaff: idStaff,
                          namaStaff: nama,
                          noTelp: noTelp,
                          gajiPokok: total,
                        );
                        showDialog(
                          context: context,
                          builder: (_) => SlipGajiPreviewDialog(slipData: slipData),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRowDetail(String label, String value, {bool isNegative = false, bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: isBold ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                fontWeight: isBold ? FontWeight.w600 : FontWeight.w400,
              )),
          Text(value,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
                color: color ?? (isNegative ? const Color(0xFFDC2626) : const Color(0xFF0F172A)),
              )),
        ],
      ),
    );
  }

  Widget _buildRiwayatTab() {
    return RefreshIndicator(
      color: const Color(0xFF0F172A),
      onRefresh: () => _loadData(forceRefresh: true),
      child: _filteredLogs.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  children: [
                    const Icon(Icons.history, size: 40, color: Color(0xFF94A3B8)),
                    const SizedBox(height: 12),
                    Text('Belum ada riwayat pencairan gaji',
                        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF64748B))),
                  ],
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _filteredLogs.length,
              itemBuilder: (ctx, idx) {
                final log = _filteredLogs[idx];
                final idLog = log['id_log'] ?? '-';
                final tgl = log['tanggal'] ?? '-';
                final nama = log['nama_staff'] ?? '-';
                final total = double.tryParse(log['total_bayar']?.toString() ?? '0') ?? 0;
                final items = (log['items'] as List?) ?? [];

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      // Header Row
                      Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(nama,
                                        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A))),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFDCFCE7),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text('Lunas',
                                          style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: const Color(0xFF16A34A))),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text('$tgl • $idLog', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8))),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(_formatRp(total),
                                    style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A))),
                                const SizedBox(height: 2),
                                Text('${items.length} item pekerjaan',
                                    style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF64748B))),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1, color: Color(0xFFF1F5F9)),

                      // Action Buttons Row
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            // Tombol Lihat Rincian
                            OutlinedButton.icon(
                              onPressed: () => _showRincianRiwayatDialog(log),
                              icon: const Icon(Icons.visibility_outlined, size: 14, color: Color(0xFF2563EB)),
                              label: Text('Lihat Rincian',
                                  style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600, color: const Color(0xFF2563EB))),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Color(0xFFBFDBFE)),
                                backgroundColor: const Color(0xFFEFF6FF),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Tombol Cetak Slip
                            OutlinedButton.icon(
                              onPressed: () {
                                final staffInfo = _staffMap[nama.toLowerCase().trim()] ?? {};
                                final idStaff = (staffInfo['id_staff'] ?? '').toString();
                                final noTelp = (staffInfo['no_telp'] ?? '').toString();

                                final slipData = SlipGajiData(
                                  idStaff: idStaff,
                                  namaStaff: nama,
                                  noTelp: noTelp,
                                  gajiPokok: total,
                                );
                                showDialog(
                                  context: context,
                                  builder: (_) => SlipGajiPreviewDialog(slipData: slipData),
                                );
                              },
                              icon: const Icon(Icons.receipt_long, size: 14, color: Color(0xFF0F172A)),
                              label: Text('Cetak Slip',
                                  style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A))),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Color(0xFFCBD5E1)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Dropdown Accordion Cepat (Optional Inline Preview)
                      if (items.isNotEmpty)
                        Theme(
                          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                          child: ExpansionTile(
                            tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
                            title: Text(
                              'Buka dropdown rincian ${items.length} pekerjaan yang dicairkan',
                              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF2563EB)),
                            ),
                            children: items.map((item) {
                              final pelanggan = (item['pelanggan'] ?? item['nama_pelanggan'] ?? '-').toString();
                              final merek = (item['merek'] ?? '').toString();
                              final jenisItem = (item['jenis_item'] ?? 'Sepatu').toString();
                              final treatment = (item['nama_treatment'] ?? '-').toString();
                              final fee = double.tryParse(item['fee']?.toString() ?? '0') ?? 0;

                              return Container(
                                margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('$pelanggan • ${merek.isNotEmpty ? "$merek " : ""}$jenisItem',
                                              style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A))),
                                          Text(treatment,
                                              style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF64748B))),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      _formatRp(fee),
                                      style: GoogleFonts.inter(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF16A34A),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
