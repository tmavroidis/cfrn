import 'package:flutter/material.dart';
import 'package:reorderables/reorderables.dart';
import 'preset_button.dart';

class PresetGrid extends StatelessWidget {
  final List<dynamic> favouriteStations;
  final bool isReorderMode;
  final String? currentlyPlayingStation;
  final List<dynamic> filteredStations;
  final Function(int oldIndex, int newIndex) onReorder;
  final VoidCallback onToggleReorderMode;
  final Function(dynamic station, double? needlePos) onPlayStation;
  final Function(int index) onShowOptions;
  final Function(int index) onRemovePreset;

  const PresetGrid({
    super.key,
    required this.favouriteStations,
    required this.isReorderMode,
    this.currentlyPlayingStation,
    required this.filteredStations,
    required this.onReorder,
    required this.onToggleReorderMode,
    required this.onPlayStation,
    required this.onShowOptions,
    required this.onRemovePreset,
  });

  @override
  Widget build(BuildContext context) {
    if (favouriteStations.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Presets:', style: TextStyle(fontWeight: FontWeight.bold)),
            if (isReorderMode)
              TextButton.icon(
                icon: const Icon(Icons.check),
                label: const Text('Done'),
                onPressed: onToggleReorderMode,
              ),
          ],
        ),
        const SizedBox(height: 8),
        ReorderableWrap(
          spacing: 12,
          runSpacing: 12,
          onReorder: onReorder,
          enableReorder: isReorderMode,
          children: favouriteStations.asMap().entries.map((entry) {
            final int index = entry.key;
            final dynamic station = entry.value;
            final isPlaying = currentlyPlayingStation != null &&
                currentlyPlayingStation!.startsWith(station['name']);

            return PresetButton(
              key: ValueKey(station['stationuuid']),
              index: index,
              station: station,
              isPlaying: isPlaying,
              isReorderMode: isReorderMode,
              onTap: isReorderMode
                  ? null
                  : () {
                      final filteredIdx = filteredStations.indexWhere(
                          (s) => s['stationuuid'] == station['stationuuid']);
                      double? pos;
                      if (filteredIdx >= 0) {
                        pos = filteredIdx /
                            (filteredStations.length > 1
                                ? filteredStations.length - 1
                                : 1);
                      }
                      onPlayStation(station, pos);
                    },
              onLongPress: isReorderMode ? null : () => onShowOptions(index),
              onSecondaryTap: isReorderMode ? null : () => onRemovePreset(index),
            );
          }).toList(),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}
