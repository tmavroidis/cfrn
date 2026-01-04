import 'dart:math';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:audioplayers/audioplayers.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Retro Radio',
      theme: ThemeData(
        primarySwatch: Colors.brown,
        scaffoldBackgroundColor: Colors.brown[100],
      ),
      home: const RadioPage(),
    );
  }
}

class RadioPage extends StatefulWidget {
  const RadioPage({super.key});

  @override
  State<RadioPage> createState() => _RadioPageState();
}

class _RadioPageState extends State<RadioPage> {
  List<dynamic> _countries = [];
  String? _selectedCountry;
  List<dynamic> _stations = [];
  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _currentlyPlayingStation;
  bool _isLoadingCountries = false;
  bool _isLoadingStations = false;
  bool _isResolvingServer = false;
  String? _apiBaseUrl;

  bool _isPowerOn = true;
  PlayerState? _playerState;

  // [FIX] Made types more explicit to prevent runtime errors
  List<Map<String, Object>> _subdivisions = [];
  String? _selectedSubdivision;
  List<dynamic> _filteredStations = [];

  @override
  void initState() {
    super.initState();
    _audioPlayer.onPlayerStateChanged.listen((PlayerState s) {
      if (!mounted) return;
      setState(() {
        _playerState = s;
      });
    });
    _resolveApiServer();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _resolveApiServer() async {
    if (!mounted) return;
    setState(() {
      _isResolvingServer = true;
    });
    try {
      final response = await http.get(Uri.parse('https://all.api.radio-browser.info/json/servers'));
      if (response.statusCode == 200) {
        final servers = json.decode(response.body) as List;
        if (servers.isNotEmpty) {
          final server = servers[Random().nextInt(servers.length)];
          if (!mounted) return;
          setState(() {
            _apiBaseUrl = 'https://${server['name']}';
          });
          await _getCountries();
        } else {
          _showError('No API servers found');
        }
      } else {
        _showError('Failed to resolve API servers');
      }
    } catch (e) {
      _showError('Error resolving API servers: $e');
    }
    if (!mounted) return;
    setState(() {
      _isResolvingServer = false;
    });
  }

  Future<void> _getCountries() async {
    if (_apiBaseUrl == null) return;
    if (!mounted) return;
    setState(() {
      _isLoadingCountries = true;
    });
    try {
      final response = await http.get(Uri.parse('$_apiBaseUrl/json/countries'));
      if (response.statusCode == 200) {
        if (!mounted) return;
        final List<dynamic> countries = json.decode(response.body);
        setState(() {
          _countries = countries;
        });

        var canada = countries.firstWhere((c) => c['name'] == 'Canada', orElse: () => null);
        if (canada != null) {
          final canadaCode = canada['iso_3166_1'];
          await _handleCountryChange(canadaCode);
        }
      } else {
        _showError('Failed to load countries');
      }
    } catch (e) {
      _showError('Error: $e');
    }
    if (!mounted) return;
    setState(() {
      _isLoadingCountries = false;
    });
  }

  Future<void> _handleCountryChange(String countryCode) async {
    setState(() {
      _selectedCountry = countryCode;
      _stations = [];
      _filteredStations = [];
      _subdivisions = [];
      _selectedSubdivision = null;
      _isLoadingStations = true;
    });

    List<dynamic> fetchedStations = [];
    try {
      final response = await http.get(Uri.parse('$_apiBaseUrl/json/stations/bycountrycodeexact/$countryCode'));
      if (response.statusCode == 200) {
        fetchedStations = json.decode(response.body);
      } else {
        _showError('Failed to load stations');
      }
    } catch (e) {
      _showError('Error getting stations: $e');
    }

    if (!mounted) return;

    final Set<String> stateSet = {};
    for (var station in fetchedStations) {
      final state = station['state'];
      if (state != null && state.isNotEmpty) {
        stateSet.add(state);
      }
    }
    final List<String> subdivisionNames = stateSet.toList();
    subdivisionNames.sort();

    // [FIX] Explicitly type the list and maps to be type-safe
    final List<Map<String, Object>> subdivisions = subdivisionNames.map((name) {
      return {
        'name': name,
        'stationcount': fetchedStations.where((s) => s['state'] == name).length,
      };
    }).toList();

    if (subdivisions.length > 1) {
      subdivisions.insert(0, {'name': 'All', 'stationcount': fetchedStations.length});
    }

    setState(() {
      _stations = fetchedStations;
      _filteredStations = List.from(_stations);
      _subdivisions = subdivisions;
      _isLoadingStations = false;
    });
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _playStation(String url, String name) {
    if (!_isPowerOn) {
      setState(() {
        _isPowerOn = true;
      });
    }
    _audioPlayer.play(UrlSource(url));
    if (!mounted) return;
    setState(() {
      _currentlyPlayingStation = name;
    });
  }

  void _stopStation() {
    _audioPlayer.stop();
    if (!mounted) return;
    setState(() {
      _currentlyPlayingStation = null;
    });
  }

  void _onStationTuned(int index) {
    if (_filteredStations.isNotEmpty && index < _filteredStations.length) {
      final station = _filteredStations[index];
      _playStation(station['url_resolved'], station['name']);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Retro Radio', style: GoogleFonts.bungeeInline()),
        actions: [
          Row(
            children: [
              const Text('Power'),
              Switch(
                value: _isPowerOn,
                onChanged: (bool value) {
                  setState(() {
                    _isPowerOn = value;
                    if (!_isPowerOn) {
                      _stopStation();
                    }
                  });
                },
              ),
            ],
          )
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: <Widget>[
              Opacity(
                opacity: _isPowerOn ? 1.0 : 0.4,
                child: AbsorbPointer(
                  absorbing: !_isPowerOn,
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      RotaryDial(
                        stationCount: _filteredStations.length,
                        onStationSelected: _onStationTuned,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        _isPowerOn ? (_currentlyPlayingStation ?? 'Select a station') : 'Radio Off',
                        style: GoogleFonts.orbitron(fontSize: 14, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      if (_isPowerOn)
                        Text(
                          'State: ${_playerState?.toString().split('.').last ?? 'unknown'}',
                          style: GoogleFonts.orbitron(fontSize: 10, color: Colors.black54),
                        ),
                      const SizedBox(height: 20),
                      DropdownButton<String>(
                        isExpanded: true,
                        hint: _isResolvingServer
                            ? const Text('Finding server...')
                            : _isLoadingCountries
                            ? const Text('Loading countries...')
                            : const Text('Select Country'),
                        value: _selectedCountry,
                        onChanged: (String? newValue) {
                          if (newValue != null && newValue != _selectedCountry) {
                            _handleCountryChange(newValue);
                          }
                        },
                        items: _countries.map<DropdownMenuItem<String>>((dynamic value) {
                          return DropdownMenuItem<String>(
                            value: value['iso_3166_1'],
                            child: Text(value['name'], overflow: TextOverflow.ellipsis),
                          );
                        }).toList(),
                      ),
                      if (_subdivisions.length > 1)
                        Padding(
                          padding: const EdgeInsets.only(top: 10.0),
                          child: DropdownButton<String>(
                            isExpanded: true,
                            value: _selectedSubdivision,
                            hint: const Text('Filter by Subdivision'),
                            onChanged: (String? newValue) {
                              setState(() {
                                _selectedSubdivision = newValue;
                                if (newValue == 'All' || newValue == null) {
                                  _filteredStations = List.from(_stations);
                                } else {
                                  _filteredStations = _stations
                                      .where((s) => s['state'] == newValue)
                                      .toList();
                                }
                              });
                            },
                            // [FIX] Safely create DropdownMenuItems with explicit casting
                            items: _subdivisions.map<DropdownMenuItem<String>>((Map<String, Object> subdivision) {
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
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Opacity(
                opacity: _isPowerOn ? 1.0 : 0.4,
                child: AbsorbPointer(
                  absorbing: !_isPowerOn,
                  child: _isLoadingStations
                      ? const Center(child: CircularProgressIndicator())
                      : _filteredStations.isEmpty
                      ? Center(child: Text(_selectedCountry == null ? '' : 'No stations found.'))
                      : ListView.builder(
                    shrinkWrap: true,
                    primary: false,
                    itemCount: _filteredStations.length,
                    itemBuilder: (context, index) {
                      final station = _filteredStations[index];
                      final isSelected = station['name'] == _currentlyPlayingStation;
                      return ListTile(
                        title: Text(station['name']),
                        subtitle: Text(
                            "${station['state'] ?? ''}, ${station['country'] ?? ''}"
                                .trim()),
                        onTap: () => _playStation(station['url_resolved'], station['name']),
                        selected: isSelected,
                        selectedTileColor: Colors.brown[400],
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RotaryDial extends StatefulWidget {
  final Function(int) onStationSelected;
  final int stationCount;

  const RotaryDial({
    super.key,
    required this.onStationSelected,
    required this.stationCount,
  });

  @override
  State<RotaryDial> createState() => _RotaryDialState();
}

class _RotaryDialState extends State<RotaryDial> {
  double _needlePosition = 0.0; // Position from 0.0 to 1.0

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double dialWidth = constraints.maxWidth;
        final double dialHeight = dialWidth / (16 / 4.5);

        return GestureDetector(
          onPanUpdate: (details) {
            final newPosition = _needlePosition + (details.delta.dx / dialWidth);
            setState(() {
              _needlePosition = newPosition.clamp(0.0, 1.0);
            });
          },
          onPanEnd: (details) {
            if (widget.stationCount > 0) {
              final stationIndex = (_needlePosition * (widget.stationCount - 1)).round();
              widget.onStationSelected(stationIndex);
            }
          },
          child: SizedBox(
            width: dialWidth,
            height: dialHeight,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.black, width: 2),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8.0),
                    child: Image.asset(
                      'assets/Dial.jpg',
                      width: dialWidth,
                      height: dialHeight,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                Positioned(
                  left: _needlePosition * (dialWidth - 4) - 1,
                  top: 4,
                  bottom: 4,
                  child: Container(
                    width: 2,
                    color: Colors.red[700],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
