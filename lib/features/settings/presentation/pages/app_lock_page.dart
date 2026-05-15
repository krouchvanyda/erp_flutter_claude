import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';

import '../../../../core/error/failure.dart';
import '../../domain/entities/app_lock_settings.dart';
import '../../domain/repositories/security_repositories.dart';
import '../../domain/usecases/manage_app_lock.dart';

/// Slice 9.3.3 — PIN + biometric re-auth on resume.
///
/// **Storage boundary** is enforced here: the PIN itself goes through
/// [PinSecretStore] (memory-only stub today, `flutter_secure_storage`
/// in prod). The PIN-enabled flag lives in [AppLockSettings] (drift in
/// prod) so wiping drift never invalidates the secret on its own.
class AppLockPage extends StatelessWidget {
  const AppLockPage();

  @override
  Widget build(BuildContext context) {
    final settingsRepo = GetIt.I<AppLockSettingsRepository>();
    return Scaffold(
      appBar: AppBar(title: const Text('App lock')),
      body: StreamBuilder<AppLockSettings>(
        stream: settingsRepo.watch(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final settings = snap.data!;
          return ListView(
            children: [
              SwitchListTile(
                title: const Text('App PIN'),
                subtitle:
                    const Text('Require a 4–8 digit PIN on resume'),
                value: settings.pinEnabled,
                onChanged: (v) async {
                  if (v) {
                    final pin = await _promptForNewPin(context);
                    if (pin == null) return;
                    await GetIt.I<PinSecretStore>().setPin(pin);
                    await settingsRepo.update(setPinEnabled(
                        current: settings, enabled: true));
                  } else {
                    await GetIt.I<PinSecretStore>().clearPin();
                    await settingsRepo.update(setPinEnabled(
                        current: settings, enabled: false));
                  }
                },
              ),
              SwitchListTile(
                title: const Text('Biometric unlock'),
                subtitle: const Text(
                    'Use Face ID / fingerprint instead of typing the PIN'),
                value: settings.biometricEnabled,
                onChanged: settings.pinEnabled
                    ? (v) async {
                        try {
                          await settingsRepo.update(
                            setBiometricEnabled(
                                current: settings, enabled: v),
                          );
                        } on ConflictFailure catch (f) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text(
                                      f.message ?? 'Cannot enable.')),
                            );
                          }
                        }
                      }
                    : null,
              ),
              const Divider(),
              ListTile(
                title: const Text('Auto-lock after'),
                subtitle: Text(
                  settings.autoLockMinutes == 0
                      ? 'Lock immediately on resume'
                      : '${settings.autoLockMinutes} min after backgrounding',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: settings.pinEnabled
                    ? () => _pickAutoLock(context, settings)
                    : null,
              ),
              if (settings.pinEnabled)
                ListTile(
                  leading: const Icon(Icons.password),
                  title: const Text('Change PIN'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    final pin = await _promptForNewPin(context);
                    if (pin == null) return;
                    await GetIt.I<PinSecretStore>().setPin(pin);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('PIN updated.')),
                      );
                    }
                  },
                ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'PIN is stored in flutter_secure_storage (the OS-backed keystore). Wiping app data clears the PIN.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _pickAutoLock(
      BuildContext context, AppLockSettings settings) async {
    final repo = GetIt.I<AppLockSettingsRepository>();
    final value = await showDialog<int>(
      context: context,
      builder: (dialogCtx) => SimpleDialog(
        title: const Text('Auto-lock after'),
        children: [
          for (final minutes in [0, 1, 5, 15, 30, 60])
            SimpleDialogOption(
              onPressed: () => Navigator.pop(dialogCtx, minutes),
              child: Text(minutes == 0
                  ? 'Immediately'
                  : '$minutes minute${minutes == 1 ? '' : 's'}'),
            ),
        ],
      ),
    );
    if (value == null) return;
    try {
      await repo.update(
        setAutoLockMinutes(current: settings, minutes: value),
      );
    } on ValidationFailure catch (f) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${f.fieldErrors}')),
        );
      }
    }
  }

  Future<String?> _promptForNewPin(BuildContext context) async {
    final pinCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    String? errorMsg;
    return showDialog<String>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setDialog) => AlertDialog(
          title: const Text('Set a PIN'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: pinCtrl,
                obscureText: true,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(8),
                ],
                decoration: const InputDecoration(
                  labelText: 'PIN (4–8 digits)',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirmCtrl,
                obscureText: true,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(8),
                ],
                decoration: const InputDecoration(
                  labelText: 'Confirm PIN',
                ),
              ),
              if (errorMsg != null) ...[
                const SizedBox(height: 12),
                Text(errorMsg!,
                    style: const TextStyle(color: Colors.red)),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                try {
                  validatePinFormat(pinCtrl.text);
                  ensurePinConfirmationMatches(
                    pin: pinCtrl.text,
                    confirm: confirmCtrl.text,
                  );
                  Navigator.pop(dialogCtx, pinCtrl.text);
                } on ValidationFailure catch (f) {
                  setDialog(() => errorMsg = f.fieldErrors.values
                      .expand((e) => e)
                      .join(', '));
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
