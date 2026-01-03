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

  bool _isPowerOn = false;
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
        setState(() {
          _countries = json.decode(response.body);
        });
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
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Container(
              width: 300,
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.brown, width: 10),
                borderRadius: BorderRadius.circular(10),
                color: Colors.brown[300],
              ),
              child: Column(
                children: [
                  Text('Radio', style: GoogleFonts.bungeeInline(fontSize: 36)),
                  SwitchListTile(
                    title: const Text('Power'),
                    value: _isPowerOn,
                    onChanged: (bool value) {
                      setState(() {
                        _isPowerOn = value;
                        if (!_isPowerOn) {
                          _stopStation();
                        }
                      });
                    },
                    subtitle: Text(_playerState?.toString() ?? 'unknown state'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Opacity(
              opacity: _isPowerOn ? 1.0 : 0.4,
              child: AbsorbPointer(
                absorbing: !_isPowerOn,
                child: Column(
                  children: [
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
                          child: Text(value['name']),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Opacity(
                opacity: _isPowerOn ? 1.0 : 0.4,
                child: AbsorbPointer(
                  absorbing: !_isPowerOn,
                  child: _isLoadingStations
                      ? const Center(child: CircularProgressIndicator())
                      : _stations.isEmpty
                      ? Center(child: Text(_selectedCountry == null ? '' : 'No stations found.'))
                      : ListView.builder(
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
            ),
          ],
        ),
      ),
    );
  }
}

// [FIX] Updated RotaryDial to be a half-moon shape with frequency markings
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
  double _angle = 0.0; // Represents the needle's angle, from -PI/2 to PI/2

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanUpdate: (details) {
        // Update angle based on horizontal drag, constrained to a 180-degree arc
        final screenWidth = MediaQuery.of(context).size.width;
        final angleChange = (details.delta.dx / screenWidth) * pi;
        setState(() {
          _angle = (_angle + angleChange).clamp(-pi / 2, pi / 2);
        });
      },
      onPanEnd: (details) {
        if (widget.stationCount > 0) {
          // Normalize the angle from 0.0 to 1.0
          final normalizedValue = (_angle + (pi / 2)) / pi;
          // Map the normalized value to a station index
          final stationIndex = (normalizedValue * (widget.stationCount - 1)).round();
          widget.onStationSelected(stationIndex);
        }
      },
      child: SizedBox(
        width: 250,
        height: 125,
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            // The half-moon background with frequency markings
            Container(
              width: 250,
              height: 125,
              decoration: BoxDecoration(
                color: Colors.brown[800],
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(125),
                  topRight: Radius.circular(125),
                ),
                border: Border.all(color: Colors.brown[900]!, width: 4),
              ),
              child: CustomPaint(
                painter: FrequencyPainter(),
              ),
            ),
            // The tuning needle
            Transform.rotate(
              angle: _angle,
              alignment: Alignment.bottomCenter,
              child: Container(
                width: 2,
                height: 110,
                decoration: BoxDecoration(
                  color: Colors.red[700],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // A decorative knob at the pivot point
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: Colors.grey[600],
                shape: BoxShape.circle,
                border: Border.all(color: Colors.black, width: 2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// [NEW] Custom Painter for drawing the frequency markings on the dial
class FrequencyPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height);
    final radius = size.width / 2;

    final paint = Paint()
      ..color = Colors.white.withOpacity(0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final textStyle = TextStyle(
      color: Colors.white.withOpacity(0.8),
      fontSize: 10,
    );

    // Draw 11 markings (for 88 to 108)
    for (int i = 0; i <= 10; i++) {
      // Calculate angle for each marking from -180 to 0 degrees
      final angle = -pi + (pi * i / 10);

      final isMajorMarking = i % 2 == 0;
      final markingLength = isMajorMarking ? 20.0 : 10.0;

      final innerX = center.dx + (radius - markingLength) * cos(angle);
      final innerY = center.dy + (radius - markingLength) * sin(angle);
      final outerX = center.dx + (radius - 4) * cos(angle);
      final outerY = center.dy + (radius - 4) * sin(angle);

      canvas.drawLine(Offset(innerX, innerY), Offset(outerX, outerY), paint);

      // Draw text for major markings
      if (isMajorMarking) {
        final textSpan = TextSpan(
          text: (88 + i * 2).toString(),
          style: textStyle,
        );
        final textPainter = TextPainter(
          text: textSpan,
          textAlign: TextAlign.center,
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();

        // Position text inside the markings
        final textX = center.dx + (radius - 35) * cos(angle) - (textPainter.width / 2);
        final textY = center.dy + (radius - 35) * sin(angle) - (textPainter.height / 2);
        textPainter.paint(canvas, Offset(textX, textY));
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}