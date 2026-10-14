import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../utils/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final AuthService _authService = AuthService();

  bool _isLoading = false;
  bool _isPasswordVisible = false;
  bool _rememberMe = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _checkSavedLogin();
  }

  Future<void> _checkSavedLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final savedRole = prefs.getString('role');
    final savedNama = prefs.getString('nama_lengkap');
    if (savedRole != null && mounted) {
      Navigator.pushReplacementNamed(context, '/dashboard',
          arguments: {'role': savedRole, 'nama_lengkap': savedNama ?? ''});
    }
  }

  void _handleLogin() async {
    setState(() { _isLoading = true; _errorMessage = null; });
    final result = await _authService.login(_usernameController.text.trim(), _passwordController.text);
    setState(() => _isLoading = false);

    if (result != null) {
      final role = result['role']!;
      final nama = result['nama_lengkap']!;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('nama_lengkap', nama);
      if (_rememberMe) await prefs.setString('role', role);
      else await prefs.remove('role');
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/dashboard', arguments: {'role': role, 'nama_lengkap': nama});
    } else {
      setState(() => _errorMessage = 'Username atau password salah.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 600;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: isMobile ? 24 : 32, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Ah', style: GoogleFonts.openSans(
                        fontSize: isMobile ? 28 : 32, fontWeight: FontWeight.bold, color: AppColors.primary)),
                      Text('Shoes', style: GoogleFonts.openSans(
                        fontSize: isMobile ? 28 : 32, fontWeight: FontWeight.w300, color: AppColors.textSecondary)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('ERP & Point of Sale', textAlign: TextAlign.center,
                      style: GoogleFonts.openSans(fontSize: 12, color: AppColors.textHint, letterSpacing: 0.4)),
                  const SizedBox(height: 32),

                  // Card login
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Masuk', style: GoogleFonts.openSans(
                          fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                        const SizedBox(height: 4),
                        Text('Masukkan akun yang terdaftar', style: GoogleFonts.openSans(
                          fontSize: 12, color: AppColors.textSecondary)),
                        const SizedBox(height: 20),

                        if (_errorMessage != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFCE8E6),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFF5C6C2)),
                            ),
                            child: Text(_errorMessage!, style: GoogleFonts.openSans(fontSize: 12, color: AppColors.error)),
                          ),
                        ],

                        // Username
                        _buildInput(
                          controller: _usernameController,
                          label: 'Username',
                          hint: 'Masukkan username',
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 12),

                        // Password
                        _buildInput(
                          controller: _passwordController,
                          label: 'Password',
                          hint: 'Masukkan password',
                          isPassword: true,
                          textInputAction: TextInputAction.done,
                          onSubmit: _handleLogin,
                        ),
                        const SizedBox(height: 12),

                        // Remember me
                        Row(
                          children: [
                            SizedBox(
                              height: 20, width: 20,
                              child: Checkbox(
                                value: _rememberMe,
                                onChanged: (v) => setState(() => _rememberMe = v ?? false),
                                activeColor: AppColors.primary,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () => setState(() => _rememberMe = !_rememberMe),
                              child: Text('Ingat Saya', style: GoogleFonts.openSans(fontSize: 12, color: AppColors.textSecondary)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        AppPrimaryButton(label: 'Masuk', isLoading: _isLoading, onPressed: _handleLogin),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInput({
    required TextEditingController controller,
    required String label,
    String? hint,
    bool isPassword = false,
    TextInputAction? textInputAction,
    VoidCallback? onSubmit,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword && !_isPasswordVisible,
      textInputAction: textInputAction,
      style: GoogleFonts.openSans(fontSize: 13, color: AppColors.textPrimary),
      onFieldSubmitted: onSubmit != null ? (_) => onSubmit() : null,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: GoogleFonts.openSans(fontSize: 12, color: AppColors.textSecondary),
        hintStyle: GoogleFonts.openSans(fontSize: 12, color: AppColors.textHint),
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(_isPasswordVisible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    size: 18, color: AppColors.textHint),
                onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
              )
            : null,
      ),
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
