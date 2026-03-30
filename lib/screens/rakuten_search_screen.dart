import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/rakuten_api_config.dart';
import '../navigation/app_route_observer.dart';
import '../state/rakuten_managed_product_provider.dart';
import '../state/rakuten_search_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/rakuten_search_result_card.dart';

/// 楽天API商品検索画面（最小構成）。
class RakutenSearchScreen extends StatefulWidget {
  const RakutenSearchScreen({super.key});

  @override
  State<RakutenSearchScreen> createState() => _RakutenSearchScreenState();
}

class _RakutenSearchScreenState extends State<RakutenSearchScreen>
    with RouteAware {
  _RakutenSearchMode _mode = _RakutenSearchMode.product;
  final TextEditingController _keywordController = TextEditingController();
  final TextEditingController _genreController = TextEditingController();
  final TextEditingController _shopController = TextEditingController();
  bool _routeSubscribed = false;

  void _resetSearchUi() {
    _keywordController.clear();
    _genreController.clear();
    _shopController.clear();
    _mode = _RakutenSearchMode.product;
    context.read<RakutenSearchProvider>().resetTransientState();
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _resetSearchUi();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_routeSubscribed) return;
    final route = ModalRoute.of(context);
    if (route is PageRoute<dynamic>) {
      appRouteObserver.subscribe(this, route);
      _routeSubscribed = true;
    }
  }

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    _keywordController.dispose();
    _genreController.dispose();
    _shopController.dispose();
    super.dispose();
  }

  @override
  void didPopNext() {
    _resetSearchUi();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('楽天検索'),
      ),
      body: SafeArea(
        child: Consumer2<RakutenSearchProvider, RakutenManagedProductProvider>(
          builder: (context, search, managed, _) {
            return Column(
              children: [
                _buildModeAndInputArea(context, search),
                Expanded(
                  child: _buildResultArea(context, search, managed),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _runSearch(BuildContext context) {
    context.read<RakutenSearchProvider>().search(_keywordController.text);
  }

  Widget _buildModeAndInputArea(
    BuildContext context,
    RakutenSearchProvider search,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '検索モード',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          _ModeSegmentedChips(
            currentMode: _mode,
            onChanged: (next) {
              if (_mode == next) return;
              setState(() => _mode = next);
              context.read<RakutenSearchProvider>().resetTransientState();
            },
          ),
          const SizedBox(height: 10),
          Text(
            _mode.description,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
          ),
          const SizedBox(height: 10),
          switch (_mode) {
            _RakutenSearchMode.product => _buildProductInput(context, search),
            _RakutenSearchMode.genre => _buildGenreInput(context),
            _RakutenSearchMode.shop => _buildShopInput(context),
          },
        ],
      ),
    );
  }

  Widget _buildProductInput(
    BuildContext context,
    RakutenSearchProvider search,
  ) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _keywordController,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _runSearch(context),
            decoration: const InputDecoration(
              hintText: '商品キーワードを入力',
              prefixIcon: Icon(Icons.search),
            ),
          ),
        ),
        const SizedBox(width: 8),
        FilledButton(
          onPressed: search.status == RakutenSearchStatus.loading
              ? null
              : () => _runSearch(context),
          child: const Text('検索'),
        ),
      ],
    );
  }

  Widget _buildGenreInput(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _genreController,
            textInputAction: TextInputAction.search,
            decoration: const InputDecoration(
              hintText: 'ジャンル名を入力（例: インテリア）',
              prefixIcon: Icon(Icons.category_outlined),
            ),
            onSubmitted: (_) => _showComingSoon(context, 'ジャンル検索'),
          ),
        ),
        const SizedBox(width: 8),
        OutlinedButton(
          onPressed: () => _showComingSoon(context, 'ジャンル検索'),
          child: const Text('検索'),
        ),
      ],
    );
  }

  Widget _buildShopInput(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _shopController,
            textInputAction: TextInputAction.search,
            decoration: const InputDecoration(
              hintText: 'ショップ名を入力（例: 楽天24）',
              prefixIcon: Icon(Icons.storefront_outlined),
            ),
            onSubmitted: (_) => _showComingSoon(context, 'ショップ検索'),
          ),
        ),
        const SizedBox(width: 8),
        OutlinedButton(
          onPressed: () => _showComingSoon(context, 'ショップ検索'),
          child: const Text('検索'),
        ),
      ],
    );
  }

  void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$featureは次ステップで有効化します')),
    );
  }

  Widget _buildResultArea(
    BuildContext context,
    RakutenSearchProvider search,
    RakutenManagedProductProvider managed,
  ) {
    if (_mode != _RakutenSearchMode.product) {
      return _modePlaceholder();
    }
    switch (search.status) {
      case RakutenSearchStatus.idle:
        return _centerText('商品名やキーワードを入力して検索してください');
      case RakutenSearchStatus.loading:
        return const Center(child: CircularProgressIndicator());
      case RakutenSearchStatus.error:
        return _centerText(
          '検索に失敗しました。\n${search.errorMessage}',
          isError: true,
        );
      case RakutenSearchStatus.success:
        if (search.results.isEmpty) {
          return _centerText('検索結果は0件でした');
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (kDebugMode) _buildAffiliateDebugBanner(search),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 90),
                itemCount: search.results.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final item = search.results[index];
                  return RakutenSearchResultCard(
                    item: item,
                    localStatus: managed.statusForProduct(item.productId),
                    isRegistering: managed.isRegistering(item.productId),
                    onRegisterCandidate: () async {
                      final err = await managed.registerCandidate(item);
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
          ],
        );
    }
  }

  Widget _buildAffiliateDebugBanner(RakutenSearchProvider provider) {
    final req = RakutenApiConfig.requestIncludesAffiliateId;
    final n = provider.resultsWithAffiliateUrlCount;
    final total = provider.results.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
      child: Text(
        'DEBUG: リクエストにaffiliateId付与=$req / レスポンスaffiliateUrlあり $n/$total 件 '
        '（APIはaffiliateId文字列を返しません。affiliateUrlの有無で判断）',
        style: TextStyle(
          fontSize: 11,
          height: 1.25,
          color: AppColors.textTertiary,
        ),
      ),
    );
  }

  Widget _centerText(String text, {bool isError = false}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isError ? AppColors.error : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _modePlaceholder() {
    final title = switch (_mode) {
      _RakutenSearchMode.genre => 'ジャンル検索の結果はここに表示されます',
      _RakutenSearchMode.shop => 'ショップ検索の結果はここに表示されます',
      _RakutenSearchMode.product => '',
    };
    final guide = switch (_mode) {
      _RakutenSearchMode.genre =>
        '上部でジャンル名を入力し検索すると、ジャンルに沿った商品一覧を表示する予定です。',
      _RakutenSearchMode.shop =>
        '上部でショップ名を入力し検索すると、ショップ起点の一覧を表示する予定です。',
      _RakutenSearchMode.product => '',
    };
    return Column(
      children: [
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _mode.icon,
                    size: 52,
                    color: AppColors.textTertiary.withValues(alpha: 0.55),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    guide,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

enum _RakutenSearchMode {
  product('商品検索', Icons.shopping_bag_outlined, '商品名・キーワードから商品を探します'),
  genre('ジャンル検索', Icons.category_outlined, 'ジャンル名から商品を探します（UI先行）'),
  shop('ショップ検索', Icons.storefront_outlined, 'ショップ名から商品を探します（UI先行）');

  const _RakutenSearchMode(this.label, this.icon, this.description);
  final String label;
  final IconData icon;
  final String description;
}

class _ModeSegmentedChips extends StatelessWidget {
  const _ModeSegmentedChips({
    required this.currentMode,
    required this.onChanged,
  });

  final _RakutenSearchMode currentMode;
  final ValueChanged<_RakutenSearchMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _RakutenSearchMode.values.map((mode) {
        final selected = currentMode == mode;
        return ChoiceChip(
          selected: selected,
          onSelected: (_) => onChanged(mode),
          avatar: Icon(
            mode.icon,
            size: 18,
            color: selected ? AppColors.textOnAccent : AppColors.textSecondary,
          ),
          label: Text(
            mode.label,
            style: TextStyle(
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? AppColors.textOnAccent : AppColors.textPrimary,
            ),
          ),
          selectedColor: AppColors.accentPrimary,
          backgroundColor: AppColors.surface,
          side: BorderSide(
            color: selected
                ? AppColors.accentPrimary
                : AppColors.divider,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusChip),
          ),
          showCheckmark: false,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
          labelPadding: const EdgeInsets.symmetric(horizontal: 6),
        );
      }).toList(),
    );
  }
}
