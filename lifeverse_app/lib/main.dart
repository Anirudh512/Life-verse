import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/user_state.dart';
import 'services/notification_service.dart';
import 'services/api_service.dart';
import 'services/session_token_cache.dart';
import 'screens/first_launch_screen.dart';
import 'screens/hde_growth_contract_screen.dart';
import 'screens/hde_dashboard.dart';
import 'screens/time_capsule_dashboard.dart';
import 'screens/capsule_creation_screen.dart';
import 'screens/capsule_ceremony_screen.dart';
import 'screens/capsule_how_it_works_screen.dart';
import 'screens/legacy_timeline_screen.dart';
import 'screens/digital_twin_screen.dart';
import 'screens/future_simulation_screen.dart';
import 'screens/auth_intro_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/recovery_screen.dart';
import 'screens/permissions_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/hde_category_tasks_screen.dart';
import 'screens/growth_goals_screen.dart';
import 'screens/main_navigation.dart';
import 'screens/progress_screen.dart';
import 'screens/weekly_review_screen.dart';
import 'screens/reflect_hub_screen.dart';
import 'theme/lifeverse_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final userState = UserState();
  runApp(
    ChangeNotifierProvider.value(value: userState, child: const LifeVerseApp()),
  );
  unawaited(_initializeStartup(userState));
}

Future<void> _initializeStartup(UserState userState) async {
  // Notification setup is optional and may invoke platform permission/plugin
  // work. It must not hold the app on the session-restoration screen.
  if (!kIsWeb) unawaited(_initializeNotifications());
  await _restoreSessionFromServer(userState);
}

Future<void> _initializeNotifications() async {
  try {
    await NotificationService.initialize();
  } catch (error) {
    debugPrint('Notification setup was skipped: $error');
  }
}

/// On startup: read cached session token → validate against MySQL on server.
/// All real user data lives in MySQL; the local file is only a session key.
Future<void> _restoreSessionFromServer(UserState userState) async {
  userState.beginSessionRestore();
  String? cachedToken;
  try {
    cachedToken = await SessionTokenCache.read();
    if (cachedToken == null) {
      ApiService.setSessionToken(null);
      userState.setRestoringComplete();
      return;
    }

    final data = await ApiService.validateSession(cachedToken);
    if (data['success'] == true) {
      userState.setSession(
        userId: data['userId'],
        sessionToken: cachedToken,
        username: data['username'],
        fullName: data['fullName'],
        appState: Map<String, dynamic>.from(data['appState'] ?? {}),
      );
    } else {
      final status = data['httpStatus'];
      if (status == 401 || status == 403) {
        await SessionTokenCache.clear();
        ApiService.setSessionToken(null);
        userState.setRestoringComplete();
      } else {
        userState.setSessionRestoreError(
          data['message']?.toString() ??
              'Could not reach LifeVerse. Check your connection and retry.',
        );
      }
    }
  } catch (error) {
    if (cachedToken != null) ApiService.setSessionToken(cachedToken);
    userState.setSessionRestoreError(
      'Could not restore your session. Check your connection and retry.',
    );
    debugPrint('Session restore failed: $error');
  }
}

class LifeVerseApp extends StatelessWidget {
  const LifeVerseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<UserState>(
      builder: (context, userState, _) {
        if (userState.sessionRestoreError != null) {
          return MaterialApp(
            key: const ValueKey('session-error'),
            debugShowCheckedModeBanner: false,
            theme: ThemeData(brightness: Brightness.dark),
            home: Scaffold(
              backgroundColor: Colors.black,
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.cloud_off,
                        color: Colors.white54,
                        size: 48,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'LifeVerse is offline',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        userState.sessionRestoreError!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () =>
                            unawaited(_restoreSessionFromServer(userState)),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        if (userState.isRestoringSession) {
          return MaterialApp(
            key: const ValueKey('session-restoring'),
            debugShowCheckedModeBanner: false,
            theme: ThemeData(brightness: Brightness.dark),
            home: const Scaffold(
              backgroundColor: Colors.black,
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: LifeVerseColors.primary),
                    SizedBox(height: 20),
                    Text(
                      'Connecting to LifeVerse...',
                      style: TextStyle(color: Colors.white54),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return MaterialApp(
          key: const ValueKey('lifeverse-routes'),
          title: 'LifeVerse',
          debugShowCheckedModeBanner: false,
          theme: LifeVerseTheme.dark,
          initialRoute: userState.isLoggedIn ? '/splash' : '/',
          routes: {
            '/': (context) => const AuthIntroScreen(),
            '/login': (context) => const LoginScreen(),
            '/register': (context) => const RegisterScreen(),
            '/recovery': (context) => const RecoveryScreen(),
            '/permissions': (context) => const PermissionsScreen(),
            '/splash': (context) => const SplashScreen(),
            '/home': (context) => const MainNavigation(),
            '/hde_dashboard': (context) => const HDEDashboard(),
            '/progress': (context) => const ProgressScreen(),
            '/weekly-review': (context) => const WeeklyReviewScreen(),
            '/reflect': (context) => const ReflectHubScreen(),
            '/growth_goals': (context) => const GrowthGoalsScreen(),
            '/hde_category_tasks': (context) => const HDECategoryTasksScreen(),
            '/time_capsules': (context) => const TimeCapsuleDashboard(),
            '/capsule_how_it_works': (context) =>
                const CapsuleHowItWorksScreen(),
            '/legacy_timeline': (context) => const LegacyTimelineScreen(),
            '/digital_twin': (context) => DigitalTwinScreen(
              openButterflyEffect:
                  ModalRoute.of(context)?.settings.arguments == 'butterfly',
            ),
            '/profile': (context) => const ProfileScreen(),
          },
          onGenerateRoute: (settings) {
            Widget page;
            switch (settings.name) {
              case '/first_launch':
                page = const FirstLaunchScreen();
                break;
              case '/hde_growth_contract':
                page = const HDEGrowthContractScreen();
                break;
              case '/hde_dashboard':
                page = const HDEDashboard();
                break;
              case '/growth_goals':
                page = const GrowthGoalsScreen();
                break;
              case '/time_capsules':
                page = const TimeCapsuleDashboard();
                break;
              case '/create_capsule':
                page = const CapsuleCreationScreen();
                break;
              case '/capsule_how_it_works':
                page = const CapsuleHowItWorksScreen();
                break;
              case '/capsule_ceremony':
                page = const CapsuleCeremonyScreen();
                break;
              case '/legacy_timeline':
                page = const LegacyTimelineScreen();
                break;
              case '/digital_twin':
                page = DigitalTwinScreen(
                  openButterflyEffect: settings.arguments == 'butterfly',
                );
                break;
              case '/future_simulation':
                page = const FutureSimulationScreen();
                break;
              case '/profile':
                page = const ProfileScreen();
                break;
              case '/progress':
                page = const ProgressScreen();
                break;
              case '/weekly-review':
                page = const WeeklyReviewScreen();
                break;
              case '/reflect':
                page = const ReflectHubScreen();
                break;
              case '/hde_category_tasks':
                page = const HDECategoryTasksScreen();
                break;
              default:
                page = _UnknownRouteScreen(routeName: settings.name);
            }

            return PageRouteBuilder(
              settings: settings,
              pageBuilder: (context, animation, secondaryAnimation) => page,
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                    var tween = Tween(
                      begin: const Offset(1.0, 0.0),
                      end: Offset.zero,
                    ).chain(CurveTween(curve: Curves.easeOutQuart));

                    return SlideTransition(
                      position: animation.drive(tween),
                      child: FadeTransition(opacity: animation, child: child),
                    );
                  },
            );
          },
        );
      },
    );
  }
}

class _UnknownRouteScreen extends StatelessWidget {
  const _UnknownRouteScreen({required this.routeName});

  final String? routeName;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Page unavailable')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.route_outlined, size: 48, color: Colors.white54),
              const SizedBox(height: 16),
              const Text(
                'This LifeVerse page could not be opened.',
                textAlign: TextAlign.center,
              ),
              if (routeName != null) ...[
                const SizedBox(height: 8),
                Text(
                  routeName!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white54),
                ),
              ],
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () => Navigator.of(
                  context,
                ).pushNamedAndRemoveUntil('/home', (route) => false),
                icon: const Icon(Icons.home_outlined),
                label: const Text('Return to LifeVerse'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
