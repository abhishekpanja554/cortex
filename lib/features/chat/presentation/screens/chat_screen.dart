import 'package:cortex/core/constants/colors.dart';
import 'package:cortex/core/constants/dimens.dart';
import 'package:cortex/core/constants/text_styles.dart';
import 'package:cortex/core/theme/liquid_glass.dart';
import 'package:cortex/features/chat/domain/chat_message.dart';
import 'package:cortex/features/chat/presentation/providers/chat_providers.dart';
import 'package:cortex/features/chat/presentation/widgets/chat_input_bar.dart';
import 'package:cortex/features/chat/presentation/widgets/chat_message_bubble.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:cortex/features/chat/presentation/providers/agent_providers.dart';
import 'package:cortex/features/chat/presentation/widgets/agent_turn_bubble.dart';

enum ChatMode { ask, agent }

/// Full-featured chat screen supporting Q&A ("Ask") and Agent action execution with approval.
class ChatScreen extends ConsumerStatefulWidget {
  final ChatMode initialMode;

  const ChatScreen({super.key, this.initialMode = ChatMode.ask});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  late ChatMode _currentMode = widget.initialMode;
  bool _isForward = true;
  final ScrollController _scrollController = ScrollController();
  final ScrollController _agentScrollController = ScrollController();
  bool _autoScrollEnabled = true;
  bool _hasInitialScrolled = false;
  double _lastBottomInset = 0.0;

  @override
  void initState() {
    super.initState();
    _currentMode = widget.initialMode;
    _isForward = widget.initialMode == ChatMode.agent;
    _jumpToBottomOnOpen();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _agentScrollController.dispose();
    super.dispose();
  }

  void _switchToMode(ChatMode mode) {
    if (_currentMode == mode) return;
    HapticFeedback.selectionClick();
    setState(() {
      _isForward = (mode == ChatMode.agent);
      _currentMode = mode;
    });
  }

  void _scrollToBottom({bool force = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      if (!force && !_autoScrollEnabled) return;
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);

      // Follow-up layout check in case of variable height child updates
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scrollController.hasClients) return;
        if (!force && !_autoScrollEnabled) return;
        final max = _scrollController.position.maxScrollExtent;
        if (_scrollController.position.pixels < max) {
          _scrollController.jumpTo(max);
        }
      });
    });
  }

  void _jumpToBottomOnOpen() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _jumpToBottomRecursive();
    });
  }

  void _jumpToBottomRecursive([int passes = 10]) {
    if (!mounted || !_scrollController.hasClients) return;
    if (passes <= 0) {
      if (!_hasInitialScrolled) {
        setState(() => _hasInitialScrolled = true);
      }
      return;
    }
    final pos = _scrollController.position;
    if (pos.pixels < pos.maxScrollExtent) {
      _scrollController.jumpTo(pos.maxScrollExtent);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _jumpToBottomRecursive(passes - 1);
      });
    } else {
      if (!_hasInitialScrolled && mounted) {
        setState(() => _hasInitialScrolled = true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 1. Reset flags if conversation is cleared
    ref.listen<bool>(chatNotifierProvider.select((s) => s.messages.isEmpty), (
      prev,
      next,
    ) {
      if (next) {
        _hasInitialScrolled = false;
        _autoScrollEnabled = true;
      }
    });

    // 2. When a user sends a message (or retries/clicks suggestion),
    // a new user message is added: re-enable auto-scroll and jump to bottom.
    ref.listen<String?>(
      chatNotifierProvider.select(
        (s) => s.messages
            .where((m) => m.sender == MessageSender.user)
            .lastOrNull
            ?.id,
      ),
      (prev, next) {
        if (next != null && next != prev) {
          _autoScrollEnabled = true;
          _scrollToBottom(force: true);
        }
      },
    );

    // 3. As new text keeps generating or sources arrive, keep moving down unless user scrolled up
    ref.listen<ChatMessage?>(
      chatNotifierProvider.select((s) => s.messages.lastOrNull),
      (previous, next) {
        if (next == null) return;
        if (_autoScrollEnabled) {
          _scrollToBottom();
        }
      },
    );

    // 4. Adjust scroll when keyboard opens
    final currentBottomInset = MediaQuery.viewInsetsOf(context).bottom;
    if (currentBottomInset > _lastBottomInset && _autoScrollEnabled) {
      _scrollToBottom();
    }
    _lastBottomInset = currentBottomInset;

    // Auto-scroll agent turns when turns are added
    ref.listen<int>(agentNotifierProvider.select((s) => s.turns.length), (
      prev,
      next,
    ) {
      if (next > (prev ?? 0)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_agentScrollController.hasClients) {
            _agentScrollController.jumpTo(
              _agentScrollController.position.maxScrollExtent,
            );
          }
        });
      }
    });

    final messageIds = ref.watch(chatMessageIdsProvider);
    final agentTurnIds = ref.watch(agentTurnIdsProvider);

    // Show bottom most chats when opening ask chat
    if (messageIds.isNotEmpty &&
        !_hasInitialScrolled &&
        _currentMode == ChatMode.ask) {
      _jumpToBottomOnOpen();
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: true,
      body: AmbientBackground(
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _buildHeader(context),
              Expanded(
                child: GestureDetector(
                  key: const ValueKey('chat_screen_body_area'),
                  behavior: HitTestBehavior.translucent,
                  onHorizontalDragEnd: (details) {
                    final vx = details.primaryVelocity;
                    if (vx == null) return;
                    if (vx < -250 && _currentMode == ChatMode.ask) {
                      _switchToMode(ChatMode.agent);
                    } else if (vx > 250 && _currentMode == ChatMode.agent) {
                      _switchToMode(ChatMode.ask);
                    }
                  },
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 280),
                    switchInCurve: Curves.easeInOutCubic,
                    switchOutCurve: Curves.easeInOutCubic,
                    layoutBuilder:
                        (Widget? currentChild, List<Widget> previousChildren) {
                          return Stack(
                            fit: StackFit.expand,
                            children: <Widget>[
                              ...previousChildren,
                              if (currentChild != null) currentChild,
                            ],
                          );
                        },
                    transitionBuilder:
                        (Widget child, Animation<double> animation) {
                          final isIncoming =
                              child.key == ValueKey(_currentMode);
                          final beginOffset = isIncoming
                              ? (_isForward
                                    ? const Offset(0.20, 0)
                                    : const Offset(-0.20, 0))
                              : (_isForward
                                    ? const Offset(-0.20, 0)
                                    : const Offset(0.20, 0));

                          final slideAnim =
                              Tween<Offset>(
                                begin: beginOffset,
                                end: Offset.zero,
                              ).animate(
                                CurvedAnimation(
                                  parent: animation,
                                  curve: Curves.easeInOutCubic,
                                ),
                              );

                          return SlideTransition(
                            position: slideAnim,
                            child: FadeTransition(
                              opacity: CurvedAnimation(
                                parent: animation,
                                curve: Curves.easeInOut,
                              ),
                              child: child,
                            ),
                          );
                        },
                    child: _currentMode == ChatMode.ask
                        ? KeyedSubtree(
                            key: const ValueKey(ChatMode.ask),
                            child: _buildAskContent(messageIds),
                          )
                        : KeyedSubtree(
                            key: const ValueKey(ChatMode.agent),
                            child: _buildAgentContent(agentTurnIds),
                          ),
                  ),
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                switchInCurve: Curves.easeInOutCubic,
                switchOutCurve: Curves.easeInOutCubic,
                transitionBuilder: (child, animation) {
                  return FadeTransition(opacity: animation, child: child);
                },
                child: _currentMode == ChatMode.ask
                    ? ChatInputBar(
                        key: const ValueKey('chat_input_bar_ask'),
                        scrollController: _scrollController,
                      )
                    : ChatInputBar(
                        key: const ValueKey('chat_input_bar_agent'),
                        scrollController: _agentScrollController,
                        hintText: 'Ask agent to find, edit, or delete notes…',
                        isStreaming: ref.watch(agentIsStreamingProvider),
                        rateLimitedUntil: ref.watch(
                          agentRateLimitedUntilProvider,
                        ),
                        onSend: (text) =>
                            ref.read(agentNotifierProvider.notifier).send(text),
                        onCancel: () =>
                            ref.read(agentNotifierProvider.notifier).cancel(),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAskContent(List<String> messageIds) {
    if (messageIds.isEmpty) {
      return _buildEmptyState(context);
    }
    return Opacity(
      opacity: _hasInitialScrolled ? 1.0 : 0.0,
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification is ScrollUpdateNotification) {
            if (notification.dragDetails != null) {
              if (notification.metrics.extentAfter > 50) {
                _autoScrollEnabled = false;
              } else {
                _autoScrollEnabled = true;
              }
            }
          } else if (notification is ScrollEndNotification) {
            if (notification.metrics.extentAfter <= 40) {
              _autoScrollEnabled = true;
            }
          }
          return false;
        },
        child: ListView.builder(
          key: const ValueKey('chat_messages_list'),
          controller: _scrollController,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.only(
            top: AppSpacing.sm,
            bottom: AppSpacing.md,
          ),
          itemCount: messageIds.length,
          itemBuilder: (context, index) {
            final id = messageIds[index];
            return ChatMessageBubble(key: ValueKey(id), messageId: id);
          },
        ),
      ),
    );
  }

  Widget _buildAgentContent(List<String> agentTurnIds) {
    if (agentTurnIds.isEmpty) {
      return _buildAgentEmptyState(context);
    }
    return ListView.builder(
      key: const ValueKey('agent_turns_list'),
      controller: _agentScrollController,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.md),
      itemCount: agentTurnIds.length,
      itemBuilder: (context, index) {
        final id = agentTurnIds[index];
        return AgentTurnBubble(key: ValueKey(id), turnId: id);
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    final isAsk = _currentMode == ChatMode.ask;

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.xs,
        AppSpacing.page,
        AppSpacing.sm,
      ),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (Navigator.of(context).canPop()) ...[
                Semantics(
                  button: true,
                  label: 'Back',
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => context.pop(),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.surface.withValues(alpha: 0.8),
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.border, width: 0.5),
                      ),
                      child: const Center(
                        child: Icon(
                          CupertinoIcons.chevron_back,
                          size: 18,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
              ],
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  switchInCurve: Curves.easeInOut,
                  switchOutCurve: Curves.easeInOut,
                  layoutBuilder:
                      (Widget? currentChild, List<Widget> previousChildren) {
                        return Stack(
                          alignment: Alignment.centerLeft,
                          children: <Widget>[
                            ...previousChildren,
                            if (currentChild != null) currentChild,
                          ],
                        );
                      },
                  transitionBuilder: (child, animation) {
                    return FadeTransition(opacity: animation, child: child);
                  },
                  child: SizedBox(
                    key: ValueKey(_currentMode),
                    width: double.infinity,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isAsk
                                  ? CupertinoIcons.sparkles
                                  : CupertinoIcons.cube_box,
                              size: 16,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                isAsk ? 'Ask Cortex' : 'Cortex Agent',
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                                style: TextStyles.cardTitle.copyWith(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 1),
                        Text(
                          isAsk
                              ? 'Grounded in your notes'
                              : 'Can search, edit, and organize notes',
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          style: TextStyles.caption.copyWith(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              _buildActionButton(isAsk),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          _buildSegmentedControl(isAsk),
        ],
      ),
    );
  }

  Widget _buildSegmentedControl(bool isAsk) {
    return Container(
      height: 36,
      padding: const EdgeInsets.all(2.5),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: [
              AnimatedAlign(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOutCubic,
                alignment: isAsk ? Alignment.centerLeft : Alignment.centerRight,
                child: FractionallySizedBox(
                  widthFactor: 0.5,
                  heightFactor: 1.0,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      border: Border.all(
                        color: AppColors.border.withValues(alpha: 0.5),
                        width: 0.5,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x18000000),
                          blurRadius: 3.5,
                          offset: Offset(0, 1.5),
                        ),
                        BoxShadow(
                          color: Color(0x0A000000),
                          blurRadius: 1,
                          offset: Offset(0, 0.5),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      key: const ValueKey('chat_mode_ask_tab'),
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _switchToMode(ChatMode.ask),
                      child: Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              CupertinoIcons.sparkles,
                              size: 13,
                              color: isAsk
                                  ? AppColors.primary
                                  : AppColors.textSecondary,
                            ),
                            const SizedBox(width: 5),
                            AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeInOut,
                              style: TextStyles.caption.copyWith(
                                fontSize: 12,
                                fontWeight: isAsk
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: isAsk
                                    ? AppColors.textPrimary
                                    : AppColors.textSecondary,
                              ),
                              child: const Text('Ask'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      key: const ValueKey('chat_mode_agent_tab'),
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _switchToMode(ChatMode.agent),
                      child: Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              CupertinoIcons.cube_box,
                              size: 13,
                              color: !isAsk
                                  ? AppColors.primary
                                  : AppColors.textSecondary,
                            ),
                            const SizedBox(width: 5),
                            AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeInOut,
                              style: TextStyles.caption.copyWith(
                                fontSize: 12,
                                fontWeight: !isAsk
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: !isAsk
                                    ? AppColors.textPrimary
                                    : AppColors.textSecondary,
                              ),
                              child: const Text('Agent'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildActionButton(bool isAsk) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      switchInCurve: Curves.easeInOut,
      switchOutCurve: Curves.easeInOut,
      layoutBuilder: (Widget? currentChild, List<Widget> previousChildren) {
        return Stack(
          alignment: Alignment.centerRight,
          children: <Widget>[
            ...previousChildren,
            if (currentChild != null) currentChild,
          ],
        );
      },
      transitionBuilder: (child, animation) {
        return FadeTransition(opacity: animation, child: child);
      },
      child: Semantics(
        key: ValueKey(isAsk ? 'action_ask' : 'action_agent'),
        button: true,
        label: isAsk ? 'Start new chat' : 'Clear agent session',
        child: GestureDetector(
          key: const ValueKey('new_chat_button'),
          behavior: HitTestBehavior.opaque,
          onTap: () {
            HapticFeedback.lightImpact();
            if (isAsk) {
              ref.read(chatNotifierProvider.notifier).newConversation();
            } else {
              ref.read(agentNotifierProvider.notifier).clear();
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(AppRadius.pill),
              border: Border.all(color: AppColors.border, width: 0.5),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0A000000),
                  blurRadius: 4,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isAsk
                      ? CupertinoIcons.square_pencil
                      : CupertinoIcons.arrow_counterclockwise,
                  size: 13,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 4),
                Text(
                  isAsk ? 'New chat' : 'Reset',
                  style: TextStyles.caption.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final suggestions = [
      'Summarize my recent notes',
      'What are my key action items?',
      'Find everything about architecture',
    ];

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  width: 1,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x14007AFF),
                    blurRadius: 16,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                CupertinoIcons.sparkles,
                size: 32,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Ask anything in your notes',
              style: TextStyles.title.copyWith(fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Answers are synthesized directly from your notes, with inline citations you can tap to read the original note.',
              style: TextStyles.bodySecondary.copyWith(fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xxl),
            for (final prompt in suggestions) ...[
              Semantics(
                button: true,
                label: 'Suggested prompt: $prompt',
                child: GestureDetector(
                  onTap: () {
                    ref.read(chatNotifierProvider.notifier).send(prompt);
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.md,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surface.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      border: Border.all(color: AppColors.border, width: 0.5),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          CupertinoIcons.bubble_left,
                          size: 14,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            prompt,
                            style: TextStyles.caption.copyWith(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        const Icon(
                          CupertinoIcons.arrow_up_right,
                          size: 12,
                          color: AppColors.textTertiary,
                        ),
                      ],
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

  Widget _buildAgentEmptyState(BuildContext context) {
    final suggestions = [
      'Search my notes for database architecture',
      'Create a note with key action items',
      'Find outdated draft notes to clean up',
    ];

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  width: 1,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x14007AFF),
                    blurRadius: 16,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                CupertinoIcons.cube_box,
                size: 32,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Cortex Autonomous Agent',
              style: TextStyles.title.copyWith(fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'The agent can search, create, and organize notes. Destructive updates and deletions will always ask for your explicit approval first.',
              style: TextStyles.bodySecondary.copyWith(fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xxl),
            for (final prompt in suggestions) ...[
              Semantics(
                button: true,
                label: 'Suggested prompt: $prompt',
                child: GestureDetector(
                  onTap: () {
                    ref.read(agentNotifierProvider.notifier).send(prompt);
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.md,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surface.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      border: Border.all(color: AppColors.border, width: 0.5),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          CupertinoIcons.bolt,
                          size: 14,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            prompt,
                            style: TextStyles.caption.copyWith(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        const Icon(
                          CupertinoIcons.arrow_up_right,
                          size: 12,
                          color: AppColors.textTertiary,
                        ),
                      ],
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
}
