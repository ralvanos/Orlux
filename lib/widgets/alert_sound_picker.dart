import 'package:flutter/material.dart';

import '../models/clock_sound.dart';
import '../services/sound_service.dart';
import '../theme.dart';

class AlertSoundPicker extends StatefulWidget {
  const AlertSoundPicker({
    super.key,
    required this.soundId,
    required this.onChanged,
    this.allowDefault = true,
    this.defaultLabel = 'App default',
    this.showImport = false,
    this.allowDelete = false,
  });

  /// Empty or null means the app default tone.
  final String? soundId;
  final ValueChanged<String?> onChanged;
  final bool allowDefault;
  final String defaultLabel;
  final bool showImport;
  final bool allowDelete;

  @override
  State<AlertSoundPicker> createState() => _AlertSoundPickerState();
}

class _AlertSoundPickerState extends State<AlertSoundPicker> {
  List<CustomSound> _custom = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final custom = await SoundService.instance.customSounds();
    if (!mounted) return;
    setState(() => _custom = custom);
  }

  List<_ToneOption> get _options {
    return [
      if (widget.allowDefault)
        _ToneOption(id: '', label: widget.defaultLabel),
      for (final tone in SoundCatalog.builtIns)
        _ToneOption(id: tone.id, label: tone.label),
      for (final tone in _custom)
        _ToneOption(id: tone.id, label: '${tone.label} (imported)'),
    ];
  }

  String get _value {
    final wanted = widget.soundId ?? '';
    for (final option in _options) {
      if (option.id == wanted) return option.id;
    }
    if (widget.allowDefault) return '';
    return SoundCatalog.defaultId;
  }

  String get _previewId {
    final id = _value;
    return id.isEmpty ? SoundCatalog.defaultId : id;
  }

  Future<void> _import() async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final sound = await SoundService.instance.importSound();
    if (!mounted) return;
    if (sound == null) return;
    await _load();
    widget.onChanged(sound.id);
    messenger?.showSnackBar(SnackBar(content: Text('Imported ${sound.label}')));
  }

  Future<void> _deleteSelected() async {
    final id = _value;
    if (!id.startsWith('custom:')) return;
    await SoundService.instance.deleteCustom(id);
    await _load();
    if (!mounted) return;
    widget.onChanged(widget.allowDefault ? null : SoundCatalog.defaultId);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Alert tone'),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                key: ValueKey('${_options.length}-$_value'),
                initialValue: _value,
                isExpanded: true,
                dropdownColor: OrluxColors.card,
                decoration: const InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
                items: [
                  for (final option in _options)
                    DropdownMenuItem(
                      value: option.id,
                      child: Text(
                        option.label,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (id) {
                  if (id == null) return;
                  widget.onChanged(id.isEmpty ? null : id);
                },
              ),
            ),
            IconButton(
              tooltip: 'Test tone',
              onPressed: () => SoundService.instance.play(
                id: _previewId,
                enabled: true,
              ),
              icon: const Icon(Icons.play_arrow_rounded),
            ),
          ],
        ),
        if (widget.showImport || (widget.allowDelete && _value.startsWith('custom:')))
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Wrap(
              spacing: 8,
              children: [
                if (widget.showImport)
                  TextButton.icon(
                    onPressed: _import,
                    icon: const Icon(Icons.library_music_outlined, size: 18),
                    label: const Text('Import sound'),
                  ),
                if (widget.allowDelete && _value.startsWith('custom:'))
                  TextButton.icon(
                    onPressed: _deleteSelected,
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Remove imported'),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _ToneOption {
  const _ToneOption({required this.id, required this.label});
  final String id;
  final String label;
}
