import 'package:flutter/material.dart';

import '../theme.dart';

class EditSheetScaffold extends StatelessWidget {
  const EditSheetScaffold({
    super.key,
    required this.body,
    required this.onSave,
    this.saveLabel = 'Save',
  });

  final Widget body;
  final VoidCallback onSave;
  final String saveLabel;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxBody = (media.size.height * 0.92) - 96;
            return Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: maxBody),
                    child: SingleChildScrollView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      child: body,
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: onSave,
                    style: FilledButton.styleFrom(
                      backgroundColor: OrluxColors.aurora,
                      foregroundColor: const Color(0xFF1A1408),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(saveLabel),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
