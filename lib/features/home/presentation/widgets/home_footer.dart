import 'package:flutter/material.dart';

import '../home_theme.dart';
import 'home_common.dart';

class HomeFooter extends StatelessWidget {
  const HomeFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 28),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: HomeColors.divider)),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 16,
        runSpacing: 12,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SphereMark(size: 22),
              const SizedBox(width: 10),
              Text(
                'SkillSphere',
                style: HomeText.body(16, weight: FontWeight.w800, color: HomeColors.ink),
              ),
            ],
          ),
          Text(
            'EXPLORE. LEARN. GROW.',
            style: HomeText.display(18, color: HomeColors.body, height: 1.2)
                .copyWith(letterSpacing: 1.1),
          ),
        ],
      ),
    );
  }
}
