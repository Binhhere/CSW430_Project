class AppConfig {
  const AppConfig({this.apiBaseUrl = 'http://10.0.2.2:3000'});

  factory AppConfig.fromEnvironment() {
    const configuredUrl = String.fromEnvironment('API_BASE_URL');
    return configuredUrl.isEmpty
        ? const AppConfig()
        : const AppConfig(apiBaseUrl: configuredUrl);
  }

  static AppConfig? _loaded;

  static AppConfig get current => _loaded ?? AppConfig.fromEnvironment();

  static Future<AppConfig> load() async {
    final environment = AppConfig.fromEnvironment();
    _loaded = environment.apiBaseUrl.isEmpty ? const AppConfig() : environment;
    return _loaded!;
  }

  final String apiBaseUrl;
}
