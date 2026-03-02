import 'dart:math';
import 'package:flutter/material.dart';

class RotaryDial extends StatefulWidget {
  final Function(int) onStationSelected;
  final int stationCount;
  final String? searchTerm;
  final bool isTuning;
  final double needlePosition;
  final ValueChanged<double> onNeedleChanged;
  final Color backgroundColor;

  const RotaryDial({
    super.key,
    required this.onStationSelected,
    required this.stationCount,
    required this.isTuning,
    required this.needlePosition,
    required this.onNeedleChanged,
    required this.backgroundColor,
    this.searchTerm,
  });

  @override
  State<RotaryDial> createState() => _RotaryDialState();
}

class _RotaryDialState extends State<RotaryDial> with SingleTickerProviderStateMixin {
  late AnimationController _jitterController;

  @override
  void initState() {
    super.initState();
    _jitterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    if (widget.isTuning) _jitterController.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(RotaryDial oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isTuning && !oldWidget.isTuning) {
      _jitterController.repeat(reverse: true);
    } else if (!widget.isTuning && oldWidget.isTuning) {
      _jitterController.stop();
    }
  }

  @override
  void dispose() {
    _jitterController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double dialWidth = constraints.maxWidth;
        final double dialHeight = dialWidth / (16 / 4.5);

        final int randomId = Random().nextInt(10000);
        final String imageUrl = widget.searchTerm != null && widget.searchTerm!.isNotEmpty
            ? 'https://loremflickr.com/400/100/${Uri.encodeComponent(widget.searchTerm!)},landscape?lock=$randomId'
            : 'https://loremflickr.com/400/100/landscape?lock=$randomId';

        return GestureDetector(
          onPanUpdate: (details) {
            final newPosition = widget.needlePosition + (details.delta.dx / dialWidth);
            widget.onNeedleChanged(newPosition.clamp(0.0, 1.0));
          },
          onPanEnd: (details) {
            if (widget.stationCount > 0) {
              final stationIndex = (widget.needlePosition * (widget.stationCount - 1)).round();
              widget.onStationSelected(stationIndex);
            }
          },
          child: SizedBox(
            width: dialWidth,
            height: dialHeight,
            child: Stack(
              alignment: Alignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 500),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.black, width: 2),
                    color: widget.backgroundColor,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8.0),
                    child: Image.asset(
                      'assets/Dial.jpg',
                      width: dialWidth,
                      height: dialHeight,
                      fit: BoxFit.cover,
                      opacity: const AlwaysStoppedAnimation(.6), 
                    ),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8.0),
                    child: Image.network(
                      imageUrl,
                      key: ValueKey(imageUrl), 
                      width: dialWidth,
                      height: dialHeight,
                      fit: BoxFit.cover,
                      opacity: const AlwaysStoppedAnimation(.6), 
                      errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(), 
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return const Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2));
                      },
                    ),
                  ),
                ),
                AnimatedBuilder(
                  animation: _jitterController,
                  builder: (context, child) {
                    final double jitter = widget.isTuning ? (_jitterController.value * 0.01 - 0.005) : 0.0;
                    return TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: widget.needlePosition, end: widget.needlePosition),
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                      builder: (context, pos, child) {
                        return Positioned(
                          left: (pos + jitter).clamp(0.0, 1.0) * (dialWidth - 4) - 1,
                          top: 4,
                          bottom: 4,
                          child: child!,
                        );
                      },
                      child: Container(
                        width: 2,
                        color: Colors.red[700],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
