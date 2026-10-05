import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/draft_item.dart';
import '../render/markdown_quill_bridge.dart';
import '../state/scratchpad_notifier.dart';
import '../state/scratchpad_state.dart';
import 'widgets/drafts_drawer.dart';
import 'export_toolbar.dart';
import 'formatting_toolbar.dart';
import 'scratchpad_editor_styles.dart';
import 'settings_bottom_sheet.dart';
import 'slide_break_embed.dart';
import 'widgets/linkedin_fold_indicator.dart';
import 'widgets/platform_counter_hud.dart';
import 'widgets/template_picker_bottom_sheet.dart';

/// Distraction-free markdown scratchpad with live stats and auto-save.
class ScratchpadScreen extends ConsumerStatefulWidget {
  const ScratchpadScreen({super.key});

  @override
  ConsumerState<ScratchpadScreen> createState() => _ScratchpadScreenState();
}

class _ScratchpadScreenState extends ConsumerState<ScratchpadScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late final QuillController _controller;
  late final FocusNode _focusNode;
  late final ScrollController _scrollController;
  StreamSubscription<DocChange>? _docChanges;
  var _applyingExternal = false;

  @override
  void initState() {
    super.initState();
    final document = Document.fromDelta(
      markdownToDelta(ref.read(scratchpadProvider).content),
    );
    _controller = QuillController(
      document: document,
      selection: const TextSelection.collapsed(offset: 0),
    );
    _focusNode = FocusNode();
    _scrollController = ScrollController();
    _listenToDocument(document);
  }

  void _listenToDocument(Document document) {
    _docChanges?.cancel();
    _docChanges = document.changes.listen((_) {
      _persistDocument(document);
    });
  }

  void _persistDocument(Document document) {
    if (_applyingExternal || !mounted) return;
    final markdown = deltaToMarkdown(document.toDelta());
    if (markdown == ref.read(scratchpadProvider).content) return;
    ref.read(scratchpadProvider.notifier).updateContent(markdown);
  }

  void _loadDraft(String markdown) {
    _applyingExternal = true;
    final next = Document.fromDelta(markdownToDelta(markdown));
    final previous = _controller.document;
    _docChanges?.cancel();
    _controller.document = next;
    if (!identical(previous, next)) {
      previous.close();
    }
    _listenToDocument(next);
    final maxOffset = next.length - 1;
    _controller.updateSelection(
      TextSelection.collapsed(offset: maxOffset < 0 ? 0 : maxOffset),
      ChangeSource.local,
    );
    _applyingExternal = false;
  }

  @override
  void dispose() {
    _docChanges?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(scratchpadProvider);
    final colors = Theme.of(context).colorScheme;

    ref.listen<String>(
      scratchpadProvider.select((value) => value.activeDraftId),
      (previous, next) {
        if (previous == null || previous == next) return;
        _loadDraft(ref.read(scratchpadProvider).content);
        _focusNode.requestFocus();
      },
    );

    ref.listen<String>(scratchpadProvider.select((value) => value.content), (
      previous,
      next,
    ) {
      if (previous == null || previous == next || _applyingExternal) return;
      final current = deltaToMarkdown(_controller.document.toDelta());
      if (current == next) return;
      _loadDraft(next);
    });

    final isKeyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;

    return Scaffold(
      key: _scaffoldKey,
      resizeToAvoidBottomInset: true,
      drawer: DraftsDrawer(
        onNewDraft: _createDraft,
        onOpenSettings: _openSettings,
      ),
      appBar: AppBar(
        leading: IconButton(
          key: const Key('drafts-menu'),
          tooltip: 'Drafts',
          icon: const Icon(Icons.folder_open_outlined),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            Flexible(
              child: InkWell(
                key: const Key('draft-title'),
                onTap: _renameDraft,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 4,
                    horizontal: 4,
                  ),
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          state.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                            fontSize: 18,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        Icons.edit_outlined,
                        size: 16,
                        color: colors.onSurface.withValues(alpha: 0.45),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            _DraftStatusSelector(status: state.status),
          ],
        ),
        centerTitle: false,
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        onVerticalDragUpdate: (details) {
          // Dismiss immediately on a downward swipe, including when the
          // editor is shorter than the viewport and is not scrolling.
          if (details.primaryDelta != null && details.primaryDelta! > 6) {
            FocusManager.instance.primaryFocus?.unfocus();
          }
        },
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                child: Column(
                  children: [
                    Expanded(child: _buildEditor()),
                    LinkedInFoldIndicator(markdown: state.content),
                  ],
                ),
              ),
            ),
            PlatformCounterHud(markdown: state.content),
            FormattingToolbar(
              controller: _controller,
              onOpenTemplates: _openTemplates,
            ),
            if (!isKeyboardVisible) ...[
              const ExportToolbar(),
              _ScratchpadStatusBar(state: state),
            ],
          ],
        ),
      ),
    );
  }

  /// The editor's own scroll view dismisses the keyboard on drag.
  ///
  /// A downward swipe anywhere on the body does the same, so a short draft
  /// that is not scrolling still hides the keyboard.
  ///
  /// Quill's internal scroller does not expose [ScrollView.keyboardDismissBehavior],
  /// so the document grows inside this view (`scrollable: false`) and caret
  /// reveal keeps using the same [ScrollController].
  Widget _buildEditor() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final minHeight = constraints.maxHeight;
        return SingleChildScrollView(
          key: const Key('scratchpad-editor-scroll'),
          controller: _scrollController,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: minHeight),
            child: QuillEditor(
              key: const Key('scratchpad-field'),
              controller: _controller,
              focusNode: _focusNode,
              scrollController: _scrollController,
              config: QuillEditorConfig(
                scrollable: false,
                expands: false,
                padding: EdgeInsets.zero,
                minHeight: minHeight,
                placeholder: 'Start writing…',
                textCapitalization: TextCapitalization.sentences,
                customStyles: scratchpadEditorStyles(context),
                embedBuilders: const [SlideBreakEmbedBuilder()],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _createDraft() async {
    await ref.read(scratchpadProvider.notifier).createNewDraft();
    _scaffoldKey.currentState?.closeDrawer();
    _focusNode.requestFocus();
  }

  Future<void> _openSettings() async {
    _scaffoldKey.currentState?.closeDrawer();
    await Future<void>.delayed(const Duration(milliseconds: 160));
    if (!mounted) return;
    await SettingsBottomSheet.show(context);
  }

  Future<void> _openTemplates() {
    return TemplatePickerBottomSheet.show(
      context,
      currentMarkdown: ref.read(scratchpadProvider).content,
      onApply: _applyTemplateMarkdown,
    );
  }

  void _applyTemplateMarkdown(String markdown) {
    if (!mounted) return;
    ref.read(scratchpadProvider.notifier).updateContent(markdown);
    _loadDraft(markdown);
  }

  Future<void> _renameDraft() async {
    final current = ref.read(scratchpadProvider).title;
    final controller = TextEditingController(text: current);
    final next = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          key: const Key('draft-rename-dialog'),
          title: Text(
            'Rename draft',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700),
          ),
          content: TextField(
            key: const Key('draft-rename-field'),
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(hintText: DraftItem.untitled),
            onSubmitted: (value) => Navigator.of(dialogContext).pop(value),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: const Key('draft-rename-save'),
              onPressed: () => Navigator.of(dialogContext).pop(controller.text),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    if (next == null || !mounted) return;
    await ref.read(scratchpadProvider.notifier).renameActiveDraft(next);
  }
}

class _DraftStatusSelector extends ConsumerWidget {
  const _DraftStatusSelector({required this.status});

  final DraftStatus status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<DraftStatus>(
      key: const Key('draft-status-pill'),
      tooltip: 'Change status',
      padding: EdgeInsets.zero,
      initialValue: status,
      onSelected: (next) {
        final id = ref.read(scratchpadProvider).activeDraftId;
        ref.read(scratchpadProvider.notifier).setDraftStatus(id, next);
      },
      itemBuilder: (context) {
        return [
          for (final value in DraftStatus.values)
            PopupMenuItem<DraftStatus>(
              key: Key('status-option-${value.name}'),
              value: value,
              child: Text(value.displayName),
            ),
        ];
      },
      child: DraftStatusBadge(status: status),
    );
  }
}

class _ScratchpadStatusBar extends StatelessWidget {
  const _ScratchpadStatusBar({required this.state});

  final ScratchpadState state;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final labelStyle = GoogleFonts.inter(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.1,
      color: colors.onSurface.withValues(alpha: 0.55),
    );

    final wordsLabel = state.wordCount == 1 ? 'word' : 'words';
    final charsLabel = state.charCount == 1 ? 'char' : 'chars';

    return Material(
      color: colors.surfaceContainerLowest,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 10, 24, 10),
          child: Row(
            children: [
              Flexible(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      '${state.wordCount} $wordsLabel',
                      key: const Key('word-count'),
                      style: labelStyle,
                    ),
                    _StatusDot(color: labelStyle.color!),
                    Text(
                      '${state.charCount} $charsLabel',
                      key: const Key('char-count'),
                      style: labelStyle,
                    ),
                    _StatusDot(color: labelStyle.color!),
                    Text(
                      '${state.estimatedReadMinutes} min read',
                      key: const Key('read-time'),
                      style: labelStyle,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                state.isSaving ? 'Saving...' : 'Saved',
                key: const Key('save-status'),
                style: labelStyle.copyWith(
                  color: state.isSaving
                      ? colors.tertiary
                      : colors.primary.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text('·', style: TextStyle(color: color, fontSize: 12));
  }
}
