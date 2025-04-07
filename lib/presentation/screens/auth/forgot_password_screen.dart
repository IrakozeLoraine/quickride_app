import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:quickride/data/providers/auth_provider.dart';
import 'package:quickride/presentation/widgets/loading_overlay.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:quickride/utils/app_utils.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({Key? key}) : super(key: key);

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isProcessing = false;
  bool _resetSent = false;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _resetPassword() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() {
        _isProcessing = true;
      });

      try {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final success = await authProvider.resetPassword(_emailController.text.trim(), context);
        final localizations = AppLocalizations.of(context)!;

        if (success) {
          setState(() {
            _resetSent = true;
          });
        } else {
          showToast(context, authProvider.errorMessage ?? localizations.resetEmailFailed, null, true);
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
          title: Text(localizations.forgotPassword),
          elevation: 0,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: _resetSent 
                ? _buildSuccessMessage() 
                : _buildResetForm(localizations),
          ),
        ),
      ),
    );
  }

  Widget _buildResetForm(AppLocalizations localizations) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 24),
          
          // Title
          Text(
            localizations.resetPassword,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          
          // Instructions
          Text(
            localizations.resetPasswordInstructions,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          
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
                return localizations.invalidEmail;
              }
              return null;
            },
          ),
          const SizedBox(height: 32),
          
          // Reset Button
          ElevatedButton(
            onPressed: _resetPassword,
            child: Text(localizations.resetPassword),
          ),
          const SizedBox(height: 16),
          
          // Back to Login
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: Text(localizations.signIn),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessMessage() {
    final localizations = AppLocalizations.of(context)!;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 40),
        const Icon(
          Icons.check_circle_outline_outlined,
          color: Colors.green,
          size: 80,
        ),
        const SizedBox(height: 24),
        Text(
          localizations.passwordResetEmailSent,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Text(
          '${localizations.passwordResetSuccess} ${_emailController.text}',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          localizations.pleaseCheckEmailInbox,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
          },
          child: Text(localizations.back),
        ),
      ],
    );
  }
}
