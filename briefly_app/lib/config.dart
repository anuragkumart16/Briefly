class AppConfig {
  static const String googleServerClientId = '183248163088-mspotq609am13jo95916set808v1680l.apps.googleusercontent.com';

  static const String backendUrl = String.fromEnvironment(
    'BACKEND_URL',
    defaultValue: 'https://briefly-nine-tan.vercel.app',
  );
}
