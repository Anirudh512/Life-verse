import 'package:flutter/material.dart';

import '../theme/lifeverse_theme.dart';

class AiDataNotice extends StatelessWidget {
  const AiDataNotice({super.key});

  @override
  Widget build(BuildContext context) => Material(
    color: LifeVerseColors.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: LifeVerseColors.line),
    ),
    clipBehavior: Clip.antiAlias,
    child: Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        leading: const Icon(
          Icons.privacy_tip_outlined,
          color: LifeVerseColors.primary,
          size: 20,
        ),
        title: const Text(
          'How LifeVerse uses AI',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
        subtitle: const Text(
          'Your prompt and selected context go to Google Gemini through LifeVerse. AI responses can be inaccurate.',
          style: TextStyle(
            color: LifeVerseColors.muted,
            fontSize: 11,
            height: 1.35,
          ),
        ),
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: const [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Life Atlas biography drafts use your saved milestones and Twin Mind memories. If you select the option on that screen, your recent daily review answers are included too. Those records go to Google Gemini when you create a draft; review and edit the result before saving. Twin Mind conversations are saved to your account. It saves short, non-sensitive preferences, goals, interests, hobbies, routines, or values only when you explicitly ask it to remember them. You can review or clear Twin Mind history and saved facts from its menu. Avoid sharing highly sensitive details.',
              style: TextStyle(
                color: LifeVerseColors.muted,
                fontSize: 12,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
