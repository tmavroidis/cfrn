import 'package:flutter/material.dart';

class ActionButtonBar extends StatelessWidget {
  final VoidCallback onExport;
  final VoidCallback onImport;
  final VoidCallback onClear;

  const ActionButtonBar({
    super.key,
    required this.onExport,
    required this.onImport,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.file_download),
          onPressed: onExport,
          tooltip: 'Export',
        ),
        const SizedBox(width: 15),
        IconButton(
          icon: const Icon(Icons.file_upload),
          onPressed: onImport,
          tooltip: 'Import',
        ),
        const SizedBox(width: 15),
        IconButton(
          icon: const Icon(Icons.delete_sweep, color: Colors.redAccent),
          onPressed: onClear,
          tooltip: 'Clear All',
        ),
      ],
    );
  }
}
