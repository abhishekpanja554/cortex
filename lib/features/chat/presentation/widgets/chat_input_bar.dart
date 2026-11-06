import 'dart:async';
import 'package:clock/clock.dart';
import 'package:cortex/core/constants/colors.dart';
import 'package:cortex/core/constants/dimens.dart';
import 'package:cortex/core/constants/text_styles.dart';
import 'package:cortex/core/theme/liquid_glass.dart';
import 'package:cortex/features/chat/presentation/providers/chat_providers.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Bottom input bar for the chat screen.
/// - Disabled while streaming, showing a Stop button that calls cancel().
/// - Disabled during rate limit, showing a live "Try again in 42s" countdown.
class ChatInputBar extends ConsumerStatefulWidget {
  final ScrollController? scrollController;
  final String? hintText;
  final bool? isStreaming;
  final DateTime? rateLimitedUntil;
  final Future<void> Function(String)? onSend;
  final VoidCallback? onCancel;

  const ChatInputBar({
    super.key,
    this.scrollController,
    this.hintText,
    this.isStreaming,
    this.rateLimitedUntil,
    this.onSend,
    this.onCancel,
  });

  @override
  ConsumerState<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends ConsumerState<ChatInputBar> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  Timer? _countdownTimer;
  int _rateLimitSecondsLeft = 0;

  @override
  void initState() {
    super.initState();
    _checkRateLimit();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _checkRateLimit() {
    final rateLimitedUntil =
        widget.rateLimitedUntil ?? ref.read(chatRateLimitedUntilProvider);
    if (rateLimitedUntil != null) {
      final diff = rateLimitedUntil.difference(clock.now()).inSeconds;
      if (diff > 0) {
        setState(() {
          _rateLimitSecondsLeft = diff;
        });
        _countdownTimer?.cancel();
        _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          final nowDiff = rateLimitedUntil.difference(clock.now()).inSeconds;
          if (nowDiff <= 0) {
            timer.cancel();
            if (mounted) {
              setState(() {
                _rateLimitSecondsLeft = 0;
              });
            }
          } else {
            if (mounted) {
              setState(() {
                _rateLimitSecondsLeft = nowDiff;
              });
            }
          }
        });
        return;
      }
    }
    _countdownTimer?.cancel();
    if (_rateLimitSecondsLeft != 0 && mounted) {
      setState(() {
        _rateLimitSecondsLeft = 0;
      });
    }
  }

  Future<void> _handleSend() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    _controller.clear();
    setState(() {});

    if (widget.onSend != null) {
      await widget.onSend!(text);
    } else {
      final notifier = ref.read(chatNotifierProvider.notifier);
      await notifier.send(text);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<DateTime?>(
      chatRateLimitedUntilProvider,
      (prev, next) {
        _checkRateLimit();
      },
    );

    final bool isStreaming =
        (widget.isStreaming ?? ref.watch(chatIsStreamingProvider)) == true;
    final rateLimitedUntil =
        widget.rateLimitedUntil ?? ref.watch(chatRateLimitedUntilProvider);
    final currentDiff = rateLimitedUntil != null
        ? rateLimitedUntil.difference(clock.now()).inSeconds
        : 0;
    final isRateLimited = currentDiff > 0 || _rateLimitSecondsLeft > 0;
    final displaySeconds =
        currentDiff > 0 ? currentDiff : _rateLimitSecondsLeft;

    final isDisabled = isStreaming || isRateLimited;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.xs,
        AppSpacing.page,
        MediaQuery.paddingOf(context).bottom + AppSpacing.sm,
      ),
      child: LiquidGlass(
        tint: AppColors.glassFillStrong,
        blur: 24,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xxl),
          side: const BorderSide(color: AppColors.border, width: 0.5),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: isRateLimited
                  ? Container(
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        children: [
                          const Icon(
                            CupertinoIcons.timer,
                            size: 16,
                            color: AppColors.warning,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Text(
                            'Try again in ${displaySeconds}s',
                            style: TextStyles.bodySecondary.copyWith(
                              color: AppColors.warning,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    )
                  : TextField(
                      key: const ValueKey('chat_input_textfield'),
                      controller: _controller,
                      focusNode: _focusNode,
                      enabled: !isDisabled,
                      maxLines: 4,
                      minLines: 1,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _handleSend(),
                      onChanged: (_) => setState(() {}),
                      style: TextStyles.body.copyWith(
                        color: isDisabled
                            ? AppColors.textTertiary
                            : AppColors.textPrimary,
                      ),
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 8,
                        ),
                        border: InputBorder.none,
                        hintText: isStreaming
                            ? 'AI is responding…'
                            : (widget.hintText ??
                                'Ask a question about your notes…'),
                        hintStyle: TextStyles.hint.copyWith(
                          fontSize: 15,
                        ),
                      ),
                    ),
            ),
            const SizedBox(width: AppSpacing.sm),
            if (isStreaming)
              Semantics(
                button: true,
                label: 'Stop generating response',
                child: GestureDetector(
                  key: const ValueKey('chat_stop_button'),
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    if (widget.onCancel != null) {
                      widget.onCancel!();
                    } else {
                      ref.read(chatNotifierProvider.notifier).cancel();
                    }
                  },
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: AppColors.dangerSoft,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.danger.withValues(alpha: 0.3),
                        width: 0.5,
                      ),
                    ),
                    child: const Center(
                      child: Icon(
                        CupertinoIcons.stop_fill,
                        size: 14,
                        color: AppColors.danger,
                      ),
                    ),
                  ),
                ),
              )
            else
              Semantics(
                button: true,
                label: 'Send message',
                child: GestureDetector(
                  key: const ValueKey('chat_send_button'),
                  behavior: HitTestBehavior.opaque,
                  onTap: isDisabled || _controller.text.trim().isEmpty
                      ? null
                      : _handleSend,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: isDisabled || _controller.text.trim().isEmpty
                          ? AppColors.surfaceMuted
                          : AppColors.primary,
                      shape: BoxShape.circle,
                      boxShadow: isDisabled || _controller.text.trim().isEmpty
                          ? null
                          : const [
                              BoxShadow(
                                color: Color(0x2E007AFF),
                                blurRadius: 6,
                                offset: Offset(0, 2),
                              ),
                            ],
                    ),
                    child: Center(
                      child: Icon(
                        CupertinoIcons.arrow_up,
                        size: 18,
                        color: isDisabled || _controller.text.trim().isEmpty
                            ? AppColors.textTertiary
                            : AppColors.onPrimary,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
