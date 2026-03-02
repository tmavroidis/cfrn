import 'dart:math';
import 'dart:io';
import 'dart:typed_data';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';

import '../widgets/rotary_dial.dart';
import '../widgets/tuning_display.dart';
import '../widgets/playing_station_info.dart';
import '../widgets/volume_preset_control.dart';
import '../widgets/preset_grid.dart';
import '../widgets/station_selector.dart';
import '../widgets/radio_app_bar.dart';
import '../widgets/action_button_bar.dart';
import '../widgets/radio_footer.dart';

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
  String? _currentlyPlayingFavicon;
  String? _currentlyPlayingHomepage;
  bool _isLoadingCountries = false;
  bool _isLoadingStations = false;
  bool _isResolvingServer = false;
  String? _apiBaseUrl;

  bool _isPowerOn = true;
  PlayerState? _playerState;

  List<Map<String, dynamic>> _subdivisions = [];
  String? _selectedSubdivision;
  List<dynamic> _filteredStations = [];

  List<dynamic> _favouriteStations = [];
  SharedPreferences? _prefs;

  bool _showStationSelector = false;
  bool _isReorderMode = false;

  bool _isTuning = false;
  double _needlePosition = 0.0;

  double _volume = 0.7;
  int _presetKnobIndex = 0;

  @override
  void initState() {
    super.initState();
    _initPrefs();
    _audioPlayer.onPlayerStateChanged.listen((PlayerState s) {
      if (!mounted) return;
      setState(() {
        _playerState = s;
        if (s == PlayerState.playing || s == PlayerState.stopped || s == PlayerState.paused || s == PlayerState.completed) {
          _isTuning = false;
        }
      });
    });
    _resolveApiServer();
  }

  Future<void> _initPrefs() async {
    _prefs = await SharedPreferences.getInstance();
    _loadFavourites();
    _loadSettings();
    _loadLastStation();
  }

  void _loadFavourites() {
    final String? favsJson = _prefs?.getString('favourite_stations');
    if (favsJson != null) {
      setState(() {
        final decoded = json.decode(favsJson);
        if (decoded is List) {
          _favouriteStations = List<dynamic>.from(decoded.map((item) {
            if (item is Map) {
              return Map<String, dynamic>.from(item);
            }
            return item;
          }));
        }
      });
    }
  }

  void _loadSettings() {
    setState(() {
      _volume = _prefs?.getDouble('volume') ?? 0.7;
      _presetKnobIndex = _prefs?.getInt('preset_knob_index') ?? 0;
    });
    _audioPlayer.setVolume(_volume);
  }

  void _loadLastStation() {
    final String? url = _prefs?.getString('last_station_url');
    final String? name = _prefs?.getString('last_station_name');
    final String? country = _prefs?.getString('last_station_country');
    final String? favicon = _prefs?.getString('last_station_favicon');
    final String? homepage = _prefs?.getString('last_station_homepage');
    final double? needlePos = _prefs?.getDouble('last_needle_pos');

    if (url != null && name != null && country != null) {
      _playStation(url, name, country, 
          needlePos: needlePos, 
          favicon: (favicon != null && favicon.isNotEmpty) ? favicon : null, 
          homepage: (homepage != null && homepage.isNotEmpty) ? homepage : null,
          saveToPrefs: false);
    }
  }

  Future<void> _saveFavourites() async {
    await _prefs?.setString('favourite_stations', json.encode(_favouriteStations));
  }

  Future<String> _getCacheFilePath(String countryCode) async {
    final directory = await getApplicationDocumentsDirectory();
    return '${directory.path}/stations_$countryCode.json';
  }

  Future<void> _cacheStations(String countryCode, List<dynamic> stations) async {
    final path = await _getCacheFilePath(countryCode);
    final file = File(path);
    await file.writeAsString(json.encode(stations));
  }

  Future<List<dynamic>?> _loadCachedStations(String countryCode) async {
    final path = await _getCacheFilePath(countryCode);
    final file = File(path);
    if (await file.exists()) {
      final content = await file.readAsString();
      return json.decode(content);
    }
    return null;
  }

  Future<void> _exportFavourites() async {
    try {
      String jsonString = json.encode(_favouriteStations);
      Uint8List bytes = Uint8List.fromList(utf8.encode(jsonString));
      
      String? outputPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Export Favourites',
        fileName: 'radio_presets.json',
        type: FileType.custom,
        allowedExtensions: ['json'],
        bytes: bytes,
      );

      if (outputPath != null) {
        if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
          final File file = File(outputPath);
          await file.writeAsString(jsonString);
        }
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Favourites exported successfully!')),
        );
      }
    } catch (e) {
      _showError('Export failed: $e');
    }
  }

  Future<void> _importFavourites() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result != null && result.files.single.path != null) {
        final File file = File(result.files.single.path!);
        String content = await file.readAsString();
        List<dynamic> importedFavs = json.decode(content);

        setState(() {
          _favouriteStations = List<dynamic>.from(importedFavs.map((item) {
            if (item is Map) {
              return Map<String, dynamic>.from(item);
            }
            return item;
          }));
        });
        await _saveFavourites();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Favourites imported successfully!')),
        );
      }
    } catch (e) {
      _showError('Import failed: $e');
    }
  }

  void _confirmClearFavourites() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Clear All Presets'),
          content: const Text('Are you sure you want to permanently delete all your favourite station presets?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _favouriteStations = [];
                });
                _saveFavourites();
                Navigator.pop(context);
              },
              child: const Text('Clear All', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
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

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      final item = _favouriteStations.removeAt(oldIndex);
      _favouriteStations.insert(newIndex, item);
    });
    _saveFavourites();
  }

  void _showPresetOptions(int index) {
    final station = _favouriteStations[index];
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Wrap(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    station['name'],
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "${station['state'] ?? ''}, ${station['country'] ?? ''}".trim(),
                    style: const TextStyle(color: Colors.black54),
                  ),
                  const Divider(),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Rename'),
              onTap: () {
                Navigator.pop(context);
                _renamePreset(index);
              },
            ),
            ListTile(
              leading: const Icon(Icons.reorder),
              title: const Text('Reorder Presets'),
              onTap: () {
                Navigator.pop(context);
                setState(() {
                  _isReorderMode = true;
                });
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
      final response = await http.get(Uri.parse('https://all.api.radio-browser.info/json/servers'))
          .timeout(const Duration(seconds: 15));
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
      final response = await http.get(Uri.parse('$_apiBaseUrl/json/countries'))
          .timeout(const Duration(seconds: 15));
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

    List<dynamic>? fetchedStations = await _loadCachedStations(countryCode);

    if (fetchedStations == null) {
      try {
        final response = await http.get(Uri.parse('$_apiBaseUrl/json/stations/bycountrycodeexact/$countryCode'))
            .timeout(const Duration(seconds: 30));
        if (response.statusCode == 200) {
          fetchedStations = json.decode(response.body);
          await _cacheStations(countryCode, fetchedStations!);
        } else {
          _showError('Failed to load stations');
        }
      } catch (e) {
        _showError('Error getting stations: $e');
      }
    }

    if (!mounted || fetchedStations == null) return;

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

    final List<Map<String, dynamic>> subdivisions = subdivisionNames.map((name) {
      return <String, dynamic>{
        'name': name,
        'stationcount': onlineStations.where((s) => s['state'] == name).length,
      };
    }).toList();

    if (subdivisions.length > 1) {
      subdivisions.insert(0, <String, dynamic>{'name': 'All', 'stationcount': onlineStations.length});
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

  void _playStation(String url, String name, String country, {double? needlePos, String? favicon, String? homepage, bool saveToPrefs = true}) {
    if (!_isPowerOn) {
      setState(() {
        _isPowerOn = true;
      });
    }
    setState(() {
      _isTuning = true;
      if (needlePos != null) {
        _needlePosition = needlePos;
      }
    });
    _audioPlayer.play(UrlSource(url)).catchError((e) {
      setState(() => _isTuning = false);
      _showError("Failed to play: $e");
    });
    if (!mounted) return;
    setState(() {
      _currentlyPlayingStation = "$name ($country)";
      _currentlyPlayingFavicon = favicon;
      _currentlyPlayingHomepage = homepage;
    });

    if (saveToPrefs) {
      _prefs?.setString('last_station_url', url);
      _prefs?.setString('last_station_name', name);
      _prefs?.setString('last_station_country', country);
      _prefs?.setString('last_station_favicon', favicon ?? '');
      _prefs?.setString('last_station_homepage', homepage ?? '');
      if (needlePos != null) {
        _prefs?.setDouble('last_needle_pos', needlePos);
      }
    }
  }

  void _stopStation() {
    _audioPlayer.stop();
    if (!mounted) return;
    setState(() {
      _currentlyPlayingStation = null;
      _currentlyPlayingFavicon = null;
      _currentlyPlayingHomepage = null;
      _isTuning = false;
    });
  }

  void _playPreset(int index) {
    if (_favouriteStations.isEmpty || index >= _favouriteStations.length) return;
    final station = _favouriteStations[index];
    final filteredIdx = _filteredStations.indexWhere((s) => s['stationuuid'] == station['stationuuid']);
    double? pos;
    if (filteredIdx >= 0) {
      pos = filteredIdx / (_filteredStations.length > 1 ? _filteredStations.length - 1 : 1);
    }
    _playStation(station['url_resolved'], station['name'], station['country'],
        needlePos: pos, favicon: station['favicon'], homepage: station['homepage']);
  }

  void _onStationTuned(int index) {
    if (_filteredStations.isNotEmpty && index < _filteredStations.length) {
      final station = _filteredStations[index];
      _playStation(station['url_resolved'], station['name'], station['country'], favicon: station['favicon'], homepage: station['homepage']);
    }
  }

  Future<void> _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      _showError('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    Color playerBackgroundColor = Colors.brown[300]!;
    if (_isPowerOn) {
      if (_playerState == PlayerState.playing) {
        playerBackgroundColor = Colors.green[300]!;
      } else if (_playerState == PlayerState.paused) {
        playerBackgroundColor = Colors.yellow[300]!;
      } else if (_playerState == PlayerState.stopped || _playerState == null) {
        playerBackgroundColor = Colors.red[300]!;
      }
    }

    final bool isPortrait = MediaQuery.of(context).orientation == Orientation.portrait;

    return Scaffold(
      appBar: RadioAppBar(
        isPortrait: isPortrait,
        isPowerOn: _isPowerOn,
        onPowerChanged: (bool value) {
          setState(() {
            _isPowerOn = value;
            if (!_isPowerOn) {
              _stopStation();
            }
          });
        },
        onExport: _exportFavourites,
        onImport: _importFavourites,
        onClear: _confirmClearFavourites,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: <Widget>[
              if (isPortrait) 
                Padding(
                  padding: const EdgeInsets.only(bottom: 15.0),
                  child: ActionButtonBar(
                    onExport: _exportFavourites,
                    onImport: _importFavourites,
                    onClear: _confirmClearFavourites,
                  ),
                ),
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
                        isTuning: _isTuning,
                        needlePosition: _needlePosition,
                        onNeedleChanged: (pos) => setState(() => _needlePosition = pos),
                        backgroundColor: playerBackgroundColor,
                        searchTerm: _currentlyPlayingStation ?? (_selectedSubdivision != null && _selectedSubdivision != 'All' 
                            ? '$_selectedSubdivision, $_selectedCountryName'
                            : _selectedCountryName),
                      ),
                      const SizedBox(height: 20),
                      TuningDisplay(
                        isPowerOn: _isPowerOn,
                        currentlyPlayingStation: _currentlyPlayingStation,
                        isTuning: _isTuning,
                        playerState: _playerState?.toString().split('.').last,
                      ),
                      const SizedBox(height: 20),
                      VolumePresetControl(
                        volume: _volume,
                        onVolumeChanged: (val) {
                          setState(() {
                            _volume = val;
                            _audioPlayer.setVolume(_volume);
                          });
                          _prefs?.setDouble('volume', val);
                        },
                        presetKnobIndex: _presetKnobIndex,
                        favouriteStations: _favouriteStations,
                        onPresetKnobChanged: (val) {
                          final newIndex = (val * (_favouriteStations.length - 1)).round();
                          setState(() {
                            _presetKnobIndex = newIndex;
                          });
                          _prefs?.setInt('preset_knob_index', newIndex);
                        },
                        onPresetTap: () => _playPreset(_presetKnobIndex),
                      ),
                      PresetGrid(
                        favouriteStations: _favouriteStations,
                        isReorderMode: _isReorderMode,
                        currentlyPlayingStation: _currentlyPlayingStation,
                        filteredStations: _filteredStations,
                        onReorder: _onReorder,
                        onToggleReorderMode: () => setState(() => _isReorderMode = !_isReorderMode),
                        onPlayStation: (station, needlePos) {
                          final idx = _favouriteStations.indexWhere((s) => s['stationuuid'] == station['stationuuid']);
                          if (idx != -1) {
                            setState(() {
                              _presetKnobIndex = idx;
                            });
                            _prefs?.setInt('preset_knob_index', idx);
                          }
                          _playStation(
                            station['url_resolved'],
                            station['name'],
                            station['country'],
                            needlePos: needlePos,
                            favicon: station['favicon'],
                            homepage: station['homepage'],
                          );
                        },
                        onShowOptions: _showPresetOptions,
                        onRemovePreset: _confirmRemovePreset,
                      ),
                      StationSelector(
                        showStationSelector: _showStationSelector,
                        isLoadingStations: _isLoadingStations,
                        onToggle: () => setState(() => _showStationSelector = !_showStationSelector),
                        onError: _showError,
                        countries: _countries,
                        selectedCountryCode: _selectedCountryCode,
                        isResolvingServer: _isResolvingServer,
                        isLoadingCountries: _isLoadingCountries,
                        onCountryChanged: (String? newValue) {
                          if (newValue != null && newValue != _selectedCountryCode) {
                            final country = _countries.firstWhere((c) => c['iso_3166_1'] == newValue);
                            _handleCountryChange(newValue, country['name']);
                          }
                        },
                        subdivisions: _subdivisions,
                        selectedSubdivision: _selectedSubdivision,
                        onSubdivisionChanged: (String? newValue) {
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
                        filteredStations: _filteredStations,
                        currentlyPlayingStation: _currentlyPlayingStation,
                        favouriteStations: _favouriteStations,
                        onStationTap: (station, index) {
                          final pos = index / (_filteredStations.length > 1 ? _filteredStations.length - 1 : 1);
                          _playStation(station['url_resolved'], station['name'], station['country'], needlePos: pos, favicon: station['favicon'], homepage: station['homepage']);
                        },
                        onPlayStopToggle: (station, index) {
                          final isSelected = _currentlyPlayingStation != null && _currentlyPlayingStation!.startsWith(station['name']);
                          if (isSelected) {
                            _stopStation();
                          } else {
                            final pos = index / (_filteredStations.length > 1 ? _filteredStations.length - 1 : 1);
                            _playStation(station['url_resolved'], station['name'], station['country'], needlePos: pos, favicon: station['favicon'], homepage: station['homepage']);
                          }
                        },
                        onFavouriteToggle: _toggleFavourite,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              PlayingStationInfo(
                favicon: _currentlyPlayingFavicon,
                homepage: _currentlyPlayingHomepage,
                onLaunchUrl: _launchURL,
              ),
              const SizedBox(height: 20),
              const RadioFooter(),
            ],
          ),
        ),
      ),
    );
  }
}
