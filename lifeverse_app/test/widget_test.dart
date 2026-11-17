import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:lifeverse_app/main.dart';
import 'package:lifeverse_app/screens/auth_intro_screen.dart';
import 'package:lifeverse_app/screens/hde_dashboard.dart';
import 'package:lifeverse_app/screens/main_navigation.dart';
import 'package:lifeverse_app/screens/progress_screen.dart';
import 'package:lifeverse_app/screens/weekly_review_screen.dart';
import 'package:lifeverse_app/services/user_state.dart';

void main() {
  testWidgets('navigation adapts between phone and desktop widths', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final userState = UserState()..setRestoringComplete();
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: userState,
        child: const MaterialApp(home: MainNavigation()),
      ),
    );
    await tester.pump();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    expect(tester.takeException(), isNull);

    tester.view.physicalSize = const Size(1365, 900);
    await tester.pump();

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows a loading screen while the saved session is restored', (
    tester,
  ) async {
    final userState = UserState();

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: userState,
        child: const LifeVerseApp(),
      ),
    );

    expect(find.text('Connecting to LifeVerse...'), findsOneWidget);
    expect(find.text('LifeVerse is offline'), findsNothing);
  });

  testWidgets('rebuilds navigation after session restoration completes', (
    tester,
  ) async {
    final userState = UserState();

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: userState,
        child: const LifeVerseApp(),
      ),
    );
    expect(find.text('Connecting to LifeVerse...'), findsOneWidget);

    userState.setRestoringComplete();
    await tester.pumpAndSettle();

    expect(find.byType(AuthIntroScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 16));
  });

  testWidgets(
    'Evolution Matrix explains how to choose and record an activity',
    (tester) async {
      final userState = UserState()
        ..setSession(userId: 'user-1', sessionToken: 'test-session');

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: userState,
          child: const MaterialApp(home: HDEDashboard()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Evolution Matrix'), findsOneWidget);
      expect(find.text('Choose one area to focus on'), findsOneWidget);
      expect(find.text('Choose an area'), findsOneWidget);
      expect(find.text('Pick a task'), findsOneWidget);
      expect(find.text('Record it when done'), findsOneWidget);
      expect(find.text('Physical'), findsOneWidget);
      expect(find.text('Progress overview'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('shows recorded visits separately from completed growth days', (
    tester,
  ) async {
    final userState = UserState()
      ..setSession(userId: 'user-1', sessionToken: 'test-session');
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: userState,
        child: MaterialApp(
          theme: ThemeData.dark(useMaterial3: true),
          home: ProgressScreen(
            analyticsLoader: (userId, days) async {
              expect(userId, 'user-1');
              expect(days, 7);
              return {
                'success': true,
                'summary': {
                  'visitDays': 2,
                  'growthDays': 1,
                  'tasksCompleted': 3,
                  'reviewsCompleted': 1,
                  'periodXp': 75,
                  'totalXp': 300,
                },
                'daily': [
                  for (var day = 1; day <= 7; day++)
                    {
                      'date': '2026-10-${day.toString().padLeft(2, '0')}',
                      'visited': day == 1 || day == 2,
                      'growthActivity': day == 2,
                      'tasksCompleted': day == 2 ? 3 : 0,
                      'reviewsCompleted': day == 2 ? 1 : 0,
                      'xp': day == 2 ? 75 : 0,
                    },
                ],
                'dimensions': {
                  'physical': {
                    'tasksCompleted': 2,
                    'reviewsCompleted': 0,
                    'activeDays': 1,
                    'xp': 50,
                  },
                  'cognitive': {
                    'tasksCompleted': 1,
                    'reviewsCompleted': 1,
                    'activeDays': 1,
                    'xp': 25,
                  },
                  'psychosocial': {
                    'tasksCompleted': 0,
                    'reviewsCompleted': 0,
                    'activeDays': 0,
                    'xp': 0,
                  },
                  'moral': {
                    'tasksCompleted': 0,
                    'reviewsCompleted': 0,
                    'activeDays': 0,
                    'xp': 0,
                  },
                },
                'goals': [],
                'recentActivity': [],
                'hdeStats': {'currentStreak': 1},
              };
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Visit days'), findsOneWidget);
    expect(find.text('Growth days'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('Activity calendar'), findsOneWidget);
    expect(find.text('Physical'), findsOneWidget);
    expect(
      find.textContaining('Earlier visits are unavailable'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'weekly review uses recorded metrics and keeps a visit separate from growth',
    (tester) async {
      final userState = UserState()
        ..setSession(userId: 'user-1', sessionToken: 'test-session');

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: userState,
          child: MaterialApp(
            home: WeeklyReviewScreen(
              reviewLoader: (userId) async {
                expect(userId, 'user-1');
                return {
                  'success': true,
                  'window': {
                    'startDate': '2026-10-21',
                    'endDate': '2026-10-27',
                    'timezone': 'UTC',
                  },
                  'summary': {
                    'visitDays': 4,
                    'growthDays': 2,
                    'tasksCompleted': 3,
                    'reviewsCompleted': 1,
                    'periodXp': 65,
                  },
                  'dimensions': {
                    'physical': {'tasksCompleted': 2, 'reviewsCompleted': 0},
                    'cognitive': {'tasksCompleted': 1, 'reviewsCompleted': 1},
                    'psychosocial': {
                      'tasksCompleted': 0,
                      'reviewsCompleted': 0,
                    },
                    'moral': {'tasksCompleted': 0, 'reviewsCompleted': 0},
                  },
                  'goals': [],
                  'recentActivity': [],
                };
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Weekly review'), findsOneWidget);
      expect(find.text('Visit days'), findsOneWidget);
      expect(find.text('Growth days'), findsOneWidget);
      expect(
        find.textContaining('Visits are not growth activity.'),
        findsOneWidget,
      );
      expect(find.text('Across your four dimensions'), findsOneWidget);
      expect(find.text('Optional reflection prompts'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
