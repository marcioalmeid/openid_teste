import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/keycloak_config.dart';

// Importa a versão apropriada baseada na plataforma
import 'package:openid_client/openid_client_io.dart' if (dart.library.html) 'package:openid_client/openid_client_browser.dart' as oidc;
import 'package:url_launcher/url_launcher.dart';

// Para web, importa dart:html para acessar window.sessionStorage  
import 'dart:html' as html if (dart.library.html) 'dart:io';

/// Implementação de autenticação usando openid_client
/// Baseado em: https://medium.com/@rangika123.kanchana/keycloak-integration-for-flutter-web-using-openid-client-with-authorization-code-flow-489afeac6e9f
class AuthServiceOpenId {
  static final AuthServiceOpenId _instance = AuthServiceOpenId._internal();
  factory AuthServiceOpenId() => _instance;
  AuthServiceOpenId._internal();

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  // Keys para armazenamento
  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _idTokenKey = 'id_token';

  oidc.Client? _client;
  oidc.Credential? _credential;

  /// Gera uma string aleatória (para codeVerifier e state)
  static String _randomString(int length) {
    var r = math.Random.secure();
    var chars =
        '0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ';
    return Iterable.generate(length, (_) => chars[r.nextInt(chars.length)])
        .join();
  }

  /// Inicializa o cliente OpenID
  Future<void> _initializeClient() async {
    if (_client != null) return;

    try {
      final issuerUri = Uri.parse(
        '${KeycloakConfig.keycloakUrl}/realms/${KeycloakConfig.realm}'
      );
      final issuer = await oidc.Issuer.discover(issuerUri);
      _client = oidc.Client(issuer, KeycloakConfig.clientId);
      debugPrint('Cliente OpenID inicializado com sucesso');
    } catch (e) {
      debugPrint('Erro ao inicializar cliente OpenID: $e');
      rethrow;
    }
  }

  /// Salva tokens do credential
  Future<void> _saveTokens(oidc.Credential credential) async {
    _credential = credential;
    
    try {
      // Obtém o TokenResponse para acessar o accessToken
      final tokenResponse = await credential.getTokenResponse();
      
      if (tokenResponse.accessToken != null) {
        await _secureStorage.write(
          key: _accessTokenKey, 
          value: tokenResponse.accessToken!
        );
      }
      await _secureStorage.write(
        key: _idTokenKey, 
        value: credential.idToken.toCompactSerialization()
      );
      if (credential.refreshToken != null) {
        await _secureStorage.write(
          key: _refreshTokenKey, 
          value: credential.refreshToken!
        );
      }
      
      debugPrint('Tokens salvos com sucesso');
    } catch (e, stackTrace) {
      debugPrint('Erro ao salvar tokens: $e');
      debugPrint('Stack: $stackTrace');
    }
  }

  /// Autenticação para web usando Authorization Code Flow com PKCE
  Future<oidc.Credential?> _authenticateWeb() async {
    await _initializeClient();
    if (_client == null) {
      throw Exception('Cliente não inicializado');
    }

    final issuerUri = Uri.parse(
      '${KeycloakConfig.keycloakUrl}/realms/${KeycloakConfig.realm}'
    );
    final issuer = await oidc.Issuer.discover(issuerUri);
    final client = oidc.Client(issuer, KeycloakConfig.clientId);

    // Obtém ou gera codeVerifier e state
    final codeVerifier = html.window.sessionStorage["auth_code_verifier"] ?? _randomString(50);
    final state = html.window.sessionStorage["auth_state"] ?? _randomString(20);
    final responseUrl = html.window.sessionStorage["auth_callback_response_url"];

    // Cria o flow usando authorizationCodeWithPKCE
    final flow = oidc.Flow.authorizationCodeWithPKCE(
      client,
      scopes: KeycloakConfig.scopes,
      codeVerifier: codeVerifier,
      state: state,
    );

    // Define o redirectUri - DEVE ser exatamente o mesmo configurado no Keycloak
    // Use o valor de KeycloakConfig.redirectUrlWeb para garantir correspondência
    final redirectUri = Uri.parse(KeycloakConfig.redirectUrlWeb);
    flow.redirectUri = redirectUri;
    
    debugPrint('Redirect URI configurado: $redirectUri');
    debugPrint('URL atual completa: ${html.window.location.href}');
    debugPrint('Redirect URI esperado no Keycloak: ${KeycloakConfig.redirectUrlWeb}');

    if (responseUrl != null && responseUrl.isNotEmpty) {
      // Handle callback - processa a resposta do Keycloak
      try {
        final responseUri = Uri.parse(responseUrl);
        debugPrint('Chamando flow.callback com queryParams: ${responseUri.queryParameters}');
        final credentials = await flow.callback(responseUri.queryParameters);
        debugPrint('Credenciais obtidas com sucesso');
        // Limpa os dados temporários do sessionStorage apenas após sucesso
        html.window.sessionStorage.remove("auth_code_verifier");
        html.window.sessionStorage.remove("auth_callback_response_url");
        html.window.sessionStorage.remove("auth_state");
        return credentials;
      } catch (e, stackTrace) {
        debugPrint('Erro ao processar callback no flow: $e');
        debugPrint('Stack: $stackTrace');
        // Não limpa o sessionStorage em caso de erro, para permitir retry
        rethrow;
      }
    } else {
      // Inicia autenticação - redireciona para Keycloak
      html.window.sessionStorage["auth_code_verifier"] = codeVerifier;
      html.window.sessionStorage["auth_state"] = state;
      final authorizationUrl = flow.authenticationUri;
      html.window.location.href = authorizationUrl.toString();
      throw "Authenticating...";
    }
  }

  /// Login para mobile (Android/iOS)
  Future<bool> _loginMobile() async {
    try {
      await _initializeClient();
      if (_client == null) {
        debugPrint('Cliente não inicializado');
        return false;
      }

      // No mobile (IO), cria o Authenticator com urlLancher
      // Usa dynamic para evitar verificação de tipo quando compilando para web
      Future<void> urlLancherFn(String url) async {
        if (await canLaunchUrl(Uri.parse(url))) {
          await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
        } else {
          throw 'Could not launch $url';
        }
      }
      
      // Cria authenticator usando dynamic para contornar diferenças entre IO e browser
      final authenticator = (oidc.Authenticator as dynamic)(
        _client!,
        scopes: KeycloakConfig.scopes,
        urlLancher: urlLancherFn,
      );

      final credential = await authenticator.authorize();
      await _saveTokens(credential as oidc.Credential);
      
      debugPrint('Login realizado com sucesso');
      return true;
    } catch (e, stackTrace) {
      debugPrint('Erro no login mobile: $e');
      debugPrint('Stack: $stackTrace');
      return false;
    }
  }

  /// Inicia o fluxo de login com PKCE
  Future<bool> login() async {
    try {
      if (kIsWeb) {
        // Para web, usa Authorization Code Flow com PKCE
        try {
          final credential = await _authenticateWeb();
          if (credential != null) {
            await _saveTokens(credential);
            debugPrint('Login realizado com sucesso');
            return true;
          }
          // Se retornou null, está redirecionando (throw "Authenticating...")
          return false;
        } catch (e) {
          if (e.toString().contains("Authenticating")) {
            // Redirecionamento em andamento, isso é esperado
            return true;
          }
          debugPrint('Erro no login web: $e');
          return false;
        }
      } else {
        // Para mobile, usa Authenticator do IO
        return await _loginMobile();
      }
    } catch (e, stackTrace) {
      debugPrint('Erro no login: $e');
      debugPrint('Stack: $stackTrace');
      return false;
    }
  }

  /// Processa o callback OAuth (usado principalmente na web)
  Future<bool> handleCallback() async {
    if (!kIsWeb) {
      return false; // Em mobile, o authenticator lida automaticamente
    }

    try {
      // Verifica se há um callback response URL no sessionStorage
      final responseUrl = html.window.sessionStorage["auth_callback_response_url"];
      debugPrint('handleCallback chamado. responseUrl: $responseUrl');
      
      if (responseUrl != null && responseUrl.isNotEmpty) {
        debugPrint('Processando callback URL: $responseUrl');
        // Processa o callback
        final credential = await _authenticateWeb();
        if (credential != null) {
          await _saveTokens(credential);
          debugPrint('Callback processado com sucesso - tokens salvos');
          // Limpa o sessionStorage após processar
          html.window.sessionStorage.remove("auth_callback_response_url");
          return true;
        } else {
          debugPrint('Erro: credencial retornou null após processar callback');
        }
      } else {
        // Tenta verificar diretamente na URL atual se não há sessionStorage
        final currentUrl = html.window.location.href;
        debugPrint('Verificando URL atual: $currentUrl');
        if (currentUrl.contains('?code=') || currentUrl.contains('&code=')) {
          debugPrint('Código encontrado na URL, salvando no sessionStorage');
          html.window.sessionStorage["auth_callback_response_url"] = currentUrl;
          // Limpa a URL
          html.window.history.replaceState({}, '', html.window.location.pathname);
          // Tenta processar novamente na próxima chamada
          return false; // Retorna false para tentar novamente
        }
      }
      return false;
    } catch (e, stackTrace) {
      debugPrint('Erro ao processar callback: $e');
      debugPrint('Stack: $stackTrace');
      return false;
    }
  }

  /// Retorna o token de acesso atual
  Future<String?> getAccessToken() async {
    if (_credential != null) {
      try {
        final tokenResponse = await _credential!.getTokenResponse();
        if (tokenResponse.accessToken != null) {
          return tokenResponse.accessToken;
        }
      } catch (e, stackTrace) {
        debugPrint('Erro ao obter token do credential: $e');
        debugPrint('Stack: $stackTrace');
      }
    }
    
    // Fallback: lê do storage
    return await _secureStorage.read(key: _accessTokenKey);
  }

  /// Retorna o ID token
  Future<String?> getIdToken() async {
    if (_credential != null) {
      try {
      return _credential!.idToken.toCompactSerialization();
      } catch (e, stackTrace) {
        debugPrint('Erro ao obter ID token: $e');
        debugPrint('Stack: $stackTrace');
      }
    }
    
    return await _secureStorage.read(key: _idTokenKey);
  }

  /// Carrega o credential do storage se necessário
  Future<oidc.Credential?> _loadCredentialFromStorage() async {
    if (_credential != null) {
      return _credential;
    }

    try {
      await _initializeClient();
      if (_client == null) {
        return null;
      }

      final accessToken = await _secureStorage.read(key: _accessTokenKey);
      final refreshToken = await _secureStorage.read(key: _refreshTokenKey);

      if (accessToken == null && refreshToken == null) {
        return null;
      }

      // Cria credential a partir dos tokens armazenados
      _credential = _client!.createCredential(
        accessToken: accessToken,
        refreshToken: refreshToken,
      );

      return _credential;
    } catch (e, stackTrace) {
      debugPrint('Erro ao carregar credential do storage: $e');
      debugPrint('Stack: $stackTrace');
      return null;
    }
  }

  /// Faz uma validação leve do token no servidor usando o endpoint userinfo
  /// Retorna true se o token é válido, false caso contrário
  Future<bool> _validateTokenWithServer(oidc.Credential credential) async {
    try {
      // Faz uma chamada leve ao endpoint userinfo do Keycloak
      // Se o token foi revogado ou é inválido, esta chamada falhará
      await credential.getUserInfo();
      debugPrint('_validateTokenWithServer: Token válido no servidor');
      return true;
    } catch (e) {
      debugPrint('_validateTokenWithServer: Token inválido ou revogado: $e');
      return false;
    }
  }

  /// Verifica se o usuário está autenticado
  /// Valida se o token ainda é válido e tenta renová-lo se expirado
  /// Faz validação leve no servidor para detectar tokens revogados
  Future<bool> isAuthenticated() async {
    try {
      // Tenta carregar o credential do storage se não estiver em memória
      final credential = await _loadCredentialFromStorage();
      if (credential == null) {
        debugPrint('isAuthenticated: Nenhum credential encontrado');
        return false;
      }

      // Tenta obter um token válido (isso verifica expiração e renova automaticamente)
      final tokenResponse = await credential.getTokenResponse();
      
      if (tokenResponse.accessToken == null || tokenResponse.accessToken!.isEmpty) {
        debugPrint('isAuthenticated: Token inválido ou vazio');
        // Limpa tokens inválidos
        await logout();
        return false;
      }

      // Verifica se o token está expirado
      if (tokenResponse.expiresAt != null && 
          tokenResponse.expiresAt!.isBefore(DateTime.now())) {
        debugPrint('isAuthenticated: Token expirado');
        
        // Tenta renovar se tiver refresh token
        if (credential.refreshToken != null) {
          try {
            await credential.getTokenResponse(true); // forceRefresh
            await _saveTokens(credential);
            debugPrint('isAuthenticated: Token renovado com sucesso');
            
            // Valida o novo token no servidor
            final isValid = await _validateTokenWithServer(credential);
            if (!isValid) {
              await logout();
              return false;
            }
            return true;
          } catch (e) {
            debugPrint('isAuthenticated: Erro ao renovar token: $e');
            // Se falhar ao renovar (ex: usuário removido do Keycloak), limpa tokens
            await logout();
            return false;
          }
        } else {
          // Sem refresh token, token expirado = não autenticado
          debugPrint('isAuthenticated: Token expirado sem refresh token');
          await logout();
          return false;
        }
      }

      // Token válido e não expirado - faz validação leve no servidor
      // para detectar se foi revogado mesmo sem estar expirado
      final isValid = await _validateTokenWithServer(credential);
      if (!isValid) {
        debugPrint('isAuthenticated: Token revogado no servidor');
        await logout();
        return false;
      }

      debugPrint('isAuthenticated: Usuário autenticado com token válido');
      return true;
    } catch (e, stackTrace) {
      debugPrint('isAuthenticated: Erro ao verificar autenticação: $e');
      debugPrint('Stack: $stackTrace');
      // Em caso de erro, considera como não autenticado e limpa tokens
      await logout();
      return false;
    }
  }

  /// Renova o token de acesso usando o refresh token
  Future<bool> refreshToken() async {
    try {
      if (_credential == null) {
        // Tenta carregar do storage
        final accessToken = await _secureStorage.read(key: _accessTokenKey);
        if (accessToken == null || _client == null) {
          return false;
        }
        _credential = _client!.createCredential(accessToken: accessToken);
      }

      // Verifica se o token está expirado e renova se necessário
      await _credential!.getTokenResponse(true); // forceRefresh = true
      await _saveTokens(_credential!);
      
      debugPrint('Token renovado com sucesso');
      return true;
    } catch (e, stackTrace) {
      debugPrint('Erro ao renovar token: $e');
      debugPrint('Stack: $stackTrace');
      return false;
    }
  }

  /// Faz logout
  Future<void> logout() async {
    try {
      // Limpa tokens
      await _secureStorage.delete(key: _accessTokenKey);
      await _secureStorage.delete(key: _refreshTokenKey);
      await _secureStorage.delete(key: _idTokenKey);
      
      // Limpa sessionStorage na web
      if (kIsWeb) {
        html.window.sessionStorage.remove("auth_code_verifier");
        html.window.sessionStorage.remove("auth_callback_response_url");
        html.window.sessionStorage.remove("auth_state");
      }
      
      _credential = null;
      _client = null;
      
      debugPrint('Logout realizado');
    } catch (e) {
      debugPrint('Erro no logout: $e');
    }
  }

  /// Obtém informações do usuário
  Future<Map<String, dynamic>?> getUserInfo() async {
    try {
      if (_credential == null) {
        final accessToken = await getAccessToken();
        if (accessToken == null || _client == null) return null;
        _credential = _client!.createCredential(accessToken: accessToken);
      }

      final userInfo = await _credential!.getUserInfo();
      return {
        'name': userInfo.name,
        'email': userInfo.email,
        'sub': userInfo.subject,
        'picture': userInfo.picture,
      };
    } catch (e) {
      debugPrint('Erro ao obter informações do usuário: $e');
      return null;
    }
  }
}
