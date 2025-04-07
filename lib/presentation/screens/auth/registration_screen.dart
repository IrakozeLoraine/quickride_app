import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:quickride/data/models/user_model.dart';
import 'package:quickride/data/providers/auth_provider.dart';
import 'package:quickride/presentation/widgets/loading_overlay.dart';
import 'package:quickride/routes/app_router.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:quickride/utils/app_utils.dart';

class RegistrationScreen extends StatefulWidget {
  final UserType userType;

  const RegistrationScreen({
    Key? key,
    required this.userType,
  }) : super(key: key);

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  bool _isProcessing = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() {
        _isProcessing = true;
      });

      try {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final success = await authProvider.registerWithEmailPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          name: _nameController.text.trim(),
          phone: _phoneController.text.trim(),
          userType: widget.userType,
          context: context,
        );
        final localizations = AppLocalizations.of(context)!;

        if (success) {
          if (widget.userType == UserType.rider) {
            // Navigate to rider registration screen
            Navigator.of(context).pushReplacementNamed(AppRouter.riderRegistration);
          } else {
            // Navigate to home screen
            Navigator.of(context).pushReplacementNamed(AppRouter.home);
          }
        } else {
          showToast(context, authProvider.errorMessage ?? localizations.registrationFailed, null, true);
        }
      } catch (e) {
        showToast(context, e.toString(), null, true);
      } finally {
        if (mounted) {
          setState(() {
            _isProcessing = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    
    return LoadingOverlay(
      isLoading: _isProcessing,
      child: Scaffold(
        key: _scaffoldKey,
        appBar: AppBar(
          title: Text(localizations.registerTitle),
          elevation: 0,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 24),
                  
                  // Title
                  Text(
                    localizations.createYourAccount,
                    style: Theme.of(context).textTheme.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  
                  // Subtitle
                  Text(
                    widget.userType == UserType.rider
                        ? localizations.registerAsRider
                        : localizations.registerAsPassenger,
                    style: Theme.of(context).textTheme.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  
                  // Name Field
                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: localizations.name,
                      prefixIcon: const Icon(Icons.person_outline),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return localizations.enterName;
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // Phone Field
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: localizations.phoneNumber,
                      prefixIcon: const Icon(Icons.phone_outlined),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return localizations.enterPhoneNumber;
                      }
                      // Simple phone number validation
                      final phoneRegExp = RegExp(r'^\+?[0-9]{10,15}$');
                      if (!phoneRegExp.hasMatch(value)) {
                        return localizations.enterValidPhoneNumber;
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Email Field
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: localizations.email,
                      prefixIcon: Icon(Icons.email_outlined),
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
                      if (value.length < 6) {
                        return localizations.enterValidPassword;
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // Confirm Password Field
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: _obscureConfirmPassword,
                    decoration: InputDecoration(
                      labelText: localizations.confirmPassword,
                      prefixIcon: const Icon(Icons.key_outlined),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirmPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscureConfirmPassword = !_obscureConfirmPassword;
                          });
                        },
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return localizations.enterConfirmPassword;
                      }
                      if (value != _passwordController.text) {
                        return localizations.passwordMismatch;
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 32),
                  
                  // Register Button
                  ElevatedButton(
                    onPressed: _register,
                    child: Text(localizations.registerButton),
                  ),
                  const SizedBox(height: 24),
                  
                  // Login Link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(localizations.hasAccount),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pushReplacementNamed(AppRouter.login);
                        },
                        child: Text(localizations.signIn),
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
