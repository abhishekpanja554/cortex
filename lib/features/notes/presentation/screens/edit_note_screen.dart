import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:cortex/core/constants/colors.dart';
import 'package:cortex/core/constants/string_constants.dart';
import 'package:cortex/core/constants/text_styles.dart';
import 'package:cortex/features/notes/domain/entities/note.dart';
import 'package:cortex/features/notes/presentation/providers/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

class EditNoteScreen extends ConsumerStatefulWidget {
  final String? noteId;

  const EditNoteScreen({super.key, this.noteId});

  @override
  ConsumerState<EditNoteScreen> createState() => _EditNoteScreenState();
}

class _EditNoteScreenState extends ConsumerState<EditNoteScreen> {
  late final TextEditingController _titleController;
  final List<Block> _blocks = [];
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, FocusNode> _focusNodes = {};
  String? _coverImage;
  Timer? _debounce;
  bool get _isEditing => widget.noteId != null;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();

    if (_isEditing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final note = ref
            .read(noteNotifierProvider)
            .notes
            .firstWhere(
              (n) => n.id == widget.noteId,
              orElse: () => Note(
                id: '',
                title: '',
                content: '',
                createdAt: DateTime.now(),
              ),
            );
        _titleController.text = note.title;
        _coverImage = note.coverImage;

        if (note.blocks.isNotEmpty) {
          for (final b in note.blocks) {
            _blocks.add(b);
            if (b is TextBlock || b is CheckboxBlock) {
              _controllers[b.id] = TextEditingController(text: b.data)
                ..addListener(_onTextChanged);
              _focusNodes[b.id] = FocusNode();
            }
          }
          _mergeAdjacentTextBlocks();
        } else {
          final id = DateTime.now().millisecondsSinceEpoch.toString();
          _blocks.add(Block.text(id: id, data: note.content, orderIndex: 0));
          _controllers[id] = TextEditingController(text: note.content)
            ..addListener(_onTextChanged);
          _focusNodes[id] = FocusNode();
        }
        setState(() {});
      });
    } else {
      final id = DateTime.now().millisecondsSinceEpoch.toString();
      _blocks.add(Block.text(id: id, data: '', orderIndex: 0));
      _controllers[id] = TextEditingController()..addListener(_onTextChanged);
      _focusNodes[id] = FocusNode();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _titleController.dispose();
    for (final c in _controllers.values) {
      c.dispose();
    }
    for (final f in _focusNodes.values) {
      f.dispose();
    }
    super.dispose();
  }

  void _mergeAdjacentTextBlocks() {
    for (int i = 0; i < _blocks.length - 1; i++) {
      if (_blocks[i] is TextBlock && _blocks[i + 1] is TextBlock) {
        final block1 = _blocks[i];
        final block2 = _blocks[i + 1];

        final text1 = _controllers[block1.id]?.text ?? '';
        final text2 = _controllers[block2.id]?.text ?? '';

        final mergedText =
            text1 +
            (text1.isNotEmpty &&
                    text2.isNotEmpty &&
                    !text1.endsWith('\n') &&
                    !text2.startsWith('\n')
                ? '\n'
                : '') +
            text2;

        _controllers[block1.id]?.text = mergedText;

        _controllers[block2.id]?.dispose();
        _controllers.remove(block2.id);
        _focusNodes[block2.id]?.dispose();
        _focusNodes.remove(block2.id);

        _blocks.removeAt(i + 1);

        i--;
      }
    }
  }

  void _onTextChanged() {
    if (!_isEditing) return; // Only auto-save existing notes
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _autoSaveNote();
    });
  }

  void _autoSaveNote() {
    final title = _titleController.text.trim();

    final updatedBlocks = _blocks.map((b) {
      if (b is TextBlock)
        return b.copyWith(data: _controllers[b.id]?.text ?? '');
      if (b is CheckboxBlock)
        return b.copyWith(data: _controllers[b.id]?.text ?? '');
      return b;
    }).toList();

    final content = updatedBlocks
        .whereType<TextBlock>()
        .map((b) => b.data)
        .join('\n')
        .trim();

    try {
      final existing = ref
          .read(noteNotifierProvider)
          .notes
          .firstWhere((n) => n.id == widget.noteId);
      ref
          .read(noteNotifierProvider.notifier)
          .updateNote(
            existing.copyWith(
              title: title,
              content: content,
              blocks: updatedBlocks,
              coverImage: _coverImage,
              updatedAt: DateTime.now(),
            ),
          );
    } catch (_) {}
  }

  void _saveNote() {
    _debounce?.cancel();
    final title = _titleController.text.trim();

    final updatedBlocks = _blocks.map((b) {
      if (b is TextBlock)
        return b.copyWith(data: _controllers[b.id]?.text ?? '');
      if (b is CheckboxBlock)
        return b.copyWith(data: _controllers[b.id]?.text ?? '');
      return b;
    }).toList();

    final content = updatedBlocks
        .whereType<TextBlock>()
        .map((b) => b.data)
        .join('\n')
        .trim();
    final hasImages = updatedBlocks.any((b) => b is ImageBlock);

    if (title.isEmpty && content.isEmpty && !hasImages) {
      Navigator.of(context).pop();
      return;
    }

    if (_isEditing) {
      _autoSaveNote();
    } else {
      ref
          .read(noteNotifierProvider.notifier)
          .addNote(
            Note(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              title: title,
              content: content,
              blocks: updatedBlocks,
              coverImage: _coverImage,
              createdAt: DateTime.now(),
            ),
          );
    }

    Navigator.of(context).pop();
  }

  Future<void> _insertImage() async {
    final picker = ImagePicker();
    final xfile = await picker.pickImage(source: ImageSource.gallery);

    if (xfile != null) {
      setState(() {
        _coverImage ??= xfile.path;

        int focusedIndex = -1;
        int cursorPosition = -1;
        for (int i = 0; i < _blocks.length; i++) {
          final b = _blocks[i];
          if ((b is TextBlock || b is CheckboxBlock) &&
              _focusNodes[b.id]?.hasFocus == true) {
            focusedIndex = i;
            cursorPosition = _controllers[b.id]?.selection.baseOffset ?? -1;
            break;
          }
        }

        if (focusedIndex != -1 && cursorPosition != -1) {
          final b = _blocks[focusedIndex];
          final text = _controllers[b.id]?.text ?? '';

          if (cursorPosition < 0 || cursorPosition > text.length) {
            cursorPosition = text.length;
          }

          final textBefore = text.substring(0, cursorPosition);
          final textAfter = text.substring(cursorPosition);

          _controllers[b.id]?.text = textBefore;

          final imageId = DateTime.now().millisecondsSinceEpoch.toString();
          _blocks.insert(
            focusedIndex + 1,
            Block.image(
              id: imageId,
              data: xfile.path,
              orderIndex: _blocks.length,
            ),
          );

          final textId = (DateTime.now().millisecondsSinceEpoch + 1).toString();
          _blocks.insert(
            focusedIndex + 2,
            Block.text(id: textId, data: textAfter, orderIndex: _blocks.length),
          );
          _controllers[textId] = TextEditingController(text: textAfter)
            ..addListener(_onTextChanged);
          _focusNodes[textId] = FocusNode();

          _focusNodes[textId]?.requestFocus();
        } else {
          final imageId = DateTime.now().millisecondsSinceEpoch.toString();
          _blocks.add(
            Block.image(
              id: imageId,
              data: xfile.path,
              orderIndex: _blocks.length,
            ),
          );

          final textId = (DateTime.now().millisecondsSinceEpoch + 1).toString();
          _blocks.add(
            Block.text(id: textId, data: '', orderIndex: _blocks.length),
          );
          _controllers[textId] = TextEditingController()
            ..addListener(_onTextChanged);
          _focusNodes[textId] = FocusNode();

          _focusNodes[textId]?.requestFocus();
        }
      });
      _onTextChanged();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundScaffold,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 100),
        child: FloatingActionButton.extended(
          onPressed: () {
            showModalBottomSheet(
              context: context,
              backgroundColor: Colors.transparent,
              builder: (ctx) => _buildSpeedDialMenu(),
            );
          },
          icon: const Icon(Icons.add),
          label: const Text("Block"),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
        ),
      ),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildTopBar()),

            SliverToBoxAdapter(child: _buildTitleInput()),

            SliverToBoxAdapter(child: _buildContentInput()),

            SliverToBoxAdapter(child: _buildActionChips()),

            SliverToBoxAdapter(child: _buildAiAssistHeader()),

            SliverToBoxAdapter(child: _buildAiGrid()),

            const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
          ],
        ),
      ),
    );
  }

  Widget _buildSpeedDialMenu() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.text_fields, color: AppColors.primary),
            title: const Text("Text Block"),
            onTap: () {
              Navigator.pop(context);
              _insertTextBlock();
            },
          ),
          ListTile(
            leading: const Icon(Icons.check_box, color: AppColors.primary),
            title: const Text("Checklist"),
            onTap: () {
              Navigator.pop(context);
              _insertCheckboxBlock();
            },
          ),
          ListTile(
            leading: const Icon(Icons.image, color: AppColors.primary),
            title: const Text("Image"),
            onTap: () {
              Navigator.pop(context);
              _insertImage();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                border: Border.all(color: AppColors.borderColor, width: 1),
              ),
              child: const Icon(
                Icons.chevron_left_rounded,
                color: AppColors.textPrimary,
                size: 24,
              ),
            ),
          ),

          Expanded(
            child: Text(
              _isEditing ? AppStrings.editNote : AppStrings.createNote,
              style: TextStyles.screenTitleStyle,
              textAlign: TextAlign.center,
            ),
          ),

          GestureDetector(
            onTap: _saveNote,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                border: Border.all(color: AppColors.borderColor, width: 1),
              ),
              child: const Icon(
                Icons.save_alt_rounded,
                color: AppColors.textPrimary,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitleInput() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.55),
                  Colors.white.withValues(alpha: 0.35),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.60),
                width: 1.2,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _titleController,
                    onChanged: (_) => _onTextChanged(),
                    style: TextStyles.inputTitleStyle,
                    decoration: InputDecoration(
                      hintText: AppStrings.titleHint,
                      hintStyle: TextStyles.inputHintStyle,
                      border: InputBorder.none,
                    ),
                  ),
                ),
                Icon(
                  Icons.mic_none_rounded,
                  color: AppColors.primary,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _splitBlockAtCursor(String blockId) {
    final index = _blocks.indexWhere((b) => b.id == blockId);
    if (index == -1) return;

    final text = _controllers[blockId]?.text ?? '';
    int cursorPosition = _controllers[blockId]?.selection.baseOffset ?? -1;

    if (cursorPosition < 0 || cursorPosition > text.length) {
      cursorPosition = text.length;
    }

    final textBefore = text.substring(0, cursorPosition);
    final textAfter = text.substring(cursorPosition);

    _controllers[blockId]?.text = textBefore;

    final newId = DateTime.now().millisecondsSinceEpoch.toString();
    final newBlock = Block.text(
      id: newId,
      data: textAfter,
      orderIndex: index + 1,
    );

    setState(() {
      _blocks.insert(index + 1, newBlock);
      _controllers[newId] = TextEditingController(text: textAfter)
        ..addListener(_onTextChanged);
      _focusNodes[newId] = FocusNode();
      _reindexBlocks();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNodes[newId]?.requestFocus();
    });
    _onTextChanged();
  }

  void _reindexBlocks() {
    for (int i = 0; i < _blocks.length; i++) {
      final b = _blocks[i];
      if (b is TextBlock)
        _blocks[i] = b.copyWith(orderIndex: i);
      else if (b is ImageBlock)
        _blocks[i] = b.copyWith(orderIndex: i);
      else if (b is CheckboxBlock)
        _blocks[i] = b.copyWith(orderIndex: i);
    }
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final item = _blocks.removeAt(oldIndex);
      _blocks.insert(newIndex, item);
      _reindexBlocks();
    });
    _onTextChanged();
  }

  void _insertCheckboxBlock() {
    final newId = DateTime.now().millisecondsSinceEpoch.toString();
    final newBlock = Block.checkbox(
      id: newId,
      data: '',
      orderIndex: _blocks.length,
    );
    setState(() {
      _blocks.add(newBlock);
      _controllers[newId] = TextEditingController()
        ..addListener(_onTextChanged);
      _focusNodes[newId] = FocusNode();
      _reindexBlocks();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNodes[newId]?.requestFocus();
    });
  }

  void _insertTextBlock() {
    final newId = DateTime.now().millisecondsSinceEpoch.toString();
    final newBlock = Block.text(
      id: newId,
      data: '',
      orderIndex: _blocks.length,
    );
    setState(() {
      _blocks.add(newBlock);
      _controllers[newId] = TextEditingController()
        ..addListener(_onTextChanged);
      _focusNodes[newId] = FocusNode();
      _reindexBlocks();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNodes[newId]?.requestFocus();
    });
  }

  Widget _buildContentInput() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            constraints: const BoxConstraints(minHeight: 180),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.55),
                  Colors.white.withValues(alpha: 0.35),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.60),
                width: 1.2,
              ),
            ),
            child: ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _blocks.length,
              onReorder: _onReorder,
              proxyDecorator: (child, index, animation) {
                return Material(color: Colors.transparent, child: child);
              },
              itemBuilder: (context, index) {
                final block = _blocks[index];
                return Container(
                  key: ValueKey(block.id),
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: _buildBlockWidget(block),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBlockWidget(Block block) {
    if (block is ImageBlock) return _buildImageBlock(block);
    if (block is TextBlock) return _buildTextBlock(block);
    if (block is CheckboxBlock) return _buildCheckboxBlock(block);
    return const SizedBox();
  }

  Widget _buildTextBlock(TextBlock block) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 8.0, right: 8.0),
          child: Icon(Icons.drag_indicator, size: 16, color: Colors.black26),
        ),
        Expanded(
          child: Focus(
            onKeyEvent: (node, event) {
              if (event is KeyDownEvent &&
                  event.logicalKey == LogicalKeyboardKey.enter &&
                  !HardwareKeyboard.instance.isShiftPressed) {
                _splitBlockAtCursor(block.id);
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: TextField(
              controller: _controllers[block.id],
              focusNode: _focusNodes[block.id],
              style: TextStyles.inputContentStyle,
              maxLines: null,
              decoration: InputDecoration(
                hintText: AppStrings.contentHint,
                hintStyle: TextStyles.inputHintStyle,
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                isDense: true,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCheckboxBlock(CheckboxBlock block) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 8.0, right: 8.0),
          child: Icon(Icons.drag_indicator, size: 16, color: Colors.black26),
        ),
        GestureDetector(
          onTap: () {
            setState(() {
              final idx = _blocks.indexWhere((b) => b.id == block.id);
              if (idx != -1) {
                _blocks[idx] = block.copyWith(isChecked: !block.isChecked);
                _onTextChanged();
              }
            });
          },
          child: Padding(
            padding: const EdgeInsets.only(top: 2.0, right: 8.0),
            child: Icon(
              block.isChecked ? Icons.check_box : Icons.check_box_outline_blank,
              color: block.isChecked
                  ? AppColors.primary
                  : AppColors.iconDefault,
              size: 20,
            ),
          ),
        ),
        Expanded(
          child: Focus(
            onKeyEvent: (node, event) {
              if (event is KeyDownEvent &&
                  event.logicalKey == LogicalKeyboardKey.enter &&
                  !HardwareKeyboard.instance.isShiftPressed) {
                _splitBlockAtCursor(block.id);
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: TextField(
              controller: _controllers[block.id],
              focusNode: _focusNodes[block.id],
              style: TextStyles.inputContentStyle.copyWith(
                decoration: block.isChecked ? TextDecoration.lineThrough : null,
                color: block.isChecked ? Colors.grey : AppColors.textPrimary,
              ),
              maxLines: null,
              decoration: const InputDecoration(
                hintText: "To-do",
                hintStyle: TextStyle(color: Colors.black38),
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                isDense: true,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImageBlock(ImageBlock block) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Stack(
        alignment: Alignment.topRight,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(File(block.data), fit: BoxFit.cover),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _blocks.remove(block);
                  if (_coverImage == block.data) {
                    final nextImage = _blocks
                        .whereType<ImageBlock>()
                        .firstOrNull;
                    _coverImage = nextImage?.data;
                  }
                  _mergeAdjacentTextBlocks();
                });
                _onTextChanged();
              },
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(4),
                child: const Icon(Icons.close, color: Colors.white, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionChips() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Wrap(
        spacing: 10,
        runSpacing: 8,
        children: [
          _actionChip(
            Icons.image_outlined,
            AppStrings.insertImage,
            AppColors.primary,
            onTap: _insertImage,
          ),
          _actionChip(
            Icons.sell_outlined,
            AppStrings.addTag,
            AppColors.aiCoral,
          ),
          _actionChip(
            Icons.folder_outlined,
            AppStrings.addCategory,
            AppColors.aiGreen,
          ),
          _actionChip(
            Icons.notifications_none_rounded,
            AppStrings.reminder,
            AppColors.aiPurple,
          ),
        ],
      ),
    );
  }

  Widget _actionChip(
    IconData icon,
    String label,
    Color iconColor, {
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.chipBorder, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: iconColor),
            const SizedBox(width: 6),
            Text(label, style: TextStyles.actionChipStyle),
          ],
        ),
      ),
    );
  }

  Widget _buildAiAssistHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Text(AppStrings.aiAssist, style: TextStyles.sectionHeaderStyle),
    );
  }

  Widget _buildAiGrid() {
    final aiActions = [
      (
        icon: Icons.auto_awesome,
        title: AppStrings.summarizeNote,
        bgColor: AppColors.aiCardBgGreen,
        iconColor: AppColors.aiGreen,
      ),
      (
        icon: Icons.psychology_outlined,
        title: AppStrings.rewriteClarity,
        bgColor: AppColors.aiCardBgPurple,
        iconColor: AppColors.aiPurple,
      ),
      (
        icon: Icons.format_list_bulleted_rounded,
        title: AppStrings.convertBullets,
        bgColor: AppColors.aiCardBgPink,
        iconColor: AppColors.aiPink,
      ),
      (
        icon: Icons.title_rounded,
        title: AppStrings.generateTitle,
        bgColor: AppColors.aiCardBgCoral,
        iconColor: AppColors.aiCoral,
      ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.3,
        ),
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: aiActions.length,
        itemBuilder: (context, index) {
          final action = aiActions[index];
          return _aiCard(
            icon: action.icon,
            title: action.title,
            bgColor: action.bgColor,
            iconColor: action.iconColor,
          );
        },
      ),
    );
  }

  Widget _aiCard({
    required IconData icon,
    required String title,
    required Color bgColor,
    required Color iconColor,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.55),
                Colors.white.withValues(alpha: 0.35),
              ],
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.60),
              width: 1.2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: iconColor),
              ),
              const Spacer(),
              Text(
                title,
                style: TextStyles.aiCardTitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
