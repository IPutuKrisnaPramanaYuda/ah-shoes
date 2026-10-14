import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/constants.dart';
import '../models/supplier_model.dart';

class SupplierService {
  final String scriptUrl = Constants.scriptUrl;

  Future<List<Supplier>> getSuppliers() async {
    try {
      final url = Uri.parse('$scriptUrl?action=get_suppliers');
      final response = await http.get(url);

      if (response.statusCode == 200 || response.statusCode == 302) {
        try {
          final data = jsonDecode(response.body);
          if (data['status'] == 'success') {
            final List list = data['data'];
            return list.map((e) => Supplier.fromJson(e)).toList();
          }
        } catch (e) {
          print("Failed to decode JSON. Response body: ${response.body}");
        }
      }
    } catch (e) {
      print("Error getSuppliers: $e");
    }
    return [];
  }

  Future<bool> addSupplier(Map<String, String> supplierData) async {
    try {
      String queryString = Uri(queryParameters: {
        'action': 'add_supplier',
        ...supplierData
      }).query;
      
      final url = Uri.parse('$scriptUrl?$queryString');
      final response = await http.get(url);

      if (response.statusCode == 200 || response.statusCode == 302) {
        try {
          final data = jsonDecode(response.body);
          return data['status'] == 'success';
        } catch (e) {
          print("Failed to decode JSON. Response body: ${response.body}");
        }
      }
    } catch (e) {
      print("Error addSupplier: $e");
    }
    return false;
  }

  Future<bool> updateSupplier(Map<String, String> supplierData) async {
    try {
      String queryString = Uri(queryParameters: {
        'action': 'update_supplier',
        ...supplierData
      }).query;
      final url = Uri.parse('$scriptUrl?$queryString');
      final response = await http.get(url);
      if (response.statusCode == 200 || response.statusCode == 302) {
        try {
          final data = jsonDecode(response.body);
          return data['status'] == 'success';
        } catch (e) {
          print("Failed to decode JSON. Response body: ${response.body}");
        }
      }
    } catch (e) {
      print("Error updateSupplier: $e");
    }
    return false;
  }

  Future<bool> deleteSupplier(String idSuplier) async {
    try {
      String queryString = Uri(queryParameters: {
        'action': 'delete_supplier',
        'id_suplier': idSuplier,
      }).query;
      final url = Uri.parse('$scriptUrl?$queryString');
      final response = await http.get(url);
      if (response.statusCode == 200 || response.statusCode == 302) {
        try {
          final data = jsonDecode(response.body);
          return data['status'] == 'success';
        } catch (e) {
          print("Failed to decode JSON. Response body: ${response.body}");
        }
      }
    } catch (e) {
      print("Error deleteSupplier: $e");
    }
    return false;
  }
}
