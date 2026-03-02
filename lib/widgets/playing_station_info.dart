import 'package:flutter/material.dart';

class PlayingStationInfo extends StatelessWidget {
  final String? favicon;
  final String? homepage;
  final Function(String) onLaunchUrl;

  const PlayingStationInfo({
    super.key,
    this.favicon,
    this.homepage,
    required this.onLaunchUrl,
  });

  @override
  Widget build(BuildContext context) {
    if ((favicon == null || favicon!.isEmpty) && (homepage == null || homepage!.isEmpty)) {
      return const SizedBox.shrink();
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (favicon != null && favicon!.isNotEmpty)
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              favicon!,
              height: 64,
              width: 64,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
            ),
          ),
        if (homepage != null && homepage!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 16.0),
            child: IconButton(
              icon: const Icon(Icons.home, size: 32, color: Colors.brown),
              tooltip: 'Visit Homepage',
              onPressed: () => onLaunchUrl(homepage!),
            ),
          ),
      ],
    );
  }
}
