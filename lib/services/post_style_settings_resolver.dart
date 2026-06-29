import '../models/post_style_settings.dart';

/// 診断結果・プロフィール等から投稿スタイル設定を解決する。
///
/// TODO(API接続時): [RoomRecommendationProfile] や診断結果から
/// [PostStyleSettings] を推定する本格実装をここに置く。
/// 現段階では [PostStyleSettings.defaults] と Provider 保存値のみを利用。
abstract final class PostStyleSettingsResolver {
  PostStyleSettingsResolver._();

  static PostStyleSettings resolve({
    PostStyleSettings? saved,
    PostStyleSettings? diagnosed,
  }) {
    return saved ?? diagnosed ?? PostStyleSettings.defaults();
  }
}
