import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:cortex/core/constants/colors.dart';
import 'package:cortex/core/constants/string_constants.dart';
import 'package:cortex/core/constants/text_styles.dart';
import 'package:cortex/features/notes/domain/entities/note_entity.dart';
import 'package:cortex/features/notes/presentation/providers/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:cortex/features/notes/domain/note_body_codec.dart';
import 'package:cortex/features/notes/presentation/widgets/attachment_image.dart';
import 'package:cortex/features/sync/presentation/sync_orchestrator.dart';
import 'package:cortex/features/sync/presentation/sync_providers.dart';
import 'package:path_provider/path_provider.dart';

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
  bool _isResolving = false;
  bool _hasInitializedFromNote = false;
  bool get _isEditing => widget.noteId != null;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();

    if (_isEditing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final note = ref
            .read(noteNotifierProvider.notifier)
            .getNoteById(widget.noteId!);
        if (note != null) {
          _initFromNote(note);
          if (mounted) setState(() {});
        }
      });
    } else {
      final id = const Uuid().v4();
      _blocks.add(Block.text(id: id, data: ''));
      _controllers[id] = TextEditingController()..addListener(_onTextChanged);
      _focusNodes[id] = FocusNode();
    }
  }

  void _initFromNote(NoteEntity note) {
    if (_hasInitializedFromNote) return;
    _hasInitializedFromNote = true;
    _titleController.text = note.title;

    final parsed = const NoteBodyCodec().parse(note.body);
    _coverImage = parsed.whereType<ImageBlock>().firstOrNull?.data;

    _blocks.clear();
    if (parsed.isNotEmpty) {
      for (final b in parsed) {
        _blocks.add(b);
        if (b is TextBlock || b is CheckboxBlock) {
          _controllers[b.id] = TextEditingController(text: b.data)
            ..addListener(_onTextChanged);
          _focusNodes[b.id] = FocusNode();
        }
      }
      _mergeAdjacentTextBlocks();
    } else {
      final id = const Uuid().v4();
      _blocks.add(Block.text(id: id, data: ''));
      _controllers[id] = TextEditingController()
        ..addListener(_onTextChanged);
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
    if (_isResolving || !_isEditing) return;
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _autoSaveNote();
    });
    if (mounted) {
      SyncOrchestrator.of(context)?.onLocalEdit();
    }
  }

  void _autoSaveNote() {
    if (_isResolving) return;
    final title = _titleController.text.trim();

    final updatedBlocks = _blocks.map((b) {
      if (b is TextBlock) {
        return b.copyWith(data: _controllers[b.id]?.text ?? '');
      }
      if (b is CheckboxBlock) {
        return b.copyWith(data: _controllers[b.id]?.text ?? '');
      }
      return b;
    }).toList();

    final body = const NoteBodyCodec().serialize(updatedBlocks);

    try {
      final existingPreview = ref
          .read(noteNotifierProvider)
          .notes
          .firstWhere((n) => n.note.id == widget.noteId);
      final existingNote = existingPreview.note;
      ref
          .read(noteNotifierProvider.notifier)
          .updateNote(
            existingNote.copyWith(
              title: title,
              body: body,
              updatedAt: DateTime.now(),
            ),
          );
    } catch (_) {}
  }

  void _saveNote() {
    if (_isResolving) return;
    _debounce?.cancel();
    final title = _titleController.text.trim();

    final updatedBlocks = _blocks.map((b) {
      if (b is TextBlock) {
        return b.copyWith(data: _controllers[b.id]?.text ?? '');
      }
      if (b is CheckboxBlock) {
        return b.copyWith(data: _controllers[b.id]?.text ?? '');
      }
      return b;
    }).toList();

    final body = const NoteBodyCodec().serialize(updatedBlocks);
    final plainText = updatedBlocks
        .whereType<TextBlock>()
        .map((b) => b.data)
        .join('\n')
        .trim();
    final hasImages = updatedBlocks.any((b) => b is ImageBlock);

    if (title.isEmpty && plainText.isEmpty && !hasImages) {
      Navigator.of(context).pop();
      return;
    }

    if (_isEditing) {
      _autoSaveNote();
    } else {
      final now = DateTime.now();
      ref
          .read(noteNotifierProvider.notifier)
          .addNote(
            NoteEntity(
              id: Uuid().v4(),
              title: title,
              body: body,
              createdAt: now,
              updatedAt: now,
            ),
          );
    }

    ref.read(syncSchedulerProvider).requestSync();
    Navigator.of(context).pop();
  }

  Future<void> _insertImage() async {
    final picker = ImagePicker();
    final xfile = await picker.pickImage(source: ImageSource.gallery);

    if (xfile != null) {
      final docDir = await getApplicationDocumentsDirectory();
      final attachDir = Directory('${docDir.path}/attachments');
      if (!await attachDir.exists()) {
        await attachDir.create(recursive: true);
      }
      final uuid = const Uuid().v4();
      final newImage = File('${attachDir.path}/$uuid.jpg');
      await File(xfile.path).copy(newImage.path);

      final relativePath = 'attachments/$uuid.jpg';

      setState(() {
        _coverImage ??= relativePath;

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

          final imageId = const Uuid().v4();
          _blocks.insert(
            focusedIndex + 1,
            Block.image(id: imageId, data: relativePath),
          );

          final textId = const Uuid().v4();
          _blocks.insert(
            focusedIndex + 2,
            Block.text(id: textId, data: textAfter),
          );
          _controllers[textId] = TextEditingController(text: textAfter)
            ..addListener(_onTextChanged);
          _focusNodes[textId] = FocusNode();

          _focusNodes[textId]?.requestFocus();
        } else {
          _blocks.add(Block.image(id: const Uuid().v4(), data: relativePath));

          final textId = const Uuid().v4();
          _blocks.add(Block.text(id: textId, data: ''));
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
    final noteState =
        widget.noteId != null ? ref.watch(noteNotifierProvider) : null;
    final currentNote = widget.noteId != null && noteState != null
        ? noteState.notes
            .where((n) => n.note.id == widget.noteId)
            .firstOrNull
            ?.note
        : null;
    final isConflictCopy = currentNote?.conflictOf != null;
    final originalNote = isConflictCopy && noteState != null
        ? noteState.notes
            .where((n) => n.note.id == currentNote!.conflictOf)
            .firstOrNull
            ?.note
        : null;

    final conflictCopies = widget.noteId != null &&
            !isConflictCopy &&
            noteState != null
        ? noteState.notes
            .where((n) => n.note.conflictOf == widget.noteId)
            .map((n) => n.note)
            .toList()
        : <NoteEntity>[];

    if (_isEditing && !_hasInitializedFromNote && currentNote != null) {
      _initFromNote(currentNote);
    }

    return Scaffold(
      backgroundColor: AppColors.searchBarBackground,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 100),
        child: FloatingActionButton.extended(
          heroTag: null,
          onPressed: () {
            showModalBottomSheet(
              context: context,
              backgroundColor: Colors.transparent,
              builder: (ctx) => _buildSpeedDialMenu(),
            );
          },
          icon: const Center(
            child: HugeIcon(
              icon: HugeIcons.strokeRoundedCheckmarkSquare01,
              color: Colors.white,
              size: 24,
            ),
          ),
          label: const Text("Check box"),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
        ),
      ),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: _buildTopBar(isConflictCopy: isConflictCopy),
            ),

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
            title: const Text('Text Block'),
            onTap: () {
              Navigator.pop(context);
              _insertTextBlock();
            },
          ),
          ListTile(
            leading: const Icon(Icons.check_box, color: AppColors.primary),
            title: const Text('Checklist'),
            onTap: () {
              Navigator.pop(context);
              _insertCheckboxBlock();
            },
          ),
          ListTile(
            leading: const Icon(Icons.image, color: AppColors.primary),
            title: const Text('Image'),
            onTap: () {
              Navigator.pop(context);
              _insertImage();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar({bool isConflictCopy = false}) {
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
              child: HugeIcon(
                icon: HugeIcons.strokeRoundedArrowLeft01,
                color: AppColors.textPrimary,
                size: 15,
              ),
            ),
          ),

          Expanded(
            child: Text(
              isConflictCopy
                  ? 'Conflict Copy'
                  : (_isEditing ? AppStrings.editNote : AppStrings.createNote),
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
                Icons.check,
                color: AppColors.textPrimary,
                size: 20,
              ),
            ),
          ),
        ],
      ),
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
    }

    ref.read(noteNotifierProvider.notifier).deleteNote(copyNote.id);
    ref.read(syncSchedulerProvider).requestSync();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kept conflict copy. Original note updated.'),
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

  Future<void> _resolveKeepOriginal({
    required NoteEntity copyNote,
    required bool isCurrentlyViewingCopy,
  }) async {
    _isResolving = true;
    _debounce?.cancel();

    ref.read(noteNotifierProvider.notifier).deleteNote(copyNote.id);
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

    final newId = const Uuid().v4();
    final newBlock = Block.text(id: newId, data: textAfter);

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

  void _reindexBlocks() {}

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
    int insertIndex = _blocks.length;
    for (int i = 0; i < _blocks.length; i++) {
      final b = _blocks[i];
      if ((b is TextBlock || b is CheckboxBlock) &&
          _focusNodes[b.id]?.hasFocus == true) {
        insertIndex = i + 1;
        break;
      }
    }

    final newId = const Uuid().v4();
    final newBlock = Block.checkbox(id: newId, data: '');
    setState(() {
      _blocks.insert(insertIndex, newBlock);
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
    int insertIndex = _blocks.length;
    for (int i = 0; i < _blocks.length; i++) {
      final b = _blocks[i];
      if ((b is TextBlock || b is CheckboxBlock) &&
          _focusNodes[b.id]?.hasFocus == true) {
        insertIndex = i + 1;
        break;
      }
    }

    final newId = const Uuid().v4();
    final newBlock = Block.text(id: newId, data: '');
    setState(() {
      _blocks.insert(insertIndex, newBlock);
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
                  child: _buildBlockWidget(block, index),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBlockWidget(Block block, int index) {
    if (block is ImageBlock) return _buildImageBlock(block, index);
    if (block is TextBlock) return _buildTextBlock(block, index);
    if (block is CheckboxBlock) return _buildCheckboxBlock(block, index);
    return const SizedBox();
  }

  Widget _buildTextBlock(TextBlock block, int index) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ReorderableDragStartListener(
          index: index,
          child: const Padding(
            padding: EdgeInsets.only(top: 8.0, right: 8.0),
            child: Icon(Icons.drag_indicator, size: 16, color: Colors.black26),
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

  Widget _buildCheckboxBlock(CheckboxBlock block, int index) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ReorderableDragStartListener(
          index: index,
          child: const Padding(
            padding: EdgeInsets.only(top: 8.0, right: 8.0),
            child: Icon(Icons.drag_indicator, size: 16, color: Colors.black26),
          ),
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
                hintText: 'To-do',
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

  Widget _buildImageBlock(ImageBlock block, int index) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ReorderableDragStartListener(
          index: index,
          child: const Padding(
            padding: EdgeInsets.only(top: 16.0, right: 8.0),
            child: Icon(Icons.drag_indicator, size: 16, color: Colors.black26),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Stack(
              alignment: Alignment.topRight,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: AttachmentImage(path: block.data),
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
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
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
