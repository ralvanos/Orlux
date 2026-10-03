class BuiltInSound {
  const BuiltInSound({
    required this.id,
    required this.label,
    this.asset,
    this.rawName,
  });

  final String id;
  final String label;
  final String? asset;
  final String? rawName;
}

class CustomSound {
  const CustomSound({
    required this.id,
    required this.label,
    required this.fileName,
  });

  final String id;
  final String label;
  final String fileName;

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'fileName': fileName,
      };

  factory CustomSound.fromJson(Map<String, dynamic> json) {
    return CustomSound(
      id: json['id'] as String? ?? '',
      label: json['label'] as String? ?? 'Imported',
      fileName: json['fileName'] as String? ?? '',
    );
  }
}

class SoundCatalog {
  SoundCatalog._();

  static const chime = BuiltInSound(
    id: 'chime',
    label: 'Chime',
    asset: 'assets/sounds/chime.wav',
    rawName: 'chime',
  );
  static const bell = BuiltInSound(
    id: 'bell',
    label: 'Bell',
    asset: 'assets/sounds/bell.wav',
    rawName: 'bell',
  );
  static const pulse = BuiltInSound(
    id: 'pulse',
    label: 'Pulse',
    asset: 'assets/sounds/pulse.wav',
    rawName: 'pulse',
  );
  static const aurora = BuiltInSound(
    id: 'aurora',
    label: 'Aurora',
    asset: 'assets/sounds/aurora.wav',
    rawName: 'aurora',
  );
  static const tick = BuiltInSound(
    id: 'tick',
    label: 'Tick',
    asset: 'assets/sounds/tick.wav',
    rawName: 'tick',
  );

  static const builtIns = [chime, bell, pulse, aurora, tick];

  static const defaultId = 'chime';

  static String resolve(String? id) {
    if (id == null || id.isEmpty || id == 'click') return defaultId;
    return id;
  }

  static BuiltInSound? builtInById(String id) {
    for (final sound in builtIns) {
      if (sound.id == id) return sound;
    }
    return null;
  }
}
