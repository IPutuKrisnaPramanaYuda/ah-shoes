# 📊 Entity Relationship Diagram (ERD) Database ERP Ah Shoes

Dokumen ini menyajikan pemetaan lengkap arsitektur basis data Google Spreadsheet sistem **Ah Shoes**, mencakup identifikasi entitas, relasi kardinalitas (*One-to-One*, *One-to-Many*, *Many-to-Many*), *junction table*, rumus kalkulasi otomatis (*Google Apps Script custom formula*), serta kamus data (*data dictionary*) menyeluruh.

---

## 1. Visualisasi Diagram ERD (Arsitektur Database)

![Diagram ERD Database Ah Shoes](file:///c:/Users/KRISNA/Downloads/Ah%20Shoes/erd_database_ahshoes.jpg)

---

## 2. Interactive Canvas Diagram (Draw.io Style dalam Markdown)

Diagram canvas interaktif di bawah ini dirender langsung oleh markdown engine menyerupai kanvas Draw.io:

```mermaid
flowchart TD
    %% Styling Class Draw.io
    classDef userClass fill:#0f172a,stroke:#38bdf8,stroke-width:2px,color:#fff;
    classDef staffClass fill:#0f172a,stroke:#818cf8,stroke-width:2px,color:#fff;
    classDef salaryClass fill:#0f172a,stroke:#f59e0b,stroke-width:2px,color:#fff;
    classDef trxClass fill:#0f172a,stroke:#0ea5e9,stroke-width:2px,color:#fff;
    classDef junctionClass fill:#1e1b4b,stroke:#a855f7,stroke-width:3px,color:#fff;
    classDef trtClass fill:#0f172a,stroke:#ec4899,stroke-width:2px,color:#fff;
    classDef invClass fill:#0f172a,stroke:#10b981,stroke-width:2px,color:#fff;
    classDef supClass fill:#0f172a,stroke:#f97316,stroke-width:2px,color:#fff;
    classDef absClass fill:#0f172a,stroke:#f43f5e,stroke-width:2px,color:#fff;

    subgraph SECTION_USER_STAFF ["👤 MODUL AUTENTIKASI & KARYAWAN"]
        USERS["<b>USERS</b><br/>━━━━━━━━━━━━━<br/>🔑 id_user (PK)<br/>• username<br/>• password<br/>• role"]:::userClass
        STAFF["<b>STAFF</b><br/>━━━━━━━━━━━━━<br/>🔑 id_staff (PK)<br/>🔗 id_user (FK)<br/>🏷️ nama_lengkap<br/>• jobdesk<br/>• no_telp (WA)"]:::staffClass
        PENGGAJIAN["<b>PENGGAJIAN</b><br/>━━━━━━━━━━━━━<br/>🔑 Nama_Staff (PK/FK)<br/>• BPJSTK & THR<br/>⚠️ Denda Keterlambatan<br/>• Tunjangan & Kasbon"]:::salaryClass
        ABSENSI["<b>ABSENSI</b><br/>━━━━━━━━━━━━━<br/>🔑 id_absen (PK)<br/>🔗 id_staff (FK)<br/>📍 lokasi_lat_long<br/>📷 link_foto_drive<br/>⏱️ menit_terlambat"]:::absClass
    end

    subgraph SECTION_ORDER ["🛒 MODUL TRANSAKSI & PENGERJAAN SEPATU"]
        TRANSAKSI["<b>TRANSAKSI</b> (Header)<br/>━━━━━━━━━━━━━━━━━<br/>🔑 id_transaksi (PK)<br/>🏷️ nama_pelanggan<br/>📱 no_hp<br/>🔖 kode_unik<br/>💰 total_harga<br/>• status_bayar<br/>• status pengerjaan"]:::trxClass
        DETAIL["<b>DETAIL_TRANSAKSI</b><br/>★ JUNCTION TABLE (M:N) ★<br/>━━━━━━━━━━━━━━━━━<br/>🔑 id_detail (PK)<br/>🔗 id_transaksi (FK)<br/>🔗 nama_treatment (FK)<br/>🔗 nama_staff (FK)<br/>👟 jenis, merek, warna, size<br/>💵 status_gaji (Belum/Sudah)"]:::junctionClass
        TREATMENT["<b>TREATMENT</b><br/>━━━━━━━━━━━━━━━━━<br/>🔑 id_treatment (PK)<br/>🏷️ nama_treatment<br/>💵 harga_jual<br/>🎖️ fee_karyawan<br/>🧪 bahan_baku (Formula M:N)<br/>📦 stok_kemampuan"]:::trtClass
    end

    subgraph SECTION_INVENTORY ["📦 MODUL BAHAN BAKU & SUPPLIER"]
        INVENTORY["<b>INVENTORY</b><br/>━━━━━━━━━━━━━<br/>🔑 id_item (PK)<br/>🏷️ nama_item<br/>📦 stok (Auto Potong)<br/>💵 harga_satuan<br/>🔗 id_suplier (FK)"]:::invClass
        SUPLIER["<b>SUPLIER</b><br/>━━━━━━━━━━━━━<br/>🔑 id_suplier (PK)<br/>🏷️ nama_suplier<br/>📱 kontak<br/>🏢 alamat"]:::supClass
        LOG_RESTOCK["<b>LOG_RESTOCK</b><br/>━━━━━━━━━━━━━<br/>🔑 id_restock (PK)<br/>🔗 id_item (FK)<br/>➕ qty_masuk<br/>💰 total_biaya"]:::supClass
    end

    %% HUBUNGAN RELASI ANTAR ENTITAS
    USERS -->|"1 : 1 (Akun Login)"| STAFF
    STAFF -->|"1 : 1 (Master Saldo Gaji)"| PENGGAJIAN
    STAFF -->|"1 : N (Log Presensi Harian)"| ABSENSI
    ABSENSI -.->|"Akumulasi Denda Menit"| PENGGAJIAN

    TRANSAKSI ==>|"1 : N (Daftar Sepatu)"| DETAIL
    DETAIL <==|"N : 1 (Layanan Dipilih)"| TREATMENT
    STAFF -.->|"1 : N (Teknisi Penanggung Jawab)"| DETAIL

    SUPLIER -->|"1 : N (Pasok Bahan)"| INVENTORY
    INVENTORY -->|"1 : N (Riwayat Pengadaan)"| LOG_RESTOCK
    INVENTORY <===>|"M : N (Resep Takaran & Auto-Cut Stok)"| TREATMENT

---

## 3. Diagram ERD Standar (Mermaid Crow's Foot)

```mermaid
erDiagram
    %% ENTITAS MASTER PENGGUNA & STAFF
    USERS {
        string id_user PK "ID Unik User (USR-xxx)"
        string username "Username Login"
        string password "Password Akun"
        string role "Admin / Kasir / Karyawan"
    }

    STAFF {
        string id_staff PK "ID Unik Karyawan (STF-xxx)"
        string id_user FK "ID User (Relasi ke Users)"
        string nama_lengkap "Nama Lengkap Karyawan"
        string alamat "Alamat Domisili"
        string status_kerja "Tetap / Kontrak / Magang"
        string tanggal_masuk "Tanggal Mulai Bekerja"
        string jobdesk "Teknisi Cuci / Kasir / Finisher"
        string masa_kerja "Lama Masa Kerja"
        string no_telp "Nomor WhatsApp Staff"
    }

    %% ENTITAS INVENTORY & SUPPLIER
    SUPLIER {
        string id_suplier PK "ID Supplier (SUP-xxx)"
        string nama_suplier "Nama Badan / Pemasok"
        string kontak "No Telepon / WhatsApp"
        string alamat "Alamat Kantor Supplier"
    }

    INVENTORY {
        string id_item PK "ID Barang / Bahan Baku (ITM-xxx)"
        string nama_item "Nama Bahan Baku"
        string jenis "Kimia / Detergen / Cat / Kemasan"
        string satuan "ml / pcs / botol / lembar"
        number harga_satuan "Harga Beli per Satuan"
        number stok "Sisa Stok Fisik"
        string merk "Merk Produsen"
        string id_suplier FK "ID Suplier Pemasok"
    }

    LOG_RESTOCK {
        string id_restock PK "ID Log Restock (RST-xxx)"
        string tanggal "Waktu Restock (WITA)"
        string id_item FK "ID Item Bahan Baku"
        string nama_item "Nama Item"
        number qty_masuk "Jumlah Barang Masuk"
        number harga_satuan "Harga Beli Baru"
        number total_biaya "Total Pengeluaran Restock"
    }

    %% ENTITAS SERVICE & TREATMENT
    TREATMENT {
        string id_treatment PK "ID Layanan (TRT-xxx)"
        string nama_treatment "Deep Clean / Repaint / Unyellowing"
        number harga_jual "Harga Jual ke Konsumen"
        string tipe_fee "Nominal / Persentase"
        number nilai_fee "Nilai Komisi Pengerjaan"
        string bahan_baku "Bahan Baku & Takaran per Pasang (M:N Formula)"
        number hpp "Formula: CALCULATE_HPP"
        number fee_karyawan "Formula: Nilai Komisi Karyawan"
        number total_biaya "Formula: HPP + Fee"
        number selisih_profit "Formula: Harga Jual - Total Biaya"
        string status_profit "Profit / Rugi"
        number persen_profit "Persentase Margin Keuntungan"
        number stok_kemampuan "Formula: CALCULATE_STOK"
    }

    %% ENTITAS TRANSAKSI & DETAIL
    TRANSAKSI {
        string id_transaksi PK "No Invoice (TRX-xxx)"
        string tanggal "Tanggal Order (dd-MM-yyyy)"
        string waktu "Waktu Order (HH:mm WITA)"
        string nama_pelanggan "Nama Customer"
        string no_hp "Nomor WhatsApp Customer"
        string nama_kasir "Kasir Penanggung Jawab"
        number total_item "Total Jumlah Pasang Sepatu"
        number total_harga "Total Tagihan Transaksi"
        string metode_bayar "Tunai / Transfer / QRIS"
        string status_bayar "Lunas / Belum Lunas"
        string status "Dikerjakan / Selesai / Diambil"
        string waktu_selesai "Timestamp Sepatu Selesai"
        string waktu_diambil "Timestamp Sepatu Diambil"
        string kode_unik "Kode Unik Lacak Nota Konsumen"
    }

    DETAIL_TRANSAKSI {
        string id_detail PK "ID Item Baris (TRX_1, TRX_2)"
        string id_transaksi FK "ID Header Transaksi"
        string nama_treatment FK "Nama Layanan Treatment"
        number harga_treatment "Harga Treatment Item"
        string jenis_item "Sepatu / Sandal / Tas / Topi"
        string merek "Nike / Adidas / Vans / dll."
        string warna "Warna Dominan Barang"
        string ukuran "Ukuran (Size 42, dll.)"
        string nama_staff FK "Nama Teknisi Penanggung Jawab"
        string status_gaji "Belum Dibayar / Sudah Dibayar"
    }

    %% ENTITAS PENGGAJIAN
    PENGGAJIAN {
        string nama_staff PK "Nama Karyawan (FK ke Staff)"
        number bpjstk "Tunjangan BPJSTK"
        number thr "Tunjangan Hari Raya"
        number keterlambatan "Potongan Denda Absensi Akumulatif"
        number tunjangan "Tunjangan Tambahan"
        number cashbon "Potongan Pinjaman / Kasbon"
    }

    LOG_PENGGAJIAN {
        string id_log PK "ID Pembayaran Gaji (PAY-xxx)"
        string tanggal "Waktu Bayar (WITA)"
        string nama_staff FK "Nama Karyawan Penerima"
        number total_bayar "Total Nominal Gaji Ditransfer"
        string items "Array JSON Rincian Sepatu Diambil"
    }

    %% ENTITAS ABSENSI & PRESENSI
    ABSENSI {
        string id_absen PK "ID Presensi (ABS-xxx)"
        string tanggal "Tanggal Absensi (yyyy-MM-dd)"
        string waktu_absen "Jam & Menit Absen (HH:mm:ss WITA)"
        string id_staff FK "ID Karyawan"
        string nama_staff "Nama Karyawan"
        string tipe "Masuk / Pulang"
        string status "Tepat Waktu / Terlambat X Mnt"
        number menit_terlambat "Jumlah Menit Keterlambatan"
        number potongan_gaji "Total Denda Potongan Gaji"
        string lokasi_lat_long "Koordinat GPS Presensi (Lat, Lng)"
        string link_foto_drive "URL Foto Selfie di Google Drive"
        string waktu_sinkron "Waktu Data Masuk Spreadsheet"
    }

    PENGATURAN_ABSENSI {
        string kunci PK "Key Konfigurasi"
        string nilai "Value Konfigurasi Toko"
    }

    %% ENTITAS KEUANGAN OPERASIONAL & MODAL
    CAPEX {
        string id_capex PK "ID Aset Modal (CPX-xxx)"
        string nama_barang "Nama Aset / Mesin / Inventaris"
        string kategori "Peralatan / Elektronik / Mesin"
        number harga_barang "Harga Pembelian Aset"
        number umur_ekonomis "Masa Manfaat (Bulan)"
        number quantity "Jumlah Unit"
        string tanggal_masuk "Tanggal Pembelian"
        string waktu_masuk "Jam Pembelian"
        string sisa_umur "Formula: Sisa Umur Ekonomis"
    }

    OPEX {
        string id_opex PK "ID Biaya Operasional (OPX-xxx)"
        string nama_pengeluaran "Nama Beban Rutin"
        string kategori "Listrik / Air / Sewa / Konsumsi"
        number nominal "Biaya Satuan"
        number quantity "Volume Pemakaian"
        number total_biaya "Formula: nominal x quantity"
        string tanggal_masuk "Tanggal Pengeluaran"
        string waktu_masuk "Jam Pengeluaran"
    }

    %% RELASI & KARDINALITAS
    USERS ||--|| STAFF : "1 to 1 (Akun Autentikasi)"
    STAFF ||--o{ ABSENSI : "1 to Many (Log Kehadiran Harian)"
    STAFF ||--|| PENGGAJIAN : "1 to 1 (Konfigurasi Gaji Master)"
    STAFF ||--o{ LOG_PENGGAJIAN : "1 to Many (Riwayat Pembayaran Slip)"
    STAFF ||--o{ DETAIL_TRANSAKSI : "1 to Many (Pengerjaan Sepatu)"

    SUPLIER ||--o{ INVENTORY : "1 to Many (Penyedia Bahan Baku)"
    INVENTORY ||--o{ LOG_RESTOCK : "1 to Many (Riwayat Restock)"

    TRANSAKSI ||--|{ DETAIL_TRANSAKSI : "1 to Many (Item Rincian Order)"
    TREATMENT ||--o{ DETAIL_TRANSAKSI : "1 to Many (Layanan Diambil)"

    INVENTORY }o--o{ TREATMENT : "Many to Many (Resep Bahan Baku Treatment)"
```

---

## 2. Klasifikasi Detail Kardinalitas Relasi

### A. Relasi One-to-One (1 : 1)
1. **`USERS` ⟷ `STAFF`**
   * **Deskripsi:** Satu user akun login aplikasi tepat merepresentasikan satu karyawan fisik di toko.
   * **Foreign Key:** `STAFF.id_user` menunjuk ke `USERS.id_user`.
   * **Karakteristik:** Memisahkan data autentikasi login (username, hashed/plain password, role privilege) dari profil sumber daya manusia (alamat, status kerja, jobdesk, tanggal masuk).

2. **`STAFF` ⟷ `PENGGAJIAN`**
   * **Deskripsi:** Satu karyawan memiliki tepat satu baris pengaturan master tunjangan & potongan aktif pada sheet `Penggajian`.
   * **Primary/Foreign Key:** `PENGGAJIAN.nama_staff` mereferensikan `STAFF.nama_lengkap`.
   * **Fungsi:** Menyimpan saldo berjalan untuk kasbon, tunjangan bulanan, BPJS, dan akumulasi penalti keterlambatan yang otomatis bertambah saat karyawan telat absen.

---

### B. Relasi One-to-Many (1 : N)
1. **`SUPLIER` ⟷ `INVENTORY` (1 : N)**
   * **Deskripsi:** Satu supplier memasok **banyak** jenis bahan baku / inventory (misal: Supplier A memasok sabun, cat hitam, dan lem).
   * **Foreign Key:** `INVENTORY.id_suplier` menunjuk ke `SUPLIER.id_suplier`.

2. **`INVENTORY` ⟷ `LOG_RESTOCK` (1 : N)**
   * **Deskripsi:** Satu item bahan baku dapat memiliki **banyak** riwayat transaksi pembelian restock dari waktu ke waktu.
   * **Foreign Key:** `LOG_RESTOCK.id_item` menunjuk ke `INVENTORY.id_item`.

3. **`TRANSAKSI` ⟷ `DETAIL_TRANSAKSI` (1 : N)**
   * **Deskripsi:** Satu invoice nota transaksi memuat **banyak** item sepatu yang dititipkan untuk dicuci/diperbaiki.
   * **Foreign Key:** `DETAIL_TRANSAKSI.id_transaksi` menunjuk ke `TRANSAKSI.id_transaksi`.

4. **`STAFF` ⟷ `ABSENSI` (1 : N)**
   * **Deskripsi:** Satu staff melakukan absensi **berkali-kali** setiap hari (absen masuk dan absen pulang) sepanjang masa kerjanya.
   * **Foreign Key:** `ABSENSI.id_staff` menunjuk ke `STAFF.id_staff`.

5. **`STAFF` ⟷ `LOG_PENGGAJIAN` (1 : N)**
   * **Deskripsi:** Satu staff menerima pencairan gaji **berulang kali** (tiap periode gajian/mingguan).
   * **Foreign Key:** `LOG_PENGGAJIAN.nama_staff` menunjuk ke `STAFF.nama_lengkap`.

6. **`STAFF` ⟷ `DETAIL_TRANSAKSI` (1 : N)**
   * **Deskripsi:** Satu staff teknisi mengerjakan **banyak** pasang sepatu di berbagai transaksi order.
   * **Foreign Key:** `DETAIL_TRANSAKSI.nama_staff` menunjuk ke `STAFF.nama_lengkap`.

7. **`TREATMENT` ⟷ `DETAIL_TRANSAKSI` (1 : N)**
   * **Deskripsi:** Satu paket jenis layanan treatment (misal: "Deep Clean Standard") dipesan pada **banyak** item sepatu pelanggan.
   * **Foreign Key:** `DETAIL_TRANSAKSI.nama_treatment` menunjuk ke `TREATMENT.nama_treatment`.

---

### C. Relasi Many-to-Many (M : N) Beserta Solusi Implementasinya

Di dalam arsitektur database formal, relasi *Many-to-Many* membutuhkan tabel perantara (*Junction Table / Associative Entity*). Pada basis data Google Sheets Ah Shoes, terdapat **dua relasi Many-to-Many utama**:

#### 1. Relasi Many-to-Many Antara `TRANSAKSI` dan `TREATMENT`
* **Konsep Bisnis:**
  * 1 Transaksi dapat mencakup **banyak** Treatment (misal: Budi memesan *Deep Clean* untuk sepatu 1, dan *Repaint Leather* untuk sepatu 2).
  * 1 Treatment yang sama dapat dipesan di **banyak** Transaksi yang berbeda oleh banyak konsumen.
* **Junction Table Fisik:** **`DETAIL_TRANSAKSI`**
  * `DETAIL_TRANSAKSI` bertindak sebagai *Junction Table* yang memecah relasi M:N menjadi dua relasi 1:N:
    * `TRANSAKSI` (1) ⟷ (N) `DETAIL_TRANSAKSI`
    * `TREATMENT` (1) ⟷ (N) `DETAIL_TRANSAKSI`
  * Selain memetakan ID Transaksi dan Nama Treatment, tabel ini menyimpan atribut spesifik fisik barang: `merek`, `warna`, `ukuran`, `jenis_item`, serta teknisi penanggung jawab `nama_staff` dan `status_gaji`.

#### 2. Relasi Many-to-Many Antara `TREATMENT` dan `INVENTORY` (Bahan Baku / Formula Resep)
* **Konsep Bisnis:**
  * 1 Treatment membutuhkan **banyak** bahan baku (misal: *Deep Clean* butuh 15ml *Cleaner Standard*, 5ml *Shoe Conditioner*, dan 1 pcs *Plastik Ziplock*).
  * 1 Bahan baku yang sama digunakan oleh **banyak** Treatment berbeda (misal: *Cleaner Standard* dipakai pada *Fast Clean*, *Deep Clean*, dan *Kids Shoes Clean*).
* **Mekanisme Penghubung di Spreadsheet:**
  * Alih-alih membuat tabel terpisah untuk resep di sheet baru, sistem menggunakan **kolom formula teks multiline terstruktur** pada kolom `bahan_baku` di sheet `Treatment`:
    ```text
    1. cleaner standard 15
    2. shoe conditioner 5
    ```
  * Custom function Apps Script:
    * **`CALCULATE_HPP(bahanBakuStr)`**: Menghubungkan Treatment ke sheet `Inventory`, mengambil harga satuan per ml/pcs, lalu mengalikan takaran untuk menghasilkan total HPP modal per pasang.
    * **`CALCULATE_STOK(bahanBakuStr)`**: Mengecek stok riil masing-masing bahan di sheet `Inventory`, lalu membagi dengan kebutuhan per pasang (`curStok / qtyNeeded`) untuk mengetahui batas maksimal pasang sepatu yang sanggup dikerjakan toko saat ini.
    * **Auto-Deduction saat Order**: Ketika transaksi baru disimpan (`action=add_transaksi`), Apps Script otomatis memotong kuantitas stok di sheet `Inventory` berdasarkan resep treatment tersebut.

---

## 3. Kamus Data Lengkap (Data Dictionary)

### 1. Sheet `Users`
| Kolom | Tipe | Kunci | Keterangan & Aturan |
| :--- | :--- | :--- | :--- |
| `id_user` | String | **PK** | ID akun (contoh: `USR-001`, `USR-002`) |
| `username` | String | Unique | Username untuk autentikasi login aplikasi |
| `password` | String | - | Kata sandi login pengguna |
| `role` | String | - | Hak akses: `Admin`, `Kasir`, atau `Karyawan` |

### 2. Sheet `Staff`
| Kolom | Tipe | Kunci | Keterangan & Aturan |
| :--- | :--- | :--- | :--- |
| `id_staff` | String | **PK** | ID unik karyawan (contoh: `STF-001`) |
| `id_user` | String | **FK** | Mereferensikan `Users.id_user` |
| `nama_lengkap`| String | Unique | Nama lengkap karyawan (dipakai sebagai kunci relasi transaksi & gaji) |
| `alamat` | String | - | Alamat tempat tinggal staff |
| `status_kerja`| String | - | Status kepegawaian (Tetap, Kontrak, Freelance) |
| `tanggal_masuk`| String | - | Tanggal pertama kali aktif bekerja |
| `jobdesk` | String | - | Tugas utama (Teknisi Treatment, Kasir, Bagian Packing) |
| `masa_kerja` | String | - | Durasi pengalaman / lama bekerja |
| `no_telp` | String | - | Nomor WhatsApp staff untuk pengiriman slip gaji |

### 3. Sheet `Suplier`
| Kolom | Tipe | Kunci | Keterangan & Aturan |
| :--- | :--- | :--- | :--- |
| `id_suplier` | String | **PK** | ID unik pemasok (contoh: `SUP-001`) |
| `nama_suplier`| String | - | Nama toko / vendor penyedia bahan baku |
| `kontak` | String | - | Nomor telepon / narahubung supplier |
| `alamat` | String | - | Lokasi fisik gudang / toko supplier |

### 4. Sheet `Inventory`
| Kolom | Tipe | Kunci | Keterangan & Aturan |
| :--- | :--- | :--- | :--- |
| `id_item` | String | **PK** | ID unik bahan baku (contoh: `ITM-001`) |
| `nama_item` | String | Unique | Nama bahan baku (dicocokkan pada resep treatment) |
| `jenis` | String | - | Kategori: Kimia Pembersih, Pewarna, Cat, Lem, Aksesoris |
| `satuan` | String | - | Unit ukur: `ml`, `gr`, `pcs`, `botol` |
| `harga_satuan`| Decimal | - | Harga beli per 1 unit satuan |
| `stok` | Decimal | - | Sisa stok barang riil (berkurang otomatis saat order masuk) |
| `merk` | String | - | Nama pabrikan / produsen |
| `id_suplier` | String | **FK** | Mereferensikan `Suplier.id_suplier` |

### 5. Sheet `Log_Restock`
| Kolom | Tipe | Kunci | Keterangan & Aturan |
| :--- | :--- | :--- | :--- |
| `id_restock` | String | **PK** | ID log pengadaan (contoh: `RST-1728889999`) |
| `tanggal` | DateTime | - | Waktu restock dicatat (`yyyy-MM-dd HH:mm` WITA) |
| `id_item` | String | **FK** | Mereferensikan `Inventory.id_item` |
| `nama_item` | String | - | Nama barang saat pembelian |
| `qty_masuk` | Decimal | - | Volume jumlah barang yang ditambahkan ke stok |
| `harga_satuan`| Decimal | - | Harga beli per unit pada saat restock dilakukan |
| `total_biaya` | Decimal | - | Total uang yang dikeluarkan (`qty_masuk` x `harga_satuan`) |

### 6. Sheet `Treatment`
| Kolom | Tipe | Kunci | Keterangan & Aturan |
| :--- | :--- | :--- | :--- |
| `id_treatment`| String | **PK** | ID paket layanan (contoh: `TRT-001`) |
| `nama_treatment`| String | Unique | Nama layanan (contoh: `Deep Clean`, `Unyellowing Sole`) |
| `harga_jual` | Decimal | - | Harga yang ditagihkan kepada konsumen |
| `tipe_fee` | String | - | Model komisi teknisi: `Nominal` atau `Persentase` |
| `nilai_fee` | Decimal | - | Angka komisi (Rp atau %) |
| `bahan_baku` | Text | **M:N** | Daftar takaran bahan baku (contoh: `1. cleaner standard 15`) |
| `hpp` | Decimal | Formula | `=CALCULATE_HPP(F{row})` dihitung dari sheet Inventory |
| `fee_karyawan`| Decimal | Formula | `=IF(D{row}="Persentase"; C{row}*(E{row}/100); E{row})` |
| `total_biaya` | Decimal | Formula | `=G{row}+H{row}` (HPP + Fee Teknisi) |
| `selisih_profit`| Decimal | Formula | `=C{row}-I{row}` (Harga Jual - Total Biaya) |
| `status_profit`| String | Formula | `=IF(J{row}<0; "Rugi"; "Profit")` |
| `persen_profit`| Decimal | Formula | `=IF(C{row}=0; 0; J{row}/C{row})` |
| `stok_kemampuan`| Integer | Formula | `=CALCULATE_STOK(F{row})` (Kapasitas pasang sepatu yang bisa dicuci) |

### 7. Sheet `Transaksi` (Header)
| Kolom | Tipe | Kunci | Keterangan & Aturan |
| :--- | :--- | :--- | :--- |
| `id_transaksi`| String | **PK** | Nomor invoice transaksi (contoh: `TRX-20261013-001`) |
| `tanggal` | Date | - | Tanggal order masuk (`dd-MM-yyyy`) |
| `waktu` | Time | - | Waktu order masuk (`HH:mm` WITA) |
| `nama_pelanggan`| String | - | Nama pemilik sepatu |
| `no_hp` | String | - | Nomor WhatsApp customer untuk pengiriman nota |
| `nama_kasir` | String | - | Nama petugas kasir yang menerima order |
| `total_item` | Integer | - | Total pasang sepatu dalam invoice |
| `total_harga` | Decimal | - | Total tagihan yang harus dibayar |
| `metode_bayar`| String | - | `Tunai`, `Transfer BCA/Mandiri`, `QRIS` |
| `status_bayar`| String | - | `Lunas` atau `Belum Lunas` |
| `status` | String | - | Status pengerjaan: `Dikerjakan`, `Selesai`, `Diambil` |
| `waktu_selesai`| DateTime | - | Waktu saat seluruh sepatu selesai dikerjakan |
| `waktu_diambil`| DateTime | - | Waktu saat konsumen mengambil sepatu |
| `kode_unik` | String | Unique | Kode unik lacak status nota untuk customer |

### 8. Sheet `Detail_Transaksi` (Junction Table)
| Kolom | Tipe | Kunci | Keterangan & Aturan |
| :--- | :--- | :--- | :--- |
| `id_detail` | String | **PK** | ID baris item (contoh: `TRX-001_1`, `TRX-001_2`) |
| `id_transaksi`| String | **FK** | Menunjuk ke `Transaksi.id_transaksi` |
| `nama_treatment`| String | **FK** | Menunjuk ke `Treatment.nama_treatment` |
| `harga_treatment`| Decimal | - | Harga per item saat transaksi dibuat |
| `jenis_item` | String | - | Kategori barang: Sepatu, Sandal, Tas, Topi |
| `merek` | String | - | Merek sepatu (Nike, Adidas, Converse, dll.) |
| `warna` | String | - | Warna dominan |
| `ukuran` | String | - | Ukuran sepatu (38, 42, 44, dll.) |
| `nama_staff` | String | **FK** | Menunjuk ke `Staff.nama_lengkap` (Teknisi yang mengerjakan) |
| `status_gaji` | String | - | `Belum Dibayar` atau `Sudah Dibayar` |

### 9. Sheet `Penggajian` (Master Saldo & Tunjangan)
| Kolom | Tipe | Kunci | Keterangan & Aturan |
| :--- | :--- | :--- | :--- |
| `Nama_Staff` | String | **PK/FK** | Nama karyawan (relasi ke `Staff.nama_lengkap`) |
| `BPJSTK` | Decimal | - | Nominal tunjangan jaminan kesehatan & ketenagakerjaan |
| `THR` | Decimal | - | Tunjangan Hari Raya |
| `Keterlambatan`| Decimal | - | Akumulasi penalti denda keterlambatan (otomatis bertambah dari Absensi) |
| `Tunjangan` | Decimal | - | Tunjangan operasional / makan / kerajinan |
| `Cashbon` | Decimal | - | Saldo pinjaman kasbon yang memotong gaji |

### 10. Sheet `Log_Penggajian` (Arsip Pencairan Gaji)
| Kolom | Tipe | Kunci | Keterangan & Aturan |
| :--- | :--- | :--- | :--- |
| `id_log` | String | **PK** | ID bukti bayar (contoh: `PAY-1728889999`) |
| `tanggal` | DateTime | - | Waktu pembayaran diverifikasi (`yyyy-MM-dd HH:mm:ss` WITA) |
| `nama_staff` | String | **FK** | Nama karyawan penerima gaji |
| `total_bayar` | Decimal | - | Nominal bersih gaji yang dibayarkan |
| `items` | LongText (JSON)| - | Rekam jejak seluruh sepatu yang sudah berstatus 'Diambil' saat gajian |

### 11. Sheet `Absensi` (Presensi Harian)
| Kolom | Tipe | Kunci | Keterangan & Aturan |
| :--- | :--- | :--- | :--- |
| `id_absen` | String | **PK** | ID unik presensi (contoh: `ABS-1728889999`) |
| `tanggal` | Date | - | Tanggal absensi (`yyyy-MM-dd`) |
| `waktu_absen` | DateTime | - | Jam dan detik saat tombol absen ditekan |
| `id_staff` | String | **FK** | Mereferensikan `Staff.id_staff` |
| `nama_staff` | String | - | Nama karyawan |
| `tipe` | String | - | `Masuk` atau `Pulang` |
| `status` | String | - | `Tepat Waktu` atau `Terlambat X Mnt` |
| `menit_terlambat`| Integer | - | Durasi telat setelah toleransi waktu terlampaui |
| `potongan_gaji`| Decimal | - | Total denda (`menit_terlambat` x `denda_per_menit`) |
| `lokasi_lat_long`| String | - | Koordinat GPS perangkat saat absen (Latitude, Longitude) |
| `link_foto_drive`| String | - | URL foto selfie karyawan di Google Drive |
| `waktu_sinkron`| DateTime | - | Waktu data tersinkronisasi ke Google Sheets |

### 12. Sheet `Pengaturan_Absensi`
| Kunci (Key) | Nilai Default | Keterangan Bisnis |
| :--- | :--- | :--- |
| `jam_masuk` | `08:00` | Batas jam masuk kerja pagi hari |
| `jam_pulang` | `17:00` | Jam kepulangan kerja sore hari |
| `toleransi_menit`| `15` | Waktu toleransi sebelum denda keterlambatan diberlakukan |
| `denda_per_menit`| `1000` | Besaran potongan gaji rupiah per menit keterlambatan |
| `lokasi_lat` | `-8.650000` | Latitude titik toko Ah Shoes |
| `lokasi_lng` | `115.216667`| Longitude titik toko Ah Shoes |
| `radius_meter` | `100` | Radius maksimal (geofence) yang diperbolehkan untuk absen |
| `folder_drive_id`| *(string ID)* | ID Folder Google Drive tempat penyimpanan arsip foto selfie |

### 13. Sheet `CAPEX` (Belanja Modal / Aset)
| Kolom | Tipe | Kunci | Keterangan & Aturan |
| :--- | :--- | :--- | :--- |
| `id_capex` | String | **PK** | ID aset (contoh: `CPX-001`) |
| `nama_barang` | String | - | Nama peralatan (mesin cuci sepatu, steamer, airbrush) |
| `kategori` | String | - | Kategori aset toko |
| `harga_barang`| Decimal | - | Biaya perolehan aset |
| `umur_ekonomis`| Integer | - | Perkiraan umur manfaat (dalam satuan Bulan) |
| `quantity` | Integer | - | Kuantitas unit aset |
| `tanggal_masuk`| Date | - | Tanggal perolehan aset |
| `waktu_masuk` | Time | - | Jam perolehan aset |
| `sisa_umur` | Integer | Formula | `=IF(G{row}=""; ""; MAX(0; E{row} - DATEDIF(G{row}; TODAY(); "M")))` |

### 14. Sheet `OPEX` (Biaya Operasional Rutin)
| Kolom | Tipe | Kunci | Keterangan & Aturan |
| :--- | :--- | :--- | :--- |
| `id_opex` | String | **PK** | ID pengeluaran operasional (contoh: `OPX-001`) |
| `nama_pengeluaran`| String | - | Nama pengeluaran (Listrik, Kuota Internet, Kantong Plastik) |
| `kategori` | String | - | Klasifikasi biaya rutin toko |
| `nominal` | Decimal | - | Harga per satuan pengeluaran |
| `quantity` | Decimal | - | Volume pemakaian |
| `total_biaya` | Decimal | Formula | `=D{row}*E{row}` (nominal x quantity) |
| `tanggal_masuk`| Date | - | Tanggal pengeluaran |
| `waktu_masuk` | Time | - | Waktu pengeluaran |

---

## 4. Alur Integrasi Antar-Entitas (Business Logic Flow)

```
[Transaksi Masuk]
       │
       ├──► 1. Buat Header di TRANSAKSI
       ├──► 2. Buat Item Pasang Sepatu di DETAIL_TRANSAKSI (Junction M:N)
       │         └── Berelasi ke TREATMENT & STAFF penanggung jawab
       └──► 3. Otomatis Potong Stok di INVENTORY (Berdasarkan Resep Bahan Baku M:N)
                     ▲
                     └── Tambah Stok saat Log Restock dicatat di LOG_RESTOCK
                            ▲
                            └── Dipasok oleh SUPLIER

[Siklus Pengerjaan Sepatu & Penggajian Staff]
       │
       ├──► Transaksi: "Dikerjakan" ──► Masuk ke "Uang Piutang Staff" (Belum Bisa Dicairkan)
       ├──► Transaksi: "Selesai"    ──► Masuk ke "Uang Piutang Staff" (Menunggu Diambil Konsumen)
       └──► Transaksi: "Diambil"    ──► Masuk ke "Uang Real Staff" (Siap Dicairkan)
                                              │
       ┌──────────────────────────────────────┴──────────────────────────────────────┐
       ▼                                                                             ▼
[Absensi Karyawan]                                                          [Pencairan Gaji]
  - Catat GPS & Selfie ke Drive                                               - Tarik total Uang Real
  - Terlambat? Hitung menit x denda                                           - Tambah Tunjangan & THR
  - Masukkan denda ke PENGGAJIAN.Keterlambatan ─────────────────────────────► - Kurangi Kasbon & Denda Keterlambatan
                                                                              - Cetak Slip & Simpan ke LOG_PENGGAJIAN
                                                                              - Update status DETAIL_TRANSAKSI = 'Sudah Dibayar'
```
