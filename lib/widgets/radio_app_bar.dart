import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'action_button_bar.dart';

class RadioAppBar extends StatelessWidget implements PreferredSizeWidget {
  final bool isPortrait;
  final bool isPowerOn;
  final ValueChanged<bool> onPowerChanged;
  final VoidCallback onExport;
  final VoidCallback onImport;
  final VoidCallback onClear;

  const RadioAppBar({
    super.key,
    required this.isPortrait,
    required this.isPowerOn,
    required this.onPowerChanged,
    required this.onExport,
    required this.onImport,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
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
        if (!isPortrait)
          ActionButtonBar(
            onExport: onExport,
            onImport: onImport,
            onClear: onClear,
          ),
        Row(
          children: [
            const Text('Power'),
            Switch(
              value: isPowerOn,
              onChanged: onPowerChanged,
            ),
          ],
        )
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
