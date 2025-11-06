import 'package:flutter/material.dart';

class UnreadBadge extends StatelessWidget {
  final int count;
  final double size;

  const UnreadBadge({
    Key? key,
    required this.count,
    this.size = 20,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Don't show badge if count is 0
    if (count <= 0) {
      return const SizedBox.shrink();
    }

    // Xuan Gong burgundy color
    const burgundy = Color(0xFF9B1C1C);

    // Format count - show "99+" for counts over 99
    final displayText = count > 99 ? '99+' : count.toString();

    return Container(
      constraints: BoxConstraints(minWidth: size),
      height: size,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: burgundy,
        borderRadius: BorderRadius.circular(size / 2),
      ),
      child: Center(
        child: Text(
          displayText,
          style: TextStyle(
            color: Colors.white,
            fontSize: size * 0.6,
            fontWeight: FontWeight.bold,
            height: 1,
          ),
        ),
      ),
    );
  }
}
