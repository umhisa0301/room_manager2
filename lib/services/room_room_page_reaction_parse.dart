import 'dart:convert';

import '../utils/room_sync_log.dart';

/// ROOM 商品ページ HTML からいいね／コメント件数を推定する（レイアウト変更で失敗しうる）。
abstract final class RoomRoomPageReactionParse {
  /// [roomLikeCount] / [roomCommentCount] はいずれも **独立**。見つからない軸は null のまま。
  static ({int? roomLikeCount, int? roomCommentCount}) tryParse(String html) {
    roomImportReactionVerboseLog('reaction parse start');

    int? like;
    int? comment;

    final nextData = _extractNextDataJson(html);
    if (nextData != null) {
      try {
        final decoded = jsonDecode(nextData);
        final fromJson = _scanJsonTree(decoded);
        like ??= fromJson.$1;
        comment ??= fromJson.$2;
      } catch (e, st) {
        roomImportReactionVerboseLog(
          'reaction parse __NEXT_DATA__ jsonDecode failed: $e',
        );
        roomImportReactionVerboseLog('$st');
      }
    }

    like ??= _firstIntMatch(html, _likeRegexes);
    comment ??= _firstIntMatch(html, _commentRegexes);

    if (like != null) {
      roomImportReactionVerboseLog('likeCount: $like');
    }
    if (comment != null) {
      roomImportReactionVerboseLog('commentCount: $comment');
    }
    if (like == null && comment == null) {
      roomImportReactionVerboseLog('reaction parse failed: not found');
    }

    return (roomLikeCount: like, roomCommentCount: comment);
  }

  static final List<RegExp> _likeRegexes = [
    RegExp(r'"likeCount"\s*:\s*(\d+)', caseSensitive: false),
    RegExp(r'"likes"\s*:\s*(\d+)', caseSensitive: false),
    RegExp(r'"favoriteCount"\s*:\s*(\d+)', caseSensitive: false),
    RegExp(r'"favorites"\s*:\s*(\d+)', caseSensitive: false),
    RegExp(r'"goodCount"\s*:\s*(\d+)', caseSensitive: false),
    RegExp(r'"reactionCount"\s*:\s*(\d+)', caseSensitive: false),
  ];

  static final List<RegExp> _commentRegexes = [
    RegExp(r'"commentCount"\s*:\s*(\d+)', caseSensitive: false),
    RegExp(r'"comments"\s*:\s*(\d+)', caseSensitive: false),
    RegExp(r'"totalComments"\s*:\s*(\d+)', caseSensitive: false),
    RegExp(r'"replyCount"\s*:\s*(\d+)', caseSensitive: false),
  ];

  static String? _extractNextDataJson(String html) {
    final idIdx = html.indexOf('id="__NEXT_DATA__"');
    if (idIdx < 0) return null;
    final typeIdx = html.indexOf('type="application/json"', idIdx);
    if (typeIdx < 0 || typeIdx > idIdx + 120) return null;
    final gt = html.indexOf('>', typeIdx);
    if (gt < 0) return null;
    final end = html.indexOf('</script>', gt);
    if (end < 0) return null;
    final raw = html.substring(gt + 1, end).trim();
    return raw.isEmpty ? null : raw;
  }

  static int? _firstIntMatch(String html, List<RegExp> patterns) {
    for (final re in patterns) {
      final m = re.firstMatch(html);
      if (m != null && m.groupCount >= 1) {
        return int.tryParse(m.group(1)!);
      }
    }
    return null;
  }

  /// JSON を浅く深く走査し、キー名からいいね／コメントらしき数値を拾う。
  static (int?, int?) _scanJsonTree(dynamic node) {
    int? like;
    int? comment;
    void visit(dynamic n) {
      if (n is Map) {
        for (final e in n.entries) {
          final key = e.key?.toString() ?? '';
          final lk = key.toLowerCase();
          final v = e.value;
          if (v is num) {
            if (_isLikeKey(lk)) {
              like ??= v.toInt();
            } else if (_isCommentKey(lk)) {
              comment ??= v.toInt();
            }
          } else if (v is String) {
            final parsed = int.tryParse(v.trim());
            if (parsed != null) {
              if (_isLikeKey(lk)) {
                like ??= parsed;
              } else if (_isCommentKey(lk)) {
                comment ??= parsed;
              }
            }
          }
          visit(v);
        }
      } else if (n is List) {
        for (final x in n) {
          visit(x);
        }
      }
    }

    visit(node);
    return (like, comment);
  }

  static bool _isLikeKey(String lk) {
    if (lk == 'likecount' ||
        lk == 'likes' ||
        lk == 'favoritecount' ||
        lk == 'favorites' ||
        lk == 'goodcount') {
      return true;
    }
    return lk.endsWith('_like_count') ||
        lk.endsWith('like_count') ||
        (lk.contains('like') && lk.contains('count'));
  }

  static bool _isCommentKey(String lk) {
    if (lk == 'commentcount' ||
        lk == 'comments' ||
        lk == 'totalcomments' ||
        lk == 'replycount') {
      return true;
    }
    return lk.endsWith('_comment_count') ||
        lk.endsWith('comment_count') ||
        (lk.contains('comment') && lk.contains('count'));
  }
}
