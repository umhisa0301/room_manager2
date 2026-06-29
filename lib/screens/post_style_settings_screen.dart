import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/post_style_settings.dart';
import '../services/post_comment_generation_service.dart';
import '../services/stub_post_comment_builder.dart';
import '../state/post_style_settings_provider.dart';
import '../theme/mypage_screen_tokens.dart';
import '../widgets/mypage/mypage_widgets.dart';

/// プレビュー用の固定商品情報。
const _previewInput = PostCommentGenerationInput(
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
  });

  /// テスト用。未指定時は Provider の現在値を利用。
  final PostStyleSettings? initialSettings;

  @override
  State<PostStyleSettingsScreen> createState() =>
      _PostStyleSettingsScreenState();
}

class _PostStyleSettingsScreenState extends State<PostStyleSettingsScreen> {
  late PostStyleSettings _draft;
  bool _initialized = false;
  bool _saving = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _draft = widget.initialSettings ??
        context.read<PostStyleSettingsProvider>().settings;
    _initialized = true;
  }

  String get _previewText => StubPostCommentBuilder.build(
        input: _previewInput,
        style: _draft,
      );

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    await context.read<PostStyleSettingsProvider>().saveSettings(_draft);
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('投稿スタイルを保存しました')),
    );
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
    setState(() => _draft = defaults);
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
    setState(() => _draft = _draft.copyWith(focusPoints: current));
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
              _SettingsCard(
                title: '文体',
                child: Semantics(
                  label: 'post_style_tone_control',
                  child: _SingleChoiceChips<PostTone>(
                    values: PostTone.values,
                    selected: _draft.tone,
                    labelBuilder: _toneLabel,
                    onChanged: (v) => setState(() => _draft = _draft.copyWith(tone: v)),
                  ),
                ),
              ),
              const SizedBox(height: MyPageScreenUi.gapSection),
              _SettingsCard(
                title: '文章量',
                child: Semantics(
                  label: 'post_style_length_control',
                  child: _SingleChoiceChips<PostLength>(
                    values: PostLength.values,
                    selected: _draft.length,
                    labelBuilder: _lengthLabel,
                    subtitleBuilder: _lengthSubtitle,
                    onChanged: (v) =>
                        setState(() => _draft = _draft.copyWith(length: v)),
                  ),
                ),
              ),
              const SizedBox(height: MyPageScreenUi.gapSection),
              _SettingsCard(
                title: '絵文字',
                child: Semantics(
                  label: 'post_style_emoji_control',
                  child: _SingleChoiceChips<EmojiLevel>(
                    values: EmojiLevel.values,
                    selected: _draft.emojiLevel,
                    labelBuilder: _emojiLabel,
                    onChanged: (v) =>
                        setState(() => _draft = _draft.copyWith(emojiLevel: v)),
                  ),
                ),
              ),
              const SizedBox(height: MyPageScreenUi.gapSection),
              _SettingsCard(
                title: '顔文字',
                child: Semantics(
                  label: 'post_style_kaomoji_switch',
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('顔文字を使う'),
                    value: _draft.kaomojiEnabled,
                    activeThumbColor: MyPageScreenUi.primary,
                    onChanged: (v) =>
                        setState(() => _draft = _draft.copyWith(kaomojiEnabled: v)),
                  ),
                ),
              ),
              const SizedBox(height: MyPageScreenUi.gapSection),
              _SettingsCard(
                title: 'ハッシュタグ',
                child: Semantics(
                  label: 'post_style_hashtag_control',
                  child: _SingleChoiceChips<HashtagLevel>(
                    values: HashtagLevel.values,
                    selected: _draft.hashtagLevel,
                    labelBuilder: _hashtagLabel,
                    onChanged: (v) => setState(
                      () => _draft = _draft.copyWith(hashtagLevel: v),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: MyPageScreenUi.gapSection),
              _SettingsCard(
                title: '推し方',
                subtitle: '最大3件まで選べます',
                child: Semantics(
                  label: 'post_style_focus_points',
                  child: _MultiChoiceChips<PostFocusPoint>(
                    values: PostFocusPoint.values,
                    selected: _draft.focusPoints,
                    labelBuilder: _focusPointLabel,
                    onToggle: _toggleFocusPoint,
                  ),
                ),
              ),
              const SizedBox(height: MyPageScreenUi.gapSection),
              _SettingsCard(
                title: '読者層',
                child: Semantics(
                  label: 'post_style_target_audience_control',
                  child: _SingleChoiceChips<PostTargetAudience>(
                    values: PostTargetAudience.values,
                    selected: _draft.targetAudience,
                    labelBuilder: _audienceLabel,
                    onChanged: (v) => setState(
                      () => _draft = _draft.copyWith(targetAudience: v),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: MyPageScreenUi.gapSection),
              _SettingsCard(
                title: '表現',
                child: Semantics(
                  label: 'post_style_avoid_overstatement_switch',
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('誇張表現を避ける'),
                    subtitle: const Text('「絶対」「必ず」などの強い表現を控えめにします。'),
                    value: _draft.avoidOverstatement,
                    activeThumbColor: MyPageScreenUi.primary,
                    onChanged: (v) => setState(
                      () => _draft = _draft.copyWith(avoidOverstatement: v),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: MyPageScreenUi.gapSection),
              MyPageCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '生成イメージ',
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: MyPageScreenUi.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Semantics(
                      label: 'post_style_preview',
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: MyPageScreenUi.chipUnsetFill,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: MyPageScreenUi.cardBorder),
                        ),
                        child: Text(
                          _previewText,
                          key: const Key('post_style_preview_text'),
                          style: textTheme.bodyMedium?.copyWith(
                            color: MyPageScreenUi.textPrimary,
                            height: 1.5,
                          ),
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

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.title,
    required this.child,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
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
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: MyPageScreenUi.textSecondary,
                    height: 1.35,
                  ),
            ),
          ],
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _SingleChoiceChips<T> extends StatelessWidget {
  const _SingleChoiceChips({
    required this.values,
    required this.selected,
    required this.labelBuilder,
    required this.onChanged,
    this.subtitleBuilder,
  });

  final List<T> values;
  final T selected;
  final String Function(T) labelBuilder;
  final String? Function(T)? subtitleBuilder;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final value in values)
          _StyleChoiceChip(
            label: labelBuilder(value),
            subtitle: subtitleBuilder?.call(value),
            selected: value == selected,
            onSelected: (_) => onChanged(value),
          ),
      ],
    );
  }
}

class _MultiChoiceChips<T> extends StatelessWidget {
  const _MultiChoiceChips({
    required this.values,
    required this.selected,
    required this.labelBuilder,
    required this.onToggle,
  });

  final List<T> values;
  final List<T> selected;
  final String Function(T) labelBuilder;
  final ValueChanged<T> onToggle;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final value in values)
          _StyleChoiceChip(
            label: labelBuilder(value),
            selected: selected.contains(value),
            onSelected: (_) => onToggle(value),
          ),
      ],
    );
  }
}

class _StyleChoiceChip extends StatelessWidget {
  const _StyleChoiceChip({
    required this.label,
    required this.selected,
    required this.onSelected,
    this.subtitle,
  });

  final String label;
  final String? subtitle;
  final bool selected;
  final ValueChanged<bool> onSelected;

  @override
  Widget build(BuildContext context) {
    final labelWidget = subtitle == null
        ? Text(label)
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
              Text(
                subtitle!,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: selected
                          ? MyPageScreenUi.primary
                          : MyPageScreenUi.textSecondary,
                    ),
              ),
            ],
          );

    return FilterChip(
      label: labelWidget,
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

String? _lengthSubtitle(PostLength length) => switch (length) {
      PostLength.short => '60〜90字',
      PostLength.standard => '100〜140字',
      PostLength.detailed => '160〜220字',
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
