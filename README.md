# openid_teste

A new Flutter project with Keycloak authentication.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Keycloak Setup

### Executando Keycloak com Docker Compose

A configuração usa um Dockerfile customizado que já vem tudo configurado. Simplesmente execute:

```bash
# Construir e iniciar os serviços (Keycloak + PostgreSQL)
docker-compose up -d --build

# Ver os logs
docker-compose logs -f keycloak

# Parar os serviços
docker-compose down

# Parar e remover volumes (apaga os dados)
docker-compose down -v
```

### Acessando o Keycloak

Após iniciar os serviços, aguarde 60-90 segundos para o Keycloak inicializar completamente:

```bash
# Acompanhar a inicialização
docker-compose logs -f keycloak
```

Quando aparecer `Keycloak x.x.x started` nos logs, o Keycloak estará pronto.

**Acesse:**
- **URL**: http://localhost:8080
- **Console de Administração**: http://localhost:8080/admin
- **Credenciais** (primeira vez):
  - Na tela de criação inicial, use:
  - Username: `admin`
  - Password: `admin`

**Nota:** A configuração já vem com `--hostname-strict=false`, então você pode acessar de qualquer origem sem problemas de "Local access required".

### Configuração no App

Atualize o arquivo `lib/config/keycloak_config.dart` com:
- `keycloakUrl`: `http://localhost:8080` (ou use `http://10.0.2.2:8080` para Android Emulator)
- `realm`: nome do realm criado no Keycloak
- `clientId`: ID do cliente configurado no Keycloak
