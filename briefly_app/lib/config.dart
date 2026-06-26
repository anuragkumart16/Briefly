class AppConfig {
  static const String googleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
    defaultValue: 'YOUR_GOOGLE_SERVER_CLIENT_ID.apps.googleusercontent.com',
  );

  static const String backendUrl = String.fromEnvironment(
    'BACKEND_URL',
    defaultValue: 'http://localhost:3000',
  );
}
