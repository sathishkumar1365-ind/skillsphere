import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../home/presentation/home_theme.dart';
import '../../data/additional_competency.dart';

/// Look shared by every Additional Competency: a warm rose accent (core
/// competencies use blue/teal/violet/slate) plus a dashed outline that
/// reads as "outside the library, not verified".
class AdditionalColors {
  AdditionalColors._();

  static const tint = Color(0xFFFCE9F1);
  static const foreground = Color(0xFF9B1F55);
  static const light = Color(0xFFD94C8A);
  static const dark = Color(0xFF8E1A4D);
  static const dash = Color(0xFFE7A3C0);
}

/// An icon that fits the name ("Poster Design" → palette).
IconData additionalIconFor(String name) {
  final n = name.toLowerCase();
  bool has(List<String> words) => words.any(n.contains);
  if (has(['poster', 'design', 'illustrat', 'paint', 'draw', 'art'])) return Icons.palette_outlined;
  if (has(['video', 'film', 'animation', 'motion'])) return Icons.movie_creation_outlined;
  if (has(['photo', 'camera'])) return Icons.photo_camera_outlined;
  if (has(['social', 'marketing', 'campaign'])) return Icons.campaign_outlined;
  if (has(['content', 'writ', 'copy', 'blog', 'newsletter'])) return Icons.edit_note_rounded;
  if (has(['speak', 'host', 'anchor', 'emcee', 'podcast'])) return Icons.mic_none_rounded;
  if (has(['event', 'party', 'celebrat'])) return Icons.celebration_outlined;
  if (has(['translat', 'language', 'korean', 'hindi'])) return Icons.translate_rounded;
  if (has(['first aid', 'medical', 'safety'])) return Icons.medical_services_outlined;
  if (has(['sport', 'coach', 'fitness', 'yoga', 'cricket'])) return Icons.sports_soccer_outlined;
  if (has(['music', 'sing', 'guitar', 'dance'])) return Icons.music_note_outlined;
  return Icons.auto_awesome_outlined;
}

/// Raised rose tile with the icon for [name].
class AdditionalIconTile extends StatelessWidget {
  const AdditionalIconTile({super.key, required this.name, this.size = 44});

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.3),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AdditionalColors.light, AdditionalColors.dark],
        ),
        boxShadow: [
          BoxShadow(
            color: AdditionalColors.dark.withValues(alpha: 0.32),
            blurRadius: size * 0.3,
            spreadRadius: -size * 0.12,
            offset: Offset(0, size * 0.14),
          ),
        ],
      ),
      child: Icon(additionalIconFor(name), size: size * 0.48, color: Colors.white),
    );
  }
}

/// "Self-declared · not verified" label.
class SelfDeclaredPill extends StatelessWidget {
  const SelfDeclaredPill({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: const BoxDecoration(
        color: AdditionalColors.tint,
        borderRadius: BorderRadius.all(Radius.circular(999)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.person_outline_rounded, size: 13, color: AdditionalColors.foreground),
          const SizedBox(width: 4),
          Text('Self-declared',
              style: HomeText.body(11.5,
                  weight: FontWeight.w700, color: AdditionalColors.foreground)),
        ],
      ),
    );
  }
}

/// Opens a sample-work link in a new tab / the browser.
Future<void> openAdditionalLink(BuildContext context, String link) async {
  final uri = Uri.tryParse(link.trim());
  var opened = false;
  if (uri != null) {
    try {
      opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      opened = false;
    }
  }
  if (!opened && context.mounted) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('Could not open $link'),
        behavior: SnackBarBehavior.floating,
      ));
  }
}

/// "Open sample work ↗" link button.
class SampleWorkLink extends StatelessWidget {
  const SampleWorkLink({super.key, required this.link});

  final String link;

  @override
  Widget build(BuildContext context) {
    final host = Uri.tryParse(link)?.host ?? '';
    return Tooltip(
      message: link,
      child: InkWell(
        onTap: () => openAdditionalLink(context, link),
        borderRadius: const BorderRadius.all(Radius.circular(8)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.open_in_new_rounded, size: 15, color: HomeColors.blue),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  host.isEmpty ? 'Open sample work' : 'Sample work · $host',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: HomeText.body(12.5, weight: FontWeight.w700, color: HomeColors.blue),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

String formatAddedDate(DateTime date) => '${date.day} ${_months[date.month - 1]} ${date.year}';

/// The entry's note, or '' when it has none.
String noteOf(AdditionalCompetency entry) => (entry.note ?? '').trim();
