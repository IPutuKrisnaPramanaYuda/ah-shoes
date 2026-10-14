# DOKUMENTASI LENGKAP PROYEK ERP AH SHOES

> **PENTING UNTUK DEVELOPER / AI LAIN:**  
> File ini adalah **Single Source of Truth (SSOT)** dan cetak biru (blueprint) utama untuk seluruh arsitektur, basis data, API Google Apps Script, dan frontend Flutter pada proyek **Ah Shoes ERP**.  
> **Wajib:** Setiap kali ada penambahan fitur, perubahan skema database, atau pembaruan kode API/UI, **perbarui dokumen ini** agar kesinambungan proyek tetap terjaga rapi.

---

## 1. Ringkasan & Arsitektur Proyek

Aplikasi **Ah Shoes ERP & Point of Sale** adalah sistem manajemen terpadu untuk bisnis perawatan/laundry sepatu, tas, dan apparel yang mencakup:
1. **Manajemen Pengguna & Hak Akses (RBAC)**: Role Admin, Kasir, dan Karyawan (Teknisi).
2. **Katalog Treatment (Layanan)**: Perhitungan otomatis HPP, fee teknisi (persentase/nominal), margin profit, dan stok layanan berdasarkan ketersediaan bahan baku.
3. **Manajemen Inventory & Restok**: Bahan baku pengerjaan, tracking kuantitas, harga modal satuan, dan konversi satuan pembelian (misal Liter -> ml, Kg -> gram).
4. **Operational Expenditure (OPEX)**: Tracking pengeluaran operasional dan perhitungan otomatis sisa umur ekonomis / depresiasi aset bulanan.
5. **Manajemen Pemasok (Suplier)**: Database vendor/pemasok bahan baku & aset operasional.
6. **Point of Sale (Kasir & Order Pengerjaan)**: Pembuatan invoice transaksi multi-item dengan detail spesifik (jenis, merk, warna, ukuran, teknisi penanggung jawab).
7. **Otomasi Pemotongan Stok**: Pengurangan stok bahan baku secara real-time saat transaksi disimpan berdasarkan resep treatment.
8. **Tracking Status Pengerjaan (Jobs)**: Monitoring alur `Dikerjakan` -> `Selesai` -> `Diambil`.
9. **Sistem Penggajian Teknisi (Payroll)**: Perhitungan komisi/fee pengerjaan, pemisahan uang real vs uang piutang (hanya transaksi lunas yang bisa dicairkan), tunjangan BPJSTK, THR, potongan keterlambatan, dan riwayat audit trail penggajian.
10. **Laporan & Rekap**: Rekap Barang Masuk/Keluar (`Barang_In`, `Barang_Out`) dan Arus Keuangan Riil vs Piutang (`Uang_Real`, `Uang_Piutang`).

### Tech Stack
- **Frontend**: Flutter 3 (Dart `^3.11.1`), Google Fonts (Open Sans & Inter), `http`, `shared_preferences`, `intl`.
- **Backend / API Gateway**: Google Apps Script (Web App Deployment dengan JSON output via `doGet`).
- **Database Engine**: Google Spreadsheet (Cloud Storage multi-tab).

---

## 2. Struktur Direktori Workspace

```text
Ah Shoes/
├── codeGS.txt                      <- Salinan kode Google Apps Script terbaru (identik dengan Code.gs)
├── PROJECT_DOCUMENTATION.md        <- DOKUMEN INI (Panduan utama proyek)
└── erpahshoes/                     <- Root folder proyek Flutter
    ├── gas/
    │   └── Code.gs                 <- File master Google Apps Script
    ├── lib/
    │   ├── main.dart               <- Entry point aplikasi & route generator
    │   ├── models/                 <- Data model Dart
    │   │   ├── inventory_model.dart
    │   │   ├── opex_model.dart
    │   │   ├── supplier_model.dart
    │   │   └── treatment_model.dart
    │   ├── services/               <- HTTP Client service berkomunikasi ke GAS
    │   │   ├── auth_service.dart
    │   │   ├── inventory_service.dart
    │   │   ├── kasir_service.dart
    │   │   ├── opex_service.dart
    │   │   ├── penggajian_service.dart
    │   │   ├── staff_service.dart
    │   │   ├── supplier_service.dart
    │   │   └── treatment_service.dart
    │   ├── screens/                <- Tampilan UI per modul
    │   │   ├── login_screen.dart
    │   │   ├── dashboard/
    │   │   │   └── dashboard_screen.dart
    │   │   ├── inventory/
    │   │   │   ├── inventory_screen.dart
    │   │   │   ├── add_inventory_screen.dart
    │   │   │   ├── add_opex_screen.dart
    │   │   │   └── restock_screen.dart
    │   │   ├── kasir/
    │   │   │   ├── kasir_screen.dart
    │   │   │   └── riwayat_screen.dart
    │   │   ├── laporan/
    │   │   │   └── laporan_screen.dart
    │   │   ├── penggajian/
    │   │   │   └── penggajian_screen.dart
    │   │   ├── staff/
    │   │   │   ├── staff_list_screen.dart
    │   │   │   └── add_staff_screen.dart
    │   │   ├── supplier/
    │   │   │   ├── supplier_screen.dart
    │   │   │   └── add_supplier_screen.dart
    │   │   └── treatment/
    │   │       ├── treatment_screen.dart
    │   │       └── add_treatment_screen.dart
    │   └── utils/
    │       ├── app_theme.dart      <- Tema warna, styling button, card, header
    │       └── constants.dart      <- Konfigurasi URL Google Apps Script
    ├── pubspec.yaml                <- Dependensi & konfigurasi Flutter
    └── ...
```

---

## 3. Database Schema (Google Sheets)

Database menggunakan satu Google Spreadsheet dengan susunan tab sebagai berikut:

```
[Users] [Staff] [Suplier] [Treatment] [Inventory] [OPEX] [Transaksi] [Log_Penggajian] [Detail_Transaksi] [Barang_In] [Barang_Out] [Uang_Real] [Uang_Piutang] (+ [Penggajian])
```

### 1. Sheet `Users`
Tabel akun untuk otentikasi login aplikasi.
| Kolom | Nama Field | Tipe Data | Keterangan |
|---|---|---|---|
| A | `id_user` | String | ID unik pengguna (misal `USR001` atau timestamp) |
| B | `username` | String | Username untuk login (harus unik) |
| C | `password` | String | Password login |
| D | `role` | String | Hak akses: `admin`, `kasir`, atau `karyawan` |

### 2. Sheet `Staff`
Tabel profil biodata karyawan/teknisi. Terhubung 1-to-1 dengan sheet `Users`.
| Kolom | Nama Field | Tipe Data | Keterangan |
|---|---|---|---|
| A | `id_staff` | String | ID unik staff (misal `STF...`) |
| B | `id_user` | String (FK) | Relasi ke `Users.id_user` |
| C | `nama_lengkap` | String | Nama lengkap staff |
| D | `alamat` | String | Alamat tempat tinggal |
| E | `status_kerja` | String | Misal: "Tetap", "Kontrak", "Magang" |
| F | `tanggal_masuk` | String/Date | Tanggal mulai bekerja |
| G | `jobdesk` | String | Posisi pekerjaan (misal: "Teknisi Cuci", "Kasir") |
| H | `masa_kerja` | String | Masa kerja staff |

### 3. Sheet `Suplier`
Tabel data vendor pemasok bahan baku atau perlengkapan.
| Kolom | Nama Field | Tipe Data | Keterangan |
|---|---|---|---|
| A | `id_suplier` | String | ID unik suplier (misal `SUP...`) |
| B | `nama_suplier` | String | Nama perusahaan / toko suplier |
| C | `kontak` | String | No HP / WhatsApp / Telepon |
| D | `alamat` | String | Alamat pemasok |

### 4. Sheet `Treatment`
Katalog layanan perawatan dengan rumus otomatis HPP, komisi staff, margin profit, dan estimasi stok sisa.
| Kolom | Nama Field | Tipe Data | Keterangan |
|---|---|---|---|
| A | `id_treatment` | String | ID unik treatment (misal `TRM...`) |
| B | `nama_treatment` | String | Nama jenis layanan (misal: "Deep Clean Standard") |
| C | `harga_jual` | Number | Tarif harga jual layanan ke pelanggan (Rp) |
| D | `tipe_fee` | String | Tipe komisi staff: `"Persentase"` atau `"Nominal"` |
| E | `nilai_fee` | Number | Nilai fee (persen e.g. `20` atau nominal e.g. `10000`) |
| F | `bahan_baku` | Text Multi-line | Resep bahan baku per baris: `1. Nama Item Qty` (misal: `1. Sabun Sepatu 50\n2. Leather Balm 10`) |
| G | `HPP` | Formula | `=CALCULATE_HPP(F{row})` -> Hitung total modal bahan dari sheet Inventory |
| H | `Fee Karyawan` | Formula | `=IF(D{row}="Persentase"; C{row}*(E{row}/100); E{row})` |
| I | `Total Cost` | Formula | `=G{row}+H{row}` |
| J | `Selisih/Margin` | Formula | `=C{row}-I{row}` |
| K | `Status Margin` | Formula | `=IF(J{row}<0; "Rugi"; "Profit")` |
| L | `Persentase Margin` | Formula | `=IF(C{row}=0; 0; J{row}/C{row})` |
| M | `Stok Tersedia` | Formula | `=CALCULATE_STOK(F{row})` -> Estimasi berapa kali treatment bisa dibuat dari stok bahan baku saat ini |

### 5. Sheet `Inventory`
Tabel stok bahan baku operasional.
| Kolom | Nama Field | Tipe Data | Keterangan |
|---|---|---|---|
| A | `id_item` | String | ID item barang (misal `INV...`) |
| B | `nama_item` | String | Nama barang / bahan baku (misal: "Cleaner Sabun") |
| C | `jenis` | String | Kategori: `"Bahan Baku"` atau `"OPEX"` |
| D | `satuan` | String | Satuan terkecil penyimpanan: `"ml"`, `"gram"`, `"pcs"`, `"botol"` |
| E | `harga_satuan` | Number | Harga modal per 1 satuan terkecil di database |
| F | `stok` | Number | Jumlah stok fisik yang tersedia |
| G | `merk` | String | Merk/brand bahan baku |
| H | `id_suplier` | String (FK) | Relasi ke `Suplier.id_suplier` |

### 6. Sheet `CAPEX` (Capital Expenditure)
Tabel perolehan aset modal jangka panjang yang memiliki masa pakai dan depresiasi/penyusutan bulanan (seperti mesin cuci sepatu, dryer, rak display, renovasi).
| Kolom | Nama Field | Tipe Data | Keterangan |
|---|---|---|---|
| A | `id_capex` | String | ID unik CAPEX (misal `CPX...`) |
| B | `nama_barang` | String | Nama barang atau aset modal |
| C | `kategori` | String | Kategori aset: `Peralatan & Mesin`, `Elektronik & Gadget`, `Renovasi & Tempat`, `Furnitur & Display`, `Aset Lainnya` |
| D | `harga_barang` | Number | Harga perolehan aset per unit (Rp) |
| E | `umur_ekonomis` | Number | Masa manfaat aset dalam hitungan **bulan** |
| F | `quantity` | Number | Jumlah kuantitas unit aset |
| G | `tanggal_masuk` | String/Date | Tanggal perolehan aset (`yyyy-MM-dd`) |
| H | `waktu_masuk` | String/Time | Waktu pencatatan aset (`HH.mm`) |
| I | `sisa_umur` | Formula | `=IF(G{row}=""; ""; MAX(0; E{row} - DATEDIF(G{row}; TODAY(); "M")))` |

### 6B. Sheet `OPEX` (Operational Expenditure)
Tabel biaya operasional harian / rutin jangka pendek habis pakai (seperti air galon, listrik toko, internet/wifi, packaging, konsumsi harian). *Catatan: Biaya gaji tidak dimasukkan di sini karena dikelola dan dipotong otomatis melalui sistem Penggajian.*
| Kolom | Nama Field | Tipe Data | Keterangan |
|---|---|---|---|
| A | `id_opex` | String | ID unik OPEX (misal `OPX...`) |
| B | `nama_pengeluaran` | String | Keterangan pengeluaran rutin |
| C | `kategori` | String | Kategori: `Operasional Toko`, `Utilitas (Listrik / Air / WiFi)`, `Konsumsi & Galon`, `Packaging & ATK`, `Kebersihan & Sanitasi`, `Lain-lain` |
| D | `nominal` | Number | Harga satuan pengeluaran (Rp) |
| E | `quantity` | Number | Jumlah item pengeluaran |
| F | `total_biaya` | Formula | `=D{row}*E{row}` |
| G | `tanggal_masuk` | String/Date | Tanggal pengeluaran (`yyyy-MM-dd`) |
| H | `waktu_masuk` | String/Time | Waktu pencatatan pengeluaran (`HH.mm`) |

### 7. Sheet `Transaksi`
Header nota/order dari kasir POS.
| Kolom | Nama Field | Tipe Data | Keterangan |
|---|---|---|---|
| A | `id_transaksi` | String | Nomor nota transaksi (misal `TRX-17283...`) |
| B | `tanggal` | String | Format tanggal `dd-MM-yyyy` |
| C | `waktu` | String | Format waktu `HH:mm` |
| D | `nama_pelanggan` | String | Nama customer |
| E | `no_hp` | String | Nomor telepon / WhatsApp pelanggan |
| F | `nama_kasir` | String | Nama petugas kasir saat checkout |
| G | `total_item` | Number | Total jumlah item dalam nota |
| H | `total_harga` | Number | Grand total tagihan transaksi (Rp) |
| I | `metode_bayar` | String | `"Cash"`, `"Transfer"`, atau `"QRIS"` |
| J | `status_bayar` | String | `"Bayar Sekarang"`, `"Bayar Saat Selesai"`, `"Lunas"`, `"Belum Lunas"` |
| K | `status` | String | Status pengerjaan: `"Dikerjakan"`, `"Selesai"`, `"Diambil"` |
| L | `waktu_selesai` | String | Timestamp pengerjaan selesai (`dd-MM-yyyy HH:mm`) |
| M | `waktu_diambil` | String | Timestamp barang diambil pelanggan (`dd-MM-yyyy HH:mm`) |

### 8. Sheet `Detail_Transaksi`
Item perawatan individual dari setiap transaksi order.
| Kolom | Nama Field | Tipe Data | Keterangan |
|---|---|---|---|
| A | `id_detail` | String | ID unik item detail (misal `{idTrx}_{index}`) |
| B | `id_transaksi` | String (FK) | Relasi ke `Transaksi.id_transaksi` |
| C | `nama_treatment` | String | Nama treatment yang dipilih |
| D | `harga_treatment`| Number | Harga satuan treatment |
| E | `jenis_item` | String | Kategori barang pelanggan (Sneakers, Tas, Topi, Boots, dll.) |
| F | `merek` | String | Merk item (Nike, Adidas, Converse, dll.) |
| G | `warna` | String | Warna sepatu/item |
| H | `ukuran` | String | Ukuran (size) sepatu/item |
| I | `nama_staff` | String | Nama teknisi yang bertanggung jawab mengerjakan |
| J | `status_gaji` | String | Status komisi teknisi: `"Belum Dibayar"` atau `"Sudah Dibayar"` |

### 9. Sheet `Log_Penggajian`
Audit trail pencatatan setiap kali admin melakukan pencairan pembayaran gaji teknisi.
| Kolom | Nama Field | Tipe Data | Keterangan |
|---|---|---|---|
| A | `id_log` | String | ID pembayaran gaji (misal `PAY-{timestamp}`) |
| B | `tanggal_bayar` | String | Waktu pembayaran (`yyyy-MM-dd HH:mm:ss`) |
| C | `nama_staff` | String | Nama staff penerima gaji |
| D | `total_bayar` | Number | Total nominal rupiah gaji yang dicairkan |

### 10. Sheet `Penggajian` (Master Tunjangan & Potongan)
Tabel master tunjangan dan potongan bulanan per staff (diperiksa/dibuat otomatis oleh GAS).
| Kolom | Nama Field | Tipe Data | Keterangan |
|---|---|---|---|
| A | `Nama_Staff` | String | Nama staff teknisi |
| B | `BPJSTK` | Number | Tunjangan BPJS Ketenagakerjaan (Rp) |
| C | `THR` | Number | Tunjangan Hari Raya / Bonus (Rp) |
| D | `Keterlambatan` | Number | Potongan denda keterlambatan kerja (Rp) |

### 11. Sheet `Barang_In`
Sheet monitoring/rekap barang yang saat ini sedang berada di outlet dalam status proses pengerjaan (`status` = `Dikerjakan` atau `Selesai` namun belum `Diambil`).  
*Implementasi*: Dapat menggunakan formula Google Sheets:
```excel
=FILTER(Detail_Transaksi!A2:I, ISNUMBER(MATCH(Detail_Transaksi!B2:B, FILTER(Transaksi!A2:A, Transaksi!K2:K<>"Diambil"), 0)))
```
Atau diakses melalui tab **Barang In** di modul Laporan pada aplikasi Flutter.

### 12. Sheet `Barang_Out`
Sheet monitoring/rekap barang yang sudah selesai dan telah diserahkan kembali kepada pelanggan (`status` = `Diambil`).  
*Implementasi*: Dapat menggunakan formula Google Sheets:
```excel
=FILTER(Detail_Transaksi!A2:I, ISNUMBER(MATCH(Detail_Transaksi!B2:B, FILTER(Transaksi!A2:A, Transaksi!K2:K="Diambil"), 0)))
```

### 13. Sheet `Uang_Real`
Sheet rekap transaksi yang uang pembayarannya sudah riil masuk ke kas (`status_bayar` = `Bayar Sekarang` / `Lunas`, atau status barang sudah `Diambil` dan dilunasi).  
*Implementasi*: Formula filter transaksi dengan status bayar lunas atau terambil.

### 14. Sheet `Uang_Piutang`
Sheet rekap transaksi yang pembayarannya masih tertunda/belum lunas (`status_bayar` = `Bayar Nanti` / `Bayar Saat Selesai` dan belum diambil/dilunasi).

---

## 4. Spesifikasi API Google Apps Script (`Code.gs`)

URL Web App Deployment dikonfigurasi di file Flutter [`lib/utils/constants.dart`](file:///c:/Users/KRISNA/Downloads/Ah%20Shoes/erpahshoes/lib/utils/constants.dart):
```dart
class Constants {
  static const String scriptUrl = 'https://script.google.com/macros/s/.../exec';
}
```

Semua request dikirim via HTTP **GET** dengan query parameter `action`.

### Daftar Endpoint / Action

#### A. Autentikasi & Akun
- `action=login&username=...&password=...`  
  - Mencocokkan username dan password di sheet `Users`.  
  - Mengambil `nama_lengkap` dari sheet `Staff`.  
  - Response sukses: `{"status": "success", "data": {"id_user": "...", "role": "admin|kasir|karyawan", "nama_lengkap": "..."}}`

#### B. Manajemen Staff
- `action=get_staff`: Mengambil seluruh daftar staff digabung dengan kredensial user & role.
- `action=add_staff`: Menerima parameter biodata staff dan kredensial user (`username`, `password`, `role`). Menulis ke sheet `Users` dan `Staff`.
- `action=update_staff`: Mengupdate data profile staff dan password user (jika diisi).
- `action=delete_staff`: Menghapus baris terkait di sheet `Users` dan `Staff`.

#### C. Manajemen Inventory
- `action=get_inventory`: Mengambil seluruh daftar item inventory.
- `action=add_inventory`: Menambahkan bahan baku/OPEX baru.
- `action=update_inventory`: Mengupdate data barang, harga, atau stok.
- `action=delete_inventory`: Menghapus item dari inventory.
- `action=restock`: Menambahkan kuantitas stok tertentu ke item yang sudah ada.

#### D. Manajemen Treatment
- `action=get_treatments`: Mengambil daftar treatment lengkap beserta nilai kolom `stok` yang dikalkulasi formula GAS.
- `action=add_treatment`: Menambahkan layanan baru dan **menyisipkan formula otomatis Google Sheets**:
  - `HPP`: `=CALCULATE_HPP(F{row})`
  - `Fee`: `=IF(D{row}="Persentase"; C{row}*(E{row}/100); E{row})`
  - `Total Cost`: `=G{row}+H{row}`
  - `Margin`: `=C{row}-I{row}`
  - `Status`: `=IF(J{row}<0; "Rugi"; "Profit")`
  - `Margin %`: `=IF(C{row}=0; 0; J{row}/C{row})`
  - `Stok`: `=CALCULATE_STOK(F{row})`
- `action=update_treatment`: Mengupdate layanan dan menyuntikkan ulang formula di atas.
- `action=delete_treatment`: Menghapus baris treatment.

#### E. Manajemen OPEX
- `action=get_opex`: Mengambil seluruh catatan OPEX dan sisa umur.
- `action=add_opex`: Menambahkan pengeluaran aset dengan formula `=IF(G{row}=""; ""; MAX(0; E{row} - DATEDIF(G{row}; TODAY(); "M")))`.
- `action=update_opex`: Mengupdate data aset.
- `action=delete_opex`: Menghapus data aset.

#### F. Manajemen Suplier
- `action=get_suppliers`: Mengambil daftar suplier.
- `action=add_supplier`: Menambah suplier baru.
- `action=update_supplier`: Mengupdate suplier.
- `action=delete_supplier`: Menghapus suplier.

#### G. Point of Sale & Order Transaksi
- `action=add_transaksi`:  
  - Menyimpan header transaksi ke sheet `Transaksi` (status default: `'Dikerjakan'`).  
  - Menyimpan detail item ke sheet `Detail_Transaksi` (status gaji default: `'Belum Dibayar'`).  
  - **Auto-deduct Bahan Baku**: Mem-parsing string bahan baku treatment pada tiap item order, lalu **mengurangi stok** item yang cocok di sheet `Inventory`.
- `action=get_transaksi`: Mengambil seluruh transaksi dan menggabungkan item detailnya dari `Detail_Transaksi`.
- `action=update_status`:  
  - Mengubah status pengerjaan (`'Dikerjakan'` -> `'Selesai'` -> `'Diambil'`).  
  - Mengisi `waktu_selesai` atau `waktu_diambil` dengan format waktu **WITA (Asia/Makassar UTC+8)**.  
  - Dapat memperbarui `metode_bayar` dan `status_bayar` (misal saat customer melunasi ketika mengambil barang).

#### H. Penggajian (Payroll)
- `action=get_penggajian`:  
  - Mengumpulkan fee pengerjaan staff dari `Detail_Transaksi` yang berstatus `'Belum Dibayar'`.  
  - Fee diambil dari kolom `FEE` (Kolom H di sheet `Treatment`) untuk setiap sepatu/item yang dikerjakan oleh staff tersebut.
  - Memisahkan nominal ke dalam:
    - **Uang Real (Siap Dicairkan)**: Sepatu yang pengerjaannya sudah **Selesai dan sudah Diambil** oleh pelanggan (`status == 'Diambil'`).
    - **Uang Piutang**: Sepatu yang **belum selesai** (`Dikerjakan`) atau **belum diambil** oleh pelanggan (`Selesai` namun belum `Diambil`). Fee ini tertahan sebagai piutang sampai sepatu diambil pelanggan.
  - Mengambil data tunjangan/potongan master staff dari sheet `Penggajian` (`BPJSTK`, `THR`, `Keterlambatan`) jika ada.
  - Menghitung: `total_gaji = uang_real + bpjstk + thr - keterlambatan`.
- `action=update_penggajian_master`: Menyimpan nilai master `bpjstk`, `thr`, dan `keterlambatan` staff ke sheet `Penggajian`.
- `action=bayar_gaji`:  
  - Mengubah status gaji pada item sepatu staff di `Detail_Transaksi` menjadi `'Sudah Dibayar'` khusus untuk item yang sudah `Diambil` (Uang Real).  
  - Item sepatu yang masih belum selesai / belum diambil tetap berstatus `'Belum Dibayar'` (Piutang) untuk periode berikutnya.  
  - Mencatat riwayat pembayaran ke sheet `Log_Penggajian` (`id_log`, `tanggal_bayar` format WITA, `nama_staff`, `total_bayar`).

---

## 5. Arsitektur Frontend Flutter (`erpahshoes`)

### Role-Based Access Control (RBAC)
Navigasi dan modul yang muncul di dashboard disesuaikan dengan role pengguna:
1. **Admin**:
   - Memiliki akses ke seluruh modul: **Treatment**, **Inventory**, **Staff**, **Suplier**, **Kasir**, **Jobs/Riwayat**, **Laporan**, dan **Penggajian**.
2. **Kasir**:
   - Memiliki akses ke: **Treatment**, **Kasir**, dan **Jobs/Riwayat**.
3. **Karyawan (Teknisi)**:
   - Memiliki akses ke: **Jobs/Riwayat** (untuk melihat antrian order sepatu yang harus dikerjakan).

### Desain & Tema (`lib/utils/app_theme.dart`)
- Skema warna elegan dan konsisten:
  - `primary`: `#2563EB` (Royal Blue)
  - `background`: `#F8FAFC` (Sleek light background)
  - `surface`: `#FFFFFF`
  - `border`: `#E2E8F0`
  - `textPrimary`: `#1E293B`
  - `textSecondary`: `#64748B`
  - `success`: `#10B981`
  - `error`: `#EF4444`
  - `warning`: `#F59E0B`
- Tipografi: Menggunakan **Google Fonts Open Sans** dan **Inter** untuk keterbacaan tinggi.

---

## 6. Prosedur Deploy & Update Google Apps Script

Jika kode di `erpahshoes/gas/Code.gs` atau `codeGS.txt` diubah, lakukan langkah berikut di Google Apps Script:
1. Buka spreadsheet database Google Sheets.
2. Klik menu **Extensions (Ekstensi)** > **Apps Script**.
3. Salin isi seluruh kode dari [`codeGS.txt`](file:///c:/Users/KRISNA/Downloads/Ah%20Shoes/codeGS.txt) ke editor Apps Script.
4. Klik tombol **Save (Simpan)**.
5. Klik tombol **Deploy (Terapkan)** > **Manage deployments (Kelola penerapan)**.
6. Klik ikon pensil (Edit) pada penerapan aktif > pilih versi **New version (Versi baru)** > klik **Deploy (Terapkan)**.
7. *Catatan:* Jika membuat deployment baru (New Deployment), salin URL Web App yang baru dan perbarui konstanta di [`lib/utils/constants.dart`](file:///c:/Users/KRISNA/Downloads/Ah%20Shoes/erpahshoes/lib/utils/constants.dart).

---

## 7. Pedoman untuk Pengembangan Selanjutnya (Untuk Developer / AI Lain)

Bila Anda ingin menambahkan fitur baru pada proyek ini, ikuti alur standar berikut:
1. **Tentukan Kebutuhan Data di Google Sheets**:
   - Tambahkan kolom baru atau buat tab sheet baru jika diperlukan.
2. **Perbarui Logika Google Apps Script**:
   - Tambahkan handler `action` baru di `doGet(e)` pada `Code.gs` dan salin ke `codeGS.txt`.
   - Lakukan deployment versi baru di Apps Script.
3. **Perbarui Model & Service Flutter**:
   - Sesuaikan file di `lib/models/` dan tambahkan fungsi HTTP request di `lib/services/`.
4. **Perbarui / Buat Tampilan Layar (UI Screen)**:
   - Tambahkan layar di `lib/screens/` dengan tetap memakai `AppTheme` dan komponen standar.
5. **Catat Perubahan pada Riwayat Perubahan di Bawah Ini**:
   - Dokumentasikan apa saja yang diubah agar developer berikutnya memahami konteksnya.

---

## 8. Log Riwayat Perubahan (Changelog)

| Tanggal | Versi | Pengubah | Deskripsi Perubahan |
|---|---|---|---|
| 2026-10-07 | 1.0.0 | Antigravity AI | - Sinkronisasi master kode `codeGS.txt` dengan `Code.gs`.<br>- Pembuatan dokumen komprehensif `PROJECT_DOCUMENTATION.md` sebagai panduan tunggal seluruh sistem ERP (Database 13 sheet, GAS API, Flutter UI, dan RBAC). |
| 2026-10-07 | 1.1.0 | Antigravity AI | - Penyesuaian Zona Waktu ke **WITA (Asia/Makassar UTC+8)** di Google Apps Script dan format tanggal.<br>- Penyempurnaan sistem Penggajian Staff: Fee diambil per treatment & per sepatu dari Kolom H (FEE) di sheet `Treatment`.<br>- Penerapan logika Piutang Staff: Sepatu yang belum selesai (`Dikerjakan`) atau belum diambil (`Selesai` tapi belum `Diambil`) otomatis masuk ke **Piutang Karyawan**.<br>- Uang Real hanya untuk sepatu yang sudah `Diambil` oleh pelanggan.<br>- Pencairan gaji via tombol "Bayar Gaji" hanya mencairkan fee sepatu yang sudah Diambil, sementara sepatu yang belum diambil tetap aman tersimpan sebagai piutang.<br>- Pembaruan UI Penggajian di Flutter menampilkan detail nama pelanggan, jenis/merek sepatu, status pengerjaan, dan badge REAL vs PIUTANG. |
| 2026-10-13 | 1.2.0 | Antigravity AI | - Modul Absensi & Kehadiran (Offline-First Hybrid) dengan integrasi Google Sheets & Google Drive.<br>- Integrasi WebRTC kamera selfie real-time.<br>- Penyelesaian masalah idempotensi sinkronisasi (mencegah data duplikat di spreadsheet).<br>- Pengaturan Titik Lokasi Toko & Radius Presensi dengan deteksi jarak karyawan dan preset Google Maps.<br>- Dukungan Geolocation lintas platform (Web HTML5 Geolocation dan Native GPS). |
