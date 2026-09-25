import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:snakes_of_imt/screens/login.dart';
import 'package:snakes_of_imt/theme/app_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:easy_localization/easy_localization.dart';

void main() async {

  WidgetsFlutterBinding.ensureInitialized();

  // Trava o app apenas na vertical (nunca rotaciona)
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  await EasyLocalization.ensureInitialized();

  await Supabase.initialize(

    url:
    'https://onisczwmchpouqrkxhli.supabase.co',

    anonKey:
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9uaXNjendtY2hwb3Vxcmt4aGxpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzgxMDUzOTcsImV4cCI6MjA5MzY4MTM5N30.XgGudHdIjJiIVOKG4i07UueyO3bA3tKcKdf4zCzzbnM',

    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.implicit,
    ),
  );

  runApp(

    EasyLocalization(

      supportedLocales: const [

        Locale('pt', 'BR'),
        Locale('en', 'US'),
      ],

      path: 'assets/translations',

      fallbackLocale:
      const Locale('pt', 'BR'),

      startLocale:
      const Locale('pt', 'BR'),

      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {

  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {

    return MaterialApp(

      debugShowCheckedModeBanner: false,

      title: 'OphidIA',

      locale: context.locale,

      supportedLocales:
      context.supportedLocales,

      localizationsDelegates:
      context.localizationDelegates,

      theme: AppTheme.theme,

      home: const LoginPage(),
    );
  }
}