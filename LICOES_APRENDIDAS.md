# Lições Aprendidas - Integração Keycloak com Flutter

Este documento descreve as principais lições aprendidas durante a implementação da autenticação Keycloak com PKCE usando Flutter, especialmente para aplicações web, Android e iOS.

## 📋 Índice

1. [Escolha da Biblioteca](#escolha-da-biblioteca)
2. [Implementação Web vs Mobile](#implementação-web-vs-mobile)
3. [PKCE e Authorization Code Flow](#pkce-e-authorization-code-flow)
4. [Gerenciamento de Tokens](#gerenciamento-de-tokens)
5. [Validação de Autenticação](#validação-de-autenticação)
6. [Configuração do Keycloak](#configuração-do-keycloak)
7. [Troubleshooting Comum](#troubleshooting-comum)
8. [Boas Práticas](#boas-práticas)

---

## Escolha da Biblioteca

### ❌ Problema Inicial
Inicialmente tentamos usar `flutter_appauth`, que é excelente para mobile (Android/iOS), mas **não funciona na web**.

### ✅ Solução
Utilizamos `openid_client` que oferece suporte completo para todas as plataformas:
- **Web**: Usa `openid_client_browser.dart` com `Flow.authorizationCodeWithPKCE`
- **Mobile**: Usa `openid_client_io.dart` com `Authenticator`

### 📝 Lição Aprendida
- Sempre verificar compatibilidade cross-platform antes de escolher uma biblioteca
- `openid_client` é a melhor opção para aplicações Flutter multi-plataforma com Keycloak
- Usar imports condicionais para plataformas específicas:
  ```dart
  import 'package:openid_client/openid_client_io.dart' 
    if (dart.library.html) 'package:openid_client/openid_client_browser.dart' as oidc;
  ```

---

## Implementação Web vs Mobile

### 🔑 Diferenças Críticas

#### **Web (Browser)**
- Usa `Flow.authorizationCodeWithPKCE` diretamente
- Gerencia estado via `window.sessionStorage` (codeVerifier, state, callback URL)
- Requer captura do callback via JavaScript no `index.html`
- Redireciona o navegador inteiro (`window.location.href`)

#### **Mobile (iOS/Android)**
- Usa `Authenticator` com `urlLancher`
- Deep linking automático para capturar callback
- Não requer gerenciamento manual de sessionStorage
- Usa `url_launcher` para abrir navegador externo

### 📝 Lição Aprendida
- **Sempre separar a lógica de autenticação por plataforma**
- Criar métodos específicos: `_authenticateWeb()` e `_loginMobile()`
- A web precisa de tratamento especial no `index.html` para capturar callbacks
- O redirect URI deve ser exatamente o mesmo configurado no Keycloak

---

## PKCE e Authorization Code Flow

### 🔐 O que é PKCE?
**Proof Key for Code Exchange** - extensão do OAuth 2.0 para segurança em clientes públicos (SPAs e apps mobile).

### ✅ Por que usar PKCE?
1. **Segurança**: Previne ataques de code interception
2. **Recomendado**: OAuth 2.1 recomenda PKCE para todos os fluxos
3. **Keycloak**: Suporta PKCE nativamente

### 📝 Implementação
```dart
// Gera codeVerifier e codeChallenge automaticamente
final flow = oidc.Flow.authorizationCodeWithPKCE(
  client,
  scopes: KeycloakConfig.scopes,
  codeVerifier: codeVerifier,
  state: state,
);
```

### 📝 Lição Aprendida
- **Sempre use PKCE** para aplicações web e mobile
- Gere `codeVerifier` seguro (50+ caracteres aleatórios)
- Armazene `codeVerifier` no sessionStorage apenas durante o fluxo
- Limpe dados sensíveis do sessionStorage após uso

---

## Gerenciamento de Tokens

### 🎯 Estrutura do Credential

O `openid_client` usa uma estrutura diferente de outras bibliotecas:

```dart
// ❌ ERRADO - Não existe tokenSet
credential.tokenSet.accessToken

// ✅ CORRETO
final tokenResponse = await credential.getTokenResponse();
tokenResponse.accessToken  // Access token
credential.idToken          // ID token (getter direto)
credential.refreshToken     // Refresh token (getter direto)
```

### 📝 Lição Aprendida
- **Nunca assumir a estrutura da API** - sempre verificar a documentação
- `Credential` não tem `tokenSet`, use `getTokenResponse()` para access token
- `getTokenResponse()` verifica expiração automaticamente e renova se necessário
- Sempre use `toCompactSerialization()` para converter `IdToken` em string

---

## Validação de Autenticação

### ⚠️ Problema Comum
Aplicação considera usuário autenticado mesmo após remoção da sessão no Keycloak, porque apenas verifica se existe um token armazenado.

### ✅ Solução
Implementar validação completa:

```dart
Future<bool> isAuthenticated() async {
  // 1. Carrega credential do storage
  final credential = await _loadCredentialFromStorage();
  if (credential == null) return false;

  // 2. Verifica token válido (verifica expiração automaticamente)
  final tokenResponse = await credential.getTokenResponse();
  
  // 3. Se expirado, tenta renovar
  if (tokenResponse.expiresAt?.isBefore(DateTime.now()) == true) {
    try {
      await credential.getTokenResponse(true); // forceRefresh
      await _saveTokens(credential);
      return true;
    } catch (e) {
      // Se falhar (ex: usuário removido), limpa tokens
      await logout();
      return false;
    }
  }
单价
  return tokenResponse.accessToken != null;
}
```

### 📝 Lição Aprendida
- **Nunca confiar apenas na existência do token** - sempre validar expiração
- Tentar renovar automaticamente se expirado
- Se renovação falhar, limpar tokens e desautenticar
- Tokens revogados no Keycloak só serão detectados quando tentar renovar ou usar o token

---

## Configuração do Keycloak

### 🔧 Configurações Críticas

#### **Redirect URIs**
- **Web**: `http://localhost:3000/callback` (exatamente como configurado)
- **Mobile**: `com.example.app://callback` (deep link)
- ⚠️ **O redirect URI deve ser EXATAMENTE igual** ao configurado no Keycloak

#### **Web Origins**
- Adicionar: `http://localhost:3000` (sem trailing slash)
- Necessário para permitir requisições CORS

#### **Client Settings**
- Access Type: `public` (para PKCE)
- Standard Flow: Habilitado
- Direct Access Grants: Opcional (depende do caso)
- Valid Redirect URIs: Adicionar todos os URIs possíveis

### 📝 Lição Aprendida
- **Erro "Invalid parameter: redirect_uri"** = URI não corresponde exatamente
- Sempre usar o valor de `KeycloakConfig.redirectUrlWeb` no código (não construir dinamicamente)
- Testar com diferentes portas (Flutter pode usar portas aleatórias)
- Configurar wildcards se necessário: `http://localhost:*/*`

---

## Troubleshooting Comum

### 1. "Invalid parameter: redirect_uri"

**Causa**: URI não corresponde exatamente ao configurado no Keycloak

**Solução**:
```dart
// ✅ CORRETO - Usa valor fixo do config
final redirectUri = Uri.parse(KeycloakConfig.redirectUrlWeb);

// ❌ ERRADO - Constrói dinamicamente (pode gerar porta duplicada)
final redirectUri = Uri.parse('${currentUrl.origin}${currentUrl.pathname}');
```

### 2. "Page stays blank after login"

**Causa**: Callback não está sendo processado corretamente

**Solução**:
- Verificar JavaScript no `index.html` capturando callback
- Verificar `handleCallback()` sendo chamado no `initState()`
- Verificar `sessionStorage` sendo limpo apenas após sucesso

### 3. "NoSuchMethodError: 'tokenSet'"

**Causa**: Tentando acessar propriedade inexistente

**Solução**:
```dart
// ✅ CORRETO
final tokenResponse = await credential.getTokenResponse();
final accessToken = tokenResponse.accessToken;

// ❌ ERRADO
credential.tokenSet.accessToken
```

### 4. "Token still valid after user removed from Keycloak"

**Causa**: Apenas verifica existência do token, não valida com servidor

**Solução**: Implementar validação de expiração e renovação (ver seção anterior)

### 5. "Port duplicated in URL" (ex: `http://0.0.0.0:3000:3000`)

**Causa**: Construção incorreta de URL

**Solução**:
```dart
// ✅ CORRETO - Usa origin (já inclui porta corretamente)
final redirectUri = Uri.parse('${currentUrl.origin}${currentUrl.pathname}');

// Ou melhor ainda, usar valor fixo do config
final redirectUri = Uri.parse(KeycloakConfig.redirectUrlWeb);
```

---

## Boas Práticas

### 🔒 Segurança

1. **Sempre use PKCE** para clientes públicos
2. **Nunca armazene secrets** no código do cliente
3. **Limpe sessionStorage** após uso de dados sensíveis
4. **Valide tokens** regularmente, não apenas na inicialização
5. **Use HTTPS** em produção (Keycloak exige para alguns fluxos)

### 📱 Cross-Platform

1. **Separe lógica por plataforma** quando necessário
2. **Use imports condicionais** para código específico de plataforma
3. **Teste em todas as plataformas** antes de considerar completo
4. **Mantenha UX consistente** entre plataformas

### 🏗️ Arquitetura

1. **Service Pattern**: Centralize lógica de autenticação em um serviço
2. **Singleton**: Use pattern singleton para o serviço de autenticação
3. **Error Handling**: Sempre trate erros e forneça feedback ao usuário
4. **Logging**: Use `debugPrint` extensivamente para debugging

### 💾 Armazenamento

1. **Use flutter_secure_storage** para tokens sensíveis
2. **SessionStorage** apenas para dados temporários do fluxo OAuth
3. **Limpe dados** após logout ou falha de autenticação
4. **Não armazene** refresh tokens em localStorage (menos seguro)

### 🔄 Refresh Tokens

1. **Renove automaticamente** quando expirado
2. **Trate falhas de renovação** (usuário removido, token revogado)
3. **Implemente backoff** para evitar loops infinitos
4. **Força renovação** quando necessário com `getTokenResponse(true)`

---

## Recursos Úteis

### Documentação
- [openid_client package](https://pub.dev/packages/openid_client)
- [Keycloak Documentation](https://www.keycloak.org/documentation)
- [OAuth 2.1 Specification](https://oauth.net/2.1/)
- [PKCE RFC 7636](https://tools.ietf.org/html/rfc7636)

### Tutoriais
- [Medium: Keycloak Integration for Flutter Web](https://medium.com/@rangika123.kanchana/keycloak-integration-for-flutter-web-using-openid-client-with-authorization-code-flow-489afeac6e9f)

### Ferramentas
- [Keycloak Admin Console](http://localhost:8080/admin)
- [OAuth Playground](https://oauthplayground.com/)
- Browser DevTools (Network tab, Application > Storage)

---

## Checklist de Implementação

### ✅ Configuração Keycloak
- [ ] Cliente criado com Access Type "public"
- [ ] Valid Redirect URIs configurado corretamente
- [ ] Web Origins configurado
- [ ] Standard Flow habilitado

### ✅ Implementação Flutter
- [ ] `openid_client` adicionado ao `pubspec.yaml`
- [ ] Configuração centralizada em `KeycloakConfig`
- [ ] Service de autenticação implementado
- [ ] Lógica separada para web e mobile
- [ ] Callback handler implementado
- [ ] Validação de autenticação implementada
- [ ] Refresh token implementado
- [ ] Logout implementado

### ✅ Web Específico
- [ ] JavaScript no `index.html` para capturar callback
- [ ] SessionStorage usado corretamente
- [ ] URL limpa após callback

### ✅ Mobile Específico
- [ ] Deep linking configurado (AndroidManifest.xml, Info.plist)
- [ ] URL launcher configurado

### ✅ Testes
- [ ] Login funciona em web
- [ ] Login funciona em mobile
- [ ] Logout funciona
- [ ] Refresh token funciona
- [ ] Validação detecta tokens inválidos
- [ ] Tokens são limpos após logout

---

## Conclusão

A integração do Keycloak com Flutter usando `openid_client` é robusta e funciona bem em todas as plataformas, mas requer atenção a detalhes específicos de cada plataforma. As principais lições são:

1. **Escolha a biblioteca certa** - `openid_client` para cross-platform
2. **Separe lógica por plataforma** - Web e mobile têm necessidades diferentes
3. **Valide tokens adequadamente** - Não apenas verifique existência
4. **Configure Keycloak corretamente** - URIs devem ser exatos
5. **Trate erros graciosamente** - Sempre limpe estado em caso de falha

Com essas práticas, você terá uma implementação segura e funcional em todas as plataformas! 🚀

