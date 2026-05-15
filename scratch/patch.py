import re

with open('lib/features/notes/presentation/screens/edit_note_screen.dart', 'r') as f:
    content = f.read()

# Add flutter/services.dart import
if 'import \'package:flutter/services.dart\';' not in content:
    content = content.replace("import 'package:flutter/material.dart';", "import 'package:flutter/material.dart';\nimport 'package:flutter/services.dart';")

# 1. Update initState block parsing
init_state_old = """        if (note.blocks.isNotEmpty) {
          for (final b in note.blocks) {
            _blocks.add(b);
            if (b.type == BlockType.text) {
              _controllers[b.id] = TextEditingController(text: b.data)
                ..addListener(_onTextChanged);
              _focusNodes[b.id] = FocusNode();
            }
          }
          // Merge any adjacent text blocks that might have been saved incorrectly
          _mergeAdjacentTextBlocks();
        } else {
          final id = DateTime.now().millisecondsSinceEpoch.toString();
          _blocks.add(Block(id: id, type: BlockType.text, data: note.content));
          _controllers[id] = TextEditingController(text: note.content)
            ..addListener(_onTextChanged);
          _focusNodes[id] = FocusNode();
        }"""
init_state_new = """        if (note.blocks.isNotEmpty) {
          for (final b in note.blocks) {
            _blocks.add(b);
            if (b is TextBlock || b is CheckboxBlock) {
              _controllers[b.id] = TextEditingController(text: b.data)
                ..addListener(_onTextChanged);
              _focusNodes[b.id] = FocusNode();
            }
          }
          // Merge any adjacent text blocks that might have been saved incorrectly
          _mergeAdjacentTextBlocks();
        } else {
          final id = DateTime.now().millisecondsSinceEpoch.toString();
          _blocks.add(Block.text(id: id, data: note.content, orderIndex: 0));
          _controllers[id] = TextEditingController(text: note.content)
            ..addListener(_onTextChanged);
          _focusNodes[id] = FocusNode();
        }"""
content = content.replace(init_state_old, init_state_new)

init_state_old_2 = """    } else {
      final id = DateTime.now().millisecondsSinceEpoch.toString();
      _blocks.add(Block(id: id, type: BlockType.text, data: ''));
      _controllers[id] = TextEditingController()..addListener(_onTextChanged);
      _focusNodes[id] = FocusNode();
    }"""
init_state_new_2 = """    } else {
      final id = DateTime.now().millisecondsSinceEpoch.toString();
      _blocks.add(Block.text(id: id, data: '', orderIndex: 0));
      _controllers[id] = TextEditingController()..addListener(_onTextChanged);
      _focusNodes[id] = FocusNode();
    }"""
content = content.replace(init_state_old_2, init_state_new_2)


# 2. Update _mergeAdjacentTextBlocks
merge_old = """  void _mergeAdjacentTextBlocks() {
    for (int i = 0; i < _blocks.length - 1; i++) {
      if (_blocks[i].type == BlockType.text &&
          _blocks[i + 1].type == BlockType.text) {"""
merge_new = """  void _mergeAdjacentTextBlocks() {
    for (int i = 0; i < _blocks.length - 1; i++) {
      if (_blocks[i] is TextBlock &&
          _blocks[i + 1] is TextBlock) {"""
content = content.replace(merge_old, merge_new)


# 3. Update _onTextChanged
debounce_old = """    _debounce = Timer(const Duration(milliseconds: 600), () {"""
debounce_new = """    _debounce = Timer(const Duration(milliseconds: 500), () {"""
content = content.replace(debounce_old, debounce_new)


# 4. Update _autoSaveNote
autosave_old = """    final updatedBlocks = _blocks.map((b) {
      if (b.type == BlockType.text) {
        return b.copyWith(data: _controllers[b.id]?.text ?? '');
      }
      return b;
    }).toList();

    final content = updatedBlocks
        .where((b) => b.type == BlockType.text)
        .map((b) => b.data)
        .join('\\n')
        .trim();"""
autosave_new = """    final updatedBlocks = _blocks.map((b) {
      if (b is TextBlock) return b.copyWith(data: _controllers[b.id]?.text ?? '');
      if (b is CheckboxBlock) return b.copyWith(data: _controllers[b.id]?.text ?? '');
      return b;
    }).toList();

    final content = updatedBlocks
        .whereType<TextBlock>()
        .map((b) => b.data)
        .join('\\n')
        .trim();"""
content = content.replace(autosave_old, autosave_new)


# 5. Update _saveNote
savenote_old = """    final updatedBlocks = _blocks.map((b) {
      if (b.type == BlockType.text) {
        return b.copyWith(data: _controllers[b.id]?.text ?? '');
      }
      return b;
    }).toList();

    final content = updatedBlocks
        .where((b) => b.type == BlockType.text)
        .map((b) => b.data)
        .join('\\n')
        .trim();
    final hasImages = updatedBlocks.any((b) => b.type == BlockType.image);"""
savenote_new = """    final updatedBlocks = _blocks.map((b) {
      if (b is TextBlock) return b.copyWith(data: _controllers[b.id]?.text ?? '');
      if (b is CheckboxBlock) return b.copyWith(data: _controllers[b.id]?.text ?? '');
      return b;
    }).toList();

    final content = updatedBlocks
        .whereType<TextBlock>()
        .map((b) => b.data)
        .join('\\n')
        .trim();
    final hasImages = updatedBlocks.any((b) => b is ImageBlock);"""
content = content.replace(savenote_old, savenote_new)


# 6. Update _insertImage
insert_image_old = """          if (b.type == BlockType.text && _focusNodes[b.id]?.hasFocus == true) {"""
insert_image_new = """          if ((b is TextBlock || b is CheckboxBlock) && _focusNodes[b.id]?.hasFocus == true) {"""
content = content.replace(insert_image_old, insert_image_new)

insert_image_old_2 = """          final imageId = DateTime.now().millisecondsSinceEpoch.toString();
          _blocks.insert(
            focusedIndex + 1,
            Block(
              id: imageId,
              type: BlockType.image,
              data: xfile.path,
              orderIndex: _blocks.length,
            ),
          );

          // Insert new text block with textAfter
          final textId = (DateTime.now().millisecondsSinceEpoch + 1).toString();
          _blocks.insert(
            focusedIndex + 2,
            Block(
              id: textId,
              type: BlockType.text,
              data: textAfter,
              orderIndex: _blocks.length,
            ),
          );"""
insert_image_new_2 = """          final imageId = DateTime.now().millisecondsSinceEpoch.toString();
          _blocks.insert(
            focusedIndex + 1,
            Block.image(
              id: imageId,
              data: xfile.path,
              orderIndex: _blocks.length,
            ),
          );

          // Insert new text block with textAfter
          final textId = (DateTime.now().millisecondsSinceEpoch + 1).toString();
          _blocks.insert(
            focusedIndex + 2,
            Block.text(
              id: textId,
              data: textAfter,
              orderIndex: _blocks.length,
            ),
          );"""
content = content.replace(insert_image_old_2, insert_image_new_2)

insert_image_old_3 = """          final imageId = DateTime.now().millisecondsSinceEpoch.toString();
          _blocks.add(
            Block(
              id: imageId,
              type: BlockType.image,
              data: xfile.path,
              orderIndex: _blocks.length,
            ),
          );

          final textId = (DateTime.now().millisecondsSinceEpoch + 1).toString();
          _blocks.add(
            Block(
              id: textId,
              type: BlockType.text,
              data: '',
              orderIndex: _blocks.length,
            ),
          );"""
insert_image_new_3 = """          final imageId = DateTime.now().millisecondsSinceEpoch.toString();
          _blocks.add(
            Block.image(
              id: imageId,
              data: xfile.path,
              orderIndex: _blocks.length,
            ),
          );

          final textId = (DateTime.now().millisecondsSinceEpoch + 1).toString();
          _blocks.add(
            Block.text(
              id: textId,
              data: '',
              orderIndex: _blocks.length,
            ),
          );"""
content = content.replace(insert_image_old_3, insert_image_new_3)


# 7. Add Block splitting and Reorder methods
additional_methods = """
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
    final newBlock = Block.text(id: newId, data: textAfter, orderIndex: index + 1);
    
    setState(() {
      _blocks.insert(index + 1, newBlock);
      _controllers[newId] = TextEditingController(text: textAfter)..addListener(_onTextChanged);
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
        if (b is TextBlock) _blocks[i] = b.copyWith(orderIndex: i);
        else if (b is ImageBlock) _blocks[i] = b.copyWith(orderIndex: i);
        else if (b is CheckboxBlock) _blocks[i] = b.copyWith(orderIndex: i);
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
      final newBlock = Block.checkbox(id: newId, data: '', orderIndex: _blocks.length);
      setState(() {
          _blocks.add(newBlock);
          _controllers[newId] = TextEditingController()..addListener(_onTextChanged);
          _focusNodes[newId] = FocusNode();
          _reindexBlocks();
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _focusNodes[newId]?.requestFocus();
      });
  }

  void _insertTextBlock() {
      final newId = DateTime.now().millisecondsSinceEpoch.toString();
      final newBlock = Block.text(id: newId, data: '', orderIndex: _blocks.length);
      setState(() {
          _blocks.add(newBlock);
          _controllers[newId] = TextEditingController()..addListener(_onTextChanged);
          _focusNodes[newId] = FocusNode();
          _reindexBlocks();
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _focusNodes[newId]?.requestFocus();
      });
  }
"""

content = content.replace("  Widget _buildContentInput() {", additional_methods + "\n  Widget _buildContentInput() {")


# 8. Update _buildContentInput with ReorderableListView
build_content_input_old = """            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: _blocks.map((block) {
                if (block.type == BlockType.image) {
                  return _buildImageBlock(block);
                } else if (block.type == BlockType.text) {
                  return TextField(
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
                  );
                }
                return const SizedBox();
              }).toList(),
            ),"""
build_content_input_new = """            child: ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _blocks.length,
              onReorder: _onReorder,
              proxyDecorator: (child, index, animation) {
                return Material(
                  color: Colors.transparent,
                  child: child,
                );
              },
              itemBuilder: (context, index) {
                 final block = _blocks[index];
                 return Container(
                   key: ValueKey(block.id),
                   padding: const EdgeInsets.symmetric(vertical: 4),
                   child: _buildBlockWidget(block),
                 );
              }
            ),"""
content = content.replace(build_content_input_old, build_content_input_new)

# 9. Update block widget rendering and close button handling
image_close_old = """                  if (_coverImage == block.data) {
                    final nextImage = _blocks
                        .where((b) => b.type == BlockType.image)
                        .firstOrNull;
                    _coverImage = nextImage?.data;
                  }"""
image_close_new = """                  if (_coverImage == block.data) {
                    final nextImage = _blocks.whereType<ImageBlock>().firstOrNull;
                    _coverImage = nextImage?.data;
                  }"""
content = content.replace(image_close_old, image_close_new)


# 10. Add _buildBlockWidget, _buildTextBlock, _buildCheckboxBlock
build_block_widgets = """
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
              if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.enter && !HardwareKeyboard.instance.isShiftPressed) {
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
              color: block.isChecked ? AppColors.primary : AppColors.iconDefault,
              size: 20,
            ),
          ),
        ),
        Expanded(
          child: Focus(
            onKeyEvent: (node, event) {
              if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.enter && !HardwareKeyboard.instance.isShiftPressed) {
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
"""
content = content.replace("  Widget _buildImageBlock(Block block) {", build_block_widgets + "\n  Widget _buildImageBlock(ImageBlock block) {")

content = content.replace("Widget _buildImageBlock(Block block) {", "Widget _buildImageBlock(ImageBlock block) {")

# 11. Add Floating Toolbar (Speed Dial alternative)
scaffold_old = """    return Scaffold(
      backgroundColor: AppColors.backgroundScaffold,"""
scaffold_new = """    return Scaffold(
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
      ),"""
content = content.replace(scaffold_old, scaffold_new)

speed_dial_menu = """
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
"""
content = content.replace("  Widget _buildTopBar() {", speed_dial_menu + "\n  Widget _buildTopBar() {")

with open('lib/features/notes/presentation/screens/edit_note_screen.dart', 'w') as f:
    f.write(content)
