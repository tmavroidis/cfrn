import 'package:flutter/material.dart';
import 'station_selector_header.dart';
import 'station_filters.dart';
import 'station_list.dart';

class StationSelector extends StatelessWidget {
  final bool showStationSelector;
  final bool isLoadingStations;
  final VoidCallback onToggle;
  final Function(String) onError;
  final List<dynamic> countries;
  final String? selectedCountryCode;
  final bool isResolvingServer;
  final bool isLoadingCountries;
  final ValueChanged<String?> onCountryChanged;
  final List<Map<String, dynamic>> subdivisions;
  final String? selectedSubdivision;
  final ValueChanged<String?> onSubdivisionChanged;
  final List<dynamic> filteredStations;
  final String? currentlyPlayingStation;
  final List<dynamic> favouriteStations;
  final Function(dynamic station, int index) onStationTap;
  final Function(dynamic station, int index) onPlayStopToggle;
  final ValueChanged<dynamic> onFavouriteToggle;

  const StationSelector({
    super.key,
    required this.showStationSelector,
    required this.isLoadingStations,
    required this.onToggle,
    required this.onError,
    required this.countries,
    this.selectedCountryCode,
    required this.isResolvingServer,
    required this.isLoadingCountries,
    required this.onCountryChanged,
    required this.subdivisions,
    this.selectedSubdivision,
    required this.onSubdivisionChanged,
    required this.filteredStations,
    this.currentlyPlayingStation,
    required this.favouriteStations,
    required this.onStationTap,
    required this.onPlayStopToggle,
    required this.onFavouriteToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        StationSelectorHeader(
          showStationSelector: showStationSelector,
          isLoadingStations: isLoadingStations,
          onToggle: onToggle,
          onError: onError,
        ),
        if (showStationSelector) ...[
          if (isLoadingStations)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Text(
                'wait - stations are being loaded',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.brown),
              ),
            ),
          StationFilters(
            countries: countries,
            selectedCountryCode: selectedCountryCode,
            isResolvingServer: isResolvingServer,
            isLoadingCountries: isLoadingCountries,
            onCountryChanged: onCountryChanged,
            subdivisions: subdivisions,
            selectedSubdivision: selectedSubdivision,
            onSubdivisionChanged: onSubdivisionChanged,
          ),
          const SizedBox(height: 20),
          isLoadingStations
              ? const CircularProgressIndicator()
              : StationList(
                  stations: filteredStations,
                  currentlyPlayingStation: currentlyPlayingStation,
                  favouriteStations: favouriteStations,
                  onStationTap: onStationTap,
                  onPlayStopToggle: onPlayStopToggle,
                  onFavouriteToggle: onFavouriteToggle,
                ),
        ],
      ],
    );
  }
}
