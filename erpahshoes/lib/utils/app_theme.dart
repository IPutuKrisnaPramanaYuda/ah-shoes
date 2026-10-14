import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ============================================================
// Design System - ERP Ah Shoes
// Warna utama: Biru Google (#1A73E8) & Putih
// Font: Google Sans via google_fonts
// ============================================================

class AppColors {
  static const primary = Color(0xFF1A73E8);       // Google Blue
  static const primaryLight = Color(0xFFE8F0FE);  // Blue 50
  static const surface = Colors.white;
  static const background = Color(0xFFF8F9FA);
  static const border = Color(0xFFE0E0E0);
  static const textPrimary = Color(0xFF202124);   // Google grey 900
  static const textSecondary = Color(0xFF5F6368); // Google grey 600
  static const textHint = Color(0xFF9AA0A6);      // Google grey 400
  static const divider = Color(0xFFE0E0E0);
  static const success = Color(0xFF137333);
  static const error = Color(0xFFD93025);
}

class AppText {
  // Heading
  static TextStyle h1(BuildContext context) => GoogleFonts.openSans(
    fontSize: _scaled(context, 18), fontWeight: FontWeight.bold, color: AppColors.textPrimary, height: 1.3);
  static TextStyle h2(BuildContext context) => GoogleFonts.openSans(
    fontSize: _scaled(context, 15), fontWeight: FontWeight.bold, color: AppColors.textPrimary);
  static TextStyle h3(BuildContext context) => GoogleFonts.openSans(
    fontSize: _scaled(context, 13), fontWeight: FontWeight.w600, color: AppColors.textPrimary);

  // Body
  static TextStyle body(BuildContext context) => GoogleFonts.openSans(
    fontSize: _scaled(context, 13), color: AppColors.textPrimary);
  static TextStyle bodySmall(BuildContext context) => GoogleFonts.openSans(
    fontSize: _scaled(context, 12), color: AppColors.textSecondary);
  static TextStyle caption(BuildContext context) => GoogleFonts.openSans(
    fontSize: _scaled(context, 11), color: AppColors.textHint);

  // Label / Button
  static TextStyle label(BuildContext context) => GoogleFonts.openSans(
    fontSize: _scaled(context, 13), fontWeight: FontWeight.w600, color: AppColors.primary);

  static double _scaled(BuildContext context, double base) {
    final w = MediaQuery.of(context).size.width;
    if (w < 400) return base * 0.95;
    if (w > 768) return base * 1.05;
    return base;
  }
}

// ============================================================
// Shared Widgets
// ============================================================

/// AppBar standar semua screen
PreferredSizeWidget appBarStandard(BuildContext context, String title, {List<Widget>? actions, bool showBack = true}) {
  return AppBar(
    backgroundColor: AppColors.surface,
    elevation: 0,
    scrolledUnderElevation: 0,
    automaticallyImplyLeading: showBack,
    iconTheme: const IconThemeData(color: AppColors.textPrimary),
    title: Text(title, style: GoogleFonts.openSans(
      fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
    actions: actions,
    bottom: const PreferredSize(
      preferredSize: Size.fromHeight(1),
      child: Divider(height: 1, color: AppColors.divider),
    ),
  );
}

/// TextField seragam
class AppTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final bool isPassword;
  final bool readOnly;
  final bool isRequired;
  final bool isNumber;
  final TextInputAction? textInputAction;

  const AppTextField({
    Key? key,
    required this.controller,
    required this.label,
    this.hint,
    this.isPassword = false,
    this.readOnly = false,
    this.isRequired = true,
    this.isNumber = false,
    this.textInputAction,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        obscureText: isPassword,
        readOnly: readOnly,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        textInputAction: textInputAction,
        style: GoogleFonts.openSans(fontSize: 13, color: AppColors.textPrimary),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          labelStyle: GoogleFonts.openSans(fontSize: 12, color: AppColors.textSecondary),
          hintStyle: GoogleFonts.openSans(fontSize: 12, color: AppColors.textHint),
          filled: true,
          fillColor: readOnly ? AppColors.background : AppColors.surface,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
          errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.error)),
        ),
        validator: isRequired
            ? (value) => (value == null || value.trim().isEmpty) ? '$label wajib diisi' : null
            : null,
      ),
    );
  }
}

/// Dropdown seragam
class AppDropdown extends StatelessWidget {
  final String label;
  final String value;
  final List<String> items;
  final void Function(String?) onChanged;

  const AppDropdown({
    Key? key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: DropdownButtonFormField<String>(
        value: value,
        style: GoogleFonts.openSans(fontSize: 13, color: AppColors.textPrimary),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.openSans(fontSize: 12, color: AppColors.textSecondary),
          filled: true,
          fillColor: AppColors.surface,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
        ),
        items: items.map((i) => DropdownMenuItem(value: i, child: Text(i, style: GoogleFonts.openSans(fontSize: 13)))).toList(),
        onChanged: onChanged,
      ),
    );
  }
}

/// Section header dalam form
class AppSectionTitle extends StatelessWidget {
  final String title;
  const AppSectionTitle(this.title, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 12),
      child: Text(title, style: GoogleFonts.openSans(
        fontSize: 12, fontWeight: FontWeight.bold,
        color: AppColors.textSecondary, letterSpacing: 0.5)),
    );
  }
}

/// Tombol utama full width
class AppPrimaryButton extends StatelessWidget {
  final String label;
  final bool isLoading;
  final VoidCallback? onPressed;
  const AppPrimaryButton({Key? key, required this.label, this.isLoading = false, this.onPressed}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.surface,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: isLoading
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : Text(label, style: GoogleFonts.openSans(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
      ),
    );
  }
}

/// Row detail simpel (label: value)
class AppDetailRow extends StatelessWidget {
  final String label;
  final String value;
  const AppDetailRow(this.label, this.value, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: GoogleFonts.openSans(fontSize: 12, color: AppColors.textSecondary)),
          ),
          Expanded(
            child: Text(value, style: GoogleFonts.openSans(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
          ),
        ],
      ),
    );
  }
}

/// Bottom sheet handle
Widget sheetHandle() => Center(
  child: Container(
    width: 32, height: 4,
    margin: const EdgeInsets.only(bottom: 16),
    decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(4)),
  ),
);
