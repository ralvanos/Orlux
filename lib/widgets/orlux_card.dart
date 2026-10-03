import 'package:flutter/material.dart';

import '../theme.dart';

class OrluxCard extends StatelessWidget {
  const OrluxCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: OrluxColors.card,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        child: child,
      ),
    );
  }
}
