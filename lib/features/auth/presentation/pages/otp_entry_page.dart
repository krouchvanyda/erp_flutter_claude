import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/router/route_paths.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/repositories/stub_otp_repository.dart';
import '../../domain/entities/otp_verification_result.dart';
import '../bloc/otp_bloc.dart';
import '../bloc/otp_event.dart';
import '../bloc/otp_state.dart';
import '../widgets/otp_input_field.dart';

/// Multi-factor authentication step — user types a 6-digit code received
/// out-of-band (TOTP authenticator app or SMS) and the verifier accepts
/// or rejects it.
///
/// **Memory-only** (per CLAUDE.md Slice 1.2.1): the typed code is held in
/// the bloc's state. Nothing is written to drift, secure storage, or
/// shared_preferences — the bloc is factory-scoped in DI so it's
/// disposed (and the code wiped) the moment the user navigates away.
class OtpEntryPage extends StatelessWidget {
  const OtpEntryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<OtpBloc>(
      create: (_) => getIt<OtpBloc>(),
      child: const _OtpEntryView(),
    );
  }
}

class _OtpEntryView extends StatelessWidget {
  const _OtpEntryView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return BlocConsumer<OtpBloc, OtpState>(
      listenWhen: (prev, next) =>
          prev.hasSucceeded == false && next.hasSucceeded,
      listener: (context, state) {
        // Demo: on success, bounce to the dashboard. In the real MFA
        // flow this is where the auth-bloc would hand back the token
        // and the router redirect would handle the destination.
        context.goNamed(RoutePaths.dashboardName);
      },
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(title: Text(l10n.otpPageTitle)),
          body: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(
                      Icons.shield_outlined,
                      size: 56,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      l10n.otpSubtitle,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      l10n.otpDevHint(StubOtpRepository.devCode),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    OtpInputField(
                      length: state.length,
                      enabled: !state.isSubmitting,
                      hasError: state.hasError,
                      onChanged: (code) => context
                          .read<OtpBloc>()
                          .add(OtpEvent.codeChanged(code)),
                      onCompleted: (_) => context
                          .read<OtpBloc>()
                          .add(const OtpEvent.submitted()),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    SizedBox(
                      height: 24,
                      child: state.hasError
                          ? Text(
                              _errorMessage(l10n, state.rejectionReason!),
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.error,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    FilledButton(
                      onPressed: state.canSubmit
                          ? () => context
                              .read<OtpBloc>()
                              .add(const OtpEvent.submitted())
                          : null,
                      child: state.isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : Text(l10n.otpVerifyButton),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  String _errorMessage(AppLocalizations l10n, OtpRejectionReason reason) {
    return switch (reason) {
      OtpRejectionReason.incorrect => l10n.otpErrorIncorrect,
      OtpRejectionReason.expired => l10n.otpErrorExpired,
      OtpRejectionReason.tooManyAttempts => l10n.otpErrorTooManyAttempts,
      OtpRejectionReason.networkError => l10n.otpErrorNetwork,
    };
  }
}
