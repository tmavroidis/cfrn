import 'dart:math';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:audioplayers/audioplayers.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:window_manager/window_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    await windowManager.ensureInitialized();
    WindowOptions windowOptions = const WindowOptions(
      size: Size(400, 800),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.normal,
    );
    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
      await windowManager.setResizable(false);
    });
  }

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
  String? _selectedCountryCode;
  String? _selectedCountryName;
  List<dynamic> _stations = [];
  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _currentlyPlayingStation;
  bool _isLoadingCountries = false;
  bool _isLoadingStations = false;
  bool _isResolvingServer = false;
  String? _apiBaseUrl;

  bool _isPowerOn = true;
  PlayerState? _playerState;

  List<Map<String, Object>> _subdivisions = [];
  String? _selectedSubdivision;
  List<dynamic> _filteredStations = [];

  List<dynamic> _favouriteStations = [];
  SharedPreferences? _prefs;

  bool _showStationSelector = false;

  @override
  void initState() {
    super.initState();
    _initPrefs();
    _audioPlayer.onPlayerStateChanged.listen((PlayerState s) {
      if (!mounted) return;
      setState(() {
        _playerState = s;
      });
    });
    _resolveApiServer();
  }

  Future<void> _initPrefs() async {
    _prefs = await SharedPreferences.getInstance();
    _loadFavourites();
  }

  void _loadFavourites() {
    final String? favsJson = _prefs?.getString('favourite_stations');
    if (favsJson != null) {
      setState(() {
        _favouriteStations = json.decode(favsJson);
      });
    }
  }

  Future<void> _saveFavourites() async {
    await _prefs?.setString('favourite_stations', json.encode(_favouriteStations));
  }

  void _toggleFavourite(dynamic station) {
    setState(() {
      final index = _favouriteStations.indexWhere((s) => s['stationuuid'] == station['stationuuid']);
      if (index >= 0) {
        _favouriteStations.removeAt(index);
      } else {
        _favouriteStations.add(Map<String, dynamic>.from(station));
      }
    });
    _saveFavourites();
  }

  // [NEW] Show preset options menu (Rename/Remove)
  void _showPresetOptions(int index) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Rename'),
              onTap: () {
                Navigator.pop(context);
                _renamePreset(index);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Remove from Favourites', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _confirmRemovePreset(index);
              },
            ),
          ],
        );
      },
    );
  }

  void _renamePreset(int index) {
    final TextEditingController controller = TextEditingController(text: _favouriteStations[index]['name']);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Rename Preset'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(hintText: "Enter new name"),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _favouriteStations[index]['name'] = controller.text;
                });
                _saveFavourites();
                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _confirmRemovePreset(int index) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Remove Favourite'),
          content: Text('Are you sure you want to remove "${_favouriteStations[index]['name']}" from your favourites?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _favouriteStations.removeAt(index);
                });
                _saveFavourites();
                Navigator.pop(context);
              },
              child: const Text('Remove', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
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
          await _handleCountryChange(canada['iso_3166_1'], canada['name']);
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

  Future<void> _handleCountryChange(String countryCode, String countryName) async {
    setState(() {
      _selectedCountryCode = countryCode;
      _selectedCountryName = countryName;
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

    final onlineStations = fetchedStations.where((station) {
      final dynamic lastCheck = station['lastcheckok'];
      if (lastCheck is bool) return lastCheck;
      if (lastCheck is int) return lastCheck == 1;
      if (lastCheck is String) return lastCheck == '1' || lastCheck.toLowerCase() == 'true';
      return false;
    }).toList();

    final Set<String> stateSet = {};
    for (var station in onlineStations) {
      final state = station['state'];
      if (state != null && state.isNotEmpty) {
        stateSet.add(state);
      }
    }
    final List<String> subdivisionNames = stateSet.toList();
    subdivisionNames.sort();

    final List<Map<String, Object>> subdivisions = subdivisionNames.map((name) {
      return {
        'name': name,
        'stationcount': onlineStations.where((s) => s['state'] == name).length,
      };
    }).toList();

    if (subdivisions.length > 1) {
      subdivisions.insert(0, {'name': 'All', 'stationcount': onlineStations.length});
    }

    setState(() {
      _stations = onlineStations;
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
                        searchTerm: _selectedSubdivision != null && _selectedSubdivision != 'All' 
                            ? '$_selectedSubdivision, $_selectedCountryName'
                            : _selectedCountryName,
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
                      if (_favouriteStations.isNotEmpty)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Presets:', style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              children: _favouriteStations.asMap().entries.map((entry) {
                                final int index = entry.key;
                                final dynamic station = entry.value;
                                final isPlaying = station['name'] == _currentlyPlayingStation;
                                
                                return GestureDetector(
                                  // [FIX] Updated long-press to show options menu
                                  onLongPress: () => _showPresetOptions(index),
                                  onSecondaryTap: () => _confirmRemovePreset(index),
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: isPlaying ? Colors.brown : Colors.brown[300],
                                      foregroundColor: Colors.white,
                                    ),
                                    onPressed: () => _playStation(station['url_resolved'], station['name']),
                                    child: Text(
                                      station['name'],
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ElevatedButton.icon(
                        icon: Icon(_showStationSelector ? Icons.expand_less : Icons.expand_more),
                        label: const Text('Select Stations'),
                        onPressed: () {
                          setState(() {
                            _showStationSelector = !_showStationSelector;
                          });
                        },
                      ),
                      const SizedBox(height: 20),
                      if (_showStationSelector)
                        Column(
                          children: [
                            DropdownButton<String>(
                              isExpanded: true,
                              hint: _isResolvingServer
                                  ? const Text('Finding server...')
                                  : _isLoadingCountries
                                  ? const Text('Loading countries...')
                                  : const Text('Select Country'),
                              value: _selectedCountryCode,
                              onChanged: (String? newValue) {
                                if (newValue != null && newValue != _selectedCountryCode) {
                                  final country = _countries.firstWhere((c) => c['iso_3166_1'] == newValue);
                                  _handleCountryChange(newValue, country['name']);
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
                            const SizedBox(height: 20),
                            _isLoadingStations
                                ? const CircularProgressIndicator()
                                : _filteredStations.isEmpty
                                ? Center(child: Text(_selectedCountryCode == null ? '' : 'No stations found.'))
                                : ListView.builder(
                              shrinkWrap: true,
                              primary: false,
                              itemCount: _filteredStations.length,
                              itemBuilder: (context, index) {
                                final station = _filteredStations[index];
                                final isSelected = station['name'] == _currentlyPlayingStation;
                                final isFavourite = _favouriteStations.any((s) => s['stationuuid'] == station['stationuuid']);
                                
                                return Card(
                                  color: isSelected ? Colors.brown[200] : Colors.white,
                                  child: ListTile(
                                    title: Text(station['name']),
                                    subtitle: Text(
                                        "${station['state'] ?? ''}, ${station['country'] ?? ''}"
                                            .trim()),
                                    onTap: () => _playStation(station['url_resolved'], station['name']),
                                    selected: isSelected,
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: Icon(
                                            isSelected ? Icons.stop_circle : Icons.play_circle,
                                            color: Colors.brown,
                                          ),
                                          onPressed: () {
                                            if (isSelected) {
                                              _stopStation();
                                            } else {
                                              _playStation(station['url_resolved'], station['name']);
                                            }
                                          },
                                        ),
                                        IconButton(
                                          icon: Icon(
                                            isFavourite ? Icons.favorite : Icons.favorite_border,
                                            color: isFavourite ? Colors.red : Colors.grey,
                                          ),
                                          onPressed: () => _toggleFavourite(station),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                    ],
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
  final String? searchTerm;

  const RotaryDial({
    super.key,
    required this.onStationSelected,
    required this.stationCount,
    this.searchTerm,
  });

  @override
  State<RotaryDial> createState() => _RotaryDialState();
}

class _RotaryDialState extends State<RotaryDial> {
  double _needlePosition = 0.0;

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
                    color: Colors.brown[800],
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
                      errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(), 
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return const Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2));
                      },
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
