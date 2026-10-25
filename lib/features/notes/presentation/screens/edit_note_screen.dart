import 'dart:async';
import 'dart:io';

import 'package:cortex/core/constants/colors.dart';
import 'package:cortex/core/constants/dimens.dart';
import 'package:cortex/core/constants/string_constants.dart';
import 'package:cortex/core/constants/text_styles.dart';
import 'package:cortex/core/theme/liquid_glass.dart';
import 'package:cortex/core/utils/date_format.dart';
import 'package:cortex/features/notes/domain/entities/note_entity.dart';
import 'package:cortex/features/notes/domain/note_body_codec.dart';
import 'package:cortex/features/notes/domain/note_template.dart';
import 'package:cortex/features/notes/presentation/note_actions.dart';
import 'package:cortex/features/notes/presentation/providers/providers.dart';
import 'package:cortex/features/notes/presentation/widgets/attachment_image.dart';
import 'package:cortex/features/sync/presentation/sync_orchestrator.dart';
import 'package:cortex/features/sync/presentation/sync_providers.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

export 'package:cortex/features/notes/domain/note_template.dart';

/// Block editor for a single note.
///
/// Saving model: every change is auto-saved (debounced) — for new notes too —
/// and flushed when the screen is left by any route (Done, back button, swipe).
/// A note created here and left completely empty is discarded.
class EditNoteScreen extends ConsumerStatefulWidget {
  final String? noteId;
  final NoteTemplate template;

  const EditNoteScreen({
    super.key,
    this.noteId,
    this.template = NoteTemplate.text,
  });

  @override
  ConsumerState<EditNoteScreen> createState() => _EditNoteScreenState();
}

class _EditNoteScreenState extends ConsumerState<EditNoteScreen> {
  static const _codec = NoteBodyCodec();
  static const _autosaveDelay = Duration(milliseconds: 600);

  late final TextEditingController _titleController;
  final FocusNode _titleFocus = FocusNode();
  final List<Block> _blocks = [];
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, FocusNode> _focusNodes = {};
  Timer? _debounce;

  /// True while a conflict resolution is in flight; suppresses auto-save so
  /// the resolution's own writes are the only ones made.
  bool _isResolving = false;
  bool _hasInitializedFromNote = false;
  bool _initializing = false;
  bool _closing = false;

  /// Id of the persisted note; null until a new note gets its first save.
  String? _noteId;
  NoteEntity? _loadedNote;
  bool _createdHere = false;
  bool _savedAnything = false;
  DateTime _createdAt = DateTime.now();
  String _lastSavedTitle = '';
  String _lastSavedBody = '';

  bool get _isEditing => widget.noteId != null;

  @override
  void initState() {
    super.initState();
    _noteId = widget.noteId;
    _titleController = TextEditingController()..addListener(_onTextChanged);
    _titleFocus.addListener(_onFocusChanged);

    if (_isEditing) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final note = await ref
            .read(noteRepositoryProvider)
            .getNote(widget.noteId!);
        if (note != null && mounted) {
          _initFromNote(note);
          setState(() {});
        }
      });
    } else {
      final id = const Uuid().v4();
      if (widget.template == NoteTemplate.checklist) {
        _blocks.add(Block.checkbox(id: id, data: ''));
      } else {
        _blocks.add(Block.text(id: id, data: ''));
      }
      _registerBlock(id, '');
      _lastSavedBody = _serialize();

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        switch (widget.template) {
          case NoteTemplate.text:
            _titleFocus.requestFocus();
          case NoteTemplate.checklist:
            _focusNodes[id]?.requestFocus();
          case NoteTemplate.image:
            _insertImage();
        }
      });
    }
  }

  void _initFromNote(NoteEntity note) {
    if (_hasInitializedFromNote) return;
    _hasInitializedFromNote = true;
    _initializing = true;
    _loadedNote = note;

    _createdAt = note.createdAt;
    _titleController.text = note.title;

    final parsed = _codec.parse(note.body);
    _blocks.clear();
    if (parsed.isNotEmpty) {
      for (final b in parsed) {
        _blocks.add(b);
        if (b is TextBlock || b is CheckboxBlock) {
          _registerBlock(b.id, b.data);
        }
      }
      _mergeAdjacentTextBlocks();
    }
    _ensureEditableBlock();

    _lastSavedTitle = _titleController.text.trim();
    _lastSavedBody = _serialize();
    _initializing = false;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _titleController.dispose();
    _titleFocus.dispose();
    for (final c in _controllers.values) {
      c.dispose();
    }
    for (final f in _focusNodes.values) {
      f.dispose();
    }
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Block bookkeeping
  // ---------------------------------------------------------------------------

  void _registerBlock(String id, String text) {
    _controllers[id] = TextEditingController(text: text)
      ..addListener(_onTextChanged);
    _focusNodes[id] = FocusNode()..addListener(_onFocusChanged);
  }

  void _unregisterBlock(String id) {
    _controllers.remove(id)?.dispose();
    _focusNodes.remove(id)?.dispose();
  }

  /// The editor always needs at least one text-like block to type into.
  void _ensureEditableBlock() {
    final hasEditable = _blocks.any((b) => b is TextBlock || b is CheckboxBlock);
    if (!hasEditable || _blocks.last is ImageBlock) {
      final id = const Uuid().v4();
      _blocks.add(Block.text(id: id, data: ''));
      _registerBlock(id, '');
    }
  }

  void _onFocusChanged() {
    if (mounted) setState(() {});
  }

  int get _focusedIndex {
    for (var i = 0; i < _blocks.length; i++) {
      if (_focusNodes[_blocks[i].id]?.hasFocus == true) return i;
    }
    return -1;
  }

  void _focusBlock(String id, {bool atEnd = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final node = _focusNodes[id];
      if (node == null) return;
      node.requestFocus();
      final c = _controllers[id];
      if (atEnd && c != null) {
        c.selection = TextSelection.collapsed(offset: c.text.length);
      }
    });
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
        _unregisterBlock(block2.id);
        _blocks.removeAt(i + 1);
        i--;
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Saving
  // ---------------------------------------------------------------------------

  List<Block> _currentBlocks() {
    return _blocks.map((b) {
      if (b is TextBlock) {
        return b.copyWith(data: _controllers[b.id]?.text ?? '');
      }
      if (b is CheckboxBlock) {
        return b.copyWith(data: _controllers[b.id]?.text ?? '');
      }
      return b;
    }).toList();
  }

  String _serialize() => _codec.serialize(_currentBlocks());

  bool _hasContent(String title, List<Block> blocks) {
    if (title.isNotEmpty) return true;
    return blocks.any((b) {
      if (b is ImageBlock) return true;
      return b.data.trim().isNotEmpty;
    });
  }

  void _onTextChanged() {
    if (_isResolving || _closing || _initializing || !mounted) return;
    final title = _titleController.text.trim();
    if (title == _lastSavedTitle && _serialize() == _lastSavedBody) return;

    _debounce?.cancel();
    _debounce = Timer(_autosaveDelay, _persist);
  }

  /// Writes the current editor state if it differs from what was last saved.
  void _persist() {
    _debounce?.cancel();
    if (_isResolving || !mounted) return;

    final title = _titleController.text.trim();
    final blocks = _currentBlocks();
    final body = _codec.serialize(blocks);
    if (title == _lastSavedTitle && body == _lastSavedBody) return;

    final notifier = ref.read(noteNotifierProvider.notifier);
    final now = DateTime.now();

    if (_noteId == null) {
      if (!_hasContent(title, blocks)) return;
      final id = const Uuid().v4();
      notifier.addNote(
        NoteEntity(
          id: id,
          title: title,
          body: body,
          createdAt: _createdAt,
          updatedAt: now,
        ),
      );
      _noteId = id;
      _createdHere = true;
    } else {
      final existing = _loadedNote;
      notifier.updateNote(
        existing != null
            ? existing.copyWith(title: title, body: body, updatedAt: now)
            : NoteEntity(
                id: _noteId!,
                title: title,
                body: body,
                createdAt: _createdAt,
                updatedAt: now,
              ),
      );
    }

    _lastSavedTitle = title;
    _lastSavedBody = body;
    _savedAnything = true;
    SyncOrchestrator.of(context)?.onLocalEdit();
  }

  /// Runs whenever the route is popped (Done, back button, swipe-back).
  void _onExit() {
    if (_isResolving || _closing) return;
    _closing = true;
    _persist();

    final notifier = ref.read(noteNotifierProvider.notifier);
    if (_createdHere &&
        _noteId != null &&
        !_hasContent(_titleController.text.trim(), _currentBlocks())) {
      notifier.deleteNote(_noteId!);
    }
    if (_savedAnything) {
      ref.read(syncSchedulerProvider).requestSync();
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showCupertinoModalPopup<bool>(
      context: context,
      builder: (sheetContext) => CupertinoActionSheet(
        message: const Text('You can undo right after deleting.'),
        actions: [
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(sheetContext).pop(true),
            child: const Text(AppStrings.deleteNote),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.of(sheetContext).pop(false),
          child: const Text('Cancel'),
        ),
      ),
    );
    if (confirmed != true || !mounted) return;

    _persist();
    final note = _loadedNote ??
        (_noteId == null
            ? null
            : NoteEntity(
                id: _noteId!,
                title: _titleController.text.trim(),
                body: _codec.serialize(_currentBlocks()),
                createdAt: _createdAt,
                updatedAt: DateTime.now(),
              ));
    _closing = true;
    _debounce?.cancel();
    final messenger = ScaffoldMessenger.of(context);
    final container = ProviderScope.containerOf(context, listen: false);
    Navigator.of(context).pop();
    if (note != null) {
      NoteActions.deleteWithUndo(
        container: container,
        messenger: messenger,
        note: note,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Images
  // ---------------------------------------------------------------------------

  Future<void> _insertImage() async {
    XFile? xfile;
    try {
      xfile = await ImagePicker().pickImage(source: ImageSource.gallery);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Couldn’t open your photo library.')),
        );
      }
      return;
    }
    if (xfile == null || !mounted) return;

    final docDir = await getApplicationDocumentsDirectory();
    final attachDir = Directory('${docDir.path}/attachments');
    if (!await attachDir.exists()) {
      await attachDir.create(recursive: true);
    }
    final uuid = const Uuid().v4();
    final newImage = File('${attachDir.path}/$uuid.jpg');
    await File(xfile.path).copy(newImage.path);
    final relativePath = 'attachments/$uuid.jpg';
    if (!mounted) return;

    String? focusAfter;
    setState(() {
      final focusedIndex = _focusedIndex;
      final focused = focusedIndex == -1 ? null : _blocks[focusedIndex];
      final imageBlock = Block.image(id: const Uuid().v4(), data: relativePath);

      if (focused is TextBlock) {
        // Split the paragraph at the cursor and put the image in between.
        final controller = _controllers[focused.id]!;
        final text = controller.text;
        var cursor = controller.selection.baseOffset;
        if (cursor < 0 || cursor > text.length) cursor = text.length;
        final before = text.substring(0, cursor);
        final after = text.substring(cursor);

        if (before.trim().isEmpty) {
          // Empty paragraph: image replaces it, text continues below.
          controller.text = after;
          _blocks.insert(focusedIndex, imageBlock);
          focusAfter = focused.id;
        } else {
          controller.text = before;
          _blocks.insert(focusedIndex + 1, imageBlock);
          final textId = const Uuid().v4();
          _blocks.insert(focusedIndex + 2, Block.text(id: textId, data: after));
          _registerBlock(textId, after);
          focusAfter = textId;
        }
      } else if (focused != null) {
        _blocks.insert(focusedIndex + 1, imageBlock);
      } else {
        // Nothing focused: replace a trailing empty paragraph, else append.
        final last = _blocks.isEmpty ? null : _blocks.last;
        if (last is TextBlock &&
            (_controllers[last.id]?.text.trim().isEmpty ?? true)) {
          _blocks.insert(_blocks.length - 1, imageBlock);
        } else {
          _blocks.add(imageBlock);
        }
      }
      _ensureEditableBlock();
    });
    if (focusAfter != null) _focusBlock(focusAfter!, atEnd: false);
    _onTextChanged();
  }

  void _removeImage(ImageBlock block) {
    setState(() {
      _blocks.removeWhere((b) => b.id == block.id);
      _mergeAdjacentTextBlocks();
      _ensureEditableBlock();
    });
    _onTextChanged();
  }

  // ---------------------------------------------------------------------------
  // Checklists
  // ---------------------------------------------------------------------------

  /// Toolbar "Checklist": turns an empty focused paragraph into a checklist
  /// item, otherwise adds a new item below the cursor's block.
  void _addChecklistItem() {
    final index = _focusedIndex;
    final focused = index == -1 ? null : _blocks[index];
    final newId = const Uuid().v4();

    setState(() {
      if (focused is TextBlock &&
          (_controllers[focused.id]?.text.trim().isEmpty ?? true)) {
        _blocks[index] = Block.checkbox(id: newId, data: '');
        _unregisterBlock(focused.id);
      } else if (focused != null) {
        _blocks.insert(index + 1, Block.checkbox(id: newId, data: ''));
      } else {
        final last = _blocks.isEmpty ? null : _blocks.last;
        if (last is TextBlock &&
            (_controllers[last.id]?.text.trim().isEmpty ?? true)) {
          _blocks[_blocks.length - 1] = Block.checkbox(id: newId, data: '');
          _unregisterBlock(last.id);
        } else {
          _blocks.add(Block.checkbox(id: newId, data: ''));
        }
      }
      _registerBlock(newId, '');
    });
    _focusBlock(newId);
    _onTextChanged();
  }

  /// Return key on a checklist item: new item below, or — on an empty item —
  /// leave the list and continue with a normal paragraph.
  void _onChecklistSubmitted(String blockId) {
    final index = _blocks.indexWhere((b) => b.id == blockId);
    if (index == -1) return;
    final controller = _controllers[blockId]!;
    final text = controller.text;
    final newId = const Uuid().v4();

    if (text.trim().isEmpty) {
      setState(() {
        _blocks[index] = Block.text(id: newId, data: '');
        _unregisterBlock(blockId);
        _registerBlock(newId, '');
        _mergeAdjacentTextBlocks();
      });
      final target = _blocks.any((b) => b.id == newId)
          ? newId
          : _blocks[index > 0 ? index - 1 : 0].id;
      _focusBlock(target);
    } else {
      var cursor = controller.selection.baseOffset;
      if (cursor < 0 || cursor > text.length) cursor = text.length;
      final before = text.substring(0, cursor);
      final after = text.substring(cursor);
      setState(() {
        controller.text = before;
        _blocks.insert(index + 1, Block.checkbox(id: newId, data: after));
        _registerBlock(newId, after);
      });
      _focusBlock(newId, atEnd: false);
    }
    _onTextChanged();
  }

  void _toggleChecklistItem(CheckboxBlock block) {
    setState(() {
      final idx = _blocks.indexWhere((b) => b.id == block.id);
      if (idx != -1) {
        final current = _blocks[idx] as CheckboxBlock;
        _blocks[idx] = current.copyWith(isChecked: !current.isChecked);
      }
    });
    _onTextChanged();
  }

  void _removeChecklistItem(String blockId) {
    final index = _blocks.indexWhere((b) => b.id == blockId);
    if (index == -1) return;
    String? focusTarget;
    setState(() {
      _blocks.removeAt(index);
      _unregisterBlock(blockId);
      _mergeAdjacentTextBlocks();
      _ensureEditableBlock();
      final start = index - 1 < _blocks.length ? index - 1 : _blocks.length - 1;
      for (var i = start; i >= 0; i--) {
        if (_blocks[i] is! ImageBlock) {
          focusTarget = _blocks[i].id;
          break;
        }
      }
    });
    if (focusTarget != null) _focusBlock(focusTarget!);
    _onTextChanged();
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = _blocks.removeAt(oldIndex);
      _blocks.insert(newIndex, item);
    });
    _onTextChanged();
  }

  /// Tapping the empty space under the content focuses the last line.
  void _focusEnd() {
    if (_blocks.isEmpty) return;
    final last = _blocks.lastWhere(
      (b) => b is! ImageBlock,
      orElse: () => _blocks.last,
    );
    if (last is ImageBlock) return;
    _focusBlock(last.id);
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final currentNote = _noteId != null
        ? ref.watch(noteStreamProvider(_noteId!)).asData?.value ?? _loadedNote
        : null;
    final isConflictCopy = currentNote?.conflictOf != null;
    final originalNote = isConflictCopy && currentNote?.conflictOf != null
        ? ref.watch(noteStreamProvider(currentNote!.conflictOf!)).asData?.value
        : null;

    final conflictCopyId = _noteId != null && !isConflictCopy
        ? ref
            .watch(noteNotifierProvider)
            .notes
            .where((n) => n.conflictOf == _noteId)
            .map((n) => n.id)
            .firstOrNull
        : null;
    final conflictCopy = conflictCopyId != null
        ? ref.watch(noteStreamProvider(conflictCopyId)).asData?.value
        : null;
    final conflictCopies =
        conflictCopy != null ? [conflictCopy] : <NoteEntity>[];

    if (_isEditing && !_hasInitializedFromNote && currentNote != null) {
      _initFromNote(currentNote);
    }

    final title = isConflictCopy
        ? AppStrings.conflictCopy
        : (_isEditing ? AppStrings.editNote : AppStrings.newNote);

    final topInset = MediaQuery.paddingOf(context).top;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    const barHeight = 60.0;

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _onExit();
      },
      child: Scaffold(
        backgroundColor: AppColors.surface,
        body: Stack(
          children: [
            Positioned.fill(
              child: CustomScrollView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.manual,
                slivers: [
                  SliverToBoxAdapter(child: SizedBox(height: topInset + barHeight)),
                  if (isConflictCopy && currentNote != null)
                    SliverToBoxAdapter(
                      child: _buildConflictBanner(
                        copyNote: currentNote,
                        originalNote: originalNote,
                        isViewingCopy: true,
                      ),
                    )
                  else if (conflictCopies.isNotEmpty)
                    SliverToBoxAdapter(
                      child: _buildConflictBanner(
                        copyNote: conflictCopies.first,
                        originalNote: currentNote,
                        isViewingCopy: false,
                      ),
                    ),
                  SliverToBoxAdapter(child: _buildTitleInput()),
                  SliverToBoxAdapter(child: _buildMeta(currentNote)),
                  SliverToBoxAdapter(child: _buildContentInput()),
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _focusEnd,
                      // Room so the last line can scroll above the toolbar.
                      child: const SizedBox(height: 200),
                    ),
                  ),
                ],
              ),
            ),
            // iOS 26 "scroll edge" fade: text scrolling under the floating
            // buttons dissolves instead of colliding with them.
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: Container(
                  height: topInset + barHeight + 8,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        AppColors.surface,
                        AppColors.surface.withValues(alpha: 0.9),
                        AppColors.surface.withValues(alpha: 0),
                      ],
                      stops: const [0, 0.6, 1],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: topInset + AppSpacing.sm,
              left: AppSpacing.page,
              right: AppSpacing.page,
              child: _buildTopBar(title: title, isConflictCopy: isConflictCopy),
            ),
            Positioned(
              left: AppSpacing.page,
              right: AppSpacing.page,
              bottom: (bottomInset > 0 ? bottomInset : AppSpacing.sm) + AppSpacing.xs,
              child: _buildToolbar(),
            ),
          ],
        ),
      ),
    );
  }

  /// Floating glass buttons instead of a solid app bar, as in iOS 26.
  Widget _buildTopBar({required String title, required bool isConflictCopy}) {
    return Row(
      children: [
        GlassIconButton(
          icon: CupertinoIcons.chevron_back,
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        Expanded(
          child: Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyles.cardTitle,
          ),
        ),
        if (_noteId != null && !isConflictCopy) ...[
          GlassIconButton(
            icon: CupertinoIcons.ellipsis,
            tooltip: 'More',
            onPressed: _confirmDelete,
          ),
          const SizedBox(width: AppSpacing.sm),
        ] else
          const SizedBox(width: 44 + AppSpacing.sm),
        GlassIconButton(
          icon: CupertinoIcons.checkmark_alt,
          tooltip: 'Done',
          prominent: true,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ],
    );
  }

  Widget _buildConflictBanner({
    required NoteEntity copyNote,
    required NoteEntity? originalNote,
    required bool isViewingCopy,
  }) {
    final conflictField = copyNote.conflictField ?? 'content';
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFB74D), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFA000).withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Color(0xFFFFECB3),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.call_split_rounded,
                  color: Color(0xFFE65100),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          isViewingCopy ? 'Conflict Copy' : 'Conflict Detected',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFE65100),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE65100),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            conflictField.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isViewingCopy
                          ? (originalNote != null
                              ? 'This duplicate copy was created because $conflictField was edited concurrently.'
                              : 'Conflict copy of a deleted note.')
                          : 'A concurrent edit created a duplicate copy of this note.',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF5D4037),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => _showComparisonSheet(
                  copyNote: copyNote,
                  originalNote: originalNote,
                  isViewingCopy: isViewingCopy,
                ),
                icon: const Icon(Icons.compare_arrows_rounded, size: 16),
                label: const Text('Compare'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFE65100),
                  side: const BorderSide(color: Color(0xFFFFB74D)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  visualDensity: VisualDensity.compact,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => _resolveKeepOriginal(
                  copyNote: copyNote,
                  isCurrentlyViewingCopy: isViewingCopy,
                ),
                icon: const Icon(Icons.close_rounded, size: 16),
                label: const Text('Keep Original'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF795548),
                  side: const BorderSide(color: Color(0xFFD7CCC8)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  visualDensity: VisualDensity.compact,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _resolveKeepCopy(
                  copyNote: copyNote,
                  originalNote: originalNote,
                  isCurrentlyViewingCopy: isViewingCopy,
                ),
                icon: const Icon(Icons.check_rounded, size: 16),
                label: const Text('Keep Copy'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE65100),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  visualDensity: VisualDensity.compact,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showComparisonSheet({
    required NoteEntity copyNote,
    required NoteEntity? originalNote,
    required bool isViewingCopy,
  }) {
    final conflictField = copyNote.conflictField ?? 'content';

    final String copyTitle;
    final String copyPlainText;
    if (isViewingCopy) {
      final t = _titleController.text.trim();
      copyTitle = t.isNotEmpty ? t : copyNote.title;
      final updatedBlocks = _blocks.map((b) {
        if (b is TextBlock) return b.copyWith(data: _controllers[b.id]?.text ?? '');
        if (b is CheckboxBlock) return b.copyWith(data: _controllers[b.id]?.text ?? '');
        return b;
      }).toList();
      final text = _blocksToPlainText(updatedBlocks);
      copyPlainText = text.isNotEmpty
          ? text
          : _blocksToPlainText(const NoteBodyCodec().parse(copyNote.body));
    } else {
      copyTitle = copyNote.title;
      copyPlainText = _blocksToPlainText(const NoteBodyCodec().parse(copyNote.body));
    }

    final String origTitle;
    final String origPlainText;
    if (originalNote != null) {
      if (!isViewingCopy) {
        origTitle = _titleController.text.trim();
        final updatedBlocks = _blocks.map((b) {
          if (b is TextBlock) return b.copyWith(data: _controllers[b.id]?.text ?? '');
          if (b is CheckboxBlock) return b.copyWith(data: _controllers[b.id]?.text ?? '');
          return b;
        }).toList();
        origPlainText = _blocksToPlainText(updatedBlocks);
      } else {
        origTitle = originalNote.title;
        origPlainText = _blocksToPlainText(const NoteBodyCodec().parse(originalNote.body));
      }
    } else {
      origTitle = '(Original note deleted)';
      origPlainText = '';
    }

    final isTitleDifferent = origTitle != copyTitle;
    final isBodyDifferent = origPlainText != copyPlainText;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Color(0xFFFBFBFB),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 20,
                    offset: Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.compare_arrows_rounded,
                          color: Color(0xFFE65100),
                          size: 24,
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Compare Notes',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Review changes and choose which version to keep.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(bottomSheetContext).pop(),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.all(20),
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF3E0),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFFFCC80)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline_rounded,
                                  size: 18, color: Color(0xFFE65100)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Conflict detected on: ${conflictField.toUpperCase()}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFFE65100),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        _buildComparisonCard(
                          title: 'Original Note',
                          badge: 'Original',
                          badgeColor: const Color(0xFF455A64),
                          icon: Icons.article_outlined,
                          noteTitle: origTitle,
                          noteBody: origPlainText,
                          isTitleDiff: isTitleDifferent,
                          isBodyDiff: isBodyDifferent,
                          conflictField: conflictField,
                        ),
                        const SizedBox(height: 16),
                        _buildComparisonCard(
                          title: 'Conflict Copy',
                          badge: 'Duplicate Copy',
                          badgeColor: const Color(0xFFE65100),
                          icon: Icons.call_split_rounded,
                          noteTitle: copyTitle,
                          noteBody: copyPlainText,
                          isTitleDiff: isTitleDifferent,
                          isBodyDiff: isBodyDifferent,
                          conflictField: conflictField,
                        ),
                        const SizedBox(height: 80),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 10,
                          offset: const Offset(0, -4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              Navigator.of(bottomSheetContext).pop();
                              _resolveKeepOriginal(
                                copyNote: copyNote,
                                isCurrentlyViewingCopy: isViewingCopy,
                              );
                            },
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: const BorderSide(color: Color(0xFFCFD8DC)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Keep Original',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF37474F),
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Delete copy',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF78909C),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.of(bottomSheetContext).pop();
                              _resolveKeepCopy(
                                copyNote: copyNote,
                                originalNote: originalNote,
                                isCurrentlyViewingCopy: isViewingCopy,
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFE65100),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Keep Copy',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Overwrite original',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFFFFE0B2),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildComparisonCard({
    required String title,
    required String badge,
    required Color badgeColor,
    required IconData icon,
    required String noteTitle,
    required String noteBody,
    required bool isTitleDiff,
    required bool isBodyDiff,
    required String conflictField,
  }) {
    final highlightTitle = isTitleDiff || conflictField == 'title';
    final highlightBody = isBodyDiff || conflictField == 'body';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: badgeColor.withValues(alpha: 0.3),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
            ),
            child: Row(
              children: [
                Icon(icon, size: 18, color: badgeColor),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: badgeColor,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: badgeColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    badge,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'TITLE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                        letterSpacing: 0.5,
                      ),
                    ),
                    if (highlightTitle) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFECB3),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'MODIFIED',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFE65100),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  noteTitle.isEmpty ? '(No title)' : noteTitle,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: noteTitle.isEmpty ? Colors.grey : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text(
                      'CONTENT',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                        letterSpacing: 0.5,
                      ),
                    ),
                    if (highlightBody) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFECB3),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'MODIFIED',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFE65100),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  noteBody.isEmpty ? '(Empty)' : noteBody,
                  maxLines: 8,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: noteBody.isEmpty ? Colors.grey : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _blocksToPlainText(List<Block> blocks) {
    return blocks
        .map((b) {
          if (b is TextBlock) return b.data;
          if (b is CheckboxBlock) {
            return '${b.isChecked ? "[x]" : "[ ]"} ${b.data}';
          }
          if (b is ImageBlock) return '[Image: ${b.data}]';
          return '';
        })
        .where((s) => s.isNotEmpty)
        .join('\n');
  }

  Future<void> _resolveKeepCopy({
    required NoteEntity copyNote,
    required NoteEntity? originalNote,
    required bool isCurrentlyViewingCopy,
  }) async {
    _isResolving = true;
    _debounce?.cancel();

    final String finalTitle;
    final String finalBody;

    if (isCurrentlyViewingCopy) {
      final t = _titleController.text.trim();
      finalTitle = t.isNotEmpty ? t : copyNote.title;
      final updatedBlocks = _blocks.map((b) {
        if (b is TextBlock) {
          return b.copyWith(data: _controllers[b.id]?.text ?? '');
        }
        if (b is CheckboxBlock) {
          return b.copyWith(data: _controllers[b.id]?.text ?? '');
        }
        return b;
      }).toList();
      final serialized = const NoteBodyCodec().serialize(updatedBlocks);
      finalBody = updatedBlocks.isNotEmpty ? serialized : copyNote.body;
    } else {
      finalTitle = copyNote.title;
      finalBody = copyNote.body;
    }

    if (originalNote != null) {
      ref.read(noteNotifierProvider.notifier).updateNote(
        NoteEntity(
          id: originalNote.id,
          title: finalTitle,
          body: finalBody,
          createdAt: originalNote.createdAt,
          updatedAt: DateTime.now().toUtc(),
          conflictOf: null,
          conflictField: null,
        ),
      );
    } else {
      final newId = const Uuid().v4();
      ref.read(noteNotifierProvider.notifier).addNote(
        NoteEntity(
          id: newId,
          title: finalTitle,
          body: finalBody,
          createdAt: DateTime.now().toUtc(),
          updatedAt: DateTime.now().toUtc(),
          conflictOf: null,
          conflictField: null,
        ),
      );
    }

    await ref.read(noteNotifierProvider.notifier).deleteNote(copyNote.id);
    ref.read(syncSchedulerProvider).requestSync();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(originalNote != null
              ? 'Kept conflict copy. Original note updated.'
              : 'Original note not found. Saved copy as a new note.'),
          duration: const Duration(seconds: 3),
        ),
      );
      if (isCurrentlyViewingCopy) {
        Navigator.of(context).pop();
      } else {
        setState(() {
          _isResolving = false;
        });
      }
    }
  }

  Future<void> _resolveKeepOriginal({
    required NoteEntity copyNote,
    required bool isCurrentlyViewingCopy,
  }) async {
    _isResolving = true;
    _debounce?.cancel();

    await ref.read(noteNotifierProvider.notifier).deleteNote(copyNote.id);
    ref.read(syncSchedulerProvider).requestSync();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kept original note. Conflict copy discarded.'),
          duration: Duration(seconds: 3),
        ),
      );
      if (isCurrentlyViewingCopy) {
        Navigator.of(context).pop();
      } else {
        setState(() {
          _isResolving = false;
        });
      }
    }
  }

  Widget _buildTitleInput() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.lg,
        AppSpacing.page,
        0,
      ),
      child: TextField(
        controller: _titleController,
        focusNode: _titleFocus,
        style: TextStyles.headline,
        maxLines: null,
        keyboardType: TextInputType.text,
        textInputAction: TextInputAction.next,
        textCapitalization: TextCapitalization.sentences,
        onEditingComplete: () {},
        onSubmitted: (_) {
          final first = _blocks.where((b) => b is! ImageBlock).firstOrNull;
          if (first != null) _focusBlock(first.id);
        },
        decoration: InputDecoration(
          hintText: AppStrings.titleHint,
          hintStyle: TextStyles.headline.copyWith(color: AppColors.textTertiary),
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.zero,
        ),
      ),
    );
  }

  Widget _buildMeta(NoteEntity? note) {
    final text = note == null
        ? (_noteId == null ? 'Saves automatically as you type' : 'Saved')
        : 'Edited ${AppDateFormat.relative(note.updatedAt)}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.sm,
        AppSpacing.page,
        AppSpacing.md,
      ),
      child: Text(text, style: TextStyles.caption),
    );
  }

  Widget _buildContentInput() {
    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      // Explicit drag handles only — otherwise a long-press inside a text
      // field (to select text) would start dragging the whole block.
      buildDefaultDragHandles: false,
      padding: const EdgeInsets.only(
        left: AppSpacing.page - AppSpacing.sm,
        right: AppSpacing.page,
      ),
      itemCount: _blocks.length,
      onReorder: _onReorder,
      proxyDecorator: (child, index, animation) => Material(
        color: AppColors.surface,
        elevation: 4,
        shadowColor: Colors.black26,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: child,
      ),
      itemBuilder: (context, index) {
        final block = _blocks[index];
        return KeyedSubtree(
          key: ValueKey(block.id),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: _buildBlockWidget(block, index),
          ),
        );
      },
    );
  }

  Widget _dragHandle(int index, {double top = 4}) {
    return ReorderableDragStartListener(
      index: index,
      child: Padding(
        padding: EdgeInsets.only(top: top, right: 6),
        child: Icon(
          CupertinoIcons.line_horizontal_3,
          size: 16,
          color: AppColors.textTertiary.withValues(alpha: 0.7),
        ),
      ),
    );
  }

  Widget _buildBlockWidget(Block block, int index) {
    if (block is ImageBlock) return _buildImageBlock(block, index);
    if (block is TextBlock) return _buildTextBlock(block, index);
    if (block is CheckboxBlock) return _buildCheckboxBlock(block, index);
    return const SizedBox.shrink();
  }

  Widget _buildTextBlock(TextBlock block, int index) {
    final isOnlyBlock = _blocks.length == 1;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _dragHandle(index),
        Expanded(
          child: TextField(
            controller: _controllers[block.id],
            focusNode: _focusNodes[block.id],
            style: TextStyles.body,
            maxLines: null,
            keyboardType: TextInputType.multiline,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: isOnlyBlock || index == _blocks.length - 1
                  ? AppStrings.contentHint
                  : null,
              hintStyle: TextStyles.hint,
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
              isDense: true,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCheckboxBlock(CheckboxBlock block, int index) {
    final hasFocus = _focusNodes[block.id]?.hasFocus ?? false;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _dragHandle(index, top: 5),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _toggleChecklistItem(block),
          child: Padding(
            padding: const EdgeInsets.only(top: 1, right: AppSpacing.sm + 2),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              transitionBuilder: (child, anim) =>
                  ScaleTransition(scale: anim, child: child),
              child: Icon(
                block.isChecked
                    ? CupertinoIcons.checkmark_circle_fill
                    : CupertinoIcons.circle,
                key: ValueKey(block.isChecked),
                color: block.isChecked ? AppColors.primary : AppColors.textTertiary,
                size: 24,
              ),
            ),
          ),
        ),
        Expanded(
          child: TextField(
            controller: _controllers[block.id],
            focusNode: _focusNodes[block.id],
            style: TextStyles.body.copyWith(
              decoration: block.isChecked ? TextDecoration.lineThrough : null,
              color: block.isChecked ? AppColors.textSecondary : AppColors.textPrimary,
            ),
            // Wraps visually, but Return creates the next item instead of a
            // newline (newlines can't be stored inside a checklist item).
            maxLines: null,
            keyboardType: TextInputType.text,
            textInputAction: TextInputAction.next,
            textCapitalization: TextCapitalization.sentences,
            onEditingComplete: () {},
            onSubmitted: (_) => _onChecklistSubmitted(block.id),
            decoration: const InputDecoration(
              hintText: AppStrings.checklistHint,
              hintStyle: TextStyles.hint,
              border: InputBorder.none,
              contentPadding: EdgeInsets.only(top: 2),
              isDense: true,
            ),
          ),
        ),
        if (hasFocus)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _removeChecklistItem(block.id),
            child: const Padding(
              padding: EdgeInsets.only(left: AppSpacing.sm, top: 3),
              child: Icon(
                CupertinoIcons.xmark_circle_fill,
                size: 20,
                color: AppColors.textTertiary,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildImageBlock(ImageBlock block, int index) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _dragHandle(index, top: 14),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Stack(
              children: [
                AttachmentImage(
                  path: block.data,
                  fit: BoxFit.cover,
                  borderRadius: AppRadius.lg,
                ),
                Positioned(
                  top: AppSpacing.sm,
                  right: AppSpacing.sm,
                  child: GlassIconButton(
                    icon: CupertinoIcons.xmark,
                    tooltip: 'Remove image',
                    size: 34,
                    onPressed: () => _removeImage(block),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Floating Liquid Glass toolbar, pinned above the keyboard.
  Widget _buildToolbar() {
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    return Row(
      children: [
        LiquidGlass(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ToolbarButton(
                icon: CupertinoIcons.checkmark_square,
                label: 'Checklist',
                onPressed: _addChecklistItem,
              ),
              Container(width: 0.5, height: 22, color: AppColors.border),
              _ToolbarButton(
                icon: CupertinoIcons.photo,
                label: 'Image',
                onPressed: _insertImage,
              ),
            ],
          ),
        ),
        const Spacer(),
        if (keyboardOpen)
          GlassIconButton(
            icon: CupertinoIcons.keyboard_chevron_compact_down,
            tooltip: 'Hide keyboard',
            onPressed: () => FocusScope.of(context).unfocus(),
          ),
      ],
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _ToolbarButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      minimumSize: const Size(44, 46),
      onPressed: onPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(label, style: TextStyles.label),
        ],
      ),
    );
  }
}
