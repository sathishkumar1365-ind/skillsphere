// Shared helpers for the HRD console data (employees, projects, roles,
// divisions, groups & departments, approvals, training plans).
//
// Everything in lib/features/admin/data is TEMPORARY in-memory data, like the
// competency library: it is lost on a page reload. Each repository says which
// Spring Boot endpoint replaces it (see CHANGES-hrd-console.md).

import '../../../core/auth/app_user.dart';

/// Thrown when a console action can't be done. [message] is safe to show.
class AdminException implements Exception {
  const AdminException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Where a record came from.
enum RecordSource {
  existing('Existing record'),
  manual('Added manually'),
  bulkImport('Bulk import'),
  crowd('Crowd sync');

  const RecordSource(this.label);
  final String label;
}

/// Case- and space-insensitive key, used to stop duplicates.
String nameKey(String value) => value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

/// Trims and collapses inner spaces: "  Quality   Assurance " → "Quality Assurance".
String cleanText(String value) => value.trim().replaceAll(RegExp(r'\s+'), ' ');

/// Largest number found in ids such as "PRJ-007" (0 when there is none).
int highestNumber(Iterable<String> ids) {
  var highest = 0;
  for (final id in ids) {
    final number = int.tryParse(id.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    if (number > highest) highest = number;
  }
  return highest;
}

/// "PRJ-" + next number, zero-padded to [width] digits.
String nextId(String prefix, Iterable<String> ids, {int width = 3}) =>
    '$prefix${(highestNumber(ids) + 1).toString().padLeft(width, '0')}';

/// Throws unless [by] is in the HRD team (Super Admin).
void requireHrd(AppUser by, String action) {
  if (!by.role.canManageOrganization) {
    throw AdminException('Only the HRD team can $action.');
  }
}

/// Short pause so buttons show their busy state, like a real API call.
Future<void> apiPause([int milliseconds = 350]) =>
    Future<void>.delayed(Duration(milliseconds: milliseconds));

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

const _monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// "Aug 2026"
String monthYear(DateTime d) => '${_monthNames[d.month - 1]} ${d.year}';

/// "14 Nov 2026"
String dayMonthYear(DateTime d) => '${d.day} ${_monthNames[d.month - 1]} ${d.year}';

/// "2026-11-14" (the format used in the import templates).
String isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// "3 days ago", "today", "in 2 days".
String relativeDays(DateTime date, {DateTime? now}) {
  final today = dateOnly(now ?? DateTime.now());
  final days = today.difference(dateOnly(date)).inDays;
  if (days == 0) return 'today';
  if (days == 1) return 'yesterday';
  if (days == -1) return 'tomorrow';
  if (days > 1) return days < 60 ? '$days days ago' : dayMonthYear(date);
  return -days < 60 ? 'in ${-days} days' : dayMonthYear(date);
}

/// Reads a date typed in a file or form: 2026-11-14, 14/11/2026, 14-11-2026,
/// 14 Nov 2026, or an Excel date number (days since 1899-12-30).
DateTime? parseFlexibleDate(String raw) {
  final text = raw.trim();
  if (text.isEmpty) return null;

  // Excel stores dates as numbers; formulas/cells may also give "46340.0".
  final serial = double.tryParse(text);
  if (serial != null) {
    if (serial < 20000 || serial > 80000) return null; // not a sensible date
    final base = DateTime.utc(1899, 12, 30);
    final d = base.add(Duration(days: serial.floor()));
    return DateTime(d.year, d.month, d.day);
  }

  final iso = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})').firstMatch(text);
  if (iso != null) {
    return _validDate(int.parse(iso.group(1)!), int.parse(iso.group(2)!), int.parse(iso.group(3)!));
  }
  final dmy = RegExp(r'^(\d{1,2})[/.\-](\d{1,2})[/.\-](\d{4})$').firstMatch(text);
  if (dmy != null) {
    return _validDate(int.parse(dmy.group(3)!), int.parse(dmy.group(2)!), int.parse(dmy.group(1)!));
  }
  final named = RegExp(r'^(\d{1,2})[\s\-]+([A-Za-z]{3,})[\s\-,]+(\d{4})$').firstMatch(text);
  if (named != null) {
    final month = _monthNames.indexWhere(
            (m) => named.group(2)!.toLowerCase().startsWith(m.toLowerCase())) +
        1;
    if (month == 0) return null;
    return _validDate(int.parse(named.group(3)!), month, int.parse(named.group(1)!));
  }
  return null;
}

DateTime? _validDate(int year, int month, int day) {
  if (month < 1 || month > 12 || day < 1 || day > 31) return null;
  final d = DateTime(year, month, day);
  // DateTime rolls 31 Feb over to March: reject that.
  return d.month == month && d.day == day ? d : null;
}

/// "1.4 MB", "820 KB".
String fileSizeLabel(int bytes) {
  if (bytes >= 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  if (bytes >= 1024) return '${(bytes / 1024).round()} KB';
  return '$bytes B';
}

/// A simple, permissive email check (the server does the real one).
bool isValidEmail(String value) =>
    RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$').hasMatch(value.trim());
