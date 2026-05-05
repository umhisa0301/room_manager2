import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/rakuten_product_search_condition.dart';
import '../models/rakuten_search_item.dart';
import '../navigation/rakuten_search_navigator.dart';
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
  final _urlFocusNode = FocusNode();
  bool _loading = false;
  String? _userMessage;
  String? _technicalErrorDetail;
  List<RakutenSearchItem> _items = const [];
  List<String> _searchTrace = const [];
  RakutenIchibaUrlHints? _lastHints;
  String? _lastUrlText;
  bool _linkMatchWasApproximate = false;

  @override
  void dispose() {
    _urlFocusNode.dispose();
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
      setState(() {
        _loading = false;
        _userMessage =
            'URLから店舗・商品情報を読み取れませんでした。'
            'コピーしたリンクを確認するか、別のURLを試してください。';
        _technicalErrorDetail = null;
        _items = const [];
        _searchTrace = const [];
        _lastHints = hints;
        _lastUrlText = urlText;
        _linkMatchWasApproximate = false;
      });
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
      _linkMatchWasApproximate = false;
    });

    final repo = context.read<RakutenSearchRepository>();
    final trace = <String>[];

    Future<bool> tryStep(
      String title,
      Future<List<RakutenSearchItem>> Function() run, {
      bool urlMatchIsApproximate = false,
    }) async {
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
            _linkMatchWasApproximate = urlMatchIsApproximate;
            _userMessage = null;
            _technicalErrorDetail = null;
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
      }, urlMatchIsApproximate: false)) {
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
      }, urlMatchIsApproximate: true)) {
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
      }, urlMatchIsApproximate: true)) {
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
      }, urlMatchIsApproximate: true)) {
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
      }, urlMatchIsApproximate: true)) {
        return;
      }
    }

    if (!mounted) return;
    setState(() {
      _loading = false;
      _items = const [];
      _searchTrace = List<String>.from(trace);
      _userMessage =
          '商品を見つけられませんでした。'
          'URLを確認するか、楽天で商品名検索を試してください。';
      _linkMatchWasApproximate = false;
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
        _linkMatchWasApproximate = true;
        if (list.isEmpty) {
          _userMessage =
              '商品を見つけられませんでした。'
              'URLを確認するか、楽天で商品名検索を試してください。';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _searchTrace = trace;
        _technicalErrorDetail = e.toString();
        _userMessage = 'ショップのみ検索でエラーになりました。';
        _linkMatchWasApproximate = false;
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
        _linkMatchWasApproximate = true;
        if (list.isEmpty) {
          _userMessage =
              '商品を見つけられませんでした。'
              'URLを確認するか、楽天で商品名検索を試してください。';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _searchTrace = trace;
        _technicalErrorDetail = e.toString();
        _userMessage = 'ショップ内キーワード検索でエラーになりました。';
        _linkMatchWasApproximate = false;
      });
    }
  }

  void _openProductNameSearch() {
    openRakutenSearchScreen(
      context,
      initialMode: RakutenSearchInitialMode.product,
    );
  }

  Widget _friendlyResultCallout(BuildContext context) {
    if (_items.isEmpty || _lastUrlText == null) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: EdgeInsets.only(top: RakutenSearchScreenUi.gapSection),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: HomeScreenColors.metricRoleCandidateIconBg.withValues(
            alpha: 0.35,
          ),
          borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
          border: Border.all(
            color: AppColors.accentPrimary.withValues(alpha: 0.18),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.link_rounded,
                    size: 20,
                    color: AppColors.accentPrimary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'URLを読み取りました',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w800,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: AppDimensions.spacingXs),
              Text(
                '${_items.length}件見つかりました',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.45,
                ),
              ),
              if (_linkMatchWasApproximate) ...[
                SizedBox(height: AppDimensions.spacingXs),
                Text(
                  '完全一致ではありません。近い候補を表示しています。',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.45,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _developerExpansion(BuildContext context) {
    final hints = _lastHints;
    final hasTrace = _searchTrace.isNotEmpty;
    final hasHints = hints != null && !hints.isEmpty;
    if (!hasTrace && !hasHints) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: EdgeInsets.only(top: RakutenSearchScreenUi.gapSection),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.only(bottom: 8),
          title: Text(
            '検索の詳細（開発者向け）',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: HomeScreenColors.footnoteMuted,
              fontWeight: FontWeight.w700,
            ),
          ),
          children: [
            if (hasHints)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '抽出: shopCode=${hints.shopCode ?? '—'} / '
                  '商品パス=${hints.itemPath ?? '—'} / '
                  'API用itemCode=${hints.itemCode ?? '—'}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.35,
                  ),
                ),
              ),
            if (hasTrace) ...[
              Text(
                '試行履歴（内部）',
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
          ],
        ),
      ),
    );
  }

  Widget _emptyStatePlaceholders(BuildContext context) {
    if (_lastUrlText == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 28),
        child: Column(
          children: [
            Icon(
              Icons.add_link_rounded,
              size: 42,
              color: AppColors.textTertiary.withValues(alpha: 0.6),
            ),
            SizedBox(height: RakutenSearchScreenUi.gapFieldStack + 2),
            Text(
              '楽天市場のURLを貼り付けて検索できます',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
                height: 1.45,
              ),
            ),
          ],
        ),
      );
    }
    final parseFailed =
        _lastHints != null && _lastHints!.isEmpty && !_loading;
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 24,
        horizontal: AppDimensions.spacingSm,
      ),
      child: Column(
        children: [
          Icon(
            parseFailed ? Icons.link_off_rounded : Icons.search_off_rounded,
            size: 44,
            color: AppColors.textTertiary.withValues(alpha: 0.65),
          ),
          SizedBox(height: RakutenSearchScreenUi.gapSection),
          Text(
            parseFailed
                ? 'URLを読み取れませんでした'
                : '商品を見つけられませんでした',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: AppDimensions.spacingSm),
          Text(
            _userMessage ??
                'URLを確認するか、楽天で商品名検索を試してください。',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          SizedBox(height: RakutenSearchScreenUi.gapSection + 4),
          AppPrimaryButton(
            label: '商品名で探す',
            expand: false,
            onPressed: _openProductNameSearch,
            icon: const Icon(Icons.search_rounded),
          ),
          SizedBox(height: AppDimensions.spacingSm),
          AppSecondaryButton(
            label: 'URLを修正する',
            expand: false,
            onPressed: () {
              _urlFocusNode.requestFocus();
              _controller.selection = TextSelection(
                baseOffset: 0,
                extentOffset: _controller.text.length,
              );
            },
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Scaffold(
      backgroundColor: HomeScreenColors.canvas,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(title: const Text('URLから追加')),
      body: SearchGroupScreenShell(
        backgroundColor: HomeScreenColors.canvas,
        subtitle:
            '探すグループ · 楽天市場のURLを貼り付けると商品を探し、候補に追加できます。',
        child: Consumer2<RakutenManagedProductProvider, RakutenSearchProvider>(
          builder: (context, managed, search, _) {
            final slivers = <Widget>[
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _controller,
                      focusNode: _urlFocusNode,
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
                    if (_items.isNotEmpty) _friendlyResultCallout(context),
                    if (_technicalErrorDetail != null) ...[
                      SizedBox(height: RakutenSearchScreenUi.gapFieldStack),
                      SelectableText(
                        _technicalErrorDetail!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                    if (_lastHints != null &&
                        !_lastHints!.isEmpty &&
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
                    _developerExpansion(context),
                    if (!_loading && _items.isEmpty)
                      _emptyStatePlaceholders(context),
                    SizedBox(height: bottomInset > 0 ? bottomInset + 12 : 0),
                  ],
                ),
              ),
              if (_loading)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 36),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
              if (!_loading && _items.isNotEmpty)
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    RakutenSearchScreenUi.screenPadH,
                    RakutenSearchScreenUi.gapListAfterDivider,
                    RakutenSearchScreenUi.screenPadH,
                    AppDimensions.spacingLg + bottomInset,
                  ),
                  sliver: SliverList.separated(
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
                        genreDisplayLineOverride: search.genreLineForItem(item),
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
                  ),
                ),
            ];
            return CustomScrollView(
              keyboardDismissBehavior:
                  ScrollViewKeyboardDismissBehavior.onDrag,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: slivers,
            );
          },
        ),
      ),
    );
  }
}
