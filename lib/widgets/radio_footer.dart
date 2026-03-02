import 'package:flutter/material.dart';

class RadioFooter extends StatelessWidget {
  const RadioFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        Text(
          'Opensource station information provided by radio-station.info and Images by unsplash.com.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 10, color: Colors.black),
        ),
        SizedBox(height: 20),
      ],
    );
  }
}
