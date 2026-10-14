import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/constants.dart';

class AuthService {
  final String scriptUrl = Constants.scriptUrl;

  // Mengembalikan Map berisi role dan nama_lengkap
  Future<Map<String, String>?> login(String username, String password) async {
    try {
      final url = Uri.parse('$scriptUrl?action=login&username=$username&password=$password');
      final response = await http.get(url);

      if (response.statusCode == 200 || response.statusCode == 302) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          return {
            'role': data['data']['role'].toString(),
            'nama_lengkap': data['data']['nama_lengkap'].toString(),
          };
        } else {
          print("Login gagal dari API: ${data['message']}");
          return null; // Login gagal
        }
      } else {
        print("HTTP Error: ${response.statusCode}");
      }
    } catch (e) {
      print("Error during login (Kemungkinan besar CORS di Web): $e");
      return null;
    }
    
    return null;
  }
}

