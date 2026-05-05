import '../models/room_collected_persist_kind.dart';
import '../repository/rakuten_managed_product_repository.dart';
import '../utils/room_rakuten_url_normalize.dart';
import 'rakuten_item_url_parser.dart';
import 'room_url_resolver.dart';

/// ROOM 商品ページURLから楽天 item を解決し、[RakutenManagedProductRepository] へ **コレ済** 登録する。
///
/// 将来の一括同期は、本クラスに `Iterable<String> roomPageUrls` を渡すメソッドを追加し、
/// 進捗 [LinearProgressIndicator] 用に `Stream` / コールバックで件数を返す拡張がしやすい構成。
class RoomCollectedRegisterService {
  RoomCollectedRegisterService({
    required RakutenManagedProductRepository repository,
    RoomUrlResolver? roomUrlResolver,
  }) : _repository = repository,
       _resolver = roomUrlResolver ?? RoomUrlResolver();

  final RakutenManagedProductRepository _repository;
  final RoomUrlResolver _resolver;

  static const String messageRoomPageAlreadySynced =
      'このROOM投稿はすでに取り込み済みです';
  static const String messageAlreadyCollected =
      'この商品はすでにコレ済です';
  static const String messageRegistered = 'ROOM投稿済み商品として登録しました';
  static const String messageFetchFailed =
      'ROOMページから楽天商品情報を取得できませんでした';

  /// 単品 ROOM 商品ページの取り込み。
  Future<RoomCollectedRegisterViewResult> registerFromRoomProductPageUrl(
    String rawRoomUrl,
  ) async {
    final normalizedRoomKey =
        RoomRakutenUrlNormalize.normalizeRoomProductPageKey(rawRoomUrl);
    if (!RoomRakutenUrlNormalize.isLikelyRoomProductPageUrl(rawRoomUrl)) {
      return RoomCollectedRegisterViewResult(
        kind: RoomCollectedRegisterUiKind.failed,
        message: messageFetchFailed,
      );
    }
    if (normalizedRoomKey.isEmpty) {
      return RoomCollectedRegisterViewResult(
        kind: RoomCollectedRegisterUiKind.failed,
        message: messageFetchFailed,
      );
    }

    final resolved = await _resolver.resolveRakutenItemUrlFromRoomPage(
      rawRoomUrl,
    );

    if (resolved is! RoomUrlResolveSuccess) {
      return RoomCollectedRegisterViewResult(
        kind: RoomCollectedRegisterUiKind.failed,
        message: messageFetchFailed,
      );
    }

    final parsed = resolved.rakutenItem;
    final verify = RakutenItemUrlParser.tryParse(parsed.rakutenUrl);
    if (verify == null) {
      return RoomCollectedRegisterViewResult(
        kind: RoomCollectedRegisterUiKind.failed,
        message: messageFetchFailed,
      );
    }

    final persist = await _repository.persistRoomCollectedFromRoomPage(
      roomUrlStoredCanonical: normalizedRoomKey,
      normalizedRoomUrlKey: normalizedRoomKey,
      parsedItem: parsed,
      roomPageTitle: resolved.roomPageTitle ?? '',
      roomPageImageUrl: resolved.roomPageImageUrl ?? '',
    );

    switch (persist.kind) {
      case RoomCollectedPersistKind.demoUnsupported:
        return RoomCollectedRegisterViewResult(
          kind: RoomCollectedRegisterUiKind.failed,
          message: messageFetchFailed,
        );
      case RoomCollectedPersistKind.roomPageAlreadySynced:
        return RoomCollectedRegisterViewResult(
          kind: RoomCollectedRegisterUiKind.roomPageAlreadySynced,
          message: messageRoomPageAlreadySynced,
          productId: persist.productId,
          rakutenUrl: parsed.rakutenUrl,
          roomUrl: normalizedRoomKey,
        );
      case RoomCollectedPersistKind.alreadyCollectedSkip:
        return RoomCollectedRegisterViewResult(
          kind: RoomCollectedRegisterUiKind.alreadyCollected,
          message: messageAlreadyCollected,
          productId: persist.productId,
          rakutenUrl: parsed.rakutenUrl,
          roomUrl: normalizedRoomKey,
        );
      case RoomCollectedPersistKind.updatedRoomUrlOnly:
        return RoomCollectedRegisterViewResult(
          kind: RoomCollectedRegisterUiKind.updatedExisting,
          message: messageRegistered,
          productId: persist.productId,
          rakutenUrl: parsed.rakutenUrl,
          roomUrl: normalizedRoomKey,
        );
      case RoomCollectedPersistKind.insertedNewCollected:
        return RoomCollectedRegisterViewResult(
          kind: RoomCollectedRegisterUiKind.registeredNew,
          message: messageRegistered,
          productId: persist.productId,
          rakutenUrl: parsed.rakutenUrl,
          roomUrl: normalizedRoomKey,
        );
    }
  }
}

enum RoomCollectedRegisterUiKind {
  registeredNew,
  updatedExisting,
  roomPageAlreadySynced,
  alreadyCollected,
  failed,
}

class RoomCollectedRegisterViewResult {
  const RoomCollectedRegisterViewResult({
    required this.kind,
    required this.message,
    this.productId,
    this.rakutenUrl,
    this.roomUrl,
  });

  final RoomCollectedRegisterUiKind kind;
  final String message;
  final String? productId;
  final String? rakutenUrl;
  final String? roomUrl;

  bool get isError => kind == RoomCollectedRegisterUiKind.failed;
}
