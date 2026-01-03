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

  // [FIX] Power is now on by default
  bool _isPowerOn = true;
  PlayerState? _playerState;

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

        // [NEW] Default to Canada
        var canada = countries.firstWhere((c) => c['name'] == 'Canada', orElse: () => null);
        if (canada != null) {
          final canadaCode = canada['iso_3166_1'];
          setState(() {
            _selectedCountry = canadaCode;
          });
          await _getStations(canadaCode);
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

  Future<void> _getStations(String countryCode) async {
    if (_apiBaseUrl == null) return;
    if (!mounted) return;
    setState(() {
      _isLoadingStations = true;
    });
    try {
      final response = await http.get(Uri.parse('$_apiBaseUrl/json/stations/bycountrycodeexact/$countryCode'));
      if (response.statusCode == 200) {
        if (!mounted) return;
        setState(() {
          _stations = json.decode(response.body);
        });
      } else {
        _showError('Failed to load stations');
      }
    } catch (e) {
      _showError('Error: $e');
    }
    if (!mounted) return;
    setState(() {
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
    if (_stations.isNotEmpty && index < _stations.length) {
      final station = _stations[index];
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
                        stationCount: _stations.length,
                        onStationSelected: _onStationTuned,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        _isPowerOn ? (_currentlyPlayingStation ?? 'Select a station') : 'Radio Off',
                        style: GoogleFonts.orbitron(fontSize: 14, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
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
                          if (newValue != null) {
                            setState(() {
                              _selectedCountry = newValue;
                              _stations = [];
                              _getStations(newValue);
                            });
                          }
                        },
                        items: _countries.map<DropdownMenuItem<String>>((dynamic value) {
                          return DropdownMenuItem<String>(
                            value: value['iso_3166_1'],
                            child: Text(value['name'], overflow: TextOverflow.ellipsis),
                          );
                        }).toList(),
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
                      : _stations.isEmpty
                          ? Center(child: Text(_selectedCountry == null ? '' : 'No stations found.'))
                          : ListView.builder(
                              shrinkWrap: true,
                              primary: false,
                              itemCount: _stations.length,
                              itemBuilder: (context, index) {
                                final station = _stations[index];
                                return ListTile(
                                  title: Text(station['name']),
                                  subtitle: Text(
                                      "${station['state'] ?? ''}, ${station['country'] ?? ''}"
                                          .trim()),
                                  onTap: () => _playStation(station['url_resolved'], station['name']),
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
        final double dialWidth = constraints.maxWidth * 0.9;
        final double dialHeight = 80;

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
                  width: dialWidth,
                  height: dialHeight,
                  decoration: BoxDecoration(
                    color: Colors.brown[800],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.black, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.5),
                        spreadRadius: 2,
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      )
                    ],
                  ),
                  child: CustomPaint(
                    painter: HorizontalDialPainter(),
                  ),
                ),
                Positioned(
                  left: _needlePosition * (dialWidth - 4) - 1,
                  child: Container(
                    width: 2,
                    height: dialHeight - 8,
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

class HorizontalDialPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;

    final paint = Paint()
      ..color = Colors.white.withOpacity(0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    const majorTickCount = 11; // For 88, 90, ..., 108
    for (int i = 0; i < majorTickCount; i++) {
      final x = (width / (majorTickCount - 1)) * i;

      canvas.drawLine(Offset(x, height), Offset(x, height - 15), paint);

      final text = (88 + i * 2).toString();
      final textSpan = TextSpan(
        text: text,
        style: GoogleFonts.orbitron(color: Colors.white, fontSize: 10),
      );
      final textPainter = TextPainter(text: textSpan, textAlign: TextAlign.center, textDirection: TextDirection.ltr);
      textPainter.layout();
      textPainter.paint(canvas, Offset(x - (textPainter.width / 2), height - 30));

      if (i < majorTickCount - 1) {
        final minorX = x + (width / (majorTickCount - 1) / 2);
        canvas.drawLine(Offset(minorX, height), Offset(minorX, height - 10), paint);
      }
    }

    final fmText = TextSpan(text: 'FM STEREO', style: GoogleFonts.orbitron(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold));
    final fmTextPainter = TextPainter(text: fmText, textDirection: TextDirection.ltr);
    fmTextPainter.layout();
    fmTextPainter.paint(canvas, const Offset(15, 10));

    final mhzText = TextSpan(text: 'MHz', style: GoogleFonts.orbitron(color: Colors.white70, fontSize: 12));
    final mhzTextPainter = TextPainter(text: mhzText, textDirection: TextDirection.ltr);
    mhzTextPainter.layout();
    mhzTextPainter.paint(canvas, Offset(width - 45, 10));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}
