import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class TuningDisplay extends StatelessWidget {
  final bool isPowerOn;
  final String? currentlyPlayingStation;
  final bool isTuning;
  final String? playerState;

  const TuningDisplay({
    super.key,
    required this.isPowerOn,
    this.currentlyPlayingStation,
    required this.isTuning,
    this.playerState,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          isPowerOn ? (currentlyPlayingStation ?? 'Select a station') : 'Radio Off',
          style: GoogleFonts.orbitron(fontSize: 14, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        if (isPowerOn)
          Text(
            isTuning ? 'wait - stations are being loaded' : 'State: ${playerState ?? 'unknown'}',
            style: GoogleFonts.orbitron(fontSize: 10, color: Colors.black54),
          ),
      ],
    );
  }
}
