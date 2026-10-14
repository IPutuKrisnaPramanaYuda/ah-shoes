import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/constants.dart';
import '../models/opex_model.dart';

class OpexService {
  final String scriptUrl = Constants.scriptUrl;

  // ==========================================
  // CAPEX (Capital Expenditure / Aset Modal)
  // ==========================================
  Future<List<CapexItem>> getCapex() async {
    try {
      final url = Uri.parse('$scriptUrl?action=get_capex');
      final response = await http.get(url);

      if (response.statusCode == 200 || response.statusCode == 302) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          final List list = data['data'];
          return list.map((e) => CapexItem.fromJson(e)).toList();
        }
      }
    } catch (e) {
      print("Error getCapex: $e");
    }
    return [];
  }

  Future<bool> addCapex(Map<String, String> capexData) async {
    try {
      String queryString = Uri(queryParameters: {
        'action': 'add_capex',
        ...capexData
      }).query;
      
      final url = Uri.parse('$scriptUrl?$queryString');
      final response = await http.get(url);

      if (response.statusCode == 200 || response.statusCode == 302) {
        final data = jsonDecode(response.body);
        return data['status'] == 'success';
      }
    } catch (e) {
      print("Error addCapex: $e");
    }
    return false;
  }

  Future<bool> updateCapex(Map<String, String> capexData) async {
    try {
      String queryString = Uri(queryParameters: {
        'action': 'update_capex',
        ...capexData
      }).query;
      final url = Uri.parse('$scriptUrl?$queryString');
      final response = await http.get(url);
      if (response.statusCode == 200 || response.statusCode == 302) {
        final data = jsonDecode(response.body);
        return data['status'] == 'success';
      }
    } catch (e) {
      print("Error updateCapex: $e");
    }
    return false;
  }

  Future<bool> deleteCapex(String idCapex) async {
    try {
      String queryString = Uri(queryParameters: {
        'action': 'delete_capex',
        'id_capex': idCapex,
      }).query;
      final url = Uri.parse('$scriptUrl?$queryString');
      final response = await http.get(url);
      if (response.statusCode == 200 || response.statusCode == 302) {
        final data = jsonDecode(response.body);
        return data['status'] == 'success';
      }
    } catch (e) {
      print("Error deleteCapex: $e");
    }
    return false;
  }

  // ==========================================
  // OPEX (Operational Expenditure / Biaya Rutin)
  // ==========================================
  Future<List<OpexItem>> getOpex() async {
    try {
      final url = Uri.parse('$scriptUrl?action=get_opex');
      final response = await http.get(url);

      if (response.statusCode == 200 || response.statusCode == 302) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          final List list = data['data'];
          return list.map((e) => OpexItem.fromJson(e)).toList();
        }
      }
    } catch (e) {
      print("Error getOpex: $e");
    }
    return [];
  }

  Future<bool> addOpex(Map<String, String> opexData) async {
    try {
      String queryString = Uri(queryParameters: {
        'action': 'add_opex',
        ...opexData
      }).query;
      
      final url = Uri.parse('$scriptUrl?$queryString');
      final response = await http.get(url);

      if (response.statusCode == 200 || response.statusCode == 302) {
        final data = jsonDecode(response.body);
        return data['status'] == 'success';
      }
    } catch (e) {
      print("Error addOpex: $e");
    }
    return false;
  }

  Future<bool> updateOpex(Map<String, String> opexData) async {
    try {
      String queryString = Uri(queryParameters: {
        'action': 'update_opex',
        ...opexData
      }).query;
      final url = Uri.parse('$scriptUrl?$queryString');
      final response = await http.get(url);
      if (response.statusCode == 200 || response.statusCode == 302) {
        final data = jsonDecode(response.body);
        return data['status'] == 'success';
      }
    } catch (e) {
      print("Error updateOpex: $e");
    }
    return false;
  }

  Future<bool> deleteOpex(String idOpex) async {
    try {
      String queryString = Uri(queryParameters: {
        'action': 'delete_opex',
        'id_opex': idOpex,
      }).query;
      final url = Uri.parse('$scriptUrl?$queryString');
      final response = await http.get(url);
      if (response.statusCode == 200 || response.statusCode == 302) {
        final data = jsonDecode(response.body);
        return data['status'] == 'success';
      }
    } catch (e) {
      print("Error deleteOpex: $e");
    }
    return false;
  }
}
