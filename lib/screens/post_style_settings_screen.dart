import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/post_style_settings.dart';
import '../services/post_comment_generation_service.dart';
import '../services/post_comment_generation_service_factory.dart';
import '../services/stub_post_comment_builder.dart';
import '../state/post_style_settings_provider.dart';
import '../theme/mypage_screen_tokens.dart';
import '../widgets/mypage/mypage_widgets.dart';

/// プレビュー用の固定商品情報。
const previewInput = PostCommentGenerationInput(
  itemName: '収納バスケット',
  recommendationReason: '部屋になじみやすく、口コミ評価も高いアイテムです。',
  itemPrice: 1980,
  reviewAverage: 4.5,
  reviewCount: 48,
);

/// AI投稿文の文体・長さなどを編集する画面。
class PostStyleSettingsScreen extends StatefulWidget {
  const PostStyleSettingsScreen({
    super.key,
    this.initialSettings,
    this.generationService,
  });

  /// テスト用。未指定時は Provider の現在値を利用。
  final PostStyleSettings? initialSettings;

  /// テスト用。未指定時は Factory 経由で生成。
  final PostCommentGenerationService? generationService;

  @override
  State<PostStyleSettingsScreen> createState() =>
      _PostStyleSettingsScreenState();
}

class _PostStyleSettingsScreenState extends State<PostStyleSettingsScreen> {
  late PostStyleSettings _draft;
  late TextEditingController _styleExampleController;
  late PostCommentGenerationService _generationService;
  bool _initialized = false;
  bool _saving = false;
  bool _refreshing = false;
  bool _previewNeedsRefresh = false;
  String? _previewError;
  PostStyleSettings? _lastRefreshedSettings;

  @override
  void dispose() {
    _styleExampleController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _draft = widget.initialSettings ??
        context.read<PostStyleSettingsProvider>().settings;
    _generationService =
        widget.generationService ?? PostCommentGenerationServiceFactory.create();
    _initializeStyleExample();
    _initialized = true;
  }

  void _initializeStyleExample() {
    final savedExample = _draft.styleExample?.trim();
    if (savedExample != null && savedExample.isNotEmpty) {
      _styleExampleController = TextEditingController(text: savedExample);
      _lastRefreshedSettings = _draft;
      _previewNeedsRefresh = false;
      return;
    }

    _styleExampleController = TextEditingController(
      text: StubPostCommentBuilder.build(input: previewInput, style: _draft),
    );
    _lastRefreshedSettings = null;
    _previewNeedsRefresh = true;
  }

  void _updateDraft(PostStyleSettings next) {
    setState(() {
      _draft = next;
      if (_lastRefreshedSettings == null ||
          !next.hasSamePreviewConfig(_lastRefreshedSettings!)) {
        _previewNeedsRefresh = true;
        _previewError = null;
      }
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    final exampleText = _styleExampleController.text.trim();
    final toSave = _draft.copyWith(
      styleExample: exampleText.isEmpty ? null : exampleText,
      clearStyleExample: exampleText.isEmpty,
    );
    await context.read<PostStyleSettingsProvider>().saveSettings(toSave);
    if (!mounted) return;
    setState(() {
      _saving = false;
      _draft = toSave;
      _lastRefreshedSettings = toSave;
      _previewNeedsRefresh = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('投稿スタイルを保存しました')),
    );
  }

  Future<void> _refreshPreview() async {
    if (_refreshing || !_previewNeedsRefresh) return;
    setState(() {
      _refreshing = true;
      _previewError = null;
    });

    try {
      final result = await _generationService.generate(
        PostCommentGenerationInput(
          itemName: previewInput.itemName,
          recommendationReason: previewInput.recommendationReason,
          itemPrice: previewInput.itemPrice,
          reviewAverage: previewInput.reviewAverage,
          reviewCount: previewInput.reviewCount,
          styleSettings: _draft,
        ),
      );
      if (!mounted) return;
      setState(() {
        _styleExampleController.text = result.displayText;
        _lastRefreshedSettings = _draft;
        _previewNeedsRefresh = false;
        _refreshing = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _previewError = '生成イメージの更新に失敗しました。';
        _refreshing = false;
      });
    }
  }

  Future<void> _confirmReset() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('初期設定に戻す'),
        content: const Text('投稿スタイルを初期設定に戻しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('戻す'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    final defaults = PostStyleSettings.defaults();
    await context.read<PostStyleSettingsProvider>().resetToDefaults();
    if (!mounted) return;
    setState(() {
      _draft = defaults;
      _styleExampleController.text =
          StubPostCommentBuilder.build(input: previewInput, style: defaults);
      _lastRefreshedSettings = null;
      _previewNeedsRefresh = true;
      _previewError = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('初期設定に戻しました')),
    );
  }

  void _toggleFocusPoint(PostFocusPoint point) {
    final current = List<PostFocusPoint>.from(_draft.focusPoints);
    if (current.contains(point)) {
      current.remove(point);
    } else {
      if (current.length >= PostStyleSettings.maxFocusPoints) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('推し方は3つまで選べます')),
        );
        return;
      }
      current.add(point);
    }
    _updateDraft(_draft.copyWith(focusPoints: current));
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Semantics(
      container: true,
      label: 'post_style_settings_screen',
      child: Scaffold(
        backgroundColor: MyPageScreenUi.canvas,
        appBar: AppBar(
          title: const Text('投稿スタイル設定'),
          backgroundColor: MyPageScreenUi.canvas,
          surfaceTintColor: Colors.transparent,
          actions: [
            TextButton(
              key: const Key('post_style_save_button'),
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('保存'),
            ),
          ],
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              MyPageScreenUi.screenPadH,
              8,
              MyPageScreenUi.screenPadH,
              MyPageScreenUi.navReserve,
            ),
            children: [
              Text(
                'AIで投稿文を作るときの文体や長さを調整できます。',
                style: textTheme.bodyMedium?.copyWith(
                  color: MyPageScreenUi.textSecondary,
                  height: 1.45,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: MyPageScreenUi.gapSection),
              _PreviewCard(
                controller: _styleExampleController,
                refreshing: _refreshing,
                previewNeedsRefresh: _previewNeedsRefresh,
                previewError: _previewError,
                onRefresh: _refreshPreview,
              ),
              const SizedBox(height: MyPageScreenUi.gapSection),
              _SettingsCard(
                title: '基本',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _SettingRow(
                      label: '文体',
                      child: Semantics(
                        label: 'post_style_tone_control',
                        child: _SingleChoiceChips<PostTone>(
                          values: PostTone.values,
                          selected: _draft.tone,
                          labelBuilder: _toneLabel,
                          onChanged: (v) => _updateDraft(_draft.copyWith(tone: v)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _SettingRow(
                      label: '文章量',
                      child: Semantics(
                        label: 'post_style_length_control',
                        child: _SingleChoiceChips<PostLength>(
                          values: PostLength.values,
                          selected: _draft.length,
                          labelBuilder: _lengthLabel,
                          onChanged: (v) =>
                              _updateDraft(_draft.copyWith(length: v)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: MyPageScreenUi.gapSection),
              _SettingsCard(
                title: '装飾',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _SettingRow(
                      label: '絵文字',
                      child: Semantics(
                        label: 'post_style_emoji_control',
                        child: _SingleChoiceChips<EmojiLevel>(
                          values: EmojiLevel.values,
                          selected: _draft.emojiLevel,
                          labelBuilder: _emojiLabel,
                          onChanged: (v) =>
                              _updateDraft(_draft.copyWith(emojiLevel: v)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _SettingRow(
                      label: '顔文字',
                      child: Semantics(
                        label: 'post_style_kaomoji_switch',
                        child: SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('顔文字を使う'),
                          value: _draft.kaomojiEnabled,
                          activeThumbColor: MyPageScreenUi.primary,
                          onChanged: (v) =>
                              _updateDraft(_draft.copyWith(kaomojiEnabled: v)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    _SettingRow(
                      label: 'ハッシュタグ',
                      child: Semantics(
                        label: 'post_style_hashtag_control',
                        child: _SingleChoiceChips<HashtagLevel>(
                          values: HashtagLevel.values,
                          selected: _draft.hashtagLevel,
                          labelBuilder: _hashtagLabel,
                          onChanged: (v) =>
                              _updateDraft(_draft.copyWith(hashtagLevel: v)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: MyPageScreenUi.gapSection),
              _SettingsCard(
                title: '内容',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _SettingRow(
                      label: '推し方',
                      subtitle: '最大3件まで',
                      child: Semantics(
                        label: 'post_style_focus_points',
                        child: _HorizontalChoiceChips<PostFocusPoint>(
                          values: PostFocusPoint.values,
                          selected: _draft.focusPoints,
                          labelBuilder: _focusPointLabel,
                          onToggle: _toggleFocusPoint,
                          multiSelect: true,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _SettingRow(
                      label: '読者層',
                      child: Semantics(
                        label: 'post_style_target_audience_control',
                        child: DropdownButtonFormField<PostTargetAudience>(
                          key: ValueKey<PostTargetAudience>(_draft.targetAudience),
                          initialValue: _draft.targetAudience,
                          isExpanded: true,
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: MyPageScreenUi.cardBorder,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: MyPageScreenUi.cardBorder,
                              ),
                            ),
                          ),
                          items: [
                            for (final audience in PostTargetAudience.values)
                              DropdownMenuItem(
                                value: audience,
                                child: Text(_audienceLabel(audience)),
                              ),
                          ],
                          onChanged: (v) {
                            if (v == null) return;
                            _updateDraft(_draft.copyWith(targetAudience: v));
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Semantics(
                      label: 'post_style_avoid_overstatement_switch',
                      child: SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('誇張表現を避ける'),
                        subtitle: const Text(
                          '「絶対」「必ず」などの強い表現を控えめにします。',
                        ),
                        value: _draft.avoidOverstatement,
                        activeThumbColor: MyPageScreenUi.primary,
                        onChanged: (v) => _updateDraft(
                          _draft.copyWith(avoidOverstatement: v),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: MyPageScreenUi.gapSection),
              MyPageOutlineButton(
                key: const Key('post_style_reset_button'),
                label: '初期設定に戻す',
                onPressed: _confirmReset,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({
    required this.controller,
    required this.refreshing,
    required this.previewNeedsRefresh,
    required this.previewError,
    required this.onRefresh,
  });

  final TextEditingController controller;
  final bool refreshing;
  final bool previewNeedsRefresh;
  final String? previewError;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return MyPageCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '生成イメージ',
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: MyPageScreenUi.textPrimary,
                  ),
                ),
              ),
              Semantics(
                label: '投稿イメージを更新',
                button: true,
                enabled: previewNeedsRefresh && !refreshing,
                child: IconButton(
                  key: const Key('post_style_preview_refresh_button'),
                  tooltip: 'AIで更新',
                  onPressed: previewNeedsRefresh && !refreshing
                      ? onRefresh
                      : null,
                  icon: refreshing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                ),
              ),
            ],
          ),
          Semantics(
            label: 'post_style_preview',
            child: TextField(
              key: const Key('post_style_preview_text_field'),
              controller: controller,
              minLines: 5,
              maxLines: null,
              decoration: InputDecoration(
                hintText: '設定を反映した投稿文の例がここに表示されます',
                filled: true,
                fillColor: MyPageScreenUi.chipUnsetFill,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: MyPageScreenUi.cardBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: MyPageScreenUi.cardBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: MyPageScreenUi.primaryBorder),
                ),
              ),
              style: textTheme.bodyMedium?.copyWith(
                color: MyPageScreenUi.textPrimary,
                height: 1.5,
              ),
            ),
          ),
          if (previewError != null) ...[
            const SizedBox(height: 8),
            Text(
              previewError!,
              key: const Key('post_style_preview_error'),
              style: textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            'この文例を参考に投稿文を作ります',
            style: textTheme.bodySmall?.copyWith(
              color: MyPageScreenUi.textSecondary,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MyPageCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: MyPageScreenUi.textPrimary,
                ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.label,
    required this.child,
    this.subtitle,
  });

  final String label;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            SizedBox(
              width: 72,
              child: Text(
                label,
                style: textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: MyPageScreenUi.textPrimary,
                ),
              ),
            ),
            if (subtitle != null)
              Text(
                subtitle!,
                style: textTheme.bodySmall?.copyWith(
                  color: MyPageScreenUi.textSecondary,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

class _SingleChoiceChips<T> extends StatelessWidget {
  const _SingleChoiceChips({
    required this.values,
    required this.selected,
    required this.labelBuilder,
    required this.onChanged,
  });

  final List<T> values;
  final T selected;
  final String Function(T) labelBuilder;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return _HorizontalChoiceChips<T>(
      values: values,
      selected: [selected],
      labelBuilder: labelBuilder,
      onToggle: (value) => onChanged(value),
    );
  }
}

class _HorizontalChoiceChips<T> extends StatelessWidget {
  const _HorizontalChoiceChips({
    required this.values,
    required this.selected,
    required this.labelBuilder,
    required this.onToggle,
    this.multiSelect = false,
  });

  final List<T> values;
  final List<T> selected;
  final String Function(T) labelBuilder;
  final ValueChanged<T> onToggle;
  final bool multiSelect;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final value in values) ...[
            _StyleChoiceChip(
              label: labelBuilder(value),
              selected: selected.contains(value),
              onSelected: (_) => onToggle(value),
            ),
            if (value != values.last) const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _StyleChoiceChip extends StatelessWidget {
  const _StyleChoiceChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      showCheckmark: true,
      checkmarkColor: MyPageScreenUi.primary,
      selectedColor: MyPageScreenUi.chipSetFill,
      backgroundColor: Colors.white,
      side: BorderSide(
        color: selected
            ? MyPageScreenUi.primaryBorder
            : MyPageScreenUi.chipUnsetBorder,
      ),
      labelStyle: TextStyle(
        color: selected ? MyPageScreenUi.primary : MyPageScreenUi.textPrimary,
        fontWeight: FontWeight.w600,
      ),
      onSelected: onSelected,
    );
  }
}

String _toneLabel(PostTone tone) => switch (tone) {
      PostTone.polite => '丁寧',
      PostTone.friendlyPolite => '親しみやすい',
      PostTone.casual => 'フランク',
    };

String _lengthLabel(PostLength length) => switch (length) {
      PostLength.short => '短め',
      PostLength.standard => '標準',
      PostLength.detailed => '詳しめ',
    };

String _emojiLabel(EmojiLevel level) => switch (level) {
      EmojiLevel.none => '使わない',
      EmojiLevel.low => '少なめ',
      EmojiLevel.medium => '普通',
    };

String _hashtagLabel(HashtagLevel level) => switch (level) {
      HashtagLevel.none => 'なし',
      HashtagLevel.few => '3個程度',
      HashtagLevel.standard => '5個程度',
    };

String _focusPointLabel(PostFocusPoint point) => switch (point) {
      PostFocusPoint.costPerformance => 'コスパ',
      PostFocusPoint.convenience => '便利さ',
      PostFocusPoint.reviews => '口コミ',
      PostFocusPoint.design => 'デザイン',
      PostFocusPoint.cute => 'かわいさ',
      PostFocusPoint.gift => 'ギフト',
      PostFocusPoint.parenting => '子育て',
      PostFocusPoint.dailyUse => '普段使い',
    };

String _audienceLabel(PostTargetAudience audience) => switch (audience) {
      PostTargetAudience.general => '指定なし',
      PostTargetAudience.women => '女性向け',
      PostTargetAudience.men => '男性向け',
      PostTargetAudience.parents => '子育て世帯向け',
      PostTargetAudience.singleLife => '一人暮らし向け',
      PostTargetAudience.roomBeginner => 'ROOM初心者向け',
    };
