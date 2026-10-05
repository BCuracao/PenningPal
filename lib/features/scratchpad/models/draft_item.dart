import 'dart:math';

import 'package:flutter/material.dart';

/// Workflow tag for a local scratchpad document.
enum DraftStatus {
  draft,
  ready,
  published;

  String get displayName => switch (this) {
        DraftStatus.draft => 'Draft',
        DraftStatus.ready => 'Ready',
        DraftStatus.published => 'Published',
      };

  /// Muted grey, amber/orange, or green — used by status pills.
  Color get foreground => switch (this) {
        DraftStatus.draft => const Color(0xFF6B7280),
        DraftStatus.ready => const Color(0xFFC2410C),
        DraftStatus.published => const Color(0xFF15803D),
      };

  Color get background => switch (this) {
        DraftStatus.draft => const Color(0xFFF3F4F6),
        DraftStatus.ready => const Color(0xFFFFEDD5),
        DraftStatus.published => const Color(0xFFDCFCE7),
      };

  static DraftStatus parse(Object? raw) {
    if (raw is DraftStatus) return raw;
    if (raw is String) {
      for (final value in DraftStatus.values) {
        if (value.name == raw) return value;
      }
    }
    return DraftStatus.draft;
  }
}

/// One scratchpad document stored in the local `drafts_box`.
class DraftItem {
  const DraftItem({
    required this.id,
    required this.title,
    String? markdownContent,
    String? content,
    this.status = DraftStatus.draft,
    required this.createdAt,
    required this.updatedAt,
  }) : markdownContent = markdownContent ?? content ?? '';

  static const String untitled = 'Untitled Draft';

  final String id;
  final String title;

  /// Raw markdown buffer. Exporters read this; the editor never rewrites it
  /// into Unicode or HTML.
  final String markdownContent;
  final DraftStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Alias for [markdownContent] used by the existing scratchpad buffer.
  String get content => markdownContent;

  /// First non-empty line, with heading markers and inline markdown stripped.
  ///
  /// Falls back to [untitled] when the buffer is empty or token-only.
  static String inferTitle(String content) {
    for (final raw in content.split(RegExp(r'\r?\n'))) {
      final stripped = stripMarkdownTokens(raw);
      if (stripped.isNotEmpty) return stripped;
    }
    return untitled;
  }

  /// Body preview used in the drafts list: first [maxChars] of text after
  /// the title line, with markdown tokens stripped.
  static String previewSnippet(String content, {int maxChars = 60}) {
    final lines = content.split(RegExp(r'\r?\n'));
    var skippedTitle = false;
    final buffer = StringBuffer();
    for (final raw in lines) {
      final stripped = stripMarkdownTokens(raw);
      if (stripped.isEmpty) continue;
      if (!skippedTitle) {
        skippedTitle = true;
        continue;
      }
      if (buffer.isNotEmpty) buffer.write(' ');
      buffer.write(stripped);
      if (buffer.length >= maxChars) break;
    }
    final snippet = buffer.toString().trim();
    if (snippet.length <= maxChars) return snippet;
    return snippet.substring(0, maxChars).trimRight();
  }

  /// Strips heading prefixes, list/quote markers, and common inline tokens.
  static String stripMarkdownTokens(String line) {
    var s = line.trim();
    if (s.isEmpty) return '';
    s = s.replaceFirst(RegExp(r'^#{1,6}\s*'), '');
    s = s.replaceFirst(RegExp(r'^>\s*'), '');
    s = s.replaceFirst(RegExp(r'^[-*+]\s+'), '');
    s = s.replaceFirst(RegExp(r'^\d+\.\s+'), '');
    if (RegExp(r'^[-*_]{3,}$').hasMatch(s)) return '';
    s = s.replaceAllMapped(
      RegExp(r'\*\*\*([^*]+)\*\*\*'),
      (match) => match[1]!,
    );
    s = s.replaceAllMapped(RegExp(r'___([^_]+)___'), (match) => match[1]!);
    s = s.replaceAllMapped(RegExp(r'\*\*([^*]+)\*\*'), (match) => match[1]!);
    s = s.replaceAllMapped(RegExp(r'__([^_]+)__'), (match) => match[1]!);
    s = s.replaceAllMapped(RegExp(r'\*([^*]+)\*'), (match) => match[1]!);
    s = s.replaceAllMapped(
      RegExp(r'(?<!\w)_([^_]+)_(?!\w)'),
      (match) => match[1]!,
    );
    s = s.replaceAllMapped(RegExp(r'`([^`]+)`'), (match) => match[1]!);
    return s.trim();
  }

  DraftItem copyWith({
    String? id,
    String? title,
    String? markdownContent,
    String? content,
    DraftStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DraftItem(
      id: id ?? this.id,
      title: title ?? this.title,
      markdownContent: markdownContent ?? content ?? this.markdownContent,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'content': markdownContent,
      'markdownContent': markdownContent,
      'status': status.name,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  static DraftItem fromMap(Map<dynamic, dynamic> map, {String? fallbackId}) {
    final id = map['id'] as String? ?? fallbackId ?? generateDraftId();
    final markdown = map['markdownContent'] as String? ??
        map['content'] as String? ??
        '';
    final title = (map['title'] as String?)?.trim();
    return DraftItem(
      id: id,
      title: (title == null || title.isEmpty) ? inferTitle(markdown) : title,
      markdownContent: markdown,
      status: DraftStatus.parse(map['status']),
      createdAt: parseTime(map['createdAt']) ??
          parseTime(map['updatedAt']) ??
          DateTime.now(),
      updatedAt: parseTime(map['updatedAt']) ?? DateTime.now(),
    );
  }

  static DateTime? parseTime(dynamic value) {
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  @override
  bool operator ==(Object other) {
    return other is DraftItem &&
        other.id == id &&
        other.title == title &&
        other.markdownContent == markdownContent &&
        other.status == status &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode =>
      Object.hash(id, title, markdownContent, status, createdAt, updatedAt);
}

/// Existing scratchpad name for [DraftItem].
typedef Draft = DraftItem;

final Random _draftIdRandom = Random();

/// UUID v4. Unique even when two drafts are created in the same tick.
String generateDraftId() {
  String hex(int length) {
    final buffer = StringBuffer();
    for (var i = 0; i < length; i++) {
      buffer.write(_draftIdRandom.nextInt(16).toRadixString(16));
    }
    return buffer.toString();
  }

  const variants = <String>['8', '9', 'a', 'b'];
  return '${hex(8)}-${hex(4)}-4${hex(3)}-'
      '${variants[_draftIdRandom.nextInt(variants.length)]}${hex(3)}-${hex(12)}';
}
