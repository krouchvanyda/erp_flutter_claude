import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_km.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('km'),
  ];

  /// Application title shown on splash and home screens
  ///
  /// In en, this message translates to:
  /// **'ERP Mobile'**
  String get appName;

  /// Title bar on the login screen
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get loginAppBarTitle;

  /// Primary button on the login form. Placeholder copy until Module 1 ships the real OAuth flow.
  ///
  /// In en, this message translates to:
  /// **'Sign in (placeholder)'**
  String get loginButton;

  /// Title bar on the dashboard / home screen
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get dashboardTitle;

  /// Body text on the dashboard while Module 2 is unimplemented
  ///
  /// In en, this message translates to:
  /// **'Dashboard placeholder — Module 2 will fill this in.'**
  String get dashboardPlaceholder;

  /// Tooltip on the sign-out icon button in the dashboard app bar
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOutTooltip;

  /// Title bar on the 404 / no-route-matched page
  ///
  /// In en, this message translates to:
  /// **'Not found'**
  String get notFoundTitle;

  /// Body text on the 404 page; explains which path the router could not resolve
  ///
  /// In en, this message translates to:
  /// **'No route matches \"{location}\"'**
  String notFoundBody(String location);

  /// Action button that returns the user to the splash / home route
  ///
  /// In en, this message translates to:
  /// **'Go home'**
  String get goHome;

  /// Subtle text button on the login page that navigates to the OTP demo route (Slice 1.2.1)
  ///
  /// In en, this message translates to:
  /// **'[demo] Try MFA code'**
  String get loginOtpDemoLink;

  /// Title bar on the OTP / TOTP entry page
  ///
  /// In en, this message translates to:
  /// **'Verification'**
  String get otpPageTitle;

  /// Body copy under the OTP page icon, instructing the user
  ///
  /// In en, this message translates to:
  /// **'Enter the 6-digit code from your authenticator app or SMS.'**
  String get otpSubtitle;

  /// Italic hint reminding the user of the dev backdoor code while the real verifier is not wired
  ///
  /// In en, this message translates to:
  /// **'Demo: enter {code} to continue'**
  String otpDevHint(String code);

  /// Primary action button on the OTP page
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get otpVerifyButton;

  /// Error shown under the OTP boxes when the entered code does not match
  ///
  /// In en, this message translates to:
  /// **'Code is incorrect. Please try again.'**
  String get otpErrorIncorrect;

  /// Error shown when the OTP validity window has elapsed
  ///
  /// In en, this message translates to:
  /// **'This code has expired. Request a new one.'**
  String get otpErrorExpired;

  /// Error shown when the server throttles further OTP attempts
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Please try again later.'**
  String get otpErrorTooManyAttempts;

  /// Error shown when the OTP verifier is unreachable
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t reach the server. Check your connection.'**
  String get otpErrorNetwork;

  /// Title bar on the 403 / permission-gated landing page
  ///
  /// In en, this message translates to:
  /// **'Access denied'**
  String get forbiddenTitle;

  /// Body text on the forbidden page; explains which path was denied
  ///
  /// In en, this message translates to:
  /// **'You don\'t have permission to access \"{location}\".'**
  String forbiddenBody(String location);

  /// Title bar on the permission-gated demo page (Slice 1.3.2)
  ///
  /// In en, this message translates to:
  /// **'Admin demo'**
  String get adminDemoTitle;

  /// Body of the admin demo page, confirming the route guard let the user through
  ///
  /// In en, this message translates to:
  /// **'You reached the admin-only demo route — RBAC works.'**
  String get adminDemoBody;

  /// Subtle text button on the dashboard that navigates to the admin-only demo route (Slice 1.3.2)
  ///
  /// In en, this message translates to:
  /// **'[demo] Open admin-only page'**
  String get dashboardAdminDemoLink;

  /// Chip label on the dashboard when the live PermissionGuard verdict for `admin` is allowed (Slice 1.3.3)
  ///
  /// In en, this message translates to:
  /// **'[demo] PermissionGuard: admin granted'**
  String get permissionGuardDemoGranted;

  /// Chip label on the dashboard when the live PermissionGuard verdict for `admin` is denied (Slice 1.3.3)
  ///
  /// In en, this message translates to:
  /// **'[demo] PermissionGuard: admin denied'**
  String get permissionGuardDemoDenied;

  /// Bottom-nav / rail label for the Home (dashboard) shell branch
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get shellHome;

  /// Bottom-nav / rail label for the Modules shell branch (Slice 2.1.2 fills it)
  ///
  /// In en, this message translates to:
  /// **'Modules'**
  String get shellModules;

  /// Bottom-nav / rail label for the Settings shell branch (Module 9 fills it)
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get shellSettings;

  /// AppBar title on the Modules placeholder page
  ///
  /// In en, this message translates to:
  /// **'Modules'**
  String get modulesTitle;

  /// Body text on the Modules placeholder page (kept for compatibility — no longer rendered after Slice 2.1.2)
  ///
  /// In en, this message translates to:
  /// **'Module shortcut tiles land here in Slice 2.1.2.'**
  String get modulesPlaceholder;

  /// Empty-state message on the Modules grid when the signed-in user holds no permission that satisfies any catalog tile
  ///
  /// In en, this message translates to:
  /// **'No modules are available for your role yet. Ask an admin to grant the permissions you need.'**
  String get modulesEmpty;

  /// Module-grid tile label for the Slice 1.3.2 admin-only demo route
  ///
  /// In en, this message translates to:
  /// **'Admin demo'**
  String get shortcutAdminDemo;

  /// Module-grid tile label for the Finance feature module (CLAUDE.md Module 3)
  ///
  /// In en, this message translates to:
  /// **'Finance'**
  String get shortcutFinance;

  /// Module-grid tile label for the Procurement feature module (CLAUDE.md Module 4)
  ///
  /// In en, this message translates to:
  /// **'Procurement'**
  String get shortcutProcurement;

  /// Module-grid tile label for the Inventory feature module (CLAUDE.md Module 5)
  ///
  /// In en, this message translates to:
  /// **'Inventory'**
  String get shortcutInventory;

  /// Module-grid tile label for the Sales & CRM feature module (CLAUDE.md Module 6)
  ///
  /// In en, this message translates to:
  /// **'Sales'**
  String get shortcutSales;

  /// Module-grid tile label for the Human Resources feature module (CLAUDE.md Module 7)
  ///
  /// In en, this message translates to:
  /// **'HR'**
  String get shortcutHr;

  /// Module-grid tile label for the Project Management feature module (CLAUDE.md Module 8)
  ///
  /// In en, this message translates to:
  /// **'Projects'**
  String get shortcutProjects;

  /// Body of the generic coming-soon landing page; explains which module the user reached
  ///
  /// In en, this message translates to:
  /// **'{module} ships in a future release.'**
  String comingSoonBody(String module);

  /// AppBar title on the Settings placeholder page
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// Body text on the Settings placeholder page
  ///
  /// In en, this message translates to:
  /// **'Real preferences land here in Module 9.'**
  String get settingsPlaceholder;

  /// Tooltip on the global search icon button in the AppBar (Slice 2.1.3)
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get globalSearchTooltip;

  /// Placeholder text inside the global search overlay's text field
  ///
  /// In en, this message translates to:
  /// **'Search modules, records, people…'**
  String get globalSearchHint;

  /// Idle-state body shown in the search overlay before the user has typed anything
  ///
  /// In en, this message translates to:
  /// **'Type to search across every module you can access.'**
  String get globalSearchPrompt;

  /// Empty-results body shown after a search returns nothing across all providers
  ///
  /// In en, this message translates to:
  /// **'No results for \"{query}\".'**
  String globalSearchNoResults(String query);

  /// Body shown when the federated search use case itself throws (per-provider failures are absorbed silently)
  ///
  /// In en, this message translates to:
  /// **'Search failed: {message}'**
  String globalSearchError(String message);

  /// Fallback short label on a KPI trend chip when the caller didn't supply a numeric delta — direction is up
  ///
  /// In en, this message translates to:
  /// **'up'**
  String get kpiTrendUp;

  /// Fallback short label on a KPI trend chip — direction is down
  ///
  /// In en, this message translates to:
  /// **'down'**
  String get kpiTrendDown;

  /// Fallback short label on a KPI trend chip — no meaningful change since the prior period
  ///
  /// In en, this message translates to:
  /// **'flat'**
  String get kpiTrendFlat;

  /// Tooltip surfaced when hovering / long-pressing a KPI trend chip pointing up
  ///
  /// In en, this message translates to:
  /// **'Up vs prior period'**
  String get kpiTrendUpTooltip;

  /// Tooltip surfaced when hovering / long-pressing a KPI trend chip pointing down
  ///
  /// In en, this message translates to:
  /// **'Down vs prior period'**
  String get kpiTrendDownTooltip;

  /// Tooltip surfaced when hovering / long-pressing a flat KPI trend chip
  ///
  /// In en, this message translates to:
  /// **'No meaningful change vs prior period'**
  String get kpiTrendFlatTooltip;

  /// Title of the demo line chart on the dashboard (Slice 2.2.3)
  ///
  /// In en, this message translates to:
  /// **'Revenue trend'**
  String get chartRevenueTrendTitle;

  /// Title of the demo bar chart on the dashboard (Slice 2.2.3)
  ///
  /// In en, this message translates to:
  /// **'Sales by region'**
  String get chartSalesByRegionTitle;

  /// Legend label for the revenue series on the line chart
  ///
  /// In en, this message translates to:
  /// **'Revenue'**
  String get chartSeriesRevenue;

  /// Legend label for the target series on the line chart
  ///
  /// In en, this message translates to:
  /// **'Target'**
  String get chartSeriesTarget;

  /// Legend label for the sales series on the bar chart
  ///
  /// In en, this message translates to:
  /// **'Sales'**
  String get chartSeriesSales;

  /// Realtime status pill — WebSocket is connected, server pushes are flowing (Slice 2.2.4)
  ///
  /// In en, this message translates to:
  /// **'Live'**
  String get realtimeStatusLive;

  /// Realtime status pill — first-attempt handshake is in flight
  ///
  /// In en, this message translates to:
  /// **'Connecting'**
  String get realtimeStatusConnecting;

  /// Realtime status pill — connection dropped, sleeping a backoff window before the next attempt
  ///
  /// In en, this message translates to:
  /// **'Reconnecting'**
  String get realtimeStatusReconnecting;

  /// Realtime status pill — service hasn't started or reconnect attempts have been exhausted
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get realtimeStatusOffline;

  /// Dashboard button that fires a fake push payload through the router (Slice 2.3.2). Visible only when LocalPushSimulator is bound.
  ///
  /// In en, this message translates to:
  /// **'[dev] Simulate push'**
  String get pushDemoButton;

  /// Title of the synthetic push payload generated by the dashboard demo button
  ///
  /// In en, this message translates to:
  /// **'Demo notification #{count}'**
  String pushDemoTitle(int count);

  /// Body of the synthetic push payload from the demo button
  ///
  /// In en, this message translates to:
  /// **'Routed through PushMessageRouter into the inbox cache.'**
  String get pushDemoBody;

  /// Snackbar confirming the simulated push reached the inbox
  ///
  /// In en, this message translates to:
  /// **'Pushed to inbox.'**
  String get pushDemoSnack;

  /// Tooltip on the AppBar bell icon (Slice 2.3.3)
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notificationsBadgeTooltip;

  /// AppBar title on the notification inbox page
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notificationInboxTitle;

  /// Body shown in the inbox when there are zero non-dismissed notifications
  ///
  /// In en, this message translates to:
  /// **'You\'re all caught up. New notifications will appear here.'**
  String get notificationInboxEmpty;

  /// Body shown when the inbox watch stream errors
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load notifications: {message}'**
  String notificationInboxError(String message);

  /// Tooltip on the AppBar action that fires the MarkedAllRead event
  ///
  /// In en, this message translates to:
  /// **'Mark all as read'**
  String get notificationInboxMarkAllRead;

  /// Snackbar surfaced after a swipe-to-dismiss gesture
  ///
  /// In en, this message translates to:
  /// **'Notification dismissed.'**
  String get notificationInboxDismissedSnack;

  /// Snackbar shown when a notification's routeName doesn't resolve (e.g. stale push pointing at a route renamed since) — Slice 2.3.4
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open this notification: {message}'**
  String notificationDeepLinkError(String message);

  /// Snackbar action label that follows a foreground push directly to its deep-link target (Slice 2.3.4)
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get notificationDeepLinkViewAction;

  /// Dashboard button that fires a fake push payload carrying a deep-link route (Slice 2.3.4). Visible only when LocalPushSimulator is bound.
  ///
  /// In en, this message translates to:
  /// **'[dev] Simulate routed push'**
  String get pushDemoRoutedButton;

  /// Body of the synthetic routed push payload
  ///
  /// In en, this message translates to:
  /// **'Tap this notification — or the Snackbar\'s View — to deep-link to the target.'**
  String get pushDemoRoutedBody;

  /// AppBar title on the chart-of-accounts tree view (Slice 3.1.1)
  ///
  /// In en, this message translates to:
  /// **'Chart of accounts'**
  String get chartOfAccountsTitle;

  /// Empty-state body shown when the accounts feed yields no rows
  ///
  /// In en, this message translates to:
  /// **'No accounts have been loaded yet.'**
  String get chartOfAccountsEmpty;

  /// Body shown when the accounts watch stream errors
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load the chart of accounts: {message}'**
  String chartOfAccountsError(String message);

  /// Tooltip on the AppBar action that opens every non-leaf node
  ///
  /// In en, this message translates to:
  /// **'Expand all'**
  String get chartOfAccountsExpandAll;

  /// Tooltip on the AppBar action that collapses every non-leaf node
  ///
  /// In en, this message translates to:
  /// **'Collapse all'**
  String get chartOfAccountsCollapseAll;

  /// Dashboard text button bypassing the Modules grid's RBAC gate to reach /finance/accounts directly (Slice 3.1.1)
  ///
  /// In en, this message translates to:
  /// **'[demo] Open chart of accounts'**
  String get dashboardChartOfAccountsLink;

  /// Localised label for AccountType.asset
  ///
  /// In en, this message translates to:
  /// **'Asset'**
  String get accountTypeAsset;

  /// Localised label for AccountType.liability
  ///
  /// In en, this message translates to:
  /// **'Liability'**
  String get accountTypeLiability;

  /// Localised label for AccountType.equity
  ///
  /// In en, this message translates to:
  /// **'Equity'**
  String get accountTypeEquity;

  /// Localised label for AccountType.revenue
  ///
  /// In en, this message translates to:
  /// **'Revenue'**
  String get accountTypeRevenue;

  /// Localised label for AccountType.expense
  ///
  /// In en, this message translates to:
  /// **'Expense'**
  String get accountTypeExpense;

  /// Fallback AppBar title on the account detail page before the account loads (Slice 3.1.2)
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get accountDetailTitle;

  /// Empty-state body shown when an account has zero transactions
  ///
  /// In en, this message translates to:
  /// **'No transactions have been posted to this account yet.'**
  String get accountDetailNoTransactions;

  /// Body shown when the URL's :id doesn't match any account (deleted server-side, typo, etc.)
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t find an account with id \"{accountId}\".'**
  String accountDetailNotFound(String accountId);

  /// Body shown when either watch stream errors
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load this account: {message}'**
  String accountDetailError(String message);

  /// AppBar title on the invoice list page (Slice 3.2.1)
  ///
  /// In en, this message translates to:
  /// **'Invoices'**
  String get invoiceListTitle;

  /// Placeholder in the invoice list search field
  ///
  /// In en, this message translates to:
  /// **'Search by number or customer'**
  String get invoiceListSearchHint;

  /// Tooltip on the invoice list sort menu
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get invoiceListSortTooltip;

  /// Empty state on the invoice list
  ///
  /// In en, this message translates to:
  /// **'No invoices match your filters.'**
  String get invoiceListEmpty;

  /// Failure body on the invoice list
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load invoices: {message}'**
  String invoiceListError(String message);

  /// Subtitle suffix "due 2026-06-01" on each invoice tile
  ///
  /// In en, this message translates to:
  /// **'due {date}'**
  String invoiceListDueLabel(String date);

  /// Invoice approval status — editable, not yet submitted
  ///
  /// In en, this message translates to:
  /// **'Draft'**
  String get invoiceStatusDraft;

  /// Invoice approval status — submitted, awaiting decision
  ///
  /// In en, this message translates to:
  /// **'Pending approval'**
  String get invoiceStatusPendingApproval;

  /// Invoice approval status — approver said yes
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get invoiceStatusApproved;

  /// Invoice approval status — approver said no
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get invoiceStatusRejected;

  /// Invoice list sort axis
  ///
  /// In en, this message translates to:
  /// **'Issued (newest)'**
  String get invoiceSortIssuedDesc;

  /// Invoice list sort axis
  ///
  /// In en, this message translates to:
  /// **'Issued (oldest)'**
  String get invoiceSortIssuedAsc;

  /// Invoice list sort axis
  ///
  /// In en, this message translates to:
  /// **'Due (soonest)'**
  String get invoiceSortDueAsc;

  /// Invoice list sort axis
  ///
  /// In en, this message translates to:
  /// **'Amount (largest)'**
  String get invoiceSortAmountDesc;

  /// Invoice list sort axis
  ///
  /// In en, this message translates to:
  /// **'Invoice number'**
  String get invoiceSortNumberAsc;

  /// Slice 3.2.2 detail AppBar title
  ///
  /// In en, this message translates to:
  /// **'Invoice'**
  String get invoiceDetailTitle;

  /// Header meta label
  ///
  /// In en, this message translates to:
  /// **'Issued'**
  String get invoiceDetailIssuedLabel;

  /// Header meta label
  ///
  /// In en, this message translates to:
  /// **'Due'**
  String get invoiceDetailDueLabel;

  /// Section heading
  ///
  /// In en, this message translates to:
  /// **'Line items'**
  String get invoiceDetailLinesHeading;

  /// Totals row label
  ///
  /// In en, this message translates to:
  /// **'Subtotal'**
  String get invoiceDetailSubtotalLabel;

  /// Totals row label
  ///
  /// In en, this message translates to:
  /// **'Tax'**
  String get invoiceDetailTaxLabel;

  /// Totals row label
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get invoiceDetailTotalLabel;

  /// Notes section heading
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get invoiceDetailNotesHeading;

  /// Heading on the PDF placeholder card
  ///
  /// In en, this message translates to:
  /// **'PDF preview'**
  String get invoiceDetailPdfHeading;

  /// Body on the PDF placeholder card
  ///
  /// In en, this message translates to:
  /// **'PDF rendering ships with the backend that serves it.'**
  String get invoiceDetailPdfPlaceholder;

  /// Not-found body on the detail page
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t find an invoice with id \"{invoiceId}\".'**
  String invoiceDetailNotFound(String invoiceId);

  /// Failure body on the detail page
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load this invoice: {message}'**
  String invoiceDetailError(String message);

  /// Slice 3.2.4 approve button label
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get invoiceApproveAction;

  /// Slice 3.2.4 reject button label
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get invoiceRejectAction;

  /// Slice 3.2.4 draft → pendingApproval transition button
  ///
  /// In en, this message translates to:
  /// **'Submit for approval'**
  String get invoiceSubmitAction;

  /// Slice 3.2.4 rejected → draft transition button
  ///
  /// In en, this message translates to:
  /// **'Re-open for revision'**
  String get invoiceReopenAction;

  /// Generic cancel for approve/reject bottom sheets
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get invoiceActionCancel;

  /// Approve bottom sheet title
  ///
  /// In en, this message translates to:
  /// **'Approve this invoice?'**
  String get invoiceApproveSheetTitle;

  /// Approve bottom sheet body
  ///
  /// In en, this message translates to:
  /// **'You\'re about to approve {invoiceNumber}. The invoice will be locked once approved.'**
  String invoiceApproveSheetBody(String invoiceNumber);

  /// Reject bottom sheet title
  ///
  /// In en, this message translates to:
  /// **'Reject this invoice?'**
  String get invoiceRejectSheetTitle;

  /// Reject bottom sheet body
  ///
  /// In en, this message translates to:
  /// **'{invoiceNumber} will be returned to the requester with the reason below.'**
  String invoiceRejectSheetBody(String invoiceNumber);

  /// Reject reason field label
  ///
  /// In en, this message translates to:
  /// **'Reason'**
  String get invoiceRejectReasonLabel;

  /// Reject reason field hint
  ///
  /// In en, this message translates to:
  /// **'Why is this invoice being rejected?'**
  String get invoiceRejectReasonHint;

  /// Reject form validator — empty reason
  ///
  /// In en, this message translates to:
  /// **'Please give a reason.'**
  String get invoiceRejectReasonRequired;

  /// Snackbar after a successful workflow action
  ///
  /// In en, this message translates to:
  /// **'Invoice marked as {status}.'**
  String invoiceActionSuccess(String status);

  /// Snackbar when finance.approve is missing
  ///
  /// In en, this message translates to:
  /// **'You don\'t have permission to action this invoice.'**
  String get invoiceActionForbidden;

  /// Snackbar when the invoice id is unknown
  ///
  /// In en, this message translates to:
  /// **'That invoice no longer exists.'**
  String get invoiceActionNotFound;

  /// Snackbar for the InvalidStateFailure / no-double-action guard
  ///
  /// In en, this message translates to:
  /// **'This invoice has already been actioned.'**
  String get invoiceActionInvalidState;

  /// Snackbar when no signed-in user is present
  ///
  /// In en, this message translates to:
  /// **'Sign-in expired — please sign in again.'**
  String get invoiceActionUnauthorized;

  /// Fallback snackbar for unmapped failures
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t action the invoice: {message}'**
  String invoiceActionGenericError(String message);

  /// Audit card heading on approved invoices
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get invoiceAuditApprovedHeading;

  /// Audit card heading on rejected invoices
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get invoiceAuditRejectedHeading;

  /// Audit card — who actioned
  ///
  /// In en, this message translates to:
  /// **'by {userId}'**
  String invoiceAuditActorLine(String userId);

  /// Audit card — when actioned
  ///
  /// In en, this message translates to:
  /// **'at {when}'**
  String invoiceAuditWhenLine(String when);

  /// Audit card — rejection reason
  ///
  /// In en, this message translates to:
  /// **'Reason: {reason}'**
  String invoiceAuditReasonLine(String reason);

  /// Slice 3.2.3 form AppBar title (create mode)
  ///
  /// In en, this message translates to:
  /// **'New invoice'**
  String get invoiceFormCreateTitle;

  /// Slice 3.2.3 form AppBar title (edit mode)
  ///
  /// In en, this message translates to:
  /// **'Edit invoice'**
  String get invoiceFormEditTitle;

  /// Tooltip on the save action
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get invoiceFormSaveTooltip;

  /// Bottom save button label
  ///
  /// In en, this message translates to:
  /// **'Save invoice'**
  String get invoiceFormSaveAction;

  /// Snackbar after a successful save
  ///
  /// In en, this message translates to:
  /// **'Invoice saved.'**
  String get invoiceFormSavedSnack;

  /// Form field label
  ///
  /// In en, this message translates to:
  /// **'Customer'**
  String get invoiceFormCustomerLabel;

  /// Form field label
  ///
  /// In en, this message translates to:
  /// **'Issued date'**
  String get invoiceFormIssuedLabel;

  /// Form field label
  ///
  /// In en, this message translates to:
  /// **'Due date'**
  String get invoiceFormDueLabel;

  /// Section heading
  ///
  /// In en, this message translates to:
  /// **'Line item'**
  String get invoiceFormLineHeading;

  /// Form field label
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get invoiceFormLineDescriptionLabel;

  /// Form field label
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get invoiceFormLineQuantityLabel;

  /// Form field label
  ///
  /// In en, this message translates to:
  /// **'Unit price'**
  String get invoiceFormLineUnitPriceLabel;

  /// Form validator: empty field
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get validatorRequired;

  /// Form validator: non-numeric
  ///
  /// In en, this message translates to:
  /// **'Must be a number'**
  String get validatorInvalidNumber;

  /// Form validator: zero or negative
  ///
  /// In en, this message translates to:
  /// **'Must be greater than 0'**
  String get validatorMustBePositive;

  /// Form validator: negative
  ///
  /// In en, this message translates to:
  /// **'Cannot be negative'**
  String get validatorMustBeNonNegative;

  /// Form validator: due-before-issued
  ///
  /// In en, this message translates to:
  /// **'Due date must be on or after the issued date'**
  String get validatorDueBeforeIssued;

  /// Slice 3.3.1 AppBar title
  ///
  /// In en, this message translates to:
  /// **'Journal entries'**
  String get journalEntriesTitle;

  /// Empty state on the journal entry list
  ///
  /// In en, this message translates to:
  /// **'No journal entries posted in this period.'**
  String get journalEntriesEmpty;

  /// Detail page AppBar title
  ///
  /// In en, this message translates to:
  /// **'Journal entry'**
  String get journalEntryDetailTitle;

  /// Not-found body
  ///
  /// In en, this message translates to:
  /// **'Journal entry \"{id}\" was not found.'**
  String journalEntryNotFound(String id);

  /// Detail table column header
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get journalEntryAccountColumn;

  /// Detail table column header
  ///
  /// In en, this message translates to:
  /// **'Debit'**
  String get journalEntryDebitColumn;

  /// Detail table column header
  ///
  /// In en, this message translates to:
  /// **'Credit'**
  String get journalEntryCreditColumn;

  /// Detail totals row label
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get journalEntryTotalLabel;

  /// Slice 3.3.2 AppBar title
  ///
  /// In en, this message translates to:
  /// **'Trial balance'**
  String get trialBalanceTitle;

  /// Empty state on the trial balance
  ///
  /// In en, this message translates to:
  /// **'No accounts have non-zero balances yet.'**
  String get trialBalanceEmpty;

  /// Trial balance column header
  ///
  /// In en, this message translates to:
  /// **'Code'**
  String get trialBalanceColumnCode;

  /// Trial balance column header
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get trialBalanceColumnName;

  /// Trial balance column header
  ///
  /// In en, this message translates to:
  /// **'Debit'**
  String get trialBalanceColumnDebit;

  /// Trial balance column header
  ///
  /// In en, this message translates to:
  /// **'Credit'**
  String get trialBalanceColumnCredit;

  /// Pagination chip text
  ///
  /// In en, this message translates to:
  /// **'Page {current} of {total}'**
  String trialBalancePageOf(int current, int total);

  /// Slice 3.3.3 export action tooltip
  ///
  /// In en, this message translates to:
  /// **'Export CSV'**
  String get trialBalanceExportCsvTooltip;

  /// Snackbar after a successful export
  ///
  /// In en, this message translates to:
  /// **'CSV saved to {path}'**
  String trialBalanceExportSuccess(String path);

  /// Snackbar after a failed export
  ///
  /// In en, this message translates to:
  /// **'CSV export failed: {message}'**
  String trialBalanceExportError(String message);

  /// Form validator: bad email
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid email'**
  String get validatorInvalidEmail;

  /// Slice 4.1.1 PR list AppBar title
  ///
  /// In en, this message translates to:
  /// **'Purchase requests'**
  String get prListTitle;

  /// AppBar add-button tooltip
  ///
  /// In en, this message translates to:
  /// **'New PR'**
  String get prListNewTooltip;

  /// PR list search field hint
  ///
  /// In en, this message translates to:
  /// **'Search by number, requester, cost center'**
  String get prListSearchHint;

  /// PR list sort menu tooltip
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get prListSortTooltip;

  /// PR list empty state
  ///
  /// In en, this message translates to:
  /// **'No purchase requests match your filters.'**
  String get prListEmpty;

  /// PR list failure body
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load purchase requests: {message}'**
  String prListError(String message);

  /// PR status label
  ///
  /// In en, this message translates to:
  /// **'Draft'**
  String get prStatusDraft;

  /// PR status label
  ///
  /// In en, this message translates to:
  /// **'Submitted'**
  String get prStatusSubmitted;

  /// PR status label
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get prStatusApproved;

  /// PR status label
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get prStatusRejected;

  /// PR status label — PR has become a PO
  ///
  /// In en, this message translates to:
  /// **'Converted'**
  String get prStatusConverted;

  /// PR sort axis
  ///
  /// In en, this message translates to:
  /// **'Created (newest)'**
  String get prSortCreatedDesc;

  /// PR sort axis
  ///
  /// In en, this message translates to:
  /// **'Created (oldest)'**
  String get prSortCreatedAsc;

  /// PR sort axis
  ///
  /// In en, this message translates to:
  /// **'Total (largest)'**
  String get prSortTotalDesc;

  /// PR sort axis
  ///
  /// In en, this message translates to:
  /// **'PR number'**
  String get prSortNumberAsc;

  /// Slice 4.1.2 form AppBar title
  ///
  /// In en, this message translates to:
  /// **'New purchase request'**
  String get prFormCreateTitle;

  /// PR form save button tooltip
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get prFormSaveTooltip;

  /// PR form bottom submit button
  ///
  /// In en, this message translates to:
  /// **'Submit request'**
  String get prFormSubmitAction;

  /// Snackbar after PR save
  ///
  /// In en, this message translates to:
  /// **'Purchase request submitted.'**
  String get prFormSavedSnack;

  /// Snackbar after PR save failure
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t submit the request: {message}'**
  String prFormSaveFailed(String message);

  /// PR form field label
  ///
  /// In en, this message translates to:
  /// **'Requester'**
  String get prFormRequesterLabel;

  /// PR form field label
  ///
  /// In en, this message translates to:
  /// **'Cost center'**
  String get prFormCostCenterLabel;

  /// PR form field label
  ///
  /// In en, this message translates to:
  /// **'Approver'**
  String get prFormApproverLabel;

  /// PR form field label
  ///
  /// In en, this message translates to:
  /// **'Justification (optional)'**
  String get prFormJustificationLabel;

  /// PR form lines section heading
  ///
  /// In en, this message translates to:
  /// **'Line items'**
  String get prFormLinesHeading;

  /// Per-line numbered heading inside the PR form
  ///
  /// In en, this message translates to:
  /// **'Line {index}'**
  String prFormLineHeading(int index);

  /// PR form add-line button
  ///
  /// In en, this message translates to:
  /// **'Add line'**
  String get prFormAddLineAction;

  /// PR form remove-line tooltip
  ///
  /// In en, this message translates to:
  /// **'Remove line'**
  String get prFormRemoveLineTooltip;

  /// PR line field label
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get prFormLineDescriptionLabel;

  /// PR line field label
  ///
  /// In en, this message translates to:
  /// **'Qty'**
  String get prFormLineQuantityLabel;

  /// PR line field label
  ///
  /// In en, this message translates to:
  /// **'Unit price'**
  String get prFormLineUnitPriceLabel;

  /// Slice 4.1.3 detail AppBar title
  ///
  /// In en, this message translates to:
  /// **'Purchase request'**
  String get prDetailTitle;

  /// Not-found body on PR detail
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t find a purchase request with id \"{prId}\".'**
  String prDetailNotFound(String prId);

  /// Failure body on PR detail
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load this purchase request: {message}'**
  String prDetailError(String message);

  /// PR detail meta label
  ///
  /// In en, this message translates to:
  /// **'Requester'**
  String get prDetailRequesterLabel;

  /// PR detail meta label
  ///
  /// In en, this message translates to:
  /// **'Cost center'**
  String get prDetailCostCenterLabel;

  /// PR detail meta label
  ///
  /// In en, this message translates to:
  /// **'Approver'**
  String get prDetailApproverLabel;

  /// PR detail meta label
  ///
  /// In en, this message translates to:
  /// **'Created'**
  String get prDetailCreatedLabel;

  /// PR detail section heading
  ///
  /// In en, this message translates to:
  /// **'Justification'**
  String get prDetailJustificationHeading;

  /// PR detail section heading
  ///
  /// In en, this message translates to:
  /// **'Line items'**
  String get prDetailLinesHeading;

  /// PR detail total row label
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get prDetailTotalLabel;

  /// PR detail action
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get prApproveAction;

  /// PR detail action
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get prRejectAction;

  /// PR detail action — draft → submitted
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get prSubmitAction;

  /// PR detail action — approved → PO
  ///
  /// In en, this message translates to:
  /// **'Convert to PO'**
  String get prConvertAction;

  /// Snackbar after PR submit
  ///
  /// In en, this message translates to:
  /// **'Purchase request submitted.'**
  String get prSubmittedSnack;

  /// Snackbar after PR approval
  ///
  /// In en, this message translates to:
  /// **'Purchase request marked as {status}.'**
  String prApprovedSnack(String status);

  /// Snackbar after PR reject
  ///
  /// In en, this message translates to:
  /// **'Purchase request rejected.'**
  String get prRejectedSnack;

  /// Snackbar after PR→PO convert
  ///
  /// In en, this message translates to:
  /// **'Purchase order created.'**
  String get prConvertedSnack;

  /// Snackbar when transition is illegal
  ///
  /// In en, this message translates to:
  /// **'This request can\'t be {action} from its current status.'**
  String prApprovalNotAllowed(String action);

  /// Snackbar after persistence failure
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t update the request: {message}'**
  String prApprovalFailed(String message);

  /// Reject dialog title
  ///
  /// In en, this message translates to:
  /// **'Reject request'**
  String get prRejectDialogTitle;

  /// Reject dialog field label
  ///
  /// In en, this message translates to:
  /// **'Reason'**
  String get prRejectReasonLabel;

  /// Reject dialog field hint
  ///
  /// In en, this message translates to:
  /// **'Why is this request being rejected?'**
  String get prRejectReasonHint;

  /// Reject dialog validation
  ///
  /// In en, this message translates to:
  /// **'Please give a reason.'**
  String get prRejectReasonRequired;

  /// Reject dialog cancel
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get prRejectCancel;

  /// Reject dialog confirm
  ///
  /// In en, this message translates to:
  /// **'Reject request'**
  String get prRejectConfirm;

  /// Convert dialog title
  ///
  /// In en, this message translates to:
  /// **'Convert to purchase order'**
  String get prConvertDialogTitle;

  /// Convert dialog vendor field
  ///
  /// In en, this message translates to:
  /// **'Vendor'**
  String get prConvertVendorLabel;

  /// Convert dialog date field
  ///
  /// In en, this message translates to:
  /// **'Expected delivery'**
  String get prConvertExpectedLabel;

  /// Convert dialog validation
  ///
  /// In en, this message translates to:
  /// **'Please pick a vendor.'**
  String get prConvertVendorRequired;

  /// Convert dialog confirm
  ///
  /// In en, this message translates to:
  /// **'Create PO'**
  String get prConvertConfirm;

  /// Convert dialog cancel
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get prConvertCancel;

  /// Slice 4.2.1 list AppBar title
  ///
  /// In en, this message translates to:
  /// **'Purchase orders'**
  String get poListTitle;

  /// PO list empty state
  ///
  /// In en, this message translates to:
  /// **'No purchase orders yet.'**
  String get poListEmpty;

  /// PO list subtitle
  ///
  /// In en, this message translates to:
  /// **'expected {date}'**
  String poListExpectedLabel(String date);

  /// PO status label
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get poStatusOpen;

  /// PO status label
  ///
  /// In en, this message translates to:
  /// **'Partial'**
  String get poStatusPartial;

  /// PO status label
  ///
  /// In en, this message translates to:
  /// **'Received'**
  String get poStatusFull;

  /// PO status label
  ///
  /// In en, this message translates to:
  /// **'Closed'**
  String get poStatusClosed;

  /// PO status label
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get poStatusCancelled;

  /// PO detail AppBar title
  ///
  /// In en, this message translates to:
  /// **'Purchase order'**
  String get poDetailTitle;

  /// PO not-found body
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t find a purchase order with id \"{poId}\".'**
  String poDetailNotFound(String poId);

  /// PO detail meta label
  ///
  /// In en, this message translates to:
  /// **'Created'**
  String get poDetailCreatedLabel;

  /// PO detail meta label
  ///
  /// In en, this message translates to:
  /// **'Expected'**
  String get poDetailExpectedLabel;

  /// PO detail meta label
  ///
  /// In en, this message translates to:
  /// **'Source PR'**
  String get poDetailSourcePrLabel;

  /// PO detail section heading
  ///
  /// In en, this message translates to:
  /// **'Line items'**
  String get poDetailLinesHeading;

  /// PO detail total row
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get poDetailTotalLabel;

  /// PO detail receipts section heading
  ///
  /// In en, this message translates to:
  /// **'Goods receipts'**
  String get poDetailReceiptsHeading;

  /// PO detail empty receipts message
  ///
  /// In en, this message translates to:
  /// **'No receipts recorded yet.'**
  String get poDetailReceiptsEmpty;

  /// Badge showing how many lines a receipt covered
  ///
  /// In en, this message translates to:
  /// **'{count} item(s)'**
  String poDetailReceiptItemsBadge(int count);

  /// PO detail bottom action
  ///
  /// In en, this message translates to:
  /// **'Record goods receipt'**
  String get poDetailRecordReceiptAction;

  /// PO line meta
  ///
  /// In en, this message translates to:
  /// **'ordered {qty}'**
  String poLineOrderedLabel(String qty);

  /// PO line meta
  ///
  /// In en, this message translates to:
  /// **'received {qty}'**
  String poLineReceivedLabel(String qty);

  /// PO line meta
  ///
  /// In en, this message translates to:
  /// **'outstanding {qty}'**
  String poLineOutstandingLabel(String qty);

  /// Slice 4.2.3 form title
  ///
  /// In en, this message translates to:
  /// **'Goods receipt'**
  String get goodsReceiptFormTitle;

  /// GR form subtitle
  ///
  /// In en, this message translates to:
  /// **'Receiving against {number}'**
  String goodsReceiptFormForPo(String number);

  /// GR form field
  ///
  /// In en, this message translates to:
  /// **'Received by'**
  String get goodsReceiptReceivedByLabel;

  /// GR form field
  ///
  /// In en, this message translates to:
  /// **'Note (optional)'**
  String get goodsReceiptNoteLabel;

  /// GR form section heading
  ///
  /// In en, this message translates to:
  /// **'Quantities received'**
  String get goodsReceiptLinesHeading;

  /// GR form per-line input
  ///
  /// In en, this message translates to:
  /// **'Receiving now'**
  String get goodsReceiptQuantityLabel;

  /// GR form submit
  ///
  /// In en, this message translates to:
  /// **'Record receipt'**
  String get goodsReceiptSubmitAction;

  /// GR snackbar
  ///
  /// In en, this message translates to:
  /// **'Goods receipt recorded.'**
  String get goodsReceiptSavedSnack;

  /// GR failure snackbar
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t record receipt: {message}'**
  String goodsReceiptSaveFailed(String message);

  /// GR validator error
  ///
  /// In en, this message translates to:
  /// **'This PO is closed and can\'t take more receipts.'**
  String get goodsReceiptErrorPoClosed;

  /// GR validator error
  ///
  /// In en, this message translates to:
  /// **'Enter a quantity for at least one line.'**
  String get goodsReceiptErrorNoLines;

  /// GR validator error
  ///
  /// In en, this message translates to:
  /// **'Quantity must be greater than 0.'**
  String get goodsReceiptErrorNonPositive;

  /// GR validator error
  ///
  /// In en, this message translates to:
  /// **'One of the lines doesn\'t belong to this PO.'**
  String get goodsReceiptErrorUnknownLine;

  /// GR validator error
  ///
  /// In en, this message translates to:
  /// **'You can\'t receive more than the outstanding quantity.'**
  String get goodsReceiptErrorExceedsOutstanding;

  /// Slice 4.3.1 list AppBar title
  ///
  /// In en, this message translates to:
  /// **'Vendors'**
  String get vendorListTitle;

  /// Vendor list empty state
  ///
  /// In en, this message translates to:
  /// **'No vendors onboarded yet.'**
  String get vendorListEmpty;

  /// AppBar add tooltip
  ///
  /// In en, this message translates to:
  /// **'Onboard vendor'**
  String get vendorListNewTooltip;

  /// Vendor status label
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get vendorStatusActive;

  /// Vendor status label
  ///
  /// In en, this message translates to:
  /// **'On hold'**
  String get vendorStatusOnHold;

  /// Vendor status label
  ///
  /// In en, this message translates to:
  /// **'Archived'**
  String get vendorStatusArchived;

  /// Vendor detail AppBar title
  ///
  /// In en, this message translates to:
  /// **'Vendor'**
  String get vendorDetailTitle;

  /// Vendor not-found body
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t find a vendor with id \"{vendorId}\".'**
  String vendorDetailNotFound(String vendorId);

  /// Vendor detail meta
  ///
  /// In en, this message translates to:
  /// **'Tax ID'**
  String get vendorDetailTaxIdLabel;

  /// Vendor detail meta
  ///
  /// In en, this message translates to:
  /// **'Onboarded'**
  String get vendorDetailOnboardedLabel;

  /// Vendor detail section
  ///
  /// In en, this message translates to:
  /// **'Contact'**
  String get vendorDetailContactHeading;

  /// Vendor detail field
  ///
  /// In en, this message translates to:
  /// **'Contact person'**
  String get vendorDetailContactPersonLabel;

  /// Vendor detail field
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get vendorDetailEmailLabel;

  /// Vendor detail field
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get vendorDetailPhoneLabel;

  /// Vendor detail field
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get vendorDetailAddressLabel;

  /// Vendor detail section
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get vendorDetailNotesHeading;

  /// Vendor detail link to 4.3.3
  ///
  /// In en, this message translates to:
  /// **'View performance scorecard'**
  String get vendorDetailScorecardAction;

  /// Slice 4.3.2 form title
  ///
  /// In en, this message translates to:
  /// **'Onboard vendor'**
  String get vendorFormTitle;

  /// Vendor form save tooltip
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get vendorFormSaveTooltip;

  /// Vendor form bottom save button
  ///
  /// In en, this message translates to:
  /// **'Save vendor'**
  String get vendorFormSaveAction;

  /// Vendor save snackbar
  ///
  /// In en, this message translates to:
  /// **'Vendor onboarded.'**
  String get vendorFormSavedSnack;

  /// Vendor save failure snackbar
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save the vendor: {message}'**
  String vendorFormSaveFailed(String message);

  /// Vendor form field
  ///
  /// In en, this message translates to:
  /// **'Vendor name'**
  String get vendorFormNameLabel;

  /// Vendor form field
  ///
  /// In en, this message translates to:
  /// **'Tax ID'**
  String get vendorFormTaxIdLabel;

  /// Vendor form field
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get vendorFormEmailLabel;

  /// Vendor form field
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get vendorFormPhoneLabel;

  /// Vendor form field
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get vendorFormAddressLabel;

  /// Vendor form field
  ///
  /// In en, this message translates to:
  /// **'Contact person (optional)'**
  String get vendorFormContactPersonLabel;

  /// Vendor form field
  ///
  /// In en, this message translates to:
  /// **'Notes (optional)'**
  String get vendorFormNotesLabel;

  /// Slice 4.3.3 page title
  ///
  /// In en, this message translates to:
  /// **'Vendor scorecard'**
  String get vendorScorecardTitle;

  /// Composite section label
  ///
  /// In en, this message translates to:
  /// **'Composite score'**
  String get vendorScorecardCompositeLabel;

  /// Metric label
  ///
  /// In en, this message translates to:
  /// **'On-time delivery'**
  String get vendorScorecardOnTimeLabel;

  /// Metric label
  ///
  /// In en, this message translates to:
  /// **'Defect rate'**
  String get vendorScorecardDefectLabel;

  /// Metric label
  ///
  /// In en, this message translates to:
  /// **'Open disputes'**
  String get vendorScorecardDisputesLabel;

  /// Metric label
  ///
  /// In en, this message translates to:
  /// **'Total spend'**
  String get vendorScorecardSpendLabel;

  /// Slice 5.1.1 list AppBar title
  ///
  /// In en, this message translates to:
  /// **'Inventory items'**
  String get inventoryItemsTitle;

  /// AppBar scan button tooltip
  ///
  /// In en, this message translates to:
  /// **'Scan barcode'**
  String get inventoryScanTooltip;

  /// AppBar alerts button tooltip
  ///
  /// In en, this message translates to:
  /// **'Low stock alerts'**
  String get inventoryLowStockAlertsTooltip;

  /// Items list search hint
  ///
  /// In en, this message translates to:
  /// **'Search by SKU, name, location, barcode'**
  String get inventoryItemsSearchHint;

  /// Items list sort tooltip
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get inventoryItemsSortTooltip;

  /// Items list empty state
  ///
  /// In en, this message translates to:
  /// **'No items match the current filters.'**
  String get inventoryItemsEmpty;

  /// Items list failure body
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load inventory: {message}'**
  String inventoryItemsError(String message);

  /// Items list trailing — current on-hand
  ///
  /// In en, this message translates to:
  /// **'on-hand {qty}'**
  String inventoryItemsOnHand(String qty);

  /// Badge under on-hand when item is at/below reorder
  ///
  /// In en, this message translates to:
  /// **'reorder at {qty}'**
  String inventoryReorderBadge(String qty);

  /// Filter chip — low-stock only
  ///
  /// In en, this message translates to:
  /// **'Low stock only'**
  String get inventoryLowStockChip;

  /// Sort axis
  ///
  /// In en, this message translates to:
  /// **'Name (A–Z)'**
  String get inventorySortNameAsc;

  /// Sort axis
  ///
  /// In en, this message translates to:
  /// **'SKU'**
  String get inventorySortSkuAsc;

  /// Sort axis
  ///
  /// In en, this message translates to:
  /// **'On-hand (low first)'**
  String get inventorySortOnHandAsc;

  /// Sort axis
  ///
  /// In en, this message translates to:
  /// **'On-hand (high first)'**
  String get inventorySortOnHandDesc;

  /// Slice 5.1.2 detail AppBar title
  ///
  /// In en, this message translates to:
  /// **'Item'**
  String get inventoryItemDetailTitle;

  /// Detail not-found body
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t find an item with id \"{itemId}\".'**
  String inventoryItemNotFound(String itemId);

  /// Detail meta label
  ///
  /// In en, this message translates to:
  /// **'Warehouse'**
  String get inventoryDetailWarehouseLabel;

  /// Detail meta label
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get inventoryDetailLocationLabel;

  /// Detail meta label
  ///
  /// In en, this message translates to:
  /// **'Reorder point'**
  String get inventoryDetailReorderLabel;

  /// Detail meta label
  ///
  /// In en, this message translates to:
  /// **'Unit cost'**
  String get inventoryDetailUnitCostLabel;

  /// Detail meta label
  ///
  /// In en, this message translates to:
  /// **'Barcode'**
  String get inventoryDetailBarcodeLabel;

  /// Detail section heading
  ///
  /// In en, this message translates to:
  /// **'Movement history'**
  String get inventoryDetailMovementsHeading;

  /// Detail empty ledger
  ///
  /// In en, this message translates to:
  /// **'No movements recorded yet.'**
  String get inventoryDetailMovementsEmpty;

  /// Ledger row label
  ///
  /// In en, this message translates to:
  /// **'Goods receipt'**
  String get inventoryMovementTypeReceipt;

  /// Ledger row label
  ///
  /// In en, this message translates to:
  /// **'Goods issue'**
  String get inventoryMovementTypeIssue;

  /// Ledger row label
  ///
  /// In en, this message translates to:
  /// **'Transfer'**
  String get inventoryMovementTypeTransfer;

  /// Ledger row label
  ///
  /// In en, this message translates to:
  /// **'Adjustment'**
  String get inventoryMovementTypeAdjustment;

  /// Trailing running-balance on a ledger row
  ///
  /// In en, this message translates to:
  /// **'balance {qty}'**
  String inventoryMovementRunningLabel(String qty);

  /// Detail bottom-bar action
  ///
  /// In en, this message translates to:
  /// **'Issue'**
  String get inventoryIssueAction;

  /// Detail bottom-bar action
  ///
  /// In en, this message translates to:
  /// **'Receive'**
  String get inventoryReceiptAction;

  /// Detail bottom-bar action
  ///
  /// In en, this message translates to:
  /// **'Transfer'**
  String get inventoryTransferAction;

  /// Slice 5.1.3 alerts page title
  ///
  /// In en, this message translates to:
  /// **'Low stock'**
  String get inventoryLowStockTitle;

  /// Alerts empty state
  ///
  /// In en, this message translates to:
  /// **'Every item is above its reorder point.'**
  String get inventoryLowStockEmpty;

  /// Slice 5.2.1 scanner title
  ///
  /// In en, this message translates to:
  /// **'Scan barcode'**
  String get inventoryScannerTitle;

  /// Inline error when scan/entry is empty
  ///
  /// In en, this message translates to:
  /// **'Scan or enter a code.'**
  String get inventoryScannerEmpty;

  /// Inline error when barcode resolves to nothing
  ///
  /// In en, this message translates to:
  /// **'No item matches \"{code}\".'**
  String inventoryScannerUnknown(String code);

  /// Snackbar for scanner exceptions
  ///
  /// In en, this message translates to:
  /// **'Scanner error: {message}'**
  String inventoryScannerError(String message);

  /// Shown on web/desktop instead of the camera preview
  ///
  /// In en, this message translates to:
  /// **'Camera not available on this platform — use manual entry below.'**
  String get inventoryScannerNoCamera;

  /// Heading for the manual entry section
  ///
  /// In en, this message translates to:
  /// **'Manual entry'**
  String get inventoryScannerManualHeading;

  /// Manual entry field label
  ///
  /// In en, this message translates to:
  /// **'Barcode'**
  String get inventoryScannerManualLabel;

  /// Manual entry field hint
  ///
  /// In en, this message translates to:
  /// **'Type or paste a code'**
  String get inventoryScannerManualHint;

  /// Manual entry submit button
  ///
  /// In en, this message translates to:
  /// **'Use'**
  String get inventoryScannerManualUseAction;

  /// Fallback link to the catalog list
  ///
  /// In en, this message translates to:
  /// **'Browse the catalog instead'**
  String get inventoryScannerBrowseFallback;

  /// Slice 5.2.2 GR form title
  ///
  /// In en, this message translates to:
  /// **'Receive stock'**
  String get inventoryReceiptFormTitle;

  /// Slice 5.2.2 GI form title
  ///
  /// In en, this message translates to:
  /// **'Issue stock'**
  String get inventoryIssueFormTitle;

  /// GR success snackbar
  ///
  /// In en, this message translates to:
  /// **'Stock received.'**
  String get inventoryReceiptSuccessSnack;

  /// GI success snackbar
  ///
  /// In en, this message translates to:
  /// **'Stock issued.'**
  String get inventoryIssueSuccessSnack;

  /// Fallback success snackbar
  ///
  /// In en, this message translates to:
  /// **'Movement recorded.'**
  String get inventoryMovementGenericSuccess;

  /// Failure snackbar
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t record movement: {message}'**
  String inventoryMovementFailed(String message);

  /// Form header showing current quantity
  ///
  /// In en, this message translates to:
  /// **'Current on-hand: {qty}'**
  String inventoryFormCurrentOnHand(String qty);

  /// Form field
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get inventoryFormQuantityLabel;

  /// Form field
  ///
  /// In en, this message translates to:
  /// **'Reference (optional)'**
  String get inventoryFormReferenceLabel;

  /// Form hint
  ///
  /// In en, this message translates to:
  /// **'e.g. PO-2026-001'**
  String get inventoryFormReferenceReceiptHint;

  /// Form hint
  ///
  /// In en, this message translates to:
  /// **'e.g. SO-2026-014'**
  String get inventoryFormReferenceIssueHint;

  /// Form field
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get inventoryFormNoteLabel;

  /// Inline error when issue qty > on-hand
  ///
  /// In en, this message translates to:
  /// **'Quantity exceeds the current on-hand.'**
  String get inventoryQtyExceedsOnHand;

  /// Slice 5.2.3 transfer form title
  ///
  /// In en, this message translates to:
  /// **'Transfer stock'**
  String get inventoryTransferFormTitle;

  /// Source card heading
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get inventoryTransferSourceHeading;

  /// Destination dropdown label
  ///
  /// In en, this message translates to:
  /// **'Destination bin'**
  String get inventoryTransferDestinationLabel;

  /// Empty destinations message
  ///
  /// In en, this message translates to:
  /// **'No active destination bins available for this SKU.'**
  String get inventoryTransferNoDestinations;

  /// Transfer reference hint
  ///
  /// In en, this message translates to:
  /// **'Internal transfer note'**
  String get inventoryTransferReferenceHint;

  /// Snackbar when destination missing
  ///
  /// In en, this message translates to:
  /// **'Please pick a destination bin.'**
  String get inventoryTransferPickDestination;

  /// Transfer success snackbar
  ///
  /// In en, this message translates to:
  /// **'Stock transferred.'**
  String get inventoryTransferSuccess;

  /// Slice 5.2.4 cycle count title
  ///
  /// In en, this message translates to:
  /// **'Cycle count'**
  String get inventoryCycleCountTitle;

  /// Empty state
  ///
  /// In en, this message translates to:
  /// **'No items to count.'**
  String get inventoryCycleNoItems;

  /// Filter chip — no warehouse filter
  ///
  /// In en, this message translates to:
  /// **'All warehouses'**
  String get inventoryCycleAllWarehouses;

  /// Per-line expected qty
  ///
  /// In en, this message translates to:
  /// **'expected {qty}'**
  String inventoryCycleExpectedLabel(String qty);

  /// Per-line counted qty input
  ///
  /// In en, this message translates to:
  /// **'Counted'**
  String get inventoryCycleCountedLabel;

  /// Snackbar when no lines
  ///
  /// In en, this message translates to:
  /// **'Enter a counted quantity for at least one item.'**
  String get inventoryCycleEmpty;

  /// Cycle count bottom action
  ///
  /// In en, this message translates to:
  /// **'Submit count'**
  String get inventoryCycleSubmitAction;

  /// Cycle count success snackbar
  ///
  /// In en, this message translates to:
  /// **'Posted {count} adjustment(s); variance {variance}.'**
  String inventoryCycleSuccess(int count, String variance);

  /// Slice 6.1.1 list AppBar title
  ///
  /// In en, this message translates to:
  /// **'Customers'**
  String get salesCustomersTitle;

  /// AppBar analytics button tooltip
  ///
  /// In en, this message translates to:
  /// **'Analytics'**
  String get salesAnalyticsTooltip;

  /// Customer list search hint
  ///
  /// In en, this message translates to:
  /// **'Search by name, email, industry'**
  String get salesCustomersSearchHint;

  /// Customer list sort tooltip
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get salesCustomersSortTooltip;

  /// Customer list empty state
  ///
  /// In en, this message translates to:
  /// **'No customers match your filters.'**
  String get salesCustomersEmpty;

  /// Customer list failure body
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load customers: {message}'**
  String salesCustomersError(String message);

  /// Subtitle date label
  ///
  /// In en, this message translates to:
  /// **'since {date}'**
  String salesCustomersOnboardedLabel(String date);

  /// Sort axis
  ///
  /// In en, this message translates to:
  /// **'Name (A–Z)'**
  String get salesCustomersSortName;

  /// Sort axis
  ///
  /// In en, this message translates to:
  /// **'Lifetime value'**
  String get salesCustomersSortLtv;

  /// Sort axis
  ///
  /// In en, this message translates to:
  /// **'Recently added'**
  String get salesCustomersSortRecent;

  /// Customer status
  ///
  /// In en, this message translates to:
  /// **'Prospect'**
  String get salesStatusProspect;

  /// Customer status
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get salesStatusActive;

  /// Customer status
  ///
  /// In en, this message translates to:
  /// **'On hold'**
  String get salesStatusOnHold;

  /// Customer status
  ///
  /// In en, this message translates to:
  /// **'Churned'**
  String get salesStatusChurned;

  /// Customer segment
  ///
  /// In en, this message translates to:
  /// **'SMB'**
  String get salesSegmentSmb;

  /// Customer segment
  ///
  /// In en, this message translates to:
  /// **'Mid-market'**
  String get salesSegmentMidMarket;

  /// Customer segment
  ///
  /// In en, this message translates to:
  /// **'Enterprise'**
  String get salesSegmentEnterprise;

  /// Slice 6.1 detail AppBar title
  ///
  /// In en, this message translates to:
  /// **'Customer'**
  String get salesCustomerDetailTitle;

  /// Detail not-found body
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t find a customer with id \"{customerId}\".'**
  String salesCustomerNotFound(String customerId);

  /// Detail meta label
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get salesCustomerDetailEmailLabel;

  /// Detail meta label
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get salesCustomerDetailPhoneLabel;

  /// Detail meta label
  ///
  /// In en, this message translates to:
  /// **'Billing address'**
  String get salesCustomerDetailAddressLabel;

  /// Detail chip label
  ///
  /// In en, this message translates to:
  /// **'Lifetime value'**
  String get salesCustomerDetailLifetimeValueLabel;

  /// Detail chip label
  ///
  /// In en, this message translates to:
  /// **'Customer since'**
  String get salesCustomerDetailSinceLabel;

  /// Detail notes heading
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get salesCustomerDetailNotesHeading;

  /// Contacts card heading
  ///
  /// In en, this message translates to:
  /// **'Contacts'**
  String get salesCustomerDetailContactsHeading;

  /// Contacts empty state
  ///
  /// In en, this message translates to:
  /// **'No contacts linked yet.'**
  String get salesCustomerDetailContactsEmpty;

  /// Timeline card heading
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get salesCustomerDetailTimelineHeading;

  /// Timeline empty state
  ///
  /// In en, this message translates to:
  /// **'No activity yet.'**
  String get salesCustomerDetailTimelineEmpty;

  /// Contacts card add button
  ///
  /// In en, this message translates to:
  /// **'Add contact'**
  String get salesContactAddAction;

  /// Contact tile menu
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get salesContactEditAction;

  /// Contact tile menu
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get salesContactDeleteAction;

  /// Badge on the primary contact tile
  ///
  /// In en, this message translates to:
  /// **'Primary'**
  String get salesContactPrimaryBadge;

  /// Contact form title (create)
  ///
  /// In en, this message translates to:
  /// **'New contact'**
  String get salesContactNewTitle;

  /// Contact form title (edit)
  ///
  /// In en, this message translates to:
  /// **'Edit contact'**
  String get salesContactEditTitle;

  /// Contact form field
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get salesContactNameLabel;

  /// Contact form field
  ///
  /// In en, this message translates to:
  /// **'Role'**
  String get salesContactRoleLabel;

  /// Contact form field
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get salesContactEmailLabel;

  /// Contact form field
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get salesContactPhoneLabel;

  /// Toggle label
  ///
  /// In en, this message translates to:
  /// **'Primary contact'**
  String get salesContactPrimaryToggle;

  /// Toggle description
  ///
  /// In en, this message translates to:
  /// **'Show this contact in the customer header.'**
  String get salesContactPrimaryDescription;

  /// Form submit
  ///
  /// In en, this message translates to:
  /// **'Save contact'**
  String get salesContactSaveAction;

  /// Save success snackbar
  ///
  /// In en, this message translates to:
  /// **'Contact saved.'**
  String get salesContactSavedSnack;

  /// Save failure snackbar
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save contact: {message}'**
  String salesContactSaveFailed(String message);

  /// Confirmation dialog title
  ///
  /// In en, this message translates to:
  /// **'Delete contact?'**
  String get salesContactDeleteTitle;

  /// Confirmation dialog body
  ///
  /// In en, this message translates to:
  /// **'The contact will be removed from this customer.'**
  String get salesContactDeleteBody;

  /// Confirmation confirm button
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get salesContactDeleteConfirm;

  /// Delete success snackbar
  ///
  /// In en, this message translates to:
  /// **'Contact removed.'**
  String get salesContactDeletedSnack;

  /// Timeline card add button
  ///
  /// In en, this message translates to:
  /// **'Log activity'**
  String get salesActivityLogAction;

  /// Activity form AppBar title
  ///
  /// In en, this message translates to:
  /// **'Log activity'**
  String get salesActivityFormTitle;

  /// Activity form field
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get salesActivityTypeLabel;

  /// Activity form field
  ///
  /// In en, this message translates to:
  /// **'Summary'**
  String get salesActivitySummaryLabel;

  /// Activity form field
  ///
  /// In en, this message translates to:
  /// **'Logged by'**
  String get salesActivityActorLabel;

  /// Activity form submit
  ///
  /// In en, this message translates to:
  /// **'Save activity'**
  String get salesActivitySaveAction;

  /// Save success snackbar
  ///
  /// In en, this message translates to:
  /// **'Activity logged.'**
  String get salesActivitySavedSnack;

  /// Save failure snackbar
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t log activity: {message}'**
  String salesActivitySaveFailed(String message);

  /// Activity type label
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get salesActivityTypeNote;

  /// Activity type label
  ///
  /// In en, this message translates to:
  /// **'Call'**
  String get salesActivityTypeCall;

  /// Activity type label
  ///
  /// In en, this message translates to:
  /// **'Meeting'**
  String get salesActivityTypeMeeting;

  /// Activity type label
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get salesActivityTypeEmail;

  /// Activity type label
  ///
  /// In en, this message translates to:
  /// **'Quotation'**
  String get salesActivityTypeQuotation;

  /// Activity type label
  ///
  /// In en, this message translates to:
  /// **'Order'**
  String get salesActivityTypeOrder;

  /// Activity type label
  ///
  /// In en, this message translates to:
  /// **'Payment'**
  String get salesActivityTypePayment;

  /// Slice 6.2.1 list title
  ///
  /// In en, this message translates to:
  /// **'Quotations'**
  String get salesQuotationListTitle;

  /// AppBar add tooltip
  ///
  /// In en, this message translates to:
  /// **'New quotation'**
  String get salesQuotationNewTooltip;

  /// Quotation list search hint
  ///
  /// In en, this message translates to:
  /// **'Search by number or customer'**
  String get salesQuotationSearchHint;

  /// Quotation list sort tooltip
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get salesQuotationSortTooltip;

  /// Quotation list empty state
  ///
  /// In en, this message translates to:
  /// **'No quotations match your filters.'**
  String get salesQuotationListEmpty;

  /// Tile subtitle validity label
  ///
  /// In en, this message translates to:
  /// **'valid until {date}'**
  String salesQuotationValidUntilLabel(String date);

  /// Sort axis
  ///
  /// In en, this message translates to:
  /// **'Created (newest)'**
  String get salesQuotationSortCreatedDesc;

  /// Sort axis
  ///
  /// In en, this message translates to:
  /// **'Created (oldest)'**
  String get salesQuotationSortCreatedAsc;

  /// Sort axis
  ///
  /// In en, this message translates to:
  /// **'Total (largest)'**
  String get salesQuotationSortTotalDesc;

  /// Sort axis
  ///
  /// In en, this message translates to:
  /// **'Expiring next'**
  String get salesQuotationSortValidity;

  /// Quotation status
  ///
  /// In en, this message translates to:
  /// **'Draft'**
  String get salesQuotationStatusDraft;

  /// Quotation status
  ///
  /// In en, this message translates to:
  /// **'Sent'**
  String get salesQuotationStatusSent;

  /// Quotation status
  ///
  /// In en, this message translates to:
  /// **'Accepted'**
  String get salesQuotationStatusAccepted;

  /// Quotation status
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get salesQuotationStatusRejected;

  /// Quotation status
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get salesQuotationStatusExpired;

  /// Quotation status — promoted to a sales order
  ///
  /// In en, this message translates to:
  /// **'Converted'**
  String get salesQuotationStatusConverted;

  /// Quotation form AppBar title
  ///
  /// In en, this message translates to:
  /// **'New quotation'**
  String get salesQuotationNewTitle;

  /// Form field
  ///
  /// In en, this message translates to:
  /// **'Customer'**
  String get salesQuotationCustomerLabel;

  /// Form field
  ///
  /// In en, this message translates to:
  /// **'Valid until'**
  String get salesQuotationValidUntilField;

  /// Form section heading
  ///
  /// In en, this message translates to:
  /// **'Line items'**
  String get salesQuotationLinesHeading;

  /// Numbered per-line heading
  ///
  /// In en, this message translates to:
  /// **'Line {index}'**
  String salesQuotationLineHeading(int index);

  /// Form add-line button
  ///
  /// In en, this message translates to:
  /// **'Add line'**
  String get salesQuotationAddLineAction;

  /// Form remove-line tooltip
  ///
  /// In en, this message translates to:
  /// **'Remove line'**
  String get salesQuotationRemoveLineTooltip;

  /// Line field
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get salesQuotationLineDescriptionLabel;

  /// Line field
  ///
  /// In en, this message translates to:
  /// **'Qty'**
  String get salesQuotationLineQuantityLabel;

  /// Line field
  ///
  /// In en, this message translates to:
  /// **'Unit price'**
  String get salesQuotationLineUnitPriceLabel;

  /// Form submit
  ///
  /// In en, this message translates to:
  /// **'Save quotation'**
  String get salesQuotationSaveAction;

  /// Save success snackbar
  ///
  /// In en, this message translates to:
  /// **'Quotation saved.'**
  String get salesQuotationSavedSnack;

  /// Save failure snackbar
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save quotation: {message}'**
  String salesQuotationSaveFailed(String message);

  /// Form validation snackbar
  ///
  /// In en, this message translates to:
  /// **'Please pick a customer.'**
  String get salesQuotationPickCustomer;

  /// Detail AppBar title
  ///
  /// In en, this message translates to:
  /// **'Quotation'**
  String get salesQuotationDetailTitle;

  /// Detail not-found body
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t find a quotation with id \"{quotationId}\".'**
  String salesQuotationNotFound(String quotationId);

  /// Detail meta
  ///
  /// In en, this message translates to:
  /// **'Created'**
  String get salesQuotationCreatedLabel;

  /// Detail meta
  ///
  /// In en, this message translates to:
  /// **'Valid until'**
  String get salesQuotationValidUntilLabel2;

  /// Detail section heading
  ///
  /// In en, this message translates to:
  /// **'Line items'**
  String get salesQuotationDetailLinesHeading;

  /// Detail total row
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get salesQuotationTotalLabel;

  /// Detail notes heading
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get salesQuotationNotesHeading;

  /// Draft → sent action
  ///
  /// In en, this message translates to:
  /// **'Send to customer'**
  String get salesQuotationSendAction;

  /// Sent → accepted action
  ///
  /// In en, this message translates to:
  /// **'Mark accepted'**
  String get salesQuotationAcceptAction;

  /// Sent → rejected action
  ///
  /// In en, this message translates to:
  /// **'Mark rejected'**
  String get salesQuotationRejectAction;

  /// Accepted → converted action
  ///
  /// In en, this message translates to:
  /// **'Convert to order'**
  String get salesQuotationConvertAction;

  /// Status change snackbar
  ///
  /// In en, this message translates to:
  /// **'Quotation updated.'**
  String get salesQuotationStatusUpdated;

  /// Convert success snackbar
  ///
  /// In en, this message translates to:
  /// **'Sales order created.'**
  String get salesQuotationConvertedSnack;

  /// Action failure snackbar
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t update quotation: {message}'**
  String salesQuotationActionFailed(String message);

  /// Convert refusal copy
  ///
  /// In en, this message translates to:
  /// **'Only accepted quotations can be converted.'**
  String get salesQuotationConvertNotAccepted;

  /// Convert refusal copy
  ///
  /// In en, this message translates to:
  /// **'This quotation has already been converted.'**
  String get salesQuotationConvertAlready;

  /// Convert refusal copy
  ///
  /// In en, this message translates to:
  /// **'This quotation has expired.'**
  String get salesQuotationConvertExpired;

  /// Slice 6.2.1 order list title
  ///
  /// In en, this message translates to:
  /// **'Sales orders'**
  String get salesOrderListTitle;

  /// Order list empty state
  ///
  /// In en, this message translates to:
  /// **'No orders yet.'**
  String get salesOrderListEmpty;

  /// Order status
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get salesOrderStatusPending;

  /// Order status
  ///
  /// In en, this message translates to:
  /// **'Packing'**
  String get salesOrderStatusPacking;

  /// Order status
  ///
  /// In en, this message translates to:
  /// **'Shipped'**
  String get salesOrderStatusShipped;

  /// Order status
  ///
  /// In en, this message translates to:
  /// **'Delivered'**
  String get salesOrderStatusDelivered;

  /// Order status
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get salesOrderStatusCancelled;

  /// Order detail AppBar title
  ///
  /// In en, this message translates to:
  /// **'Sales order'**
  String get salesOrderDetailTitle;

  /// Detail not-found body
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t find an order with id \"{orderId}\".'**
  String salesOrderNotFound(String orderId);

  /// Detail meta
  ///
  /// In en, this message translates to:
  /// **'Created'**
  String get salesOrderCreatedLabel;

  /// Detail meta
  ///
  /// In en, this message translates to:
  /// **'Source quotation'**
  String get salesOrderSourceQuotationLabel;

  /// Detail meta
  ///
  /// In en, this message translates to:
  /// **'Shipped'**
  String get salesOrderShippedAtLabel;

  /// Detail meta
  ///
  /// In en, this message translates to:
  /// **'Delivered'**
  String get salesOrderDeliveredAtLabel;

  /// Detail meta and tracking dialog label
  ///
  /// In en, this message translates to:
  /// **'Tracking'**
  String get salesOrderTrackingLabel;

  /// Detail section heading
  ///
  /// In en, this message translates to:
  /// **'Line items'**
  String get salesOrderDetailLinesHeading;

  /// Cancellation action
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get salesOrderCancelAction;

  /// pending → packing action
  ///
  /// In en, this message translates to:
  /// **'Start packing'**
  String get salesOrderStartPackingAction;

  /// packing → shipped action
  ///
  /// In en, this message translates to:
  /// **'Ship'**
  String get salesOrderShipAction;

  /// shipped → delivered action
  ///
  /// In en, this message translates to:
  /// **'Mark delivered'**
  String get salesOrderMarkDeliveredAction;

  /// Tracking prompt title
  ///
  /// In en, this message translates to:
  /// **'Tracking reference'**
  String get salesOrderTrackingDialogTitle;

  /// Tracking prompt confirm
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get salesOrderTrackingConfirm;

  /// Snackbar when tracking is empty
  ///
  /// In en, this message translates to:
  /// **'A tracking reference is required to ship.'**
  String get salesOrderTrackingRequired;

  /// Advance success snackbar
  ///
  /// In en, this message translates to:
  /// **'Order marked as {status}.'**
  String salesOrderAdvancedSnack(String status);

  /// Advance failure snackbar
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t update order: {message}'**
  String salesOrderAdvanceFailed(String message);

  /// Slice 6.3 analytics page title
  ///
  /// In en, this message translates to:
  /// **'Sales analytics'**
  String get salesAnalyticsTitle;

  /// Revenue chart heading
  ///
  /// In en, this message translates to:
  /// **'Revenue'**
  String get salesAnalyticsRevenueHeading;

  /// Revenue chart empty state
  ///
  /// In en, this message translates to:
  /// **'No revenue in the selected window.'**
  String get salesAnalyticsRevenueEmpty;

  /// Period toggle
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get salesAnalyticsPeriodWeekly;

  /// Period toggle
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get salesAnalyticsPeriodMonthly;

  /// Top customers card heading
  ///
  /// In en, this message translates to:
  /// **'Top customers'**
  String get salesAnalyticsTopCustomersHeading;

  /// Top customers empty state
  ///
  /// In en, this message translates to:
  /// **'No customer revenue to rank yet.'**
  String get salesAnalyticsTopCustomersEmpty;

  /// Top products card heading
  ///
  /// In en, this message translates to:
  /// **'Top products'**
  String get salesAnalyticsTopProductsHeading;

  /// Top products empty state
  ///
  /// In en, this message translates to:
  /// **'No product revenue to rank yet.'**
  String get salesAnalyticsTopProductsEmpty;

  /// Leaderboard card heading
  ///
  /// In en, this message translates to:
  /// **'Sales rep leaderboard'**
  String get salesAnalyticsLeaderboardHeading;

  /// Leaderboard empty state
  ///
  /// In en, this message translates to:
  /// **'No reps yet.'**
  String get salesAnalyticsLeaderboardEmpty;

  /// Deals count under a rep
  ///
  /// In en, this message translates to:
  /// **'{count} deals closed'**
  String salesAnalyticsLeaderboardDealsLabel(String count);

  /// Attainment line
  ///
  /// In en, this message translates to:
  /// **'{pct}% of {target}'**
  String salesAnalyticsLeaderboardAttainmentLabel(String pct, String target);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'km'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'km':
      return AppLocalizationsKm();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
