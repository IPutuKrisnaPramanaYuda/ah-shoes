class Supplier {
  final String idSuplier;
  final String namaSuplier;
  final String kontak;
  final String alamat;

  Supplier({
    required this.idSuplier,
    required this.namaSuplier,
    required this.kontak,
    required this.alamat,
  });

  factory Supplier.fromJson(Map<String, dynamic> json) {
    return Supplier(
      idSuplier: json['id_suplier']?.toString() ?? '',
      namaSuplier: json['nama_suplier']?.toString() ?? '',
      kontak: json['kontak']?.toString() ?? '',
      alamat: json['alamat']?.toString() ?? '',
    );
  }
}
