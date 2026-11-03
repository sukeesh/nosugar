import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/home.dart';
import 'screens/onboarding.dart';
import 'state.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
  final state = AppState();
  await state.load();
  if (AppState.demo && const String.fromEnvironment('SCREEN') == 'onboard') state.onboarded = false;
  runApp(NoSugarApp(state: state));
}

class NoSugarApp extends StatelessWidget {
  const NoSugarApp({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'nosugar',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: ListenableBuilder(
        listenable: state,
        builder: (context, _) => AnimatedSwitcher(
          duration: const Duration(milliseconds: 500),
          child: state.onboarded ? Shell(key: const ValueKey('shell'), state: state) : OnboardingScreen(key: const ValueKey('onboard'), state: state),
        ),
      ),
    );
  }
}
