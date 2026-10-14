class CapexItem {
  final String idCapex;
  final String namaBarang;
  final String kategori;
  final double hargaBarang;
  final int umurEkonomis;
  final int quantity;
  final String tanggalMasuk;
  final String waktuMasuk;
  final String sisaUmur;

  CapexItem({
    required this.idCapex,
    required this.namaBarang,
    required this.kategori,
    required this.hargaBarang,
    required this.umurEkonomis,
    required this.quantity,
    required this.tanggalMasuk,
    required this.waktuMasuk,
    required this.sisaUmur,
  });

  factory CapexItem.fromJson(Map<String, dynamic> json) {
    return CapexItem(
      idCapex: json['id_capex']?.toString() ?? json['id_opex']?.toString() ?? '',
      namaBarang: json['nama_barang']?.toString() ?? json['pengeluaran']?.toString() ?? '',
      kategori: json['kategori']?.toString() ?? '',
      hargaBarang: double.tryParse(json['harga_barang']?.toString() ?? '0') ?? 0,
      umurEkonomis: int.tryParse(json['umur_ekonomis']?.toString() ?? '1') ?? 1,
      quantity: int.tryParse(json['quantity']?.toString() ?? '1') ?? 1,
      tanggalMasuk: json['tanggal_masuk']?.toString() ?? '',
      waktuMasuk: json['waktu_masuk']?.toString() ?? '',
      sisaUmur: json['sisa_umur']?.toString() ?? '',
    );
  }

  double get biayaPerBulan {
    if (umurEkonomis <= 0) return 0;
    return (hargaBarang / umurEkonomis) * quantity;
  }
}

class OpexItem {
  final String idOpex;
  final String namaPengeluaran;
  final String kategori;
  final double nominal;
  final double quantity;
  final double totalBiaya;
  final String tanggalMasuk;
  final String waktuMasuk;

  OpexItem({
    required this.idOpex,
    required this.namaPengeluaran,
    required this.kategori,
    required this.nominal,
    required this.quantity,
    required this.totalBiaya,
    required this.tanggalMasuk,
    required this.waktuMasuk,
  });

  factory OpexItem.fromJson(Map<String, dynamic> json) {
    final nom = double.tryParse(json['nominal']?.toString() ?? json['harga_barang']?.toString() ?? '0') ?? 0;
    final qty = double.tryParse(json['quantity']?.toString() ?? '1') ?? 1;
    final tot = double.tryParse(json['total_biaya']?.toString() ?? '') ?? (nom * qty);

    return OpexItem(
      idOpex: json['id_opex']?.toString() ?? '',
      namaPengeluaran: json['nama_pengeluaran']?.toString() ?? json['pengeluaran']?.toString() ?? '',
      kategori: json['kategori']?.toString() ?? '',
      nominal: nom,
      quantity: qty,
      totalBiaya: tot,
      tanggalMasuk: json['tanggal_masuk']?.toString() ?? '',
      waktuMasuk: json['waktu_masuk']?.toString() ?? '',
    );
  }
}
