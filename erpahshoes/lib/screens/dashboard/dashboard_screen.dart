import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../staff/staff_list_screen.dart';
import '../inventory/inventory_screen.dart';
import '../treatment/treatment_screen.dart';
import '../supplier/supplier_screen.dart';
import '../kasir/kasir_screen.dart';
import '../kasir/riwayat_screen.dart';
import '../laporan/laporan_screen.dart';
import '../penggajian/penggajian_screen.dart';
import '../absensi/absensi_screen.dart';
import '../../services/kasir_service.dart';
import '../../utils/app_theme.dart';

class DashboardScreen extends StatefulWidget {
  final String role;
  final String namaLengkap;

  const DashboardScreen({Key? key, required this.role, required this.namaLengkap}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final KasirService _kasirService = KasirService();
  List<Map<String, dynamic>> _activeJobs = [];
  bool _isLoadingJobs = true;

  @override
  void initState() {
    super.initState();
    _loadActiveJobs();
  }

  Future<void> _loadActiveJobs() async {
    setState(() => _isLoadingJobs = true);
    final data = await _kasirService.getTransaksi();
    if (mounted) {
      setState(() {
        _activeJobs = data.where((t) => t['status'] == 'Dikerjakan').toList();
        _isLoadingJobs = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final menus = _buildMenus(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadActiveJobs,
          child: Column(
            children: [
              // Header
              Container(
                color: AppColors.surface,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Selamat datang,',
                              style: GoogleFonts.openSans(fontSize: 11, color: AppColors.textHint)),
                          const SizedBox(height: 2),
                          Text(widget.namaLengkap,
                              style: GoogleFonts.openSans(
                                  fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(widget.role.toUpperCase(),
                          style: GoogleFonts.openSans(
                              fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary)),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.divider),

              // Active Jobs Widget
              if (_isLoadingJobs)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_activeJobs.isNotEmpty)
                _buildJobsWidget(),

              // Menu Grid (Bentuk Icon App)
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Wrap(
                    spacing: 24, // Jarak horizontal antar icon
                    runSpacing: 24, // Jarak vertikal antar icon
                    alignment: WrapAlignment.start,
                    children: menus,
                  ),
                ),
              ),

              // Logout
              const Divider(height: 1, color: AppColors.divider),
              Material(
                color: AppColors.surface,
                child: InkWell(
                  onTap: () async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.remove('role');
                    await prefs.remove('nama_lengkap');
                    if (!context.mounted) return;
                    Navigator.pushReplacementNamed(context, '/login');
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                    child: Row(
                      children: [
                        const Icon(Icons.logout, size: 16, color: AppColors.error),
                        const SizedBox(width: 10),
                        Text('Keluar dari Akun',
                            style: GoogleFonts.openSans(
                                fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.error)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildJobsWidget() {
    return Container(
      width: double.infinity,
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(vertical: 16),
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Sedang Dikerjakan (${_activeJobs.length})',
                    style: GoogleFonts.openSans(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                InkWell(
                  onTap: () async {
                    await Navigator.push(context, MaterialPageRoute(builder: (_) => const RiwayatScreen(initialFilter: 'Dikerjakan')));
                    _loadActiveJobs();
                  },
                  child: Text('Lihat Semua', style: GoogleFonts.openSans(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 100,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              scrollDirection: Axis.horizontal,
              itemCount: _activeJobs.length,
              itemBuilder: (context, index) {
                final job = _activeJobs[index];
                final items = (job['items'] as List?) ?? [];
                return GestureDetector(
                  onTap: () async {
                    await Navigator.push(context, MaterialPageRoute(builder: (_) => const RiwayatScreen(initialFilter: 'Dikerjakan')));
                    _loadActiveJobs();
                  },
                  child: Container(
                    width: 220,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(job['id_transaksi'] ?? '', style: GoogleFonts.openSans(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.orange)),
                            const Icon(Icons.build_circle, size: 14, color: Colors.orange),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(job['nama_pelanggan'] ?? '-', maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.openSans(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                        const SizedBox(height: 4),
                        Text('${items.length} Item', style: GoogleFonts.openSans(fontSize: 11, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildMenus(BuildContext context) {
    bool hasActiveJobs = _activeJobs.isNotEmpty;

    final all = [
      if (widget.role == 'admin' || widget.role == 'kasir')
        _AppIcon(
          title: 'Treatment', 
          icon: Icons.local_offer,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TreatmentScreen()))
        ),
      if (widget.role == 'admin')
        _AppIcon(
          title: 'Inventory', 
          icon: Icons.inventory_2,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InventoryScreen()))
        ),
      if (widget.role == 'admin')
        _AppIcon(
          title: 'Staff', 
          icon: Icons.people,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StaffListScreen()))
        ),
      if (widget.role == 'admin')
        _AppIcon(
          title: 'Suplier', 
          icon: Icons.local_shipping,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SupplierScreen()))
        ),
      if (widget.role == 'admin' || widget.role == 'kasir')
        _AppIcon(
          title: 'Kasir', 
          icon: Icons.point_of_sale,
          showBadge: hasActiveJobs,
          onTap: () async {
            await Navigator.push(context, MaterialPageRoute(builder: (_) => const KasirScreen()));
            _loadActiveJobs();
          }
        ),
      // Karyawan dan Admin bisa akses menu Jobs langsung
      if (widget.role == 'admin' || widget.role == 'karyawan' || widget.role == 'kasir')
        _AppIcon(
          title: 'Jobs/Riwayat', 
          icon: Icons.assignment,
          showBadge: hasActiveJobs,
          onTap: () async {
            await Navigator.push(context, MaterialPageRoute(builder: (_) => const RiwayatScreen(initialFilter: 'Dikerjakan')));
            _loadActiveJobs();
          }
        ),
      // Laporan hanya untuk admin
      if (widget.role == 'admin')
        _AppIcon(
          title: 'Laporan', 
          icon: Icons.analytics,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LaporanScreen()))
        ),
      // Penggajian hanya untuk admin
      if (widget.role == 'admin')
        _AppIcon(
          title: 'Penggajian', 
          icon: Icons.payments,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PenggajianScreen()))
        ),
      // Absensi untuk semua role (karyawan, kasir, admin)
      _AppIcon(
        title: 'Absensi', 
        icon: Icons.camera_front_rounded,
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AbsensiScreen()))
      ),
    ];
    return all.map((m) => m.build(context)).toList();
  }
}

class _AppIcon {
  final String title;
  final IconData icon;
  final VoidCallback onTap;
  final bool showBadge;

  const _AppIcon({required this.title, required this.icon, required this.onTap, this.showBadge = false});

  Widget build(BuildContext context) {
    return SizedBox(
      width: 72, // Ukuran ideal untuk icon app di HP
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16), // Rounded seperti icon iOS/Android
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    )
                  ],
                  border: Border.all(color: AppColors.border, width: 0.5),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: onTap,
                    child: Center(
                      child: Icon(icon, size: 28, color: AppColors.primary),
                    ),
                  ),
                ),
              ),
              if (showBadge)
                Positioned(
                  top: -2,
                  right: -2,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: AppColors.error,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.surface, width: 2),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.openSans(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
