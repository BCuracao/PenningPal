import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/persistence/draft_storage.dart';
import '../state/scratchpad_notifier.dart';
import '../state/scratchpad_state.dart';
import 'drafts_drawer.dart';
import 'export_toolbar.dart';
import 'formatting_toolbar.dart';
import 'settings_bottom_sheet.dart';
import 'styled_markdown_controller.dart';

/// Distraction-free markdown scratchpad with live stats and auto-save.
class ScratchpadScreen extends ConsumerStatefulWidget {
  const ScratchpadScreen({super.key});

  @override
  ConsumerState<ScratchpadScreen> createState() => _ScratchpadScreenState();
}

class _ScratchpadScreenState extends ConsumerState<ScratchpadScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late final StyledMarkdownEditingController _controller;
  late final FocusNode _focusNode;
  var _syncingController = false;

  @override
  void initState() {
    super.initState();
    _controller = StyledMarkdownEditingController(
      text: ref.read(scratchpadProvider).content,
    );
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
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
        final content = ref.read(scratchpadProvider).content;
        _syncingController = true;
        _controller.value = TextEditingValue(
          text: content,
          selection: TextSelection.collapsed(offset: content.length),
        );
        _syncingController = false;
        _focusNode.requestFocus();
      },
    );

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
          icon: const Icon(Icons.menu),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        title: InkWell(
          key: const Key('draft-title'),
          onTap: _renameDraft,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
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
        centerTitle: false,
      ),
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
              child: TextField(
                key: const Key('scratchpad-field'),
                controller: _controller,
                focusNode: _focusNode,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                keyboardType: TextInputType.multiline,
                textCapitalization: TextCapitalization.sentences,
                cursorColor: colors.primary,
                style: GoogleFonts.inter(
                  fontSize: 18,
                  height: 1.7,
                  fontWeight: FontWeight.w400,
                  color: colors.onSurface,
                ),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Start writing…',
                  hintStyle: GoogleFonts.inter(
                    fontSize: 18,
                    height: 1.7,
                    color: colors.onSurface.withValues(alpha: 0.35),
                  ),
                ),
                onChanged: (value) {
                  if (_syncingController) return;
                  ref.read(scratchpadProvider.notifier).updateContent(value);
                },
              ),
            ),
          ),
          FormattingToolbar(
            controller: _controller,
            onTextChanged: (value) {
              ref.read(scratchpadProvider.notifier).updateContent(value);
            },
          ),
          const ExportToolbar(),
          _ScratchpadStatusBar(state: state),
        ],
      ),
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
            decoration: const InputDecoration(
              hintText: Draft.untitled,
            ),
            onSubmitted: (value) => Navigator.of(dialogContext).pop(value),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: const Key('draft-rename-save'),
              onPressed: () =>
                  Navigator.of(dialogContext).pop(controller.text),
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
