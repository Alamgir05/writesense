import 'package:flutter/material.dart';

class StyledProgressIndicator extends StatelessWidget {
  final double size;
  const StyledProgressIndicator({super.key, this.size = 40.0});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: const CircularProgressIndicator(
        strokeWidth: 4,
        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6C63FF)),
        backgroundColor: Colors.white10,
      ),
    );
  }
}
