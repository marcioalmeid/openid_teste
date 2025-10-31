# Configuração do Keycloak para Flutter
 
Este guia explica passo a passo como configurar o Keycloak para funcionar com o aplicativo Flutter usando PKCE (Proof Key for Code Exchange).

## Índice

1. [Configuração no Keycloak](#1-configuração-no-keycloak)
2. [Configuração no Aplicativo Flutter](#2-configuração-no-aplicativo-flutter)
3. [Configuração de Redirect URIs por Plataforma](#3-configuração-de-redirect-uris-por-plataforma)
4. [Testando a Aplicação](#4-testando-a-aplicação)
5. [Troubleshooting](#5-troubleshooting)

---

## 1. Configuração no Keycloak

### 1.1 Criar um Cliente

1. Acesse o console administrativo do Keycloak
2. Selecione o realm desejado (ou crie um novo realm)
3. No menu lateral, vá até **Clients**
4. Clique em **Create client** ou **Criar cliente**

### 1.2 Configuração Inicial do Cliente

Na tela de criação do cliente:

1. **Client type**: Selecione `OpenID Connect`
2. Clique em **Next**

### 1.3 Configuração Geral

Configure os seguintes campos:

- **Client ID**: Escolha um identificador único (ex: `flutter-app`)
- **Name**: Nome descritivo do cliente (opcional)
- Clique em **Next**

### 1.4 Configuração de Capacidades

Configure as opções de capacidade:

- **Client authentication**: Desmarque esta opção (cliente público)
- **Authorization**: Pode deixar desmarcado (não necessário para PKCE básico)
- **Authentication flow**: Marque **Standard flow**
- **Direct access grants**: Pode deixar desmarcado
- Clique em **Next**

### 1.5 Configuração de Login

Configure as URLs de redirecionamento:

1. **Valid redirect URIs**: Adicione os seguintes URIs (um por linha):
   ```
   http://localhost:3000/callback
   com.example.openid_teste://callback
   ```

2. **Valid post logout redirect URIs**: Adicione os mesmos URIs:
   ```
   http://localhost:3000/callback
   com.example.openid_teste://callback
   ```

3. **Web origins**: Para desenvolvimento, adicione:
   ```
   http://localhost:3000
   *
   ```
   (O asterisco permite todos os origins, mas use com cuidado em produção)

4. Clique em **Save**

### 1.6 Configuração Avançada

Após salvar o cliente, vá para a aba **Advanced settings**:

- **Proof Key for Code Exchange Code Challenge Method**: Selecione `S256` (recomendado)
- **Access Token Lifespan**: Configure conforme necessário (padrão: 5 minutos)
- **Client Session Idle Timeout**: Configure conforme necessário

### 1.7 Verificar Configurações Finais

Na aba **Settings**, verifique:

- ✓ **Access Type**: Deve estar como `public`
- ✓ **Standard Flow Enabled**: Deve estar habilitado
- ✓ **Valid Redirect URIs**: Deve conter os URIs configurados

---

## 2. Configuração no Aplicativo Flutter

### 2.1 Editar Arquivo de Configuração

Edite o arquivo `lib/config/keycloak_config.dart` e substitua os valores de exemplo pelas suas credenciais:

```dart
class KeycloakConfig {
  // URL do servidor Keycloak (sem /auth no final)
  static const String keycloakUrl = 'https://seu-servidor-keycloak.com';
  
  // Nome do realm configurado no Keycloak
  static const String realm = 'seu-realm';
  
  // Client ID criado no Keycloak
  static const String clientId = 'flutter-app';
  
  // ... resto da configuração permanece igual
}
```

### 2.2 Exemplo Completo

```dart
class KeycloakConfig {
  static const String keycloakUrl = 'https://keycloak.example.com';
  static const String realm = 'myrealm';
  static const String clientId = 'flutter-app';
  
  // Redirect URIs (já configurados corretamente)
  static const String redirectUrlMobile = 'com.example.openid_teste://callback';
  static const String redirectUrlWeb = 'http://localhost:3000/callback';
  
  // ... restante do código
}
```

### 2.3 Instalar Dependências

Execute no terminal:

```bash
flutter pub get
```

---

## 3. Configuração de Redirect URIs por Plataforma

### 3.1 Android

O redirect URI já está configurado no projeto:

- **Arquivo**: `android/app/src/main/AndroidManifest.xml`
- **URI configurado**: `com.example.openid_teste://callback`

**Se você mudar o `applicationId` no Android:**

1. Edite `android/app/build.gradle.kts`:
   ```kotlin
   applicationId = "seu.novo.pacote"
   ```

2. Atualize `AndroidManifest.xml`:
   ```xml
   <data android:scheme="seu.novo.pacote" android:host="callback" />
   ```

3. Atualize `lib/config/keycloak_config.dart`:
   ```dart
   static const String redirectUrlMobile = 'seu.novo.pacote://callback';
   ```

4. Atualize o **Valid Redirect URIs** no Keycloak com o novo URI

### 3.2 iOS

O redirect URI já está configurado no projeto:

- **Arquivo**: `ios/Runner/Info.plist`
- **URI configurado**: `com.example.openid_teste://callback`

**Se você mudar o Bundle Identifier:**

1. No Xcode, edite o **Bundle Identifier** no projeto
2. Atualize `ios/Runner/Info.plist`:
   ```xml
   <string>seu.novo.bundle.id</string>
   ```
   
3. Atualize `lib/config/keycloak_config.dart`:
   ```dart
   static const String redirectUrlMobile = 'seu.novo.bundle.id://callback';
   ```

4. Atualize o **Valid Redirect URIs** no Keycloak com o novo URI

### 3.3 Web

Para desenvolvimento local:
- **URI padrão**: `http://localhost:3000/callback`

**Para produção:**

1. Atualize `lib/config/keycloak_config.dart`:
   ```dart
   static const String redirectUrlWeb = 'https://seu-dominio.com/callback';
   ```

2. Adicione o URI no Keycloak em **Valid Redirect URIs**:
   ```
   https://seu-dominio.com/callback
   ```

3. Atualize `web/index.html` se necessário para o domínio correto

---

## 4. Testando a Aplicação

### 4.1 Verificação Pré-Teste

Antes de testar, verifique:

- [ ] Keycloak está acessível e rodando
- [ ] Realm foi criado no Keycloak
- [ ] Cliente foi criado e configurado corretamente
- [ ] `keycloak_config.dart` foi atualizado com suas credenciais
- [ ] Dependências foram instaladas (`flutter pub get`)

### 4.2 Testar no Android

```bash
flutter run -d android
```

1. O aplicativo deve abrir na tela de login
2. Clique em "Entrar com Keycloak"
3. O navegador/WebView deve abrir com a tela de login do Keycloak
4. Faça login com suas credenciais
5. Você deve ser redirecionado de volta para o app
6. A tela deve mudar para a tela Home mostrando os tokens

### 4.3 Testar no iOS

```bash
flutter run -d ios
```

1. Siga os mesmos passos do Android
2. O Safari ou WebView deve abrir para o login
3. Após o login, o app deve receber o callback

### 4.4 Testar na Web

```bash
flutter run -d chrome
```

1. O navegador deve abrir
2. Clique em "Entrar com Keycloak"
3. Uma nova aba/janela deve abrir para o login
4. Após o login, você deve ser redirecionado de volta

**Nota para Web**: Certifique-se de que o Keycloak permite requests do origin `http://localhost:3000` na configuração **Web origins**.

---

## 5. Troubleshooting

### 5.1 Erro: "Invalid redirect URI"

**Problema**: O redirect URI usado não está configurado no Keycloak.

**Solução**:
1. Verifique o URI exato no erro
2. Adicione o URI exato em **Valid Redirect URIs** no Keycloak
3. Certifique-se de que não há espaços ou caracteres extras

### 5.2 Erro: "Client authentication failed"

**Problema**: O cliente não está configurado como público.

**Solução**:
1. No Keycloak, vá até o cliente
2. Na aba **Settings**, verifique que **Access Type** está como `public`
3. Salve as alterações

### 5.3 Erro: "Standard flow is not enabled"

**Problema**: O fluxo padrão não está habilitado.

**Solução**:
1. No Keycloak, vá até o cliente
2. Na aba **Settings**, habilite **Standard Flow Enabled**
3. Salve as alterações

### 5.4 Tokens não são salvos

**Problema**: O `flutter_secure_storage` pode ter problemas de permissão.

**Solução Android**:
- Verifique permissões no `AndroidManifest.xml`
- O `flutter_secure_storage` geralmente funciona sem permissões adicionais

**Solução iOS**:
- Certifique-se de ter um **Keychain Sharing** habilitado (geralmente não necessário)
- Teste em um dispositivo real se estiver tendo problemas no simulador

### 5.5 Deep link não funciona (Android/iOS)

**Problema**: O deep link não está redirecionando para o app.

**Solução Android**:
1. Verifique o `intent-filter` no `AndroidManifest.xml`
2. Certifique-se de que o `scheme` está correto
3. Limpe e reconstrua o app: `flutter clean && flutter run`

**Solução iOS**:
1. Verifique o `CFBundleURLSchemes` no `Info.plist`
2. Certifique-se de que o valor está correto
3. Limpe e reconstrua o app: `flutter clean && flutter run`

### 5.6 Web não funciona

**Problema**: O login na web não está funcionando.

**Solução**:
1. Verifique que o `redirectUrlWeb` está correto
2. Verifique que o URI está configurado no Keycloak
3. Verifique a configuração de **Web origins** no Keycloak
4. Certifique-se de que não há problemas de CORS

---

## Segurança

### Boas Práticas

- ✓ Os tokens são armazenados de forma segura usando `flutter_secure_storage` (criptografado)
- ✓ PKCE é habilitado automaticamente pelo `flutter_appauth`
- ✓ Tokens nunca são expostos em logs ou código
- ✓ O refresh token é usado automaticamente para renovar tokens expirados
- ✓ Use HTTPS em produção para o servidor Keycloak
- ✓ Configure corretamente os **Web origins** para evitar ataques CSRF
- ✓ Use um Client ID diferente para desenvolvimento e produção
- ✓ Configure adequadamente os tempos de expiração dos tokens

### Configurações Recomendadas

No Keycloak, para produção:
- **Access Token Lifespan**: 5-15 minutos
- **SSO Session Idle**: 30 minutos
- **SSO Session Max**: 8 horas
- Use **Web origins** específicos ao invés de `*`

---

## Recursos Adicionais

- [Documentação do Keycloak](https://www.keycloak.org/documentation)
- [Documentação do flutter_appauth](https://pub.dev/packages/flutter_appauth)
- [OAuth 2.0 PKCE Flow](https://oauth.net/2/pkce/)
- [OpenID Connect](https://openid.net/connect/)

---

## Suporte

Se encontrar problemas não listados aqui:

1. Verifique os logs do Keycloak
2. Verifique os logs do Flutter (`flutter run -v`)
3. Verifique a documentação oficial do flutter_appauth
4. Certifique-se de que todas as configurações estão corretas
