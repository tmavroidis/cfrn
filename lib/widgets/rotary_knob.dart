import 'dart:math';
import 'package:flutter/material.dart';

class RotaryKnob extends StatelessWidget {
  final double value;
  final ValueChanged<double> onChanged;
  final VoidCallback? onTap;
  final String label;

  const RotaryKnob({
    super.key,
    required this.value,
    required this.onChanged,
    this.onTap,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.brown)),
        const SizedBox(height: 4),
        GestureDetector(
          onPanUpdate: (details) {
            // Calculate the angle based on touch position relative to center
            final RenderBox renderBox = context.findRenderObject() as RenderBox;
            final center = renderBox.size.center(Offset.zero);
            final localPos = details.localPosition;
            
            final double angle = atan2(localPos.dy - center.dy, localPos.dx - center.dx);
            // Normalize angle to 0.0 - 1.0 range (matching the pi*0.8 sweep)
            double normalized = (angle + (pi * 0.8)) / (2 * pi * 0.8);
            onChanged(normalized.clamp(0.0, 1.0));
          },
          onTap: onTap,
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey[400],
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 4, offset: const Offset(0, 2)),
              ],
              border: Border.all(color: Colors.black54, width: 2),
              gradient: LinearGradient(
                colors: [Colors.grey[300]!, Colors.grey[600]!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Stack(
              children: [
                Center(
                  child: Transform.rotate(
                    angle: (value * 2 * pi * 0.8) - (pi * 0.8),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: Container(
                        margin: const EdgeInsets.only(top: 4),
                        width: 4,
                        height: 15,
                        decoration: BoxDecoration(
                          color: Colors.red[900],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
