// Additional Competencies: things an employee is good at outside the
// automotive competency library, such as Content Creation or Poster Design.
//
// * Employees add their own (Home page → Additional).
// * No levels and no verification by anyone.
// * HRD sees and searches everyone's (dashboard → Competencies), e.g. to
//   find who can design a poster for a plant event.
//
// Spring Boot API later:
//   GET    /api/employees/me/additional-competencies
//   POST   /api/employees/me/additional-competencies   {name, note, link}
//   DELETE /api/employees/me/additional-competencies/{id}
//   GET    /api/additional-competencies?q=              (SUPER_ADMIN only)

class AdditionalCompetency {
  const AdditionalCompetency({
    required this.id,
    required this.employeeId,
    required this.name,
    required this.addedAt,
    this.note,
    this.link,
  });

  /// e.g. "ADD-001".
  final String id;

  /// Owner, matches EmployeeRecord.id / AppUser.id.
  final String employeeId;
  final String name;

  /// Optional: what they have done with it ("Designed the Safety Week posters").
  final String? note;

  /// Optional: link to sample work (portfolio, video, drive folder…).
  final String? link;

  final DateTime addedAt;

  String get key => keyFor(name);

  bool get hasLink => (link ?? '').trim().isNotEmpty;

  /// Case- and space-insensitive key, so "poster design" = "Poster  Design".
  static String keyFor(String name) =>
      name.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  /// Text the HRD search looks in.
  String get searchText => '$name ${note ?? ''}'.toLowerCase();
}

class AdditionalCompetencyRules {
  AdditionalCompetencyRules._();

  static const int nameMax = 40;
  static const int noteMax = 160;

  /// Most additional competencies one employee can list.
  static const int maxPerEmployee = 15;

  /// Offered while typing. Names other employees already use are offered
  /// too, so the same skill is written the same way.
  static const suggestions = [
    'Content Creation',
    'Poster Design',
    'Graphic Design',
    'Video Editing',
    'Photography',
    'Illustration',
    'Social Media',
    'Copywriting',
    'Public Speaking',
    'Event Hosting',
    'Event Planning',
    'Translation',
    'First Aid',
    'Sports Coaching',
  ];
}
