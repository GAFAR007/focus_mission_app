/**
 * WHAT:
 * avatar_presets defines the curated DiceBear avatar choices shown in profile
 * selection.
 * WHY:
 * Learners and staff need a fixed, safe avatar set so profile updates feel fun
 * without introducing unpredictable external assets.
 * HOW:
 * Store labeled preset seeds and convert them into DiceBear image URLs.
 */
// ignore_for_file: dangling_library_doc_comments, slash_for_doc_comments

class AvatarPreset {
  const AvatarPreset({
    required this.seed,
    required this.label,
    required this.group,
    this.options = const {},
  });

  final String seed;
  final String label;
  final String group;
  final Map<String, String> options;

  String get url => Uri.https('api.dicebear.com', '/9.x/adventurer/png', {
    // WHY: Seeded avatar URLs keep profile identity stable across sessions while
    // still letting the user pick from a playful preset set.
    'seed': seed,
    'size': '128',
    ...options,
  }).toString();
}

abstract final class AvatarPresets {
  static const boys = <AvatarPreset>[
    AvatarPreset(
      seed: 'Ethan',
      label: 'Ethan',
      group: 'Boys',
      options: {
        'hair': 'short05',
        'earringsProbability': '0',
        'glassesProbability': '0',
      },
    ),
    AvatarPreset(
      seed: 'Marcus',
      label: 'Marcus',
      group: 'Boys',
      options: {
        'hair': 'short09',
        'earringsProbability': '0',
        'glassesProbability': '0',
      },
    ),
    AvatarPreset(
      seed: 'Noah',
      label: 'Noah',
      group: 'Boys',
      options: {
        'hair': 'short02',
        'earringsProbability': '0',
        'glassesProbability': '0',
      },
    ),
    AvatarPreset(
      seed: 'Daniel',
      label: 'Daniel',
      group: 'Boys',
      options: {
        'hair': 'short12',
        'earringsProbability': '0',
        'glassesProbability': '0',
      },
    ),
    AvatarPreset(
      seed: 'Finn',
      label: 'Finn',
      group: 'Boys',
      options: {
        'hair': 'short15',
        'earringsProbability': '0',
        'glassesProbability': '0',
      },
    ),
  ];

  static const girls = <AvatarPreset>[
    AvatarPreset(seed: 'Riley', label: 'Riley', group: 'Girls'),
    AvatarPreset(seed: 'Avery', label: 'Avery', group: 'Girls'),
    AvatarPreset(seed: 'Layla', label: 'Layla', group: 'Girls'),
    AvatarPreset(seed: 'Maya', label: 'Maya', group: 'Girls'),
    AvatarPreset(seed: 'Zoe', label: 'Zoe', group: 'Girls'),
  ];

  static const all = <AvatarPreset>[...boys, ...girls];
}
