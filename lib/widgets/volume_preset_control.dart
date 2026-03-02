import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'rotary_knob.dart';

class VolumePresetControl extends StatelessWidget {
  final double volume;
  final ValueChanged<double> onVolumeChanged;
  final int presetKnobIndex;
  final List<dynamic> favouriteStations;
  final ValueChanged<double> onPresetKnobChanged;
  final VoidCallback onPresetTap;

  const VolumePresetControl({
    super.key,
    required this.volume,
    required this.onVolumeChanged,
    required this.presetKnobIndex,
    required this.favouriteStations,
    required this.onPresetKnobChanged,
    required this.onPresetTap,
  });

  @override
  Widget build(BuildContext context) {
    if (favouriteStations.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          RotaryKnob(
            label: 'VOLUME',
            value: volume,
            onChanged: onVolumeChanged,
          ),
          Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(4),
                ),
                constraints: const BoxConstraints(maxWidth: 150),
                child: Text(
                  favouriteStations[presetKnobIndex]['name'],
                  style: GoogleFonts.orbitron(color: Colors.greenAccent, fontSize: 10),
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 4),
              RotaryKnob(
                label: 'PRESETS',
                value: presetKnobIndex / (favouriteStations.length > 1 ? favouriteStations.length - 1 : 1),
                onChanged: onPresetKnobChanged,
                onTap: onPresetTap,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
