import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/router/config_router.dart';
import '../../../../core/theme/app_font_size.dart';
import '../../../../core/theme/app_label.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/widgets/dynamic_status_bar.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/app_text_field.dart';
import 'biometric_unlock_page.dart';
import 'forgot_password_page.dart';
import 'otp_entry_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, this.onSimulatedLogin});

  final VoidCallback? onSimulatedLogin;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleLogin() {
    if (_formKey.currentState?.validate() ?? false) {
      widget.onSimulatedLogin?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      body: DynamicStatusBar(
        child: Stack(
          children: [
            // Background Gradient
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: [
                    theme.colorScheme.primaryContainer.withOpacity(0.8),
                    theme.colorScheme.surface,
                    theme.colorScheme.secondaryContainer.withOpacity(0.3),
                  ],
                ),
              ),
            ),
            
            // Decorative Circles
            Positioned(
              top: -100,
              right: -100,
              child: CircleAvatar(
                radius: 150,
                backgroundColor: theme.colorScheme.primary.withOpacity(0.05),
              ),
            ).animate().fadeIn(duration: 1200.ms).scale(begin: const Offset(0.5, 0.5)),
            
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Logo and Welcome Text
                        Icon(
                          Icons.business_center_rounded,
                          size: 64,
                          color: theme.colorScheme.primary,
                        ).animate().fadeIn(duration: 600.ms).scale(),
                        
                        const SizedBox(height: 16),
                        
                        AppLabel(
                          text: l10n.appName,
                          fontSize: AppFontSize.value24,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                          textAlign: TextAlign.center,
                        ).animate().fadeIn(delay: 200.ms),

                        const SizedBox(height: 8),

                        AppLabel(
                          text: 'Welcome back! Please sign in to continue.',
                          fontSize: AppFontSize.value14,
                          color: theme.colorScheme.onSurfaceVariant,
                          textAlign: TextAlign.center,
                        ).animate().fadeIn(delay: 300.ms),
                        
                        const SizedBox(height: 48),
                        
                        // Glassmorphic Login Card
                        ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadii.lg),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                            child: Container(
                              padding: const EdgeInsets.all(32),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surface.withValues(alpha: 0.7),
                                borderRadius: BorderRadius.circular(AppRadii.lg),
                                border: Border.all(
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 20,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: Form(
                                key: _formKey,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    AppTextField(
                                      controller: _emailController,
                                      label: 'Email',
                                      icon: Icons.email_outlined,
                                      hintText: 'name@company.com',
                                      keyboardType: TextInputType.emailAddress,
                                      textCapitalization: TextCapitalization.none,
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Please enter your email';
                                        }
                                        final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                                        if (!emailRegex.hasMatch(value)) {
                                          return 'Please enter a valid email address';
                                        }
                                        return null;
                                      },
                                    ),

                                    const SizedBox(height: 20),

                                    AppTextField(
                                      controller: _passwordController,
                                      label: 'Password',
                                      icon: Icons.lock_outline_rounded,
                                      obscureText: _obscurePassword,
                                      textCapitalization: TextCapitalization.none,
                                      suffixIcon: IconButton(
                                        icon: Icon(
                                          _obscurePassword
                                              ? Icons.visibility_outlined
                                              : Icons.visibility_off_outlined,
                                          size: 20,
                                        ),
                                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                      ),
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Please enter your password';
                                        }
                                        if (value.length < 6) {
                                          return 'Password must be at least 6 characters';
                                        }
                                        return null;
                                      },
                                    ),
                                    
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: TextButton(
                                        onPressed: () => ConfigRouter.pushPageAnimation(context, const ForgotPasswordPage()),
                                        child: const Text('Forgot Password?'),
                                      ),
                                    ),
                                    
                                    const SizedBox(height: 24),
                                    
                                    FilledButton(
                                      onPressed: _handleLogin,
                                      child: const Text('Sign In'),
                                    ).animate().shimmer(delay: 2000.ms, duration: 1500.ms),
                                    
                                    const SizedBox(height: 16),
                                    
                                    OutlinedButton.icon(
                                      onPressed: () => ConfigRouter.pushPageAnimation(context, const BiometricUnlockPage()),
                                      icon: Icon(
                                        Icons.fingerprint_rounded,
                                        color: theme.colorScheme.primary,
                                      ),
                                      label: const Text('Use Biometrics'),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.1, end: 0),
                        
                        const SizedBox(height: 32),
                        
                        // Demo Link
                        TextButton(
                          onPressed: () => ConfigRouter.pushPageAnimation(context, const OtpEntryPage()),
                          child: Text(l10n.loginOtpDemoLink),
                        ).animate().fadeIn(delay: 800.ms),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
