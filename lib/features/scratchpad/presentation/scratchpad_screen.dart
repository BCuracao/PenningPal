import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../state/scratchpad_notifier.dart';
import '../state/scratchpad_state.dart';
import 'export_toolbar.dart';

/// Distraction-free markdown scratchpad with live stats and auto-save.
class ScratchpadScreen extends ConsumerStatefulWidget {
  const ScratchpadScreen({super.key});

  @override
  ConsumerState<ScratchpadScreen> createState() => _ScratchpadScreenState();
}

class _ScratchpadScreenState extends ConsumerState<ScratchpadScreen> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
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

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text(
          'Clean Canvas',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 18,
            letterSpacing: -0.2,
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
                  ref.read(scratchpadProvider.notifier).updateContent(value);
                },
              ),
            ),
          ),
          const ExportToolbar(),
          _ScratchpadStatusBar(state: state),
        ],
      ),
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
