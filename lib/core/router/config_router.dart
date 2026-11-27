import 'package:flutter/material.dart';
import 'package:page_transition/page_transition.dart';

/// All page pushes go through here, so transitions look the same everywhere.
///
/// ```dart
/// ConfigRouter.pushPageAnimation(context, const ChatInfoPage());
/// ```
///
/// Which one?
/// - normal "next page"            → [pushPageAnimation] (slide right→left)
/// - replace the whole stack       → [pushPageAndRemoveUntilAnimation]
/// - a page over the current one   → [pushPageOverlay] (dim + fade)
/// - full-screen modal (close ✕)   → [pushPageDialog]
/// - sheet from the bottom         → [pushPageOverlayBottomSheet]
/// - close every page above home   → [popToFirst]
class ConfigRouter {
  /// Closes every page above the FIRST one (the home, e.g. Chats).
  /// Used before opening a chat from a tapped banner / push (5.7), so Back
  /// from that chat goes to Chats, not to the page you were on.
  static void popToFirst(BuildContext context) {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  static Future<T?> pushPageNotAnimation<T>(BuildContext context, Widget page) {
    return Navigator.push<T>(
      context,
      MaterialPageRoute(builder: (BuildContext context) => page),
    );
  }

  static Future<T?> pushPageAnimation<T>(BuildContext context, Widget page) {
    return Navigator.push<T>(
      context,
      PageTransition(
        type: PageTransitionType.rightToLeft,
        isIos: true,
        opaque: true,
        reverseType: PageTransitionType.fade,
        child: page,
      ),
    );
  }

  static Future<T?> pushPageAndRemoveUntilNotAnimation<T>(
    BuildContext context,
    Widget page,
  ) {
    return Navigator.of(context).pushAndRemoveUntil<T>(
      MaterialPageRoute(builder: (context) => page),
      (Route<dynamic> route) => false,
    );
  }

  static Future<T?> pushPageAndRemoveUntilAnimation<T>(
    BuildContext context,
    Widget page,
  ) {
    return Navigator.pushAndRemoveUntil<T>(
      context,
      PageTransition(
        type: PageTransitionType.fade,
        isIos: true,

        /// see pushPageAnimation — PageTransition defaults `opaque` to false.
        opaque: true,
        reverseType: PageTransitionType.fade,
        child: page,
      ),
      (Route<dynamic> route) => false,
    );
  }

  /// Pushes [page] OVER the current screen without hiding it.
  ///
  /// opaque:false is the whole point - it tells the framework this route does
  /// not cover what is beneath, so the screen below keeps being built and
  /// painted. With opaque:true Flutter stops painting it once the transition
  /// ends and nothing can show through, however transparent the page itself
  /// is.
  ///
  /// barrierColor is the dim over that screen. It is a ModalRoute barrier, so
  /// it is painted for us behind the page - the page does not have to draw a
  /// scrim. barrierDismissible lets a tap outside close it.
  ///
  /// The page itself still has to be transparent where you want the screen
  /// below to read through; an opaque Scaffold would defeat all of this.
  static Future<T?> pushPageOverlay<T>(
    BuildContext context,
    Widget page, {
    Color barrierColor = const Color(0x8A000000),
    bool barrierDismissible = true,
  }) {
    return Navigator.of(context).push<T>(
      _OverlayPageRoute<T>(
        barrierColor: barrierColor,
        barrierDismissible: barrierDismissible,
        barrierLabel: MaterialLocalizations.of(
          context,
        ).modalBarrierDismissLabel,
        page: page,
      ),
    );
  }

  static Future<T?> pushPageFast<T>(BuildContext context, Widget page) {
    return Navigator.of(context).push<T>(
      PageRouteBuilder<T>(
        opaque: true,
        fullscreenDialog: true,
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
        pageBuilder: (_, _, _) => page,
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  static Future<T?> pushPageDialog<T>(BuildContext context, Widget page) {
    return Navigator.push<T>(
      context,
      MaterialPageRoute(
        builder: (BuildContext context) => page,
        fullscreenDialog: true,
      ),
    );
  }

  static Future<T?> pushPageOverlayBottomToTop<T>(
    BuildContext context,
    Widget page,
  ) {
    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      barrierLabel: 'overlay-bottom-to-top',
      useRootNavigator: false,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (_, _, _) => page,
      transitionBuilder: (_, animation, _, child) => SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
            .animate(
              CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
                reverseCurve: Curves.easeInCubic,
              ),
            ),
        child: child,
      ),
    );
  }

  /// enableDrag defaults to false: pages with their own pull-down-to-close
  /// would fight the sheet's drag.
  static Future<T?> pushPageOverlayBottomSheet<T>(
    BuildContext context,
    Widget page, {
    bool isDismissible = false,
    bool enableDrag = false,
    bool isFullScreen = false,
    Color? backgroundColor,
    Color? modalBarrierColor,
  }) {
    /// what showModalBottomSheet does, but with _StatusBarSafeSheetRoute -
    /// see there
    final NavigatorState navigator = Navigator.of(context);
    final MaterialLocalizations localizations = MaterialLocalizations.of(
      context,
    );
    return navigator.push<T>(
      _StatusBarSafeSheetRoute<T>(
        capturedThemes: InheritedTheme.capture(
          from: context,
          to: navigator.context,
        ),
        barrierLabel: localizations.scrimLabel,
        barrierOnTapHint: localizations.scrimOnTapHint(
          localizations.bottomSheetLabel,
        ),
        isScrollControlled: true,
        isDismissible: isDismissible,
        enableDrag: enableDrag,
        useSafeArea: false,
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width),
        backgroundColor: backgroundColor ?? Colors.transparent,
        modalBarrierColor: modalBarrierColor ?? Colors.transparent,
        elevation: 0,
        sheetAnimationStyle: AnimationStyle(
          duration: const Duration(milliseconds: 300),
          reverseDuration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        ),
        builder: (sheetContext) => SizedBox(
          height: isFullScreen ? MediaQuery.sizeOf(sheetContext).height : null,
          child: page,
        ),
      ),
    );
  }
}

/// The route [ConfigRouter.pushPageOverlayBottomSheet] pushes: a plain
/// ModalBottomSheetRoute whose barrier ignores the status-bar strip.
///
/// iOS hands a status-bar tap to Flutter as a FAKE tap at (0,0) - that is how
/// Scaffold's tap-the-status-bar-to-scroll-to-top works. A dismissible sheet's
/// barrier covers (0,0), so that fake tap closed the sheet. On iPad a toolbar
/// right under the status bar made the same tap that OPENED the sheet also
/// count as a status-bar tap, and the sheet "closed by itself".
///
/// The strip swallows it. Real taps outside the sheet, below the status bar,
/// still close it.
class _StatusBarSafeSheetRoute<T> extends ModalBottomSheetRoute<T> {
  _StatusBarSafeSheetRoute({
    required super.builder,
    required super.isScrollControlled,
    super.capturedThemes,
    super.barrierLabel,
    super.barrierOnTapHint,
    super.backgroundColor,
    super.elevation,
    super.constraints,
    super.modalBarrierColor,
    super.isDismissible,
    super.enableDrag,
    super.useSafeArea,
    super.sheetAnimationStyle,
  });

  @override
  Widget buildModalBarrier() {
    return Stack(
      children: [
        Positioned.fill(child: super.buildModalBarrier()),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Builder(
            builder: (context) => AbsorbPointer(
              child: SizedBox(height: MediaQuery.viewPaddingOf(context).top),
            ),
          ),
        ),
      ],
    );
  }
}

/// The route [ConfigRouter.pushPageOverlay] pushes.
///
/// It exists for ONE override: canTransitionFrom.
///
/// Routes pushed through pushPageAnimation use PageTransition(isIos: true),
/// which delegates to CupertinoPageTransitionsBuilder - and that builder gives
/// the outgoing page a parallax: when something is pushed on top, it slides a
/// third of the screen to the left. Behind an opaque route nobody ever sees
/// it. Behind a transparent one you see the page slide away and a black band
/// open up on the right where nothing is painted any more.
///
/// TransitionRoute only drives that exit animation when BOTH
/// `previous.canTransitionTo(next)` and `next.canTransitionFrom(previous)` are
/// true. We cannot change the route below, but this is the other half of the
/// test: returning false hands it kAlwaysDismissedAnimation instead, so it
/// stays put and keeps filling the screen.
class _OverlayPageRoute<T> extends PageRouteBuilder<T> {
  _OverlayPageRoute({
    required Widget page,
    required Color barrierColor,
    required super.barrierDismissible,
    required String barrierLabel,
  }) : super(
         opaque: false,
         barrierColor: barrierColor,
         barrierLabel: barrierLabel,

         /// kept short: the keyboard is coming up right behind it
         transitionDuration: const Duration(milliseconds: 140),
         reverseTransitionDuration: const Duration(milliseconds: 120),
         pageBuilder: (_, _, _) => page,
         transitionsBuilder: (_, animation, _, child) =>
             FadeTransition(opacity: animation, child: child),
       );

  @override
  bool canTransitionFrom(TransitionRoute<dynamic> previousRoute) => false;
}
