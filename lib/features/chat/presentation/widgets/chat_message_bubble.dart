import 'package:cortex/core/constants/colors.dart';
import 'package:cortex/core/constants/dimens.dart';
import 'package:cortex/core/constants/text_styles.dart';
import 'package:cortex/core/navigation/note_routes.dart';
import 'package:cortex/features/chat/domain/chat_message.dart';
import 'package:cortex/features/chat/domain/chat_source.dart';
import 'package:cortex/features/chat/domain/chat_source_parser.dart';
import 'package:cortex/features/chat/presentation/providers/chat_providers.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'chat_source_card.dart';

/// Keyed message bubble watching its own [chatMessageFamilyProvider].
/// Ensures only the specific bubble receiving streamed tokens rebuilds.
class ChatMessageBubble extends ConsumerWidget {
  final String messageId;

  const ChatMessageBubble({
    super.key,
    required this.messageId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final message = ref.watch(chatMessageFamilyProvider(messageId));
    if (message == null) return const SizedBox.shrink();

    if (message.sender == MessageSender.user) {
      return _UserMessageBubble(message: message);
    } else {
      return _AssistantMessageBubble(message: message);
    }
  }
}

class _UserMessageBubble extends StatelessWidget {
  final ChatMessage message;

  const _UserMessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(48, 6, AppSpacing.page, 6),
      child: Align(
        alignment: Alignment.centerRight,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(AppRadius.lg),
              topRight: Radius.circular(AppRadius.lg),
              bottomLeft: Radius.circular(AppRadius.lg),
              bottomRight: Radius.circular(AppRadius.sm),
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1F007AFF),
                blurRadius: 8,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Text(
            message.text,
            style: TextStyles.body.copyWith(
              color: AppColors.onPrimary,
              height: 1.35,
            ),
          ),
        ),
      ),
    );
  }
}

class _AssistantMessageBubble extends ConsumerWidget {
  final ChatMessage message;

  const _AssistantMessageBubble({required this.message});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // If aiUnavailable status, render distinct offline card style
    if (message.status == ChatMessageStatus.aiUnavailable) {
      return _AiUnavailableBubble(message: message);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.page, 6, 48, 6),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(AppRadius.lg),
              topRight: Radius.circular(AppRadius.lg),
              bottomLeft: Radius.circular(AppRadius.sm),
              bottomRight: Radius.circular(AppRadius.lg),
            ),
            border: Border.all(
              color: message.status == ChatMessageStatus.error
                  ? AppColors.danger.withValues(alpha: 0.3)
                  : AppColors.border.withValues(alpha: 0.6),
              width: 0.8,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A000000),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(context),
              const SizedBox(height: AppSpacing.sm),
              _buildContent(context),
              if (message.status == ChatMessageStatus.error) ...[
                const SizedBox(height: AppSpacing.md),
                _buildErrorBanner(context, ref),
              ],
              if (message.sources.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                _buildSourcesSection(context),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: AppColors.primarySoft,
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.3),
              width: 0.5,
            ),
          ),
          child: const Icon(
            CupertinoIcons.sparkles,
            size: 12,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          'Cortex AI',
          style: TextStyles.caption.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const Spacer(),
        if (message.status == ChatMessageStatus.stopped)
          Container(
            key: const ValueKey('chat_stopped_badge'),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(AppRadius.pill),
              border: Border.all(
                color: AppColors.border,
                width: 0.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  CupertinoIcons.stop_fill,
                  size: 9,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 3),
                Text(
                  'Stopped',
                  style: TextStyles.caption.copyWith(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          )
        else if (message.fromCache)
          Container(
            key: const ValueKey('chat_cached_badge'),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.warningSoft,
              borderRadius: BorderRadius.circular(AppRadius.pill),
              border: Border.all(
                color: AppColors.warning.withValues(alpha: 0.3),
                width: 0.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  CupertinoIcons.bolt_fill,
                  size: 10,
                  color: AppColors.warning,
                ),
                const SizedBox(width: 3),
                Text(
                  'cached',
                  style: TextStyles.caption.copyWith(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.warning,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildContent(BuildContext context) {
    final isStreaming = message.status == ChatMessageStatus.streaming;

    if (message.text.isEmpty && isStreaming) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CupertinoActivityIndicator(radius: 7),
          const SizedBox(width: AppSpacing.sm),
          Text(
            'Thinking…',
            style: TextStyles.bodySecondary.copyWith(
              fontStyle: FontStyle.italic,
              fontSize: 14,
            ),
          ),
        ],
      );
    }

    final segments = parseSourceCitations(message.text, message.sources);

    final textWidget = Text.rich(
      TextSpan(
        children: [
          for (final segment in segments)
            switch (segment) {
              PlainTextSegment(:final text) => TextSpan(
                  text: text,
                  style: TextStyles.body.copyWith(
                    color: AppColors.textPrimary,
                    height: 1.4,
                  ),
                ),
              SourceCitationSegment(:final sourceNumber, :final source) =>
                WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: _CitationChip(
                    sourceNumber: sourceNumber,
                    source: source,
                  ),
                ),
            },
          if (isStreaming)
            const WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Padding(
                padding: EdgeInsets.only(left: 4),
                child: CupertinoActivityIndicator(radius: 6),
              ),
            ),
        ],
      ),
    );

    if (message.status == ChatMessageStatus.stopped) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          textWidget,
          const SizedBox(height: AppSpacing.xs + 2),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                CupertinoIcons.stop_circle,
                size: 13,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 4),
              Text(
                'Stopped',
                key: const ValueKey('chat_stopped_label'),
                style: TextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                  fontStyle: FontStyle.italic,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      );
    }

    return textWidget;
  }

  Widget _buildErrorBanner(BuildContext context, WidgetRef ref) {
    return Container(
      key: const ValueKey('chat_error_banner'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.dangerSoft,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(
          color: AppColors.danger.withValues(alpha: 0.3),
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          const Icon(
            CupertinoIcons.exclamationmark_circle_fill,
            size: 15,
            color: AppColors.danger,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message.errorText ?? 'Connection lost',
              style: TextStyles.caption.copyWith(
                color: AppColors.danger,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Semantics(
            button: true,
            label: 'Retry message',
            child: GestureDetector(
              key: const ValueKey('chat_retry_button'),
              behavior: HitTestBehavior.opaque,
              onTap: () {
                ref.read(chatNotifierProvider.notifier).retry(message.id);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  border: Border.all(
                    color: AppColors.border,
                    width: 0.5,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x0D000000),
                      blurRadius: 4,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      CupertinoIcons.arrow_clockwise,
                      size: 12,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Retry',
                      style: TextStyles.caption.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSourcesSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(color: AppColors.border, height: 1, thickness: 0.5),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Sources (${message.sources.length})',
          style: TextStyles.caption.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        for (var i = 0; i < message.sources.length; i++) ...[
          ChatSourceCard(
            sourceNumber: i + 1,
            source: message.sources[i],
          ),
          if (i < message.sources.length - 1)
            const SizedBox(height: AppSpacing.xs + 2),
        ],
      ],
    );
  }
}

/// Inline citation chip rendered for `[Source N]` within text.
class _CitationChip extends ConsumerWidget {
  final int sourceNumber;
  final ChatSource source;

  const _CitationChip({
    required this.sourceNumber,
    required this.source,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Semantics(
        button: true,
        label: 'Open Source $sourceNumber: ${source.title}',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            if (source.noteId.isNotEmpty) {
              NoteRoutes.openOrSync(context, ref, source.noteId);
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(AppRadius.pill),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.35),
                width: 0.8,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  CupertinoIcons.doc_text,
                  size: 11,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 3),
                Text(
                  'Source $sourceNumber',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Distinct style for when cortex-ai is unreachable.
class _AiUnavailableBubble extends StatelessWidget {
  final ChatMessage message;

  const _AiUnavailableBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.page, 6, 48, 6),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          key: const ValueKey('chat_ai_unavailable_bubble'),
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.surfaceMuted.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: AppColors.border,
              width: 0.8,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  CupertinoIcons.wifi_slash,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      message.errorText ?? 'AI is offline. Your notes still work.',
                      style: TextStyles.cardTitle.copyWith(
                        fontSize: 14,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Your local notes, search, and editing remain fully functional.',
                      style: TextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
