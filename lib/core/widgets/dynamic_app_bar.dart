import 'package:flutter/material.dart';

/// A premium, dynamic AppBar that supports transitions and modern ERP aesthetics.
/// 
/// It automatically handles status bar styling when used in conjunction with
/// [DynamicStatusBar] or standard [Scaffold] settings.
class DynamicAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final Widget? leading;
  final bool centerTitle;
  final double elevation;
  final Color? backgroundColor;
  final PreferredSizeWidget? bottom;

  const DynamicAppBar({
    super.key,
    required this.title,
    this.actions,
    this.leading,
    this.centerTitle = false,
    this.elevation = 0,
    this.backgroundColor,
    this.bottom,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return AppBar(
      title: Text(
        title,
        style: theme.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
      actions: actions,
      leading: leading,
      centerTitle: centerTitle,
      elevation: elevation,
      backgroundColor: backgroundColor ?? theme.colorScheme.surface.withOpacity(0.8),
      surfaceTintColor: Colors.transparent,
      bottom: bottom,
      flexibleSpace: ClipRRect(
        child: BackdropFilter(
          filter: ColorFilter.mode(
            theme.colorScheme.surface.withOpacity(0.0), 
            BlendMode.srcOver,
          ),
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: theme.colorScheme.outlineVariant.withOpacity(0.3),
                  width: 1,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(
    kToolbarHeight + (bottom?.preferredSize.height ?? 0.0),
  );
}
