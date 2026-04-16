import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class ClosedTestDemoScreen extends StatelessWidget {
  const ClosedTestDemoScreen({super.key});

  static const String title = 'クローズドテスト用デモ';

  @override
  Widget build(BuildContext context) {
    final demo = _DemoDataSource.sample();
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text(title)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppDimensions.screenPaddingH,
            AppDimensions.spacingMd,
            AppDimensions.screenPaddingH,
            28,
          ),
          children: [
            _SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'この画面はデモ専用です',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '表示内容は固定のサンプルデータのみを使っています。'
                    '通常の候補・コレ済・保存ショップには一切保存しません。',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppDimensions.spacingMd),
            _SectionHeader(title: 'ROOMコレ デモ集計', body: 'サンプルの進捗イメージです。'),
            const SizedBox(height: 10),
            _SectionCard(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _StatChip(label: '候補', value: '${demo.candidateCount}件'),
                  _StatChip(label: 'コレ済', value: '${demo.collectedCount}件'),
                  _StatChip(label: '今日のコレ', value: '${demo.todayCollectedCount}件'),
                  _StatChip(label: '保存ショップ', value: '${demo.savedShopCount}件'),
                ],
              ),
            ),
            const SizedBox(height: AppDimensions.spacingMd),
            _SectionHeader(title: '候補デモ', body: '実データとは無関係の候補一覧です。'),
            const SizedBox(height: 10),
            _SectionCard(
              child: Column(
                children: demo.candidateItems
                    .map((e) => _DemoItemTile(item: e, kind: '候補'))
                    .toList(growable: false),
              ),
            ),
            const SizedBox(height: AppDimensions.spacingMd),
            _SectionHeader(title: 'コレ済デモ', body: 'コレ済み状態の見え方サンプルです。'),
            const SizedBox(height: 10),
            _SectionCard(
              child: Column(
                children: demo.collectedItems
                    .map((e) => _DemoItemTile(item: e, kind: 'コレ済'))
                    .toList(growable: false),
              ),
            ),
            const SizedBox(height: AppDimensions.spacingMd),
            _SectionHeader(title: '保存ショップデモ', body: '保存ショップの例です。'),
            const SizedBox(height: 10),
            _SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: demo.savedShops
                    .map(
                      (e) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.storefront_outlined,
                              size: 18,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                e,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(growable: false),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DemoDataSource {
  const _DemoDataSource({
    required this.candidateCount,
    required this.collectedCount,
    required this.todayCollectedCount,
    required this.savedShopCount,
    required this.candidateItems,
    required this.collectedItems,
    required this.savedShops,
  });

  final int candidateCount;
  final int collectedCount;
  final int todayCollectedCount;
  final int savedShopCount;
  final List<_DemoItem> candidateItems;
  final List<_DemoItem> collectedItems;
  final List<String> savedShops;

  factory _DemoDataSource.sample() {
    const candidateItems = <_DemoItem>[
      _DemoItem(name: '北欧デザイン マグカップ', shop: 'くらし雑貨ストア'),
      _DemoItem(name: '軽量 コンパクト 折りたたみ傘', shop: 'Daily Outdoor'),
      _DemoItem(name: '耐熱 ガラス保存容器セット', shop: 'キッチンラボ'),
    ];
    const collectedItems = <_DemoItem>[
      _DemoItem(name: '着圧 ソックス 3足セット', shop: 'ヘルスケア本舗'),
      _DemoItem(name: 'USB充電式 ハンディファン', shop: 'Life Gadget'),
    ];
    const savedShops = <String>[
      'くらし雑貨ストア',
      'キッチンラボ',
      'Life Gadget',
      '北欧インテリア館',
    ];

    return _DemoDataSource(
      candidateCount: candidateItems.length,
      collectedCount: collectedItems.length,
      todayCollectedCount: 1,
      savedShopCount: savedShops.length,
      candidateItems: candidateItems,
      collectedItems: collectedItems,
      savedShops: savedShops,
    );
  }
}

class _DemoItem {
  const _DemoItem({required this.name, required this.shop});

  final String name;
  final String shop;
}

class _DemoItemTile extends StatelessWidget {
  const _DemoItemTile({required this.item, required this.kind});

  final _DemoItem item;
  final String kind;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.inventory_2_outlined,
              size: 18,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${item.shop}  ・  $kind',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          body,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppColors.textSecondary,
            height: 1.42,
          ),
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        border: Border.all(color: AppColors.divider),
      ),
      child: child,
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppDimensions.radiusChip),
      ),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '$label: ',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
            TextSpan(
              text: value,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
