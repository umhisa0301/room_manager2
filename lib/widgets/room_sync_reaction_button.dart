import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/room_sync_card_copy.dart';
import '../utils/room_sync_log.dart';

/// ROOM同期カードの手動反応確認サブCTA（ホーム／マイページ共通・補助導線）。
class RoomSyncReactionButton extends StatelessWidget {
  const RoomSyncReactionButton({
    super.key,
    required this.screen,
    required this.onPressed,
    this.enabled = true,
    this.label = RoomSyncCardCopy.manualReactionCheckLabel,
  });

  final String screen;
  final VoidCallback? onPressed;
  final bool enabled;
  final String label;

  static const Color _bg = Color(0xFFFFFBFC);
  static const Color _border = Color(0xFFE8B4C8);
  static const Color _fg = Color(0xFF1A1A1A);

  @override
  Widget build(BuildContext context) {
    final effectiveOnPressed = enabled ? onPressed : null;
    const fg = _fg;
    const bg = _bg;
    const border = _border;
    const contrastSafe = true;
    if (kDebugMode) {
      roomSyncReactionButtonStyleLog(
        'screen=$screen visible=true enabled=$enabled label=$label '
        'foregroundColor=${fg.toARGB32()} backgroundColor=${bg.toARGB32()} '
        'borderColor=${border.toARGB32()} contrastSafe=$contrastSafe '
        'reason=${enabled ? 'ready' : 'disabled'}',
      );
    }
    return OutlinedButton.icon(
      onPressed: effectiveOnPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: fg,
        backgroundColor: bg,
        disabledForegroundColor: fg.withValues(alpha: 0.55),
        disabledBackgroundColor: bg,
        side: const BorderSide(color: border, width: 1.2),
        minimumSize: const Size(double.infinity, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        textStyle: AppTextStyles.button.copyWith(fontWeight: FontWeight.w800),
      ),
      icon: Icon(
        Icons.favorite_border_rounded,
        size: 20,
        color: enabled ? fg : fg.withValues(alpha: 0.55),
      ),
      label: Text(label),
    );
  }
}
