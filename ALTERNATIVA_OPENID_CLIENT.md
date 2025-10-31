# Alternativa usando openid_client

Esta é uma implementação alternativa usando o pacote [openid_client](https://pub.dev/packages/openid_client), que é uma biblioteca especializada para OpenID Connect e suporta nativamente web, Android e iOS.

## Vantagens do openid_client

- ✅ Suporte nativo para web, Android e iOS
- ✅ Implementação completa do protocolo OpenID Connect
- ✅ Descoberta automática de metadata (Discovery)
- ✅ Validação de tokens integrada
- ✅ Suporte a PKCE nativo
- ✅ Bibliotecas mais testadas e mantidas

## Instalação

As dependências já foram adicionadas ao `pubspec.yaml`:

```yaml
openid_client: ^0.4.9+1
url_launcher: ^6.3.1
```

Execute:

```bash
flutter pub get
```

## Como Usar

### Opção 1: Usar diretamente (Mais Simples)

Para usar a implementação com `openid_client`, você pode substituir temporariamente no seu código:

```dart
import 'services/auth_service_openid.dart';

// Use AuthServiceOpenId ao invés de AuthService
final authService = AuthServiceOpenId();
```

### Opção 2: Criar um Wrapper Unificado

O arquivo `lib/services/auth_service_wrapper.dart` já foi criado e permite alternar entre implementações.

## Implementação

O arquivo `lib/services/auth_service_openid.dart` contém uma implementação completa usando `openid_client` que:

1. **Descobre automaticamente o Issuer**: Usa a discovery URL do Keycloak
2. **Cria o cliente**: Configurado para cliente público (PKCE)
3. **Autentica**: Usa o `Authenticator` que gerencia todo o fluxo
4. **Gerencia tokens**: Armazena e renova tokens automaticamente
5. **Obtém informações do usuário**: Método `getUserInfo()` incluído

## Funcionalidades

### Métodos Disponíveis

- `login()` - Inicia o fluxo de autenticação
- `handleCallback()` - Processa callback OAuth (web)
- `isAuthenticated()` - Verifica se está autenticado
- `getAccessToken()` - Obtém o token de acesso
- `getIdToken()` - Obtém o ID token
- `refreshToken()` - Renova o token
- `logout()` - Faz logout
- `getUserInfo()` - Obtém informações do usuário

### Diferenças da Implementação Manual

1. **Web**: O `openid_client_browser.dart` gerencia automaticamente o redirect
2. **Mobile**: O `openid_client_io.dart` usa `url_launcher` para abrir o browser
3. **PKCE**: Implementado automaticamente pelo pacote
4. **Validação**: Tokens são validados automaticamente

## Exemplo de Uso

```dart
import 'services/auth_service_openid.dart';

final authService = AuthServiceOpenId();

// Login
final success = await authService.login();

// Verificar autenticação
if (await authService.isAuthenticated()) {
  // Obter informações do usuário
  final userInfo = await authService.getUserInfo();
  print('Usuário: ${userInfo?['name']}');
}

// Logout
await authService.logout();
```

## Configuração

A configuração continua usando o mesmo `KeycloakConfig`:

```dart
class KeycloakConfig {
  static const String keycloakUrl = 'http://localhost:8080';
  static const String realm = 'master';
  static const String clientId = 'flutter-app';
  // ...
}
```

## Comparação

| Feature | flutter_appauth + manual | openid_client |
|---------|-------------------------|---------------|
| Web | Manual (auth_service_web.dart) | Nativo |
| Android | flutter_appauth | Nativo |
| iOS | flutter_appauth | Nativo |
| PKCE | Manual | Automático |
| Discovery | Manual | Automático |
| Validação de tokens | Manual | Automático |
| Refresh token | Manual | Automático |
| UserInfo | Manual | Automático |

## Recomendação

O `openid_client` é recomendado porque:
- É mais completo e testado
- Suporta nativamente todas as plataformas
- Tem menos código para manter
- Segue melhor as especificações OpenID Connect

## Referências

- [Documentação do openid_client](https://pub.dev/packages/openid_client)
- [Exemplos no GitHub](https://github.com/appsup-dart/openid_client)

