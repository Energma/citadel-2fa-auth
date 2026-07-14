import 'package:flutter/material.dart';

import 'service_icon.dart';

/// The emoji offered for categories, grouped the way people actually sort tokens.
///
/// Deliberately a curated catalogue rather than a full emoji keyboard: it needs no
/// third-party dependency in a vault app, and it renders as a swatch grid matching
/// the colour picker already used for profiles.
class CategoryIcons {
  static const Map<String, List<String>> emoji = {
    'Finance': ['🏦', '💰', '💳', '💵', '🪙', '📈', '🧾', '💎', '🏧', '💸'],
    'Cloud & Dev': ['☁️', '💻', '🖥️', '⚙️', '🐳', '🚀', '🗄️', '🔧', '📦', '🧪', '🌐', '⌨️'],
    'Social': ['💬', '📱', '📧', '👥', '📢', '❤️', '👍', '🗨️', '📮', '🤝'],
    'Security': ['🔐', '🔑', '🛡️', '🔒', '🗝️', '🚨', '👁️', '🧿'],
    'Work': ['💼', '🏢', '📊', '📅', '📋', '✅', '📝', '🖇️', '📁', '🗂️'],
    'Media & Games': ['🎮', '🎵', '🎬', '📷', '📺', '🎨', '🕹️', '🎧', '🎤', '🍿'],
    'Life': ['🛒', '🎁', '✈️', '🏠', '🚗', '🍔', '☕', '🏨', '🏥', '🎓', '🐾', '🌱'],
    'Marks': ['⭐', '🔥', '⚡', '🌟', '🎯', '🧩', '🐙', '🦊', '🔴', '🟢', '🔵', '🟣'],
  };
}

/// Renders a category's icon: a brand glyph for a known service key ("github"),
/// the character itself for an emoji, or a folder when nothing is chosen.
///
/// This is the read side of [TokenGroup.icon] — the one field that holds either
/// kind, disambiguated by [ServiceIcon.styleFor] returning null for non-brands.
class CategoryIcon extends StatelessWidget {
  final String? icon;
  final double size;

  const CategoryIcon({super.key, required this.icon, this.size = 24});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final value = icon?.trim() ?? '';

    if (value.isEmpty) {
      return Icon(Icons.folder_rounded,
          size: size, color: theme.colorScheme.primary);
    }

    final style = ServiceIcon.styleFor(value);
    if (style != null) {
      return Icon(style.icon, size: size, color: _legible(context, style.color));
    }

    return Text(value, style: TextStyle(fontSize: size * 0.85));
  }

  /// Brand colours are picked for a white page, so some sit invisibly against our
  /// theme — GitHub's near-black (#333) on the dark navy surface, Snapchat's
  /// near-white yellow on the light one. Nudge only those toward the readable end
  /// and leave every well-contrasted brand exactly as its own colour.
  static Color _legible(BuildContext context, Color brand) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final luminance = brand.computeLuminance();
    if (isDark && luminance < 0.15) {
      return Color.lerp(brand, Colors.white, 0.72)!;
    }
    if (!isDark && luminance > 0.85) {
      return Color.lerp(brand, Colors.black, 0.45)!;
    }
    return brand;
  }
}

/// A sectioned grid for choosing a category icon: the built-in services first
/// (they are what most tokens are), then the curated emoji.
///
/// [onChanged] receives a service key, an emoji, or the empty string for "None"
/// — empty is what clears the icon back to the folder default.
class CategoryIconPicker extends StatelessWidget {
  final String? value;
  final ValueChanged<String> onChanged;

  const CategoryIconPicker({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final selected = value?.trim() ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _section(context, 'None', [
          _cell(context, '', selected.isEmpty),
        ]),
        _section(
          context,
          'Services',
          ServiceIcon.knownServices
              .map((key) => _cell(context, key, selected == key))
              .toList(),
        ),
        for (final entry in CategoryIcons.emoji.entries)
          _section(
            context,
            entry.key,
            entry.value
                .map((e) => _cell(context, e, selected == e))
                .toList(),
          ),
      ],
    );
  }

  Widget _section(BuildContext context, String title, List<Widget> cells) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 6),
          Wrap(spacing: 6, runSpacing: 6, children: cells),
        ],
      ),
    );
  }

  Widget _cell(BuildContext context, String token, bool isSelected) {
    final theme = Theme.of(context);

    final cell = InkWell(
      onTap: () => onChanged(token),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary.withAlpha(40)
              : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.outline.withAlpha(50),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Center(child: CategoryIcon(icon: token, size: 22)),
      ),
    );

    // Service keys are glyphs with no label in the grid; name them on long-press
    // so "which cloud is this one" is answerable without guessing.
    return token.isEmpty ? cell : Tooltip(message: token, child: cell);
  }
}
