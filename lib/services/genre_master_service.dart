import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/rakuten_genre_master_entry.dart';

/// 同梱の `genre_master_flutter.json`（楽天ジャンルマスタ）を1回だけ読み、メモリ上で参照する。
class GenreMasterService {
  GenreMasterService._();

  static const String _assetPath = 'assets/genre_master_flutter.json';

  static final GenreMasterService instance = GenreMasterService._();

  Map<String, Map<String, dynamic>> _byId = {};
  List<String> _rootIds = [];
  bool _parseSucceeded = false;
  Future<void>? _inFlight;

  /// 直近の [load] が JSON として正常終了したときのみ true。
  bool get isLoaded => _parseSucceeded;

  /// アセットからマスタを読み込む。成功済みなら何もしない。並行呼び出しは同一 Future に合流する。
  /// 失敗時はログのみ（例外は再スローしない）。[_parseSucceeded] は false のまま。
  Future<void> load() async {
    if (_parseSucceeded) return;
    _inFlight ??= _loadInternal();
    try {
      await _inFlight;
    } finally {
      _inFlight = null;
    }
  }

  Future<void> _loadInternal() async {
    try {
      final raw = await rootBundle.loadString(_assetPath);
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        throw FormatException('genre master root is not an object');
      }
      final byIdRaw = decoded['byId'];
      if (byIdRaw == null) {
        throw FormatException('genre master missing byId');
      }
      if (byIdRaw is! Map) {
        throw FormatException('genre master byId is not an object');
      }
      final next = <String, Map<String, dynamic>>{};
      byIdRaw.forEach((key, value) {
        final id = key.toString().trim();
        if (id.isEmpty) return;
        if (value is Map<String, dynamic>) {
          next[id] = value;
        } else if (value is Map) {
          next[id] = Map<String, dynamic>.from(value);
        }
      });
      _byId = next;
      final rootsRaw = decoded['roots'];
      if (rootsRaw is List) {
        _rootIds = rootsRaw
            .map((e) => e.toString().trim())
            .where((s) => s.isNotEmpty)
            .toList(growable: false);
      } else {
        _rootIds = [];
      }
      _parseSucceeded = true;
      final count = decoded['count'];
      debugPrint(
        '[GenreMasterService] load ok path=$_assetPath entries=${_byId.length} '
        'jsonCount=$count',
      );
    } catch (e, st) {
      _byId = {};
      _rootIds = [];
      _parseSucceeded = false;
      debugPrint('[GenreMasterService] load failed: $e');
      debugPrint('$st');
    }
  }

  String? _normalizeKey(dynamic genreId) {
    if (genreId == null) return null;
    if (genreId is int) {
      return '$genreId';
    }
    final s = genreId.toString().trim();
    return s.isEmpty ? null : s;
  }

  /// [genreId] に対応する `byId` エントリ。未ロード・不正キー・未登録は null。
  Map<String, dynamic>? getGenreById(dynamic genreId) {
    final id = _normalizeKey(genreId);
    if (id == null) return null;
    final e = _byId[id];
    if (e == null) return null;
    return Map<String, dynamic>.from(e);
  }

  /// `genreName` のみ。空文字・欠損は null。
  String? getGenreNameById(dynamic genreId) {
    final id = _normalizeKey(genreId);
    if (id == null) return null;
    final e = _byId[id];
    if (e == null) return null;
    final name = e['genreName'];
    if (name is! String) return null;
    final t = name.trim();
    return t.isEmpty ? null : t;
  }

  /// 親ジャンル ID。ルートは null。
  String? getParentGenreId(dynamic genreId) {
    final id = _normalizeKey(genreId);
    if (id == null) return null;
    final m = _byId[id];
    if (m == null) return null;
    final p = m['parentGenreId'];
    if (p == null) return null;
    final s = p.toString().trim();
    return s.isEmpty ? null : s;
  }

  /// JSON の `roots` に列挙された最上位ジャンル ID（読み取り専用）。未ロード時は空。
  List<String> get rootGenreIds => List<String>.unmodifiable(_rootIds);

  /// `roots` 各 ID に対応する [RakutenGenreMasterEntry]（親なし）。`byId` に無い ID は省略。
  /// プルダウン・マイページの選択肢向け。未ロード時は空。
  List<RakutenGenreMasterEntry> rootMasterEntries() {
    if (!_parseSucceeded || _rootIds.isEmpty) return const [];
    final out = <RakutenGenreMasterEntry>[];
    for (final id in _rootIds) {
      final name = getGenreNameById(id);
      if (name == null) continue;
      out.add(
        RakutenGenreMasterEntry(
          genreId: id,
          genreName: name,
          parentGenreId: null,
        ),
      );
    }
    return out;
  }

  /// `pathNames` を文字列リストで返す。欠損時は空リスト。
  List<String> getPathNames(dynamic genreId) {
    final id = _normalizeKey(genreId);
    if (id == null) return const [];
    final m = _byId[id];
    if (m == null) return const [];
    final raw = m['pathNames'];
    if (raw is! List) return const [];
    return raw
        .map((e) => e.toString().trim())
        .where((s) => s.isNotEmpty)
        .toList(growable: false);
  }
}
