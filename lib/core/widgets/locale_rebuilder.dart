import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../i18n/locale_cubit.dart';

/// Redraws everything below it when the language changes, so every
/// `'key'.tr` shows the new language (GetX text is not tied to the widget
/// tree, so Flutter can't know by itself). Put it above MaterialApp, so all
/// open screens and dialogs are included.
class LocaleRebuilder extends StatelessWidget {
  const LocaleRebuilder({super.key, required this.child});

  final Widget child;

  static void _markAll(Element element) {
    element.markNeedsBuild();
    element.visitChildren(_markAll);
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<LocaleCubit, Locale>(
      listener: (context, _) => (context as Element).visitChildren(_markAll),
      child: child,
    );
  }
}
