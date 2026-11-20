import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/di/service_locator.dart';
import '../viewmodel/login/login_view_model_bloc.dart';
import '../widgets/login_brand_panel.dart';
import '../widgets/login_form_column.dart';

/// Screen 1.1 — Login (design guide): calm, single column, no card on phone.
///
/// This file is only the LAYOUT. Each piece lives in `../widgets/`.
///
/// Responsive:
/// - narrow (< [_wideBreakpoint]) → one column
/// - wide (tablet / landscape)    → brand panel left, form right
///
/// The page never navigates: on success the repository opens the session and
/// `AuthGate` swaps Login → Home.
class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  static const double _wideBreakpoint = 720;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      // an "edge": may take from the DI box (a fresh bloc — registerFactory)
      create: (_) => getIt<LoginViewModelBloc>(),
      child: Scaffold(
        body: GestureDetector(
          // tap anywhere outside a field → hide the keyboard
          onTap: () => FocusScope.of(context).unfocus(),
          behavior: HitTestBehavior.opaque,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= _wideBreakpoint;
              final form = LoginFormColumn(showBrandHeader: !wide);
              if (!wide) return SafeArea(child: form);
              return Row(
                children: [
                  const Expanded(flex: 5, child: LoginBrandPanel()),
                  Expanded(flex: 6, child: SafeArea(child: form)),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
