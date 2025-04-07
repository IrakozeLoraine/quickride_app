import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:quickride/data/providers/auth_provider.dart';
import 'package:quickride/routes/app_router.dart';
import 'package:quickride/presentation/widgets/loading_overlay.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:quickride/utils/app_utils.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  
  bool _isProcessing = false;
  bool _obscurePassword = true;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  
  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleEmailPasswordLogin() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() {
        _isProcessing = true;
      });

      try {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        
        final success = await authProvider.signInWithEmailPassword(
          _emailController.text.trim(),
          _passwordController.text,
          context
        );
        
        if (success) {
          _navigateAfterLogin();
        } else {
          if (mounted) {
            final localizations = AppLocalizations.of(context)!;
            showToast(context, authProvider.errorMessage ?? localizations.loginFailed, null, true);
          }
        }
      } catch (e) {
        if (mounted) {
          showToast(context, e.toString(), null, true);
        }
      } finally {
        if (mounted) {
          setState(() {
            _isProcessing = false;
          });
        }
      }
    }
  }

  void _navigateAfterLogin() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.isRider) {
      Navigator.of(context).pushReplacementNamed(AppRouter.riderHome);
    } else {
      Navigator.of(context).pushReplacementNamed(AppRouter.home);
    }
  }

  void _navigateToForgotPassword() {
    Navigator.of(context).pushNamed(AppRouter.forgotPassword);
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    
    return LoadingOverlay(
      isLoading: _isProcessing,
      child: Scaffold(
        key: _scaffoldKey,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 40),
                  
                  // App Logo
                  Center(
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        borderRadius: BorderRadius.circular(50),
                      ),
                      child: const Icon(
                        Icons.motorcycle,
                        size: 60,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // App Name
                  Text(
                    localizations.appTitle,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.displayMedium,
                  ),
                  const SizedBox(height: 8),
                  
                  // Welcome Message
                  Text(
                    localizations.welcomeMessage,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 40),
                  
                  // Login Title
                  Text(
                    localizations.loginTitle,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 24),
                  
                  // Email Field
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: localizations.email,
                      prefixIcon: Icon(Icons.email_outlined),
                      hintText: 'your.email@example.com',
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return localizations.enterEmail;
                      }
                      // Simple email validation
                      final emailRegExp = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
                      if (!emailRegExp.hasMatch(value)) {
                        return localizations.enterValidEmail;
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // Password Field
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: localizations.password,
                      prefixIcon: const Icon(Icons.key_outlined),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return localizations.enterPassword;
                      }
                      return null;
                    },
                  ),
                  
                  // Forgot Password
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _navigateToForgotPassword,
                      child: Text('${localizations.forgotPassword}?'),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Login Button
                  ElevatedButton(
                    onPressed: _handleEmailPasswordLogin,
                    child: Text(localizations.loginButton),
                  ),
                  const SizedBox(height: 16),
                  
                  // Register Link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(localizations.noAccount),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pushNamed(AppRouter.userTypeSelection);
                        },
                        child: Text(localizations.signUp),
                      ),
                    ],
                  ),
                  
                  // Language Selection
                  Center(
                    child: TextButton.icon(
                      icon: const Icon(Icons.language_outlined),
                      label: Text(localizations.language),
                      onPressed: () {
                        Navigator.of(context).pushNamed(AppRouter.languageSelection);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
