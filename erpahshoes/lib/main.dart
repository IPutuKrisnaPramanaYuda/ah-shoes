import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'screens/login_screen.dart';
import 'screens/dashboard/dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID', null);
  runApp(const AhShoesApp());
}

class AhShoesApp extends StatelessWidget {
  const AhShoesApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ah Shoes ERP',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        textTheme: GoogleFonts.interTextTheme(
          Theme.of(context).textTheme,
        ),
      ),
      initialRoute: '/login',
      onGenerateRoute: (settings) {
        if (settings.name == '/login') {
          return MaterialPageRoute(builder: (context) => const LoginScreen());
        }
        if (settings.name == '/dashboard') {
          final args = settings.arguments as Map<String, String>? ?? {'role': 'karyawan', 'nama_lengkap': 'Demo'};
          return MaterialPageRoute(
            builder: (context) => DashboardScreen(
              role: args['role']!, 
              namaLengkap: args['nama_lengkap']!
            ),
          );
        }
        return null;
      },
    );
  }
}

