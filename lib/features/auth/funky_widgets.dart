import 'package:flutter/material.dart';

// 1. FunkyTextField (Unchanged)
class FunkyTextField extends StatelessWidget {
  final String label;
  final bool obscureText;
  final TextEditingController controller;
  final IconData icon;

  const FunkyTextField({
    super.key,
    required this.label,
    required this.controller,
    required this.icon,
    this.obscureText = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.black, width: 3),
        boxShadow: const [
          BoxShadow(
            color: Colors.black,
            offset: Offset(4, 4),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        style: const TextStyle(fontWeight: FontWeight.bold),
        decoration: InputDecoration(
          hintText: label,
          hintStyle: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold),
          prefixIcon: Icon(icon, color: Colors.black),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        ),
      ),
    );
  }
}

// 2. UPDATED FunkyButton (Accepts null)
class FunkyButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed; // <--- CHANGED FROM VoidCallback TO VoidCallback?
  final Color color;
  final Color textColor;

  const FunkyButton({
    super.key,
    required this.text,
    this.onPressed, // <--- No longer 'required'
    required this.color,
    this.textColor = Colors.black,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed, // If null, this simply does nothing (perfect for your use case)
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.black, width: 3),
          boxShadow: const [
            BoxShadow(
              color: Colors.black,
              offset: Offset(4, 4),
            ),
          ],
        ),
        child: Center(
          child: Text(
            text.toUpperCase(),
            style: TextStyle(
              color: textColor,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.0,
            ),
          ),
        ),
      ),
    );
  }
}