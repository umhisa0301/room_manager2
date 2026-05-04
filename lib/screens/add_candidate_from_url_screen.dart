import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/rakuten_product_search_condition.dart';
import '../models/rakuten_search_item.dart';
import '../repository/rakuten_search_repository.dart';
import '../state/rakuten_managed_product_provider.dart';
import '../state/rakuten_search_provider.dart';
import '../theme/app_theme.dart';
import '../theme/home_screen_colors.dart';
import '../theme/rakuten_search_screen_tokens.dart';
import '../utils/rakuten_ichiba_url_parse.dart';
import '../widgets/app_button.dart';
import '../widgets/rakuten_search_result_card.dart';
import '../widgets/search_group_screen_shell.dart';

/// 楽天市場の商品・ショップURLから検索して候補追加する。
class AddCandidateFromUrlScreen extends StatefulWidget {
  const AddCandidateFromUrlScreen({super.key});

  @override
  State<AddCandidateFromUrlScreen> createState() =>
      _AddCandidateFromUrlScreenState();
}

class _AddCandidateFromUrlScreenState extends State<AddCandidateFromUrlScreen> {
  final _controller = TextEditingController();
  bool _loading = false;
  String? _userMessage;
  String? _technicalErrorDetail;
  List<RakutenSearchItem> _items = const [];
  List<String> _searchTrace = const [];
  RakutenIchibaUrlHints? _lastHints;
  String? _lastUrlText;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<List<RakutenSearchItem>> _safeSearch(
    RakutenSearchRepository repo,
    RakutenProductSearchCondition condition,
  ) async {
    return repo.search(condition: condition);
  }

  /// 優先順位 1→4 で試行。いずれかでヒットしたら打ち切り。
  Future<void> _runSearch() async {
    final urlText = _controller.text.trim();
    if (urlText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('URL を入力してください')),
      );
      return;
    }
    final hints = parseRakutenIchibaUrlHints(urlText);
    final fallbackKw = rakutenIchibaKeywordFallbackFromRawUrl(urlText);
    if (hints.isEmpty && (fallbackKw == null || fallbackKw.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('shopCode / 商品パス を URL から読み取れませんでした'),
        ),
      );
      return;
    }

    setState(() {
      _loading = true;
      _userMessage = null;
      _technicalErrorDetail = null;
      _items = const [];
      _searchTrace = const [];
      _lastHints = hints;
      _lastUrlText = urlText;
    });

    final repo = context.read<RakutenSearchRepository>();
    final trace = <String>[];

    Future<bool> tryStep(
      String title,
      Future<List<RakutenSearchItem>> Function() run,
    ) async {
      trace.add('▼ $title');
      try {
        final list = await run();
        trace.add('→ ${list.length}件');
        if (list.isNotEmpty) {
          if (!mounted) return true;
          setState(() {
            _loading = false;
            _items = list;
            _searchTrace = List<String>.from(trace);
          });
          return true;
        }
      } catch (e) {
        trace.add('→ 失敗: $e');
      }
      return false;
    }

    // 1. 公式形式の itemCode（shop:数字）のみ API itemCode 検索
    if (hints.itemCode != null && hints.itemCode!.isNotEmpty) {
      if (await tryStep('① API形式の itemCode（shop:ID）で検索', () {
        return _safeSearch(
          repo,
          RakutenProductSearchCondition(keyword: '', itemCode: hints.itemCode),
        );
      })) {
        return;
      }
    }

    // 2. shopCode + パススラッグをキーワードに
    if (hints.shopCode != null &&
        hints.itemPath != null &&
        hints.itemPath!.trim().isNotEmpty) {
      if (await tryStep('② ショップ内キーワード検索（URLの商品パス）', () {
        return _safeSearch(
          repo,
          RakutenProductSearchCondition(
            keyword: hints.itemPath!,
            shopCode: hints.shopCode,
          ),
        );
      })) {
        return;
      }
    }

    // 2b. パスが無いがフォールバックKWがありショップがある
    if (hints.shopCode != null &&
        (hints.itemPath == null || hints.itemPath!.isEmpty) &&
        fallbackKw != null &&
        fallbackKw.isNotEmpty &&
        fallbackKw != hints.itemPath) {
      if (await tryStep('② ショップ内キーワード（URL末尾から推定）', () {
        return _safeSearch(
          repo,
          RakutenProductSearchCondition(
            keyword: fallbackKw,
            shopCode: hints.shopCode,
          ),
        );
      })) {
        return;
      }
    }

    // 3. shopCode のみ
    if (hints.shopCode != null && hints.shopCode!.isNotEmpty) {
      if (await tryStep('③ ショップ全体（shopCode のみ）', () {
        return _safeSearch(
          repo,
          RakutenProductSearchCondition(
            keyword: '',
            shopCode: hints.shopCode,
          ),
        );
      })) {
        return;
      }
    }

    // 4. キーワードのみ（ショップ不明時など）
    if (fallbackKw != null && fallbackKw.isNotEmpty) {
      if (await tryStep('④ キーワードのみ（URLから推定）', () {
        return _safeSearch(
          repo,
          RakutenProductSearchCondition(keyword: fallbackKw),
        );
      })) {
        return;
      }
    }

    if (!mounted) return;
    setState(() {
      _loading = false;
      _items = const [];
      _searchTrace = List<String>.from(trace);
      _userMessage =
          '自動検索のどの段階でも商品が見つかりませんでした。'
          '履歴を確認のうえ、下のボタンで切り替えて試せます。';
    });
  }

  Future<void> _retryShopOnly() async {
    final hints = _lastHints;
    if (hints == null || hints.shopCode == null || hints.shopCode!.isEmpty) {
      return;
    }
    setState(() {
      _loading = true;
      _userMessage = null;
      _technicalErrorDetail = null;
      _items = const [];
    });
    final trace = <String>['▼ 手動: ショップのみ（shopCode）', '→ 検索中…'];
    try {
      final repo = context.read<RakutenSearchRepository>();
      final list = await _safeSearch(
        repo,
        RakutenProductSearchCondition(keyword: '', shopCode: hints.shopCode),
      );
      trace[1] = '→ ${list.length}件';
      if (!mounted) return;
      setState(() {
        _loading = false;
        _items = list;
        _searchTrace = trace;
        if (list.isEmpty) {
          _userMessage = 'ショップ内に該当商品が見つかりませんでした。';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _searchTrace = trace;
        _technicalErrorDetail = e.toString();
        _userMessage = 'ショップのみ検索でエラーになりました。';
      });
    }
  }

  Future<void> _retryShopWithPathKeyword() async {
    final hints = _lastHints;
    if (hints == null ||
        hints.shopCode == null ||
        hints.itemPath == null ||
        hints.itemPath!.isEmpty) {
      return;
    }
    setState(() {
      _loading = true;
      _userMessage = null;
      _technicalErrorDetail = null;
      _items = const [];
    });
    final trace = <String>[
      '▼ 手動: ショップ内キーワード（商品パス）',
      '→ 検索中…',
    ];
    try {
      final repo = context.read<RakutenSearchRepository>();
      final list = await _safeSearch(
        repo,
        RakutenProductSearchCondition(
          keyword: hints.itemPath!,
          shopCode: hints.shopCode,
        ),
      );
      trace[1] = '→ ${list.length}件';
      if (!mounted) return;
      setState(() {
        _loading = false;
        _items = list;
        _searchTrace = trace;
        if (list.isEmpty) {
          _userMessage = 'ショップ内キーワードでもヒットしませんでした。';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _searchTrace = trace;
        _technicalErrorDetail = e.toString();
        _userMessage = 'ショップ内キーワード検索でエラーになりました。';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Scaffold(
      backgroundColor: HomeScreenColors.canvas,
      appBar: AppBar(title: const Text('URLから追加')),
      body: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: SearchGroupScreenShell(
          backgroundColor: HomeScreenColors.canvas,
          subtitle:
              '探すグループ · 楽天市場URLから shopCode・商品パスを読み取り、API仕様に沿って順に検索します。',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _controller,
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.search,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: '楽天市場のURL',
                  hintText: 'https://item.rakuten.co.jp/...',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => _runSearch(),
              ),
              SizedBox(height: RakutenSearchScreenUi.gapFieldStack),
              AppPrimaryButton(
                label: '解析して検索',
                isLoading: _loading,
                onPressed: () {
                  _runSearch();
                },
                icon: const Icon(Icons.search_rounded),
              ),
              if (_lastHints != null) ...[
                SizedBox(height: RakutenSearchScreenUi.gapSection),
                Text(
                  '抽出: shopCode=${_lastHints!.shopCode ?? '—'} / '
                  '商品パス=${_lastHints!.itemPath ?? '—'} / '
                  'API用itemCode=${_lastHints!.itemCode ?? '—'}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.35,
                  ),
                ),
              ],
              if (_userMessage != null) ...[
                SizedBox(height: RakutenSearchScreenUi.gapSection),
                Material(
                  color: AppColors.accentLight.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(
                    AppDimensions.radiusButton,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: 20,
                          color: AppColors.accentPrimary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _userMessage!,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: AppColors.textPrimary,
                                  height: 1.4,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              if (_technicalErrorDetail != null) ...[
                SizedBox(height: RakutenSearchScreenUi.gapFieldStack),
                SelectableText(
                  _technicalErrorDetail!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
              if (_searchTrace.isNotEmpty) ...[
                SizedBox(height: RakutenSearchScreenUi.gapSection),
                Text(
                  '検索の試行履歴',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: HomeScreenColors.footnoteMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                ..._searchTrace.map(
                  (line) => Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Text(
                      line,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.35,
                      ),
                    ),
                  ),
                ),
              ],
              if (_lastHints != null &&
                  (_items.isEmpty && !_loading) &&
                  (_lastHints!.shopCode != null &&
                      _lastHints!.shopCode!.isNotEmpty)) ...[
                SizedBox(height: RakutenSearchScreenUi.gapSection),
                Wrap(
                  spacing: AppDimensions.spacingSm,
                  runSpacing: AppDimensions.spacingSm,
                  children: [
                    if (_lastHints!.itemPath != null &&
                        _lastHints!.itemPath!.isNotEmpty)
                      AppSecondaryButton(
                        label: 'ショップ内検索へ切替',
                        expand: false,
                        onPressed: _retryShopWithPathKeyword,
                        icon: const Icon(Icons.storefront_outlined),
                      ),
                    AppSecondaryButton(
                      label: 'ショップ全体を再検索',
                      expand: false,
                      onPressed: _retryShopOnly,
                      icon: const Icon(Icons.refresh_rounded),
                    ),
                  ],
                ),
              ],
              SizedBox(height: RakutenSearchScreenUi.gapListAfterDivider),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : Consumer2<RakutenManagedProductProvider,
                        RakutenSearchProvider>(
                        builder: (context, managed, search, _) {
                          if (_items.isEmpty) {
                            return Center(
                              child: Text(
                                _lastUrlText == null
                                    ? 'ここに検索結果が表示されます'
                                    : '結果がありません',
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(color: AppColors.textSecondary),
                              ),
                            );
                          }
                          return ListView.separated(
                            padding: EdgeInsets.fromLTRB(
                              RakutenSearchScreenUi.screenPadH,
                              RakutenSearchScreenUi.listScrollTopPad,
                              RakutenSearchScreenUi.screenPadH,
                              AppDimensions.spacingLg,
                            ),
                            itemCount: _items.length,
                            separatorBuilder: (_, __) =>
                                SizedBox(height: RakutenSearchScreenUi.listCardGap),
                            itemBuilder: (context, index) {
                              final item = _items[index];
                              return RakutenSearchResultCard(
                                item: item,
                                localStatus: managed.statusForProduct(
                                  item.productId,
                                ),
                                isRegistering: managed.isRegistering(
                                  item.productId,
                                ),
                                genreDisplayLineOverride:
                                    search.genreLineForItem(item),
                                sourceContextLabel: 'URLから追加',
                                onRegisterCandidate: () async {
                                  final err = await managed.registerCandidate(
                                    item,
                                  );
                                  if (!context.mounted) return;
                                  if (err != null) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(err)),
                                    );
                                  }
                                },
                              );
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
