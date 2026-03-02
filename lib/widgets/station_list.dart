import 'package:flutter/material.dart';
import 'station_card.dart';

class StationList extends StatelessWidget {
  final List<dynamic> stations;
  final String? currentlyPlayingStation;
  final List<dynamic> favouriteStations;
  final Function(dynamic station, int index) onStationTap;
  final Function(dynamic station, int index) onPlayStopToggle;
  final ValueChanged<dynamic> onFavouriteToggle;

  const StationList({
    super.key,
    required this.stations,
    required this.currentlyPlayingStation,
    required this.favouriteStations,
    required this.onStationTap,
    required this.onPlayStopToggle,
    required this.onFavouriteToggle,
  });

  @override
  Widget build(BuildContext context) {
    if (stations.isEmpty) {
      return const Center(child: Text('No stations found.'));
    }

    return ListView.builder(
      shrinkWrap: true,
      primary: false,
      itemCount: stations.length,
      itemBuilder: (context, index) {
        final station = stations[index];
        final isSelected = currentlyPlayingStation != null && 
                          currentlyPlayingStation!.startsWith(station['name']);
        final isFavourite = favouriteStations.any((s) => s['stationuuid'] == station['stationuuid']);
        
        return StationCard(
          station: station,
          isSelected: isSelected,
          isFavourite: isFavourite,
          onTap: () => onStationTap(station, index),
          onPlayStopToggle: () => onPlayStopToggle(station, index),
          onFavouriteToggle: () => onFavouriteToggle(station),
        );
      },
    );
  }
}
