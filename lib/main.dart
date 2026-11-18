import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/app_info.dart';
import 'core/app_state.dart';
import 'pages/shell.dart';
import 'ui/components.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  final state = AppState();
  runApp(GoldenGlassApp(state: state));
  await state.load();
}

class GoldenGlassApp extends StatelessWidget {
  const GoldenGlassApp({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: state,
      child: Builder(builder: (context) {
        final app = context.app;
        final p = app.palette;
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: (p.dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark).copyWith(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: Colors.transparent,
            systemNavigationBarContrastEnforced: false,
          ),
          child: MaterialApp(
            title: appName,
            debugShowCheckedModeBanner: false,
            theme: buildMaterialTheme(p, app.look),
            home: app.ready ? const HomeShell() : const _Splash(),
          ),
        );
      }),
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.pal.background,
      child: Center(child: CircularProgressIndicator(color: context.pal.accent)),
    );
  }
}
