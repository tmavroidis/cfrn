import 'package:flutter/material.dart';

class StationSelectorHeader extends StatelessWidget {
  final bool showStationSelector;
  final bool isLoadingStations;
  final VoidCallback onToggle;
  final Function(String) onError;

  const StationSelectorHeader({
    super.key,
    required this.showStationSelector,
    required this.isLoadingStations,
    required this.onToggle,
    required this.onError,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ElevatedButton.icon(
          icon: Icon(showStationSelector ? Icons.expand_less : Icons.expand_more),
          label: const Text('Select Stations'),
          onPressed: () {
            if (!showStationSelector && isLoadingStations) {
              onError('wait - stations are being loaded');
            }
            onToggle();
          },
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}
