import 'package:flutter/material.dart';

class PresetButton extends StatelessWidget {
  final int index;
  final dynamic station;
  final bool isPlaying;
  final bool isReorderMode;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onSecondaryTap;

  const PresetButton({
    super.key,
    required this.index,
    required this.station,
    required this.isPlaying,
    required this.isReorderMode,
    this.onTap,
    this.onLongPress,
    this.onSecondaryTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: "${station['name']}\n${station['state'] ?? ''}, ${station['country'] ?? ''}\nQuick press to select, long press to modify",
      waitDuration: const Duration(seconds: 2),
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        onSecondaryTap: onSecondaryTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 45,
          height: 45,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isPlaying ? Colors.brown : Colors.brown[300],
            border: isReorderMode 
                ? Border.all(color: Colors.white, width: 2) 
                : Border.all(color: Colors.black26, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 4,
                offset: const Offset(0, 2),
              )
            ],
          ),
          child: Center(
            child: (station['favicon'] != null && station['favicon'].toString().isNotEmpty)
                ? ClipOval(
                    child: Image.network(
                      station['favicon'],
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Text(
                        '${index + 1}',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                  )
                : Text(
                    '${index + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
