import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/constants.dart';

class StaffService {
  final String scriptUrl = Constants.scriptUrl;

  static List<Map<String, dynamic>>? _cache;

  Future<List<Map<String, dynamic>>> getStaffList({bool forceRefresh = false}) async {
    if (!forceRefresh && _cache != null && _cache!.isNotEmpty) {
      return _cache!;
    }
    try {
      final url = Uri.parse('$scriptUrl?action=get_staff');
      final response = await http.get(url);

      if (response.statusCode == 200 || response.statusCode == 302) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          _cache = List<Map<String, dynamic>>.from(data['data']);
          return _cache!;
        }
      }
    } catch (e) {
      print("Error getStaffList: $e");
    }
    return _cache ?? [];
  }

  static void invalidateCache() {
    _cache = null;
  }

  Future<bool> addStaff(Map<String, String> staffData) async {
    try {
      // Create query parameters
      String queryString = Uri(queryParameters: {
        'action': 'add_staff',
        ...staffData
      }).query;
      
      final url = Uri.parse('$scriptUrl?$queryString');
      final response = await http.get(url);

      if (response.statusCode == 200 || response.statusCode == 302) {
        final data = jsonDecode(response.body);
        return data['status'] == 'success';
      }
    } catch (e) {
      print("Error addStaff: $e");
    }
    return false;
  }

  Future<bool> updateStaff(Map<String, String> staffData) async {
    try {
      String queryString = Uri(queryParameters: {
        'action': 'update_staff',
        ...staffData
      }).query;
      final url = Uri.parse('$scriptUrl?$queryString');
      final response = await http.get(url);
      if (response.statusCode == 200 || response.statusCode == 302) {
        final data = jsonDecode(response.body);
        return data['status'] == 'success';
      }
    } catch (e) {
      print("Error updateStaff: $e");
    }
    return false;
  }

  Future<bool> deleteStaff(String idUser, String idStaff) async {
    try {
      String queryString = Uri(queryParameters: {
        'action': 'delete_staff',
        'id_user': idUser,
        'id_staff': idStaff
      }).query;
      final url = Uri.parse('$scriptUrl?$queryString');
      final response = await http.get(url);
      if (response.statusCode == 200 || response.statusCode == 302) {
        final data = jsonDecode(response.body);
        return data['status'] == 'success';
      }
    } catch (e) {
      print("Error deleteStaff: $e");
    }
    return false;
  }
}
