import 'dart:math';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:audioplayers/audioplayers.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:window_manager/window_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:reorderables/reorderables.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    await windowManager.ensureInitialized();
    WindowOptions windowOptions = const WindowOptions(
      size: Size(400, 800),
      minimumSize: Size(300, 600),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.normal,
    );
    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
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
  String? _currentlyPlayingFavicon;
  String? _currentlyPlayingHomepage;
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
  bool _isReorderMode = false;

  bool _isTuning = false;
  double _needlePosition = 0.0;

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

  Future<void> _exportFavourites() async {
    try {
      String jsonString = json.encode(_favouriteStations);
      // [FIX] Required bytes for mobile platforms
      Uint8List bytes = Uint8List.fromList(utf8.encode(jsonString));
      
      String? outputPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Export Favourites',
        fileName: 'radio_presets.json',
        type: FileType.custom,
        allowedExtensions: ['json'],
        bytes: bytes, // [FIX] Passing the required bytes
      );

      if (outputPath != null) {
        // Desktop platforms might still need manual write
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
          _favouriteStations = importedFavs;
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

  void _playStation(String url, String name, String country, {double? needlePos, String? favicon, String? homepage}) {
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
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image.asset(
                'assets/radio.jpg',
                height: 32,
                width: 32,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                'Retro Radio',
                style: GoogleFonts.bungeeInline(),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          // Desktop specific header buttons
          if (!isPortrait) ...[
            IconButton(
              icon: const Icon(Icons.file_download),
              tooltip: 'Export Favourites',
              onPressed: _exportFavourites,
            ),
            IconButton(
              icon: const Icon(Icons.file_upload),
              tooltip: 'Import Favourites',
              onPressed: _importFavourites,
            ),
          ],
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
              // [NEW] Mobile specific transfer buttons line
              if (isPortrait) 
                Padding(
                  padding: const EdgeInsets.only(bottom: 10.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextButton.icon(
                        icon: const Icon(Icons.file_download),
                        label: const Text('Export'),
                        onPressed: _exportFavourites,
                      ),
                      const SizedBox(width: 20),
                      TextButton.icon(
                        icon: const Icon(Icons.file_upload),
                        label: const Text('Import'),
                        onPressed: _importFavourites,
                      ),
                    ],
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
                          _isTuning ? 'Tuning...' : 'State: ${_playerState?.toString().split('.').last ?? 'unknown'}',
                          style: GoogleFonts.orbitron(fontSize: 10, color: Colors.black54),
                        ),
                      const SizedBox(height: 20),
                      if (_favouriteStations.isNotEmpty)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Presets:', style: TextStyle(fontWeight: FontWeight.bold)),
                                if (_isReorderMode)
                                  TextButton.icon(
                                    icon: const Icon(Icons.check),
                                    label: const Text('Done'),
                                    onPressed: () => setState(() => _isReorderMode = false),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ReorderableWrap(
                              spacing: 12,
                              runSpacing: 12,
                              onReorder: _onReorder,
                              enableReorder: _isReorderMode, 
                              children: _favouriteStations.asMap().entries.map((entry) {
                                final int index = entry.key;
                                final dynamic station = entry.value;
                                final isPlaying = _currentlyPlayingStation != null && _currentlyPlayingStation!.startsWith(station['name']);
                                
                                return Tooltip(
                                  message: "${station['name']}\n${station['state'] ?? ''}, ${station['country'] ?? ''}\nQuick press to select, long press to modify",
                                  waitDuration: const Duration(seconds: 2),
                                  child: GestureDetector(
                                    key: ValueKey(station['stationuuid']),
                                    onTap: _isReorderMode ? null : () {
                                      final filteredIdx = _filteredStations.indexWhere((s) => s['stationuuid'] == station['stationuuid']);
                                      double? pos;
                                      if (filteredIdx >= 0) {
                                        pos = filteredIdx / (_filteredStations.length > 1 ? _filteredStations.length - 1 : 1);
                                      }
                                      _playStation(station['url_resolved'], station['name'], station['country'], needlePos: pos, favicon: station['favicon'], homepage: station['homepage']);
                                    },
                                    onLongPress: _isReorderMode ? null : () => _showPresetOptions(index),
                                    onSecondaryTap: _isReorderMode ? null : () => _confirmRemovePreset(index),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 300),
                                      width: 45,
                                      height: 45,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: isPlaying ? Colors.brown : Colors.brown[300],
                                        border: _isReorderMode 
                                            ? Border.all(color: Colors.white, width: 2) 
                                            : Border.all(color: Colors.black26, width: 1),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.2),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          )
                                        ],
                                      ),
                                      child: Center(
                                        child: Text(
                                          '${index + 1}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
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
                                final isSelected = _currentlyPlayingStation != null && _currentlyPlayingStation!.startsWith(station['name']);
                                final isFavourite = _favouriteStations.any((s) => s['stationuuid'] == station['stationuuid']);
                                
                                return Card(
                                  color: isSelected ? Colors.brown[200] : Colors.white,
                                  child: ListTile(
                                    title: Text(station['name']),
                                    subtitle: Text(
                                        "${station['state'] ?? ''}, ${station['country'] ?? ''}"
                                            .trim()),
                                    onTap: () {
                                      final pos = index / (_filteredStations.length > 1 ? _filteredStations.length - 1 : 1);
                                      _playStation(station['url_resolved'], station['name'], station['country'], needlePos: pos, favicon: station['favicon'], homepage: station['homepage']);
                                    },
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
                                              final pos = index / (_filteredStations.length > 1 ? _filteredStations.length - 1 : 1);
                                              _playStation(station['url_resolved'], station['name'], station['country'], needlePos: pos, favicon: station['favicon'], homepage: station['homepage']);
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
              const SizedBox(height: 20),
              if (_currentlyPlayingStation != null)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_currentlyPlayingFavicon != null && _currentlyPlayingFavicon!.isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          _currentlyPlayingFavicon!,
                          height: 64,
                          width: 64,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                        ),
                      ),
                    if (_currentlyPlayingHomepage != null && _currentlyPlayingHomepage!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(left: 16.0),
                        child: IconButton(
                          icon: const Icon(Icons.home, size: 32, color: Colors.brown),
                          tooltip: 'Visit Homepage',
                          onPressed: () => _launchURL(_currentlyPlayingHomepage!),
                        ),
                      ),
                  ],
                ),
              const SizedBox(height: 20),
              const Text(
                'Opensource station information provided by radio-station.info and Images by unsplash.com.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10, color: Colors.black),
              ),
              const SizedBox(height: 20),
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
  final bool isTuning;
  final double needlePosition;
  final ValueChanged<double> onNeedleChanged;
  final Color backgroundColor;

  const RotaryDial({
    super.key,
    required this.onStationSelected,
    required this.stationCount,
    required this.isTuning,
    required this.needlePosition,
    required this.onNeedleChanged,
    required this.backgroundColor,
    this.searchTerm,
  });

  @override
  State<RotaryDial> createState() => _RadioDialState();
}

class _RadioDialState extends State<RotaryDial> with SingleTickerProviderStateMixin {
  late AnimationController _jitterController;

  @override
  void initState() {
    super.initState();
    _jitterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    if (widget.isTuning) _jitterController.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(RotaryDial oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isTuning && !oldWidget.isTuning) {
      _jitterController.repeat(reverse: true);
    } else if (!widget.isTuning && oldWidget.isTuning) {
      _jitterController.stop();
    }
  }

  @override
  void dispose() {
    _jitterController.dispose();
    super.dispose();
  }

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
            final newPosition = widget.needlePosition + (details.delta.dx / dialWidth);
            widget.onNeedleChanged(newPosition.clamp(0.0, 1.0));
          },
          onPanEnd: (details) {
            if (widget.stationCount > 0) {
              final stationIndex = (widget.needlePosition * (widget.stationCount - 1)).round();
              widget.onStationSelected(stationIndex);
            }
          },
          child: SizedBox(
            width: dialWidth,
            height: dialHeight,
            child: Stack(
              alignment: Alignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 500),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.black, width: 2),
                    color: widget.backgroundColor,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8.0),
                    child: Image.asset(
                      'assets/Dial.jpg',
                      width: dialWidth,
                      height: dialHeight,
                      fit: BoxFit.cover,
                      opacity: const AlwaysStoppedAnimation(.6), 
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
                      opacity: const AlwaysStoppedAnimation(.6), 
                      errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(), 
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return const Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2));
                      },
                    ),
                  ),
                ),
                AnimatedBuilder(
                  animation: _jitterController,
                  builder: (context, child) {
                    final double jitter = widget.isTuning ? (_jitterController.value * 0.01 - 0.005) : 0.0;
                    return TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: widget.needlePosition, end: widget.needlePosition),
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                      builder: (context, pos, child) {
                        return Positioned(
                          left: (pos + jitter).clamp(0.0, 1.0) * (dialWidth - 4) - 1,
                          top: 4,
                          bottom: 4,
                          child: child!,
                        );
                      },
                      child: Container(
                        width: 2,
                        color: Colors.red[700],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
