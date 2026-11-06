/// What kind of note the editor should start with when creating a new one.
enum NoteTemplate {
  text,
  checklist,
  image;

  static NoteTemplate fromName(String? name) {
    for (final t in NoteTemplate.values) {
      if (t.name == name) return t;
    }
    return NoteTemplate.text;
  }
}
