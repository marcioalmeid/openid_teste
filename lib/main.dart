import 'package:flutter/material.dart';
import 'services/auth_service_openid.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Keycloak Auth Test',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const AuthWrapper(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final AuthServiceOpenId _authService = AuthServiceOpenId();
  bool _isLoading = true;
  bool _isAuthenticated = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      // Na web, verifica se há um callback OAuth para processar
      debugPrint('_initialize: Verificando callback...');
      final callbackProcessed = await _authService.handleCallback();
      debugPrint('_initialize: Callback processado: $callbackProcessed');
      
      // Sempre verifica o status após tentar processar callback
      await _checkAuthStatus();
      
      // Se ainda não processou o callback mas há código na URL, tenta novamente
      if (!callbackProcessed) {
        // Aguarda um pouco e tenta novamente (caso o sessionStorage ainda não esteja pronto)
        await Future.delayed(const Duration(milliseconds: 500));
        final retryCallback = await _authService.handleCallback();
        if (retryCallback) {
          await _checkAuthStatus();
        }
      }
    } catch (e, stackTrace) {
      debugPrint('Erro na inicialização: $e');
      debugPrint('Stack: $stackTrace');
      // Garante que o loading seja desativado mesmo em caso de erro
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isAuthenticated = false;
        });
      }
    }
  }

  Future<void> _checkAuthStatus() async {
    try {
      final isAuth = await _authService.isAuthenticated();
      debugPrint('_checkAuthStatus: isAuthenticated = $isAuth');
      if (mounted) {
        setState(() {
          _isAuthenticated = isAuth;
          _isLoading = false;
        });
        debugPrint('_checkAuthStatus: Estado atualizado - _isAuthenticated = $_isAuthenticated, _isLoading = $_isLoading');
      }
    } catch (e) {
      debugPrint('Erro ao verificar status de autenticação: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isAuthenticated = false;
        });
      }
    }
  }

  void _handleAuthChange() {
    _checkAuthStatus();
  }


  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // Retorna a tela apropriada baseado no estado de autenticação
    if (_isAuthenticated) {
      return HomeScreen(onAuthChange: _handleAuthChange);
    } else {
      return LoginScreen(onAuthChange: _handleAuthChange);
    }
  }
}
