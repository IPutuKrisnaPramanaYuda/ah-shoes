import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/constants.dart';
import '../models/inventory_model.dart';

class InventoryService {
  final String scriptUrl = Constants.scriptUrl;

  Future<List<InventoryItem>> getInventory() async {
    try {
      final url = Uri.parse('$scriptUrl?action=get_inventory');
      final response = await http.get(url);

      if (response.statusCode == 200 || response.statusCode == 302) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          final List list = data['data'];
          return list.map((e) => InventoryItem.fromJson(e)).toList();
        }
      }
    } catch (e) {
      print("Error getInventory: $e");
    }
    return [];
  }

  Future<bool> addInventory(Map<String, String> inventoryData) async {
    try {
      String queryString = Uri(queryParameters: {
        'action': 'add_inventory',
        ...inventoryData
      }).query;
      
      final url = Uri.parse('$scriptUrl?$queryString');
      final response = await http.get(url);

      if (response.statusCode == 200 || response.statusCode == 302) {
        final data = jsonDecode(response.body);
        return data['status'] == 'success';
      }
    } catch (e) {
      print("Error addInventory: $e");
    }
    return false;
  }

  /// Restok: menambahkan stok yang ada dengan jumlah baru
  Future<bool> restockInventory({
    required String idItem,
    required String namaItem,
    required String jenis,
    required String satuan,
    required double hargaSatuan,
    required double stokLama,
    required double stokTambahan,
    required String merk,
    required String idSuplier,
  }) async {
    final double stokBaru = stokLama + stokTambahan;
    final ok = await updateInventory({
      'id_item': idItem,
      'nama_item': namaItem,
      'jenis': jenis,
      'satuan': satuan,
      'harga_satuan': hargaSatuan.toStringAsFixed(2),
      'stok': stokBaru.toString(),
      'merk': merk,
      'id_suplier': idSuplier,
    });

    // Catat ke Log_Restock di Google Sheets
    try {
      final logUrl = Uri.parse(
        '$scriptUrl?action=restock&id_item=${Uri.encodeComponent(idItem)}&tambah_stok=$stokTambahan&harga_satuan=$hargaSatuan'
      );
      await http.get(logUrl);
    } catch (e) {
      print("Error logging restock to GAS: $e");
    }

    return ok;
  }

  Future<List<Map<String, dynamic>>> getLogRestock() async {
    try {
      final url = Uri.parse('$scriptUrl?action=get_log_restock');
      final response = await http.get(url);

      if (response.statusCode == 200 || response.statusCode == 302) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          final List list = data['data'] ?? [];
          return list.map((e) => Map<String, dynamic>.from(e)).toList();
        }
      }
    } catch (e) {
      print("Error getLogRestock: $e");
    }
    return [];
  }

  Future<bool> updateInventory(Map<String, String> inventoryData) async {
    try {
      String queryString = Uri(queryParameters: {
        'action': 'update_inventory',
        ...inventoryData
      }).query;
      final url = Uri.parse('$scriptUrl?$queryString');
      final response = await http.get(url);
      if (response.statusCode == 200 || response.statusCode == 302) {
        final data = jsonDecode(response.body);
        return data['status'] == 'success';
      }
    } catch (e) {
      print("Error updateInventory: $e");
    }
    return false;
  }

  Future<bool> deleteInventory(String idItem) async {
    try {
      String queryString = Uri(queryParameters: {
        'action': 'delete_inventory',
        'id_item': idItem,
      }).query;
      final url = Uri.parse('$scriptUrl?$queryString');
      final response = await http.get(url);
      if (response.statusCode == 200 || response.statusCode == 302) {
        final data = jsonDecode(response.body);
        return data['status'] == 'success';
      }
    } catch (e) {
      print("Error deleteInventory: $e");
    }
    return false;
  }
}
