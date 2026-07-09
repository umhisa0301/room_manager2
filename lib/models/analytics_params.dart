/// Analytics イベント用の列挙値（送信前に [AnalyticsService] で正規化される）。
enum AnalyticsSearchSource {
  keyword,
  url,
  genre,
  shop,
  unknown,
}

enum AnalyticsSearchErrorType {
  rateLimit,
  unsupportedUrl,
  network,
  api,
  unknown,
}

enum AnalyticsCandidateSource {
  search,
  recommendation,
  manual,
  unknown,
}

enum AnalyticsPostPrepareSource {
  search,
  recommendation,
  candidate,
  collected,
  unknown,
}

enum AnalyticsAiCommentSource {
  postPrepare,
  unknown,
}

enum AnalyticsAiCommentErrorType {
  limit,
  serverUnavailable,
  network,
  api,
  unknown,
}

enum AnalyticsAiCommentTextType {
  generated,
  manual,
  unknown,
}

enum AnalyticsRoomLaunchSource {
  postPrepare,
  search,
  recommendation,
  candidate,
  unknown,
}

enum AnalyticsRoomLaunchType {
  room,
  rakuten,
  browser,
  unknown,
}

enum AnalyticsRecommendationAction {
  openDetail,
  postPrepare,
  addCandidate,
  unknown,
}

enum AnalyticsMonetizationPlanSource {
  mypage,
  limitDialog,
  unknown,
}

enum AnalyticsGeneratedLengthBucket {
  short,
  medium,
  long,
}
