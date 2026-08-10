import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Non-face emoji set for group icons. [Category.SMILEYS] bundles faces
/// together with people/body/hand emoji in this package, so excluding the
/// whole category is what keeps group icons reading as organizational
/// symbols rather than faces.
List<CategoryEmoji> groupIconEmojiSet(Locale locale) {
  return emojiSetEnglish.where((c) => c.category != Category.SMILEYS).toList();
}

/// Renders a group's chosen emoji, or the default folder icon when none is
/// set (new groups, or groups created before this feature existed).
///
/// Wrapped in a fixed-size, centered box rather than returned bare: unlike
/// [Icon], [Text] doesn't self-center against surrounding layout, so the
/// emoji would sit top/left-aligned wherever there's slack space to fill
/// (e.g. a bare `Row` child, which also gives unbounded width to a bare
/// [Center] — the fixed [SizedBox] here keeps that bounded and safe too).
Widget groupIcon(String? iconName, {double size = 20, Color? color}) {
  final child = (iconName == null || iconName.isEmpty)
      ? Icon(Icons.folder_rounded, size: size, color: color)
      : Text(
          iconName,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: size, height: 1),
        );
  return SizedBox(width: size, height: size, child: Center(child: child));
}

/// Opens a bottom sheet emoji picker (Objects/Symbols/Animals/etc. only)
/// and returns the picked emoji, or null if dismissed without a pick.
///
/// Themed to the app's active theme (dark/light/custom) instead of the
/// package's default light-gray chrome, which would otherwise clash.
Future<String?> pickGroupIcon(BuildContext context) {
  final theme = Theme.of(context);
  final surface = theme.colorScheme.surface;
  final card = theme.cardTheme.color ?? surface;
  final onSurface = theme.colorScheme.onSurface;
  final accent = theme.colorScheme.primary;

  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: surface,
    builder: (ctx) => EmojiPicker(
      onEmojiSelected: (category, emoji) => Navigator.pop(ctx, emoji.emoji),
      config: Config(
        height: 400,
        emojiSet: groupIconEmojiSet,
        emojiViewConfig: EmojiViewConfig(backgroundColor: surface),
        categoryViewConfig: CategoryViewConfig(
          initCategory: Category.OBJECTS,
          backgroundColor: card,
          iconColor: onSurface.withValues(alpha: 0.5),
          iconColorSelected: accent,
          indicatorColor: accent,
          backspaceColor: accent,
          dividerColor: theme.dividerColor,
        ),
        searchViewConfig: SearchViewConfig(
          backgroundColor: card,
          buttonIconColor: onSurface,
          inputTextStyle: TextStyle(color: onSurface),
          hintTextStyle: TextStyle(color: onSurface.withValues(alpha: 0.5)),
        ),
        bottomActionBarConfig: BottomActionBarConfig(
          backgroundColor: card,
          buttonColor: accent,
          buttonIconColor: AppTheme.onAccent(accent),
        ),
      ),
    ),
  );
}
