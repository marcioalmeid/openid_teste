class KeycloakConfig {
  // Configurações do Keycloak
  // TODO: Configure estes valores com as informações do seu servidor Keycloak
  static const String keycloakUrl = 'http://localhost:8080';
  static const String realm = 'master';
  static const String clientId = 'flutter-app';
  
  // Redirect URIs por plataforma
  static const String redirectUrlMobile = 'com.example.openid_teste://callback';
  static const String redirectUrlWeb = 'http://localhost:3000/callback';
  
  // Discovery URL (opcional, mas recomendado)
  // O flutter_appauth pode descobrir automaticamente os endpoints
  static String get discoveryUrl => 
      '$keycloakUrl/realms/$realm/.well-known/openid-configuration';
  
  // Authorization endpoint
  static String get authorizationEndpoint => 
      '$keycloakUrl/realms/$realm/protocol/openid-connect/auth';
  
  // Token endpoint
  static String get tokenEndpoint => 
      '$keycloakUrl/realms/$realm/protocol/openid-connect/token';
  
  // Logout endpoint
  static String get endSessionEndpoint => 
      '$keycloakUrl/realms/$realm/protocol/openid-connect/logout';
  
  // Scopes (ajuste conforme necessário)
  static const List<String> scopes = [
    'openid',
    'profile',
    'email',
    'offline_access', // Para refresh token
  ];
}



