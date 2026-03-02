import 'package:flutter/material.dart';

class StationFilters extends StatelessWidget {
  final List<dynamic> countries;
  final String? selectedCountryCode;
  final bool isResolvingServer;
  final bool isLoadingCountries;
  final ValueChanged<String?> onCountryChanged;
  final List<Map<String, dynamic>> subdivisions;
  final String? selectedSubdivision;
  final ValueChanged<String?> onSubdivisionChanged;

  const StationFilters({
    super.key,
    required this.countries,
    this.selectedCountryCode,
    required this.isResolvingServer,
    required this.isLoadingCountries,
    required this.onCountryChanged,
    required this.subdivisions,
    this.selectedSubdivision,
    required this.onSubdivisionChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        DropdownButton<String>(
          isExpanded: true,
          hint: isResolvingServer
              ? const Text('Finding server...')
              : isLoadingCountries
                  ? const Text('Loading countries...')
                  : const Text('Select Country'),
          value: selectedCountryCode,
          onChanged: onCountryChanged,
          items: countries.map<DropdownMenuItem<String>>((dynamic value) {
            return DropdownMenuItem<String>(
              value: value['iso_3166_1'],
              child: Text(value['name'], overflow: TextOverflow.ellipsis),
            );
          }).toList(),
        ),
        if (subdivisions.length > 1)
          Padding(
            padding: const EdgeInsets.only(top: 10.0),
            child: DropdownButton<String>(
              isExpanded: true,
              value: selectedSubdivision,
              hint: const Text('Filter by Subdivision'),
              onChanged: onSubdivisionChanged,
              items: subdivisions.map<DropdownMenuItem<String>>((Map<String, dynamic> subdivision) {
                final String name = subdivision['name'] as String;
                final int stationCount = subdivision['stationcount'] as int;
                return DropdownMenuItem<String>(
                  value: name,
                  child: Text(
                    '$name ($stationCount)',
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }
}
