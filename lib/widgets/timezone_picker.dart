import 'package:flutter/material.dart';
import 'package:timezone/timezone.dart' as tz;

import '../theme.dart';

class TimezonePickerTile extends StatelessWidget {
  const TimezonePickerTile({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final String value;
  final ValueChanged<String> onChanged;

  Future<void> _open(BuildContext context) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: OrluxColors.card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _TimezoneSheet(selected: value),
    );
    if (picked == null || picked == value) return;
    onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: const Text('Timezone'),
      subtitle: Text(value),
      trailing: const Icon(Icons.expand_more, color: OrluxColors.aurora),
      onTap: () => _open(context),
    );
  }
}

class _TimezoneSheet extends StatefulWidget {
  const _TimezoneSheet({required this.selected});

  final String selected;

  @override
  State<_TimezoneSheet> createState() => _TimezoneSheetState();
}

class _TimezoneSheetState extends State<_TimezoneSheet> {
  String _query = '';
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final zones = tz.timeZoneDatabase.locations.keys.where((z) {
      if (q.isEmpty) return true;
      return z.toLowerCase().contains(q);
    }).toList()
      ..sort();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.72,
      minChildSize: 0.45,
      maxChildSize: 0.92,
      builder: (context, scroll) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(height: 16),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Timezone',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _controller,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Search (e.g. New_York or Tokyo)',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: zones.isEmpty
                    ? Center(
                        child: Text(
                          'No matching zones.',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: scroll,
                        itemCount: zones.length,
                        itemBuilder: (context, index) {
                          final zone = zones[index];
                          final selected = zone == widget.selected;
                          return ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text(zone),
                            trailing: selected
                                ? const Icon(
                                    Icons.check,
                                    color: OrluxColors.aurora,
                                  )
                                : null,
                            onTap: () => Navigator.pop(context, zone),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
