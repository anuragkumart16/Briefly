import 'package:flutter/foundation.dart';

class AppConfig {
  static const String googleServerClientId = kDebugMode
      ? '183248163088-mspotq609am13jo95916set808v1680l.apps.googleusercontent.com'
      : '183248163088-d0902lpo1kvedvt71tdfivpta658p5cn.apps.googleusercontent.com';

  static const String backendUrl = String.fromEnvironment(
    'BACKEND_URL',
    defaultValue: 'https://briefly-nine-tan.vercel.app',
  );
}
