import 'package:flutter/material.dart';

class EinkFlash extends StatelessWidget {
  final bool visible;
  const EinkFlash({super.key, required this.visible});

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();
    return Container(
      color: Colors.black,
      width: double.infinity,
      height: double.infinity,
    );
  }
}
