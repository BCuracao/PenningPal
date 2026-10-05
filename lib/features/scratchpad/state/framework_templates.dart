/// How a framework skeleton is written into the current draft.
enum TemplateInsertMode { append, replace }

/// A proven post skeleton. [markdown] keeps `---` slide breaks intact.
class FrameworkTemplate {
  const FrameworkTemplate({
    required this.id,
    required this.title,
    required this.blurb,
    required this.markdown,
  });

  final String id;
  final String title;
  final String blurb;
  final String markdown;
}

/// Scratchpad frameworks. Insertion returns a new Markdown string and does
/// not mutate the caller's buffer.
class FrameworkTemplates {
  const FrameworkTemplates._();

  static const FrameworkTemplate contrarianHook = FrameworkTemplate(
    id: 'contrarian-hook',
    title: 'Contrarian Hook',
    blurb: 'Challenge a common belief, then prove it wrong.',
    markdown: '# Most people think [common belief] is true.\n'
        'Here is why they are completely wrong:\n'
        '---\n'
        '### Point 1...',
  );

  static const FrameworkTemplate fiveStepBreakdown = FrameworkTemplate(
    id: 'five-step',
    title: 'The 5-Step Breakdown',
    blurb: 'Promise an outcome, then walk through the steps.',
    markdown: '# How to [Achieve Desired Outcome] in 5 Steps\n'
        'A step-by-step framework to get started:\n'
        '---\n'
        '### Step 1: Foundation...',
  );

  static const FrameworkTemplate storyAndLesson = FrameworkTemplate(
    id: 'story-lesson',
    title: 'The Story + Lesson',
    blurb: 'Open with a mistake, then land the lessons.',
    markdown: '# In 2022, I made a massive mistake with [Topic].\n'
        'Here is what happened and the 3 lessons I learned:\n'
        '---\n'
        '### Lesson 1...',
  );

  static const List<FrameworkTemplate> all = [
    contrarianHook,
    fiveStepBreakdown,
    storyAndLesson,
  ];

  static bool isBlank(String markdown) => markdown.trim().isEmpty;

  /// Appends [template] after a blank line, or replaces the draft.
  ///
  /// Blank drafts always take the template itself so a `---` slide break is
  /// not prefixed with an empty slide.
  static String apply({
    required String current,
    required FrameworkTemplate template,
    required TemplateInsertMode mode,
  }) {
    if (mode == TemplateInsertMode.replace || isBlank(current)) {
      return template.markdown;
    }
    final trimmed = current.replaceFirst(RegExp(r'\s+$'), '');
    return '$trimmed\n\n${template.markdown}';
  }
}
