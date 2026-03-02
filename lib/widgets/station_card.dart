import 'package:flutter/material.dart';

class StationCard extends StatelessWidget {
  final dynamic station;
  final bool isSelected;
  final bool isFavourite;
  final VoidCallback onTap;
  final VoidCallback onPlayStopToggle;
  final VoidCallback onFavouriteToggle;

  const StationCard({
    super.key,
    required this.station,
    required this.isSelected,
    required this.isFavourite,
    required this.onTap,
    required this.onPlayStopToggle,
    required this.onFavouriteToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: isSelected ? Colors.brown[200] : Colors.white,
      child: ListTile(
        title: Text(station['name']),
        subtitle: Text(
            "${station['state'] ?? ''}, ${station['country'] ?? ''}"
                .trim()),
        onTap: onTap,
        selected: isSelected,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(
                isSelected ? Icons.stop_circle : Icons.play_circle,
                color: Colors.brown,
              ),
              onPressed: onPlayStopToggle,
            ),
            IconButton(
              icon: Icon(
                isFavourite ? Icons.favorite : Icons.favorite_border,
                color: isFavourite ? Colors.red : Colors.grey,
              ),
              onPressed: onFavouriteToggle,
            ),
          ],
        ),
      ),
    );
  }
}
