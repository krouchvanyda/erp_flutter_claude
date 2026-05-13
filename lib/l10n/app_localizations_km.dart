// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Khmer Central Khmer (`km`).
class AppLocalizationsKm extends AppLocalizations {
  AppLocalizationsKm([String locale = 'km']) : super(locale);

  @override
  String get appName => 'ERP Mobile';

  @override
  String get loginAppBarTitle => 'ចូលគណនី';

  @override
  String get loginButton => 'ចូល (សាកល្បង)';

  @override
  String get dashboardTitle => 'ផ្ទាំងគ្រប់គ្រង';

  @override
  String get dashboardPlaceholder =>
      'ផ្ទាំងគ្រប់គ្រងសាកល្បង — Module 2 នឹងបំពេញ។';

  @override
  String get signOutTooltip => 'ចាកចេញ';

  @override
  String get notFoundTitle => 'រកមិនឃើញ';

  @override
  String notFoundBody(String location) {
    return 'មិនមានផ្លូវសម្រាប់ \"$location\"';
  }

  @override
  String get goHome => 'ទៅទំព័រដើម';

  @override
  String get loginOtpDemoLink => '[demo] សាកល្បងលេខកូដ MFA';

  @override
  String get otpPageTitle => 'ផ្ទៀងផ្ទាត់';

  @override
  String get otpSubtitle => 'បញ្ចូលលេខកូដ ៦ ខ្ទង់ពីកម្មវិធីផ្ទៀងផ្ទាត់ឬ SMS។';

  @override
  String otpDevHint(String code) {
    return 'សាកល្បង៖ បញ្ចូល $code ដើម្បីបន្ត';
  }

  @override
  String get otpVerifyButton => 'ផ្ទៀងផ្ទាត់';

  @override
  String get otpErrorIncorrect => 'លេខកូដខុស។ សូមព្យាយាមម្ដងទៀត។';

  @override
  String get otpErrorExpired => 'លេខកូដនេះបានផុតកំណត់។ សូមស្នើសុំលេខកូដថ្មី។';

  @override
  String get otpErrorTooManyAttempts =>
      'ការព្យាយាមច្រើនពេក។ សូមព្យាយាមនៅពេលក្រោយ។';

  @override
  String get otpErrorNetwork =>
      'មិនអាចទាក់ទងម៉ាស៊ីនមេបាន។ ពិនិត្យការតភ្ជាប់របស់អ្នក។';

  @override
  String get forbiddenTitle => 'គ្មានសិទ្ធិចូល';

  @override
  String forbiddenBody(String location) {
    return 'អ្នកមិនមានសិទ្ធិចូល \"$location\" ទេ។';
  }

  @override
  String get adminDemoTitle => 'ទំព័រសាកល្បងអ្នកគ្រប់គ្រង';

  @override
  String get adminDemoBody =>
      'អ្នកបានចូលដល់ផ្លូវសាកល្បងសម្រាប់អ្នកគ្រប់គ្រង — RBAC ដំណើរការ។';

  @override
  String get dashboardAdminDemoLink => '[demo] បើកទំព័រអ្នកគ្រប់គ្រង';

  @override
  String get permissionGuardDemoGranted =>
      '[demo] PermissionGuard: អនុញ្ញាតជាអ្នកគ្រប់គ្រង';

  @override
  String get permissionGuardDemoDenied =>
      '[demo] PermissionGuard: មិនអនុញ្ញាតជាអ្នកគ្រប់គ្រង';

  @override
  String get shellHome => 'ដើម';

  @override
  String get shellModules => 'ម៉ូឌុល';

  @override
  String get shellSettings => 'ការកំណត់';

  @override
  String get modulesTitle => 'ម៉ូឌុល';

  @override
  String get modulesPlaceholder => 'ប៊ូតុងម៉ូឌុលនឹងបង្ហាញនៅ Slice 2.1.2។';

  @override
  String get modulesEmpty =>
      'មិនមានម៉ូឌុលណាសម្រាប់តួនាទីរបស់អ្នកនៅឡើយទេ។ សូមស្នើសុំសិទ្ធិពីអ្នកគ្រប់គ្រង។';

  @override
  String get shortcutAdminDemo => 'ទំព័រសាកល្បងអ្នកគ្រប់គ្រង';

  @override
  String get shortcutFinance => 'ហិរញ្ញវត្ថុ';

  @override
  String get shortcutProcurement => 'ការទិញ';

  @override
  String get shortcutInventory => 'ឃ្លាំង';

  @override
  String get shortcutSales => 'លក់';

  @override
  String get shortcutHr => 'ធនធានមនុស្ស';

  @override
  String get shortcutProjects => 'គម្រោង';

  @override
  String comingSoonBody(String module) {
    return '$module នឹងមកដល់នៅការចេញផ្សាយក្រោយ។';
  }

  @override
  String get settingsTitle => 'ការកំណត់';

  @override
  String get settingsPlaceholder => 'ការកំណត់ពិតប្រាកដនឹងមកដល់នៅ Module 9។';

  @override
  String get globalSearchTooltip => 'ស្វែងរក';

  @override
  String get globalSearchHint => 'ស្វែងរកម៉ូឌុល កំណត់ត្រា មនុស្ស…';

  @override
  String get globalSearchPrompt =>
      'វាយពាក្យ ដើម្បីស្វែងរកគ្រប់ម៉ូឌុលដែលអ្នកអាចចូលបាន។';

  @override
  String globalSearchNoResults(String query) {
    return 'មិនមានលទ្ធផលសម្រាប់ \"$query\" ទេ។';
  }

  @override
  String globalSearchError(String message) {
    return 'ការស្វែងរកបានបរាជ័យ៖ $message';
  }

  @override
  String get kpiTrendUp => 'កើនឡើង';

  @override
  String get kpiTrendDown => 'ធ្លាក់ចុះ';

  @override
  String get kpiTrendFlat => 'ស្ថេរ';

  @override
  String get kpiTrendUpTooltip => 'កើនឡើងធៀបរយៈពេលមុន';

  @override
  String get kpiTrendDownTooltip => 'ធ្លាក់ចុះធៀបរយៈពេលមុន';

  @override
  String get kpiTrendFlatTooltip =>
      'មិនមានការផ្លាស់ប្ដូរច្បាស់លាស់ធៀបរយៈពេលមុន';

  @override
  String get chartRevenueTrendTitle => 'និន្នាការចំណូល';

  @override
  String get chartSalesByRegionTitle => 'ការលក់តាមតំបន់';

  @override
  String get chartSeriesRevenue => 'ចំណូល';

  @override
  String get chartSeriesTarget => 'គោលដៅ';

  @override
  String get chartSeriesSales => 'ការលក់';

  @override
  String get realtimeStatusLive => 'ផ្សាយផ្ទាល់';

  @override
  String get realtimeStatusConnecting => 'កំពុងតភ្ជាប់';

  @override
  String get realtimeStatusReconnecting => 'កំពុងតភ្ជាប់ឡើងវិញ';

  @override
  String get realtimeStatusOffline => 'ផ្ដាច់';

  @override
  String get pushDemoButton => '[dev] សាកល្បងផ្ញើជូនដំណឹង';

  @override
  String pushDemoTitle(int count) {
    return 'ការជូនដំណឹងសាកល្បង #$count';
  }

  @override
  String get pushDemoBody => 'បានបញ្ជូនតាម PushMessageRouter ទៅប្រអប់សារ។';

  @override
  String get pushDemoSnack => 'បានផ្ញើទៅប្រអប់សារ។';

  @override
  String get notificationsBadgeTooltip => 'ការជូនដំណឹង';

  @override
  String get notificationInboxTitle => 'ការជូនដំណឹង';

  @override
  String get notificationInboxEmpty =>
      'អ្នកបានពិនិត្យអស់ហើយ។ ការជូនដំណឹងថ្មីនឹងបង្ហាញនៅទីនេះ។';

  @override
  String notificationInboxError(String message) {
    return 'មិនអាចផ្ទុកការជូនដំណឹង៖ $message';
  }

  @override
  String get notificationInboxMarkAllRead => 'សម្គាល់ថាបានអានទាំងអស់';

  @override
  String get notificationInboxDismissedSnack => 'បានលុបការជូនដំណឹង។';

  @override
  String notificationDeepLinkError(String message) {
    return 'មិនអាចបើកការជូនដំណឹងនេះ៖ $message';
  }

  @override
  String get notificationDeepLinkViewAction => 'មើល';

  @override
  String get pushDemoRoutedButton => '[dev] សាកល្បងផ្ញើដែលមានតំណ';

  @override
  String get pushDemoRoutedBody =>
      'ចុចលើការជូនដំណឹងនេះ ឬប៊ូតុងមើលនៅ Snackbar ដើម្បីបើកគោលដៅ។';

  @override
  String get chartOfAccountsTitle => 'តារាងគណនី';

  @override
  String get chartOfAccountsEmpty => 'មិនទាន់មានគណនីត្រូវបានផ្ទុក។';

  @override
  String chartOfAccountsError(String message) {
    return 'មិនអាចផ្ទុកតារាងគណនី៖ $message';
  }

  @override
  String get chartOfAccountsExpandAll => 'ពង្រីកទាំងអស់';

  @override
  String get chartOfAccountsCollapseAll => 'បង្រួមទាំងអស់';

  @override
  String get dashboardChartOfAccountsLink => '[demo] បើកតារាងគណនី';

  @override
  String get accountTypeAsset => 'ទ្រព្យសកម្ម';

  @override
  String get accountTypeLiability => 'បំណុល';

  @override
  String get accountTypeEquity => 'មូលធន';

  @override
  String get accountTypeRevenue => 'ចំណូល';

  @override
  String get accountTypeExpense => 'ចំណាយ';

  @override
  String get accountDetailTitle => 'គណនី';

  @override
  String get accountDetailNoTransactions =>
      'មិនទាន់មានប្រតិបត្តិការត្រូវបានបញ្ជូលនៅក្នុងគណនីនេះទេ។';

  @override
  String accountDetailNotFound(String accountId) {
    return 'យើងរកមិនឃើញគណនីដែលមានលេខសម្គាល់ \"$accountId\" ទេ។';
  }

  @override
  String accountDetailError(String message) {
    return 'មិនអាចផ្ទុកគណនីនេះ៖ $message';
  }

  @override
  String get invoiceListTitle => 'វិក្កយបត្រ';

  @override
  String get invoiceListSearchHint => 'ស្វែងរកតាមលេខ ឬឈ្មោះអតិថិជន';

  @override
  String get invoiceListSortTooltip => 'តម្រៀប';

  @override
  String get invoiceListEmpty => 'មិនមានវិក្កយបត្រត្រូវនឹងតម្រងរបស់អ្នកទេ។';

  @override
  String invoiceListError(String message) {
    return 'មិនអាចផ្ទុកវិក្កយបត្រ៖ $message';
  }

  @override
  String invoiceListDueLabel(String date) {
    return 'ដល់កំណត់ $date';
  }

  @override
  String get invoiceStatusDraft => 'ព្រាង';

  @override
  String get invoiceStatusPendingApproval => 'កំពុងរង់ចាំការអនុម័ត';

  @override
  String get invoiceStatusApproved => 'បានអនុម័ត';

  @override
  String get invoiceStatusRejected => 'បានបដិសេធ';

  @override
  String get invoiceSortIssuedDesc => 'ចេញ (ថ្មីបំផុត)';

  @override
  String get invoiceSortIssuedAsc => 'ចេញ (ចាស់បំផុត)';

  @override
  String get invoiceSortDueAsc => 'ដល់កំណត់ (ឆាប់បំផុត)';

  @override
  String get invoiceSortAmountDesc => 'ចំនួន (ច្រើនបំផុត)';

  @override
  String get invoiceSortNumberAsc => 'លេខវិក្កយបត្រ';

  @override
  String get invoiceDetailTitle => 'វិក្កយបត្រ';

  @override
  String get invoiceDetailIssuedLabel => 'ចេញ';

  @override
  String get invoiceDetailDueLabel => 'ដល់កំណត់';

  @override
  String get invoiceDetailLinesHeading => 'បន្ទាត់សារពើ';

  @override
  String get invoiceDetailSubtotalLabel => 'សរុបរង';

  @override
  String get invoiceDetailTaxLabel => 'ពន្ធ';

  @override
  String get invoiceDetailTotalLabel => 'សរុប';

  @override
  String get invoiceDetailNotesHeading => 'កំណត់ចំណាំ';

  @override
  String get invoiceDetailPdfHeading => 'បង្ហាញ PDF';

  @override
  String get invoiceDetailPdfPlaceholder =>
      'ការបង្ហាញ PDF នឹងមកដល់ជាមួយម៉ាស៊ីនមេ។';

  @override
  String invoiceDetailNotFound(String invoiceId) {
    return 'យើងរកមិនឃើញវិក្កយបត្រដែលមានលេខសម្គាល់ \"$invoiceId\" ទេ។';
  }

  @override
  String invoiceDetailError(String message) {
    return 'មិនអាចផ្ទុកវិក្កយបត្រនេះ៖ $message';
  }

  @override
  String get invoiceApproveAction => 'អនុម័ត';

  @override
  String get invoiceRejectAction => 'បដិសេធ';

  @override
  String get invoiceSubmitAction => 'ដាក់ស្នើដើម្បីអនុម័ត';

  @override
  String get invoiceReopenAction => 'បើកដើម្បីកែសម្រួល';

  @override
  String get invoiceActionCancel => 'បោះបង់';

  @override
  String get invoiceApproveSheetTitle => 'អនុម័តវិក្កយបត្រនេះ?';

  @override
  String invoiceApproveSheetBody(String invoiceNumber) {
    return 'អ្នកនឹងអនុម័ត $invoiceNumber។ វិក្កយបត្រនឹងត្រូវចាក់សោបន្ទាប់ពីការអនុម័ត។';
  }

  @override
  String get invoiceRejectSheetTitle => 'បដិសេធវិក្កយបត្រនេះ?';

  @override
  String invoiceRejectSheetBody(String invoiceNumber) {
    return '$invoiceNumber នឹងត្រូវបញ្ជូនត្រឡប់ទៅអ្នកស្នើជាមួយមូលហេតុខាងក្រោម។';
  }

  @override
  String get invoiceRejectReasonLabel => 'មូលហេតុ';

  @override
  String get invoiceRejectReasonHint => 'ហេតុអ្វីបានជាបដិសេធវិក្កយបត្រនេះ?';

  @override
  String get invoiceRejectReasonRequired => 'សូមបញ្ចូលមូលហេតុ។';

  @override
  String invoiceActionSuccess(String status) {
    return 'បានសម្គាល់វិក្កយបត្រជា $status។';
  }

  @override
  String get invoiceActionForbidden =>
      'អ្នកមិនមានសិទ្ធិធ្វើសកម្មភាពលើវិក្កយបត្រនេះទេ។';

  @override
  String get invoiceActionNotFound => 'វិក្កយបត្រនេះមិនមានទៀតទេ។';

  @override
  String get invoiceActionInvalidState =>
      'វិក្កយបត្រនេះត្រូវបានធ្វើសកម្មភាពរួចហើយ។';

  @override
  String get invoiceActionUnauthorized =>
      'ការចូលរបស់អ្នកបានផុតកំណត់ — សូមចូលម្ដងទៀត។';

  @override
  String invoiceActionGenericError(String message) {
    return 'មិនអាចធ្វើសកម្មភាពលើវិក្កយបត្រ៖ $message';
  }

  @override
  String get invoiceAuditApprovedHeading => 'បានអនុម័ត';

  @override
  String get invoiceAuditRejectedHeading => 'បានបដិសេធ';

  @override
  String invoiceAuditActorLine(String userId) {
    return 'ដោយ $userId';
  }

  @override
  String invoiceAuditWhenLine(String when) {
    return 'នៅ $when';
  }

  @override
  String invoiceAuditReasonLine(String reason) {
    return 'មូលហេតុ៖ $reason';
  }

  @override
  String get invoiceFormCreateTitle => 'វិក្កយបត្រថ្មី';

  @override
  String get invoiceFormEditTitle => 'កែវិក្កយបត្រ';

  @override
  String get invoiceFormSaveTooltip => 'រក្សាទុក';

  @override
  String get invoiceFormSaveAction => 'រក្សាទុកវិក្កយបត្រ';

  @override
  String get invoiceFormSavedSnack => 'បានរក្សាទុកវិក្កយបត្រ។';

  @override
  String get invoiceFormCustomerLabel => 'អតិថិជន';

  @override
  String get invoiceFormIssuedLabel => 'កាលបរិច្ឆេទចេញ';

  @override
  String get invoiceFormDueLabel => 'កាលបរិច្ឆេទដល់កំណត់';

  @override
  String get invoiceFormLineHeading => 'បន្ទាត់សារពើ';

  @override
  String get invoiceFormLineDescriptionLabel => 'ពិពណ៌នា';

  @override
  String get invoiceFormLineQuantityLabel => 'បរិមាណ';

  @override
  String get invoiceFormLineUnitPriceLabel => 'តម្លៃឯកតា';

  @override
  String get validatorRequired => 'ត្រូវការ';

  @override
  String get validatorInvalidNumber => 'ត្រូវតែជាលេខ';

  @override
  String get validatorMustBePositive => 'ត្រូវតែធំជាង 0';

  @override
  String get validatorMustBeNonNegative => 'មិនអាចជាលេខអវិជ្ជមានទេ';

  @override
  String get validatorDueBeforeIssued =>
      'កាលបរិច្ឆេទដល់កំណត់ត្រូវតែស្មើ ឬក្រោយកាលបរិច្ឆេទចេញ';

  @override
  String get journalEntriesTitle => 'ធាតុសៀវភៅ';

  @override
  String get journalEntriesEmpty => 'មិនមានធាតុសៀវភៅក្នុងរយៈពេលនេះទេ។';

  @override
  String get journalEntryDetailTitle => 'ធាតុសៀវភៅ';

  @override
  String journalEntryNotFound(String id) {
    return 'មិនមានធាតុសៀវភៅ \"$id\" ទេ។';
  }

  @override
  String get journalEntryAccountColumn => 'គណនី';

  @override
  String get journalEntryDebitColumn => 'ឥណពន្ធ';

  @override
  String get journalEntryCreditColumn => 'ឥណទាន';

  @override
  String get journalEntryTotalLabel => 'សរុប';

  @override
  String get trialBalanceTitle => 'តារាងតុល្យភាពសាកល្បង';

  @override
  String get trialBalanceEmpty => 'មិនទាន់មានគណនីដែលមានសមតុល្យមិនសូន្យទេ។';

  @override
  String get trialBalanceColumnCode => 'លេខ';

  @override
  String get trialBalanceColumnName => 'គណនី';

  @override
  String get trialBalanceColumnDebit => 'ឥណពន្ធ';

  @override
  String get trialBalanceColumnCredit => 'ឥណទាន';

  @override
  String trialBalancePageOf(int current, int total) {
    return 'ទំព័រ $current នៃ $total';
  }

  @override
  String get trialBalanceExportCsvTooltip => 'នាំចេញ CSV';

  @override
  String trialBalanceExportSuccess(String path) {
    return 'បានរក្សាទុក CSV នៅ $path';
  }

  @override
  String trialBalanceExportError(String message) {
    return 'ការនាំចេញ CSV បានបរាជ័យ៖ $message';
  }

  @override
  String get validatorInvalidEmail => 'សូមបញ្ចូលអ៊ីមែលត្រឹមត្រូវ';

  @override
  String get prListTitle => 'សំណើទិញ';

  @override
  String get prListNewTooltip => 'សំណើថ្មី';

  @override
  String get prListSearchHint => 'ស្វែងរកតាមលេខ អ្នកស្នើ ឬមជ្ឈមណ្ឌលថ្លៃ';

  @override
  String get prListSortTooltip => 'តម្រៀប';

  @override
  String get prListEmpty => 'គ្មានសំណើទិញដែលត្រូវនឹងតម្រងរបស់អ្នកទេ។';

  @override
  String prListError(String message) {
    return 'មិនអាចផ្ទុកសំណើទិញ៖ $message';
  }

  @override
  String get prStatusDraft => 'ព្រាង';

  @override
  String get prStatusSubmitted => 'បានដាក់ស្នើ';

  @override
  String get prStatusApproved => 'បានអនុម័ត';

  @override
  String get prStatusRejected => 'បានបដិសេធ';

  @override
  String get prStatusConverted => 'បានបម្លែង';

  @override
  String get prSortCreatedDesc => 'បង្កើត (ថ្មីបំផុត)';

  @override
  String get prSortCreatedAsc => 'បង្កើត (ចាស់បំផុត)';

  @override
  String get prSortTotalDesc => 'សរុប (ច្រើនបំផុត)';

  @override
  String get prSortNumberAsc => 'លេខសំណើ';

  @override
  String get prFormCreateTitle => 'សំណើទិញថ្មី';

  @override
  String get prFormSaveTooltip => 'ដាក់ស្នើ';

  @override
  String get prFormSubmitAction => 'ដាក់ស្នើសំណើ';

  @override
  String get prFormSavedSnack => 'បានដាក់ស្នើសំណើទិញ។';

  @override
  String prFormSaveFailed(String message) {
    return 'មិនអាចដាក់ស្នើសំណើ៖ $message';
  }

  @override
  String get prFormRequesterLabel => 'អ្នកស្នើ';

  @override
  String get prFormCostCenterLabel => 'មជ្ឈមណ្ឌលថ្លៃ';

  @override
  String get prFormApproverLabel => 'អ្នកអនុម័ត';

  @override
  String get prFormJustificationLabel => 'ការបង្ហាញហេតុផល (ស្រេចចិត្ត)';

  @override
  String get prFormLinesHeading => 'បន្ទាត់ទំនិញ';

  @override
  String prFormLineHeading(int index) {
    return 'បន្ទាត់ $index';
  }

  @override
  String get prFormAddLineAction => 'បន្ថែមបន្ទាត់';

  @override
  String get prFormRemoveLineTooltip => 'លុបបន្ទាត់';

  @override
  String get prFormLineDescriptionLabel => 'ការពិពណ៌នា';

  @override
  String get prFormLineQuantityLabel => 'ចំនួន';

  @override
  String get prFormLineUnitPriceLabel => 'ថ្លៃឯកតា';

  @override
  String get prDetailTitle => 'សំណើទិញ';

  @override
  String prDetailNotFound(String prId) {
    return 'យើងរកមិនឃើញសំណើទិញដែលមាន id \"$prId\" ទេ។';
  }

  @override
  String prDetailError(String message) {
    return 'មិនអាចផ្ទុកសំណើទិញនេះ៖ $message';
  }

  @override
  String get prDetailRequesterLabel => 'អ្នកស្នើ';

  @override
  String get prDetailCostCenterLabel => 'មជ្ឈមណ្ឌលថ្លៃ';

  @override
  String get prDetailApproverLabel => 'អ្នកអនុម័ត';

  @override
  String get prDetailCreatedLabel => 'បង្កើត';

  @override
  String get prDetailJustificationHeading => 'ការបង្ហាញហេតុផល';

  @override
  String get prDetailLinesHeading => 'បន្ទាត់ទំនិញ';

  @override
  String get prDetailTotalLabel => 'សរុប';

  @override
  String get prApproveAction => 'អនុម័ត';

  @override
  String get prRejectAction => 'បដិសេធ';

  @override
  String get prSubmitAction => 'ដាក់ស្នើ';

  @override
  String get prConvertAction => 'បម្លែងទៅ PO';

  @override
  String get prSubmittedSnack => 'បានដាក់ស្នើសំណើទិញ។';

  @override
  String prApprovedSnack(String status) {
    return 'បានសម្គាល់សំណើទិញជា $status។';
  }

  @override
  String get prRejectedSnack => 'បានបដិសេធសំណើទិញ។';

  @override
  String get prConvertedSnack => 'បានបង្កើតបញ្ជាទិញ។';

  @override
  String prApprovalNotAllowed(String action) {
    return 'មិនអាច$actionសំណើនេះពីស្ថានភាពបច្ចុប្បន្នបានទេ។';
  }

  @override
  String prApprovalFailed(String message) {
    return 'មិនអាចធ្វើបច្ចុប្បន្នភាពសំណើ៖ $message';
  }

  @override
  String get prRejectDialogTitle => 'បដិសេធសំណើ';

  @override
  String get prRejectReasonLabel => 'មូលហេតុ';

  @override
  String get prRejectReasonHint => 'ហេតុអ្វីបានជាបដិសេធសំណើនេះ?';

  @override
  String get prRejectReasonRequired => 'សូមបញ្ចូលមូលហេតុ។';

  @override
  String get prRejectCancel => 'បោះបង់';

  @override
  String get prRejectConfirm => 'បដិសេធសំណើ';

  @override
  String get prConvertDialogTitle => 'បម្លែងទៅបញ្ជាទិញ';

  @override
  String get prConvertVendorLabel => 'អ្នកផ្គត់ផ្គង់';

  @override
  String get prConvertExpectedLabel => 'កាលបរិច្ឆេទរំពឹងទុក';

  @override
  String get prConvertVendorRequired => 'សូមជ្រើសរើសអ្នកផ្គត់ផ្គង់។';

  @override
  String get prConvertConfirm => 'បង្កើត PO';

  @override
  String get prConvertCancel => 'បោះបង់';

  @override
  String get poListTitle => 'បញ្ជាទិញ';

  @override
  String get poListEmpty => 'មិនទាន់មានបញ្ជាទិញនៅឡើយទេ។';

  @override
  String poListExpectedLabel(String date) {
    return 'រំពឹងទុក $date';
  }

  @override
  String get poStatusOpen => 'បើក';

  @override
  String get poStatusPartial => 'មួយផ្នែក';

  @override
  String get poStatusFull => 'បានទទួល';

  @override
  String get poStatusClosed => 'បានបិទ';

  @override
  String get poStatusCancelled => 'បានលុបចោល';

  @override
  String get poDetailTitle => 'បញ្ជាទិញ';

  @override
  String poDetailNotFound(String poId) {
    return 'យើងរកមិនឃើញបញ្ជាទិញដែលមាន id \"$poId\" ទេ។';
  }

  @override
  String get poDetailCreatedLabel => 'បង្កើត';

  @override
  String get poDetailExpectedLabel => 'រំពឹងទុក';

  @override
  String get poDetailSourcePrLabel => 'PR ប្រភព';

  @override
  String get poDetailLinesHeading => 'បន្ទាត់ទំនិញ';

  @override
  String get poDetailTotalLabel => 'សរុប';

  @override
  String get poDetailReceiptsHeading => 'បង្កាន់ដៃទទួល';

  @override
  String get poDetailReceiptsEmpty => 'មិនទាន់មានបង្កាន់ដៃនៅឡើយទេ។';

  @override
  String poDetailReceiptItemsBadge(int count) {
    return '$count ធាតុ';
  }

  @override
  String get poDetailRecordReceiptAction => 'កត់ត្រាការទទួលទំនិញ';

  @override
  String poLineOrderedLabel(String qty) {
    return 'បានបញ្ជា $qty';
  }

  @override
  String poLineReceivedLabel(String qty) {
    return 'បានទទួល $qty';
  }

  @override
  String poLineOutstandingLabel(String qty) {
    return 'នៅសល់ $qty';
  }

  @override
  String get goodsReceiptFormTitle => 'ការទទួលទំនិញ';

  @override
  String goodsReceiptFormForPo(String number) {
    return 'កំពុងទទួលប្រឆាំងនឹង $number';
  }

  @override
  String get goodsReceiptReceivedByLabel => 'ទទួលដោយ';

  @override
  String get goodsReceiptNoteLabel => 'កំណត់ចំណាំ (ស្រេចចិត្ត)';

  @override
  String get goodsReceiptLinesHeading => 'ចំនួនបានទទួល';

  @override
  String get goodsReceiptQuantityLabel => 'ទទួលឥឡូវនេះ';

  @override
  String get goodsReceiptSubmitAction => 'កត់ត្រាបង្កាន់ដៃ';

  @override
  String get goodsReceiptSavedSnack => 'បានកត់ត្រាបង្កាន់ដៃទំនិញ។';

  @override
  String goodsReceiptSaveFailed(String message) {
    return 'មិនអាចកត់ត្រាបង្កាន់ដៃ៖ $message';
  }

  @override
  String get goodsReceiptErrorPoClosed =>
      'PO នេះត្រូវបានបិទ — មិនអាចទទួលទៀតបានទេ។';

  @override
  String get goodsReceiptErrorNoLines =>
      'សូមបញ្ចូលចំនួនយ៉ាងហោចណាស់សម្រាប់បន្ទាត់មួយ។';

  @override
  String get goodsReceiptErrorNonPositive => 'ចំនួនត្រូវតែធំជាង 0។';

  @override
  String get goodsReceiptErrorUnknownLine =>
      'បន្ទាត់មួយមិនជាកម្មសិទ្ធិរបស់ PO នេះទេ។';

  @override
  String get goodsReceiptErrorExceedsOutstanding =>
      'មិនអាចទទួលលើសពីចំនួននៅសល់បានទេ។';

  @override
  String get vendorListTitle => 'អ្នកផ្គត់ផ្គង់';

  @override
  String get vendorListEmpty => 'មិនទាន់មានអ្នកផ្គត់ផ្គង់នៅឡើយទេ។';

  @override
  String get vendorListNewTooltip => 'បន្ថែមអ្នកផ្គត់ផ្គង់';

  @override
  String get vendorStatusActive => 'សកម្ម';

  @override
  String get vendorStatusOnHold => 'ផ្អាក';

  @override
  String get vendorStatusArchived => 'បានទុក';

  @override
  String get vendorDetailTitle => 'អ្នកផ្គត់ផ្គង់';

  @override
  String vendorDetailNotFound(String vendorId) {
    return 'យើងរកមិនឃើញអ្នកផ្គត់ផ្គង់ដែលមាន id \"$vendorId\" ទេ។';
  }

  @override
  String get vendorDetailTaxIdLabel => 'លេខពន្ធ';

  @override
  String get vendorDetailOnboardedLabel => 'បានចុះបញ្ជី';

  @override
  String get vendorDetailContactHeading => 'ទំនាក់ទំនង';

  @override
  String get vendorDetailContactPersonLabel => 'បុគ្គលទំនាក់ទំនង';

  @override
  String get vendorDetailEmailLabel => 'អ៊ីមែល';

  @override
  String get vendorDetailPhoneLabel => 'ទូរស័ព្ទ';

  @override
  String get vendorDetailAddressLabel => 'អាសយដ្ឋាន';

  @override
  String get vendorDetailNotesHeading => 'កំណត់ចំណាំ';

  @override
  String get vendorDetailScorecardAction => 'មើលកាតសម្គាល់ការអនុវត្ត';

  @override
  String get vendorFormTitle => 'ចុះបញ្ជីអ្នកផ្គត់ផ្គង់';

  @override
  String get vendorFormSaveTooltip => 'រក្សាទុក';

  @override
  String get vendorFormSaveAction => 'រក្សាទុកអ្នកផ្គត់ផ្គង់';

  @override
  String get vendorFormSavedSnack => 'បានចុះបញ្ជីអ្នកផ្គត់ផ្គង់។';

  @override
  String vendorFormSaveFailed(String message) {
    return 'មិនអាចរក្សាទុកអ្នកផ្គត់ផ្គង់៖ $message';
  }

  @override
  String get vendorFormNameLabel => 'ឈ្មោះអ្នកផ្គត់ផ្គង់';

  @override
  String get vendorFormTaxIdLabel => 'លេខពន្ធ';

  @override
  String get vendorFormEmailLabel => 'អ៊ីមែល';

  @override
  String get vendorFormPhoneLabel => 'ទូរស័ព្ទ';

  @override
  String get vendorFormAddressLabel => 'អាសយដ្ឋាន';

  @override
  String get vendorFormContactPersonLabel => 'បុគ្គលទំនាក់ទំនង (ស្រេចចិត្ត)';

  @override
  String get vendorFormNotesLabel => 'កំណត់ចំណាំ (ស្រេចចិត្ត)';

  @override
  String get vendorScorecardTitle => 'កាតសម្គាល់អ្នកផ្គត់ផ្គង់';

  @override
  String get vendorScorecardCompositeLabel => 'ពិន្ទុរួម';

  @override
  String get vendorScorecardOnTimeLabel => 'ដឹកជញ្ជូនទាន់ពេល';

  @override
  String get vendorScorecardDefectLabel => 'អត្រាខូច';

  @override
  String get vendorScorecardDisputesLabel => 'ជម្លោះបើកចំហ';

  @override
  String get vendorScorecardSpendLabel => 'ការចំណាយសរុប';

  @override
  String get inventoryItemsTitle => 'ទំនិញស្តុក';

  @override
  String get inventoryScanTooltip => 'ស្កែនបាកូដ';

  @override
  String get inventoryLowStockAlertsTooltip => 'ការជូនដំណឹងស្តុកទាប';

  @override
  String get inventoryItemsSearchHint => 'ស្វែងរកតាម SKU, ឈ្មោះ, ទីតាំង, បាកូដ';

  @override
  String get inventoryItemsSortTooltip => 'តម្រៀប';

  @override
  String get inventoryItemsEmpty => 'គ្មានទំនិញត្រូវនឹងតម្រងបច្ចុប្បន្នទេ។';

  @override
  String inventoryItemsError(String message) {
    return 'មិនអាចផ្ទុកស្តុក៖ $message';
  }

  @override
  String inventoryItemsOnHand(String qty) {
    return 'មាន $qty';
  }

  @override
  String inventoryReorderBadge(String qty) {
    return 'បញ្ជាក់ឡើងវិញនៅ $qty';
  }

  @override
  String get inventoryLowStockChip => 'តែស្តុកទាប';

  @override
  String get inventorySortNameAsc => 'ឈ្មោះ (A–Z)';

  @override
  String get inventorySortSkuAsc => 'SKU';

  @override
  String get inventorySortOnHandAsc => 'ស្តុក (ទាបមុន)';

  @override
  String get inventorySortOnHandDesc => 'ស្តុក (ខ្ពស់មុន)';

  @override
  String get inventoryItemDetailTitle => 'ទំនិញ';

  @override
  String inventoryItemNotFound(String itemId) {
    return 'យើងរកមិនឃើញទំនិញដែលមាន id \"$itemId\" ទេ។';
  }

  @override
  String get inventoryDetailWarehouseLabel => 'ឃ្លាំង';

  @override
  String get inventoryDetailLocationLabel => 'ទីតាំង';

  @override
  String get inventoryDetailReorderLabel => 'ចំណុចបញ្ជាឡើងវិញ';

  @override
  String get inventoryDetailUnitCostLabel => 'តម្លៃឯកតា';

  @override
  String get inventoryDetailBarcodeLabel => 'បាកូដ';

  @override
  String get inventoryDetailMovementsHeading => 'ប្រវត្តិចលនា';

  @override
  String get inventoryDetailMovementsEmpty => 'មិនទាន់មានចលនាទេ។';

  @override
  String get inventoryMovementTypeReceipt => 'ទទួលទំនិញ';

  @override
  String get inventoryMovementTypeIssue => 'ចេញទំនិញ';

  @override
  String get inventoryMovementTypeTransfer => 'ផ្ទេរ';

  @override
  String get inventoryMovementTypeAdjustment => 'កែតម្រូវ';

  @override
  String inventoryMovementRunningLabel(String qty) {
    return 'សមតុល្យ $qty';
  }

  @override
  String get inventoryIssueAction => 'ចេញ';

  @override
  String get inventoryReceiptAction => 'ទទួល';

  @override
  String get inventoryTransferAction => 'ផ្ទេរ';

  @override
  String get inventoryLowStockTitle => 'ស្តុកទាប';

  @override
  String get inventoryLowStockEmpty => 'ទំនិញទាំងអស់ខ្ពស់ជាងចំណុចបញ្ជាឡើងវិញ។';

  @override
  String get inventoryScannerTitle => 'ស្កែនបាកូដ';

  @override
  String get inventoryScannerEmpty => 'សូមស្កែនឬបញ្ចូលលេខកូដ។';

  @override
  String inventoryScannerUnknown(String code) {
    return 'គ្មានទំនិញត្រូវនឹង \"$code\" ទេ។';
  }

  @override
  String inventoryScannerError(String message) {
    return 'កំហុសម៉ាស៊ីនស្កែន៖ $message';
  }

  @override
  String get inventoryScannerNoCamera =>
      'មិនមានកាមេរ៉ាសម្រាប់វេទិកានេះ — សូមប្រើការបញ្ចូលដោយដៃខាងក្រោម។';

  @override
  String get inventoryScannerManualHeading => 'ការបញ្ចូលដោយដៃ';

  @override
  String get inventoryScannerManualLabel => 'បាកូដ';

  @override
  String get inventoryScannerManualHint => 'វាយឬបិទភ្ជាប់លេខកូដ';

  @override
  String get inventoryScannerManualUseAction => 'ប្រើ';

  @override
  String get inventoryScannerBrowseFallback => 'មើលកាតាឡុកជំនួស';

  @override
  String get inventoryReceiptFormTitle => 'ទទួលស្តុក';

  @override
  String get inventoryIssueFormTitle => 'ចេញស្តុក';

  @override
  String get inventoryReceiptSuccessSnack => 'បានទទួលស្តុក។';

  @override
  String get inventoryIssueSuccessSnack => 'បានចេញស្តុក។';

  @override
  String get inventoryMovementGenericSuccess => 'បានកត់ត្រាចលនា។';

  @override
  String inventoryMovementFailed(String message) {
    return 'មិនអាចកត់ត្រាចលនា៖ $message';
  }

  @override
  String inventoryFormCurrentOnHand(String qty) {
    return 'ស្តុកបច្ចុប្បន្ន៖ $qty';
  }

  @override
  String get inventoryFormQuantityLabel => 'បរិមាណ';

  @override
  String get inventoryFormReferenceLabel => 'ឯកសារយោង (ស្រេចចិត្ត)';

  @override
  String get inventoryFormReferenceReceiptHint => 'ឧ. PO-2026-001';

  @override
  String get inventoryFormReferenceIssueHint => 'ឧ. SO-2026-014';

  @override
  String get inventoryFormNoteLabel => 'កំណត់ចំណាំ';

  @override
  String get inventoryQtyExceedsOnHand => 'បរិមាណលើសពីស្តុកបច្ចុប្បន្ន។';

  @override
  String get inventoryTransferFormTitle => 'ផ្ទេរស្តុក';

  @override
  String get inventoryTransferSourceHeading => 'ពី';

  @override
  String get inventoryTransferDestinationLabel => 'ទីតាំងគោលដៅ';

  @override
  String get inventoryTransferNoDestinations =>
      'គ្មានទីតាំងគោលដៅសកម្មសម្រាប់ SKU នេះទេ។';

  @override
  String get inventoryTransferReferenceHint => 'កំណត់ចំណាំការផ្ទេរផ្ទៃក្នុង';

  @override
  String get inventoryTransferPickDestination => 'សូមជ្រើសរើសទីតាំងគោលដៅ។';

  @override
  String get inventoryTransferSuccess => 'បានផ្ទេរស្តុក។';

  @override
  String get inventoryCycleCountTitle => 'ការរាប់វដ្ត';

  @override
  String get inventoryCycleNoItems => 'គ្មានទំនិញត្រូវរាប់ទេ។';

  @override
  String get inventoryCycleAllWarehouses => 'ឃ្លាំងទាំងអស់';

  @override
  String inventoryCycleExpectedLabel(String qty) {
    return 'រំពឹង $qty';
  }

  @override
  String get inventoryCycleCountedLabel => 'បានរាប់';

  @override
  String get inventoryCycleEmpty =>
      'សូមបញ្ចូលបរិមាណដែលបានរាប់សម្រាប់យ៉ាងហោចណាស់មួយ។';

  @override
  String get inventoryCycleSubmitAction => 'ដាក់ស្នើការរាប់';

  @override
  String inventoryCycleSuccess(int count, String variance) {
    return 'បានបង្ហោះការកែតម្រូវ $count ដង; ភាពខុសគ្នា $variance។';
  }

  @override
  String get salesCustomersTitle => 'អតិថិជន';

  @override
  String get salesAnalyticsTooltip => 'ការវិភាគ';

  @override
  String get salesCustomersSearchHint => 'ស្វែងរកតាមឈ្មោះ អ៊ីមែល ឧស្សាហកម្ម';

  @override
  String get salesCustomersSortTooltip => 'តម្រៀប';

  @override
  String get salesCustomersEmpty => 'គ្មានអតិថិជនត្រូវនឹងតម្រងរបស់អ្នកទេ។';

  @override
  String salesCustomersError(String message) {
    return 'មិនអាចផ្ទុកអតិថិជន៖ $message';
  }

  @override
  String salesCustomersOnboardedLabel(String date) {
    return 'ចាប់ពី $date';
  }

  @override
  String get salesCustomersSortName => 'ឈ្មោះ (A–Z)';

  @override
  String get salesCustomersSortLtv => 'តម្លៃពេញមួយជីវិត';

  @override
  String get salesCustomersSortRecent => 'បានបន្ថែមថ្មីៗ';

  @override
  String get salesStatusProspect => 'អនាគត';

  @override
  String get salesStatusActive => 'សកម្ម';

  @override
  String get salesStatusOnHold => 'ផ្អាក';

  @override
  String get salesStatusChurned => 'ចេញ';

  @override
  String get salesSegmentSmb => 'SMB';

  @override
  String get salesSegmentMidMarket => 'ទីផ្សារកណ្តាល';

  @override
  String get salesSegmentEnterprise => 'សហគ្រាស';

  @override
  String get salesCustomerDetailTitle => 'អតិថិជន';

  @override
  String salesCustomerNotFound(String customerId) {
    return 'យើងរកមិនឃើញអតិថិជនដែលមាន id \"$customerId\" ទេ។';
  }

  @override
  String get salesCustomerDetailEmailLabel => 'អ៊ីមែល';

  @override
  String get salesCustomerDetailPhoneLabel => 'ទូរស័ព្ទ';

  @override
  String get salesCustomerDetailAddressLabel => 'អាសយដ្ឋានវិក្កយបត្រ';

  @override
  String get salesCustomerDetailLifetimeValueLabel => 'តម្លៃពេញមួយជីវិត';

  @override
  String get salesCustomerDetailSinceLabel => 'អតិថិជនចាប់ពី';

  @override
  String get salesCustomerDetailNotesHeading => 'កំណត់ចំណាំ';

  @override
  String get salesCustomerDetailContactsHeading => 'ទំនាក់ទំនង';

  @override
  String get salesCustomerDetailContactsEmpty =>
      'មិនទាន់មានទំនាក់ទំនងភ្ជាប់ទេ។';

  @override
  String get salesCustomerDetailTimelineHeading => 'សកម្មភាព';

  @override
  String get salesCustomerDetailTimelineEmpty => 'មិនទាន់មានសកម្មភាពទេ។';

  @override
  String get salesContactAddAction => 'បន្ថែមទំនាក់ទំនង';

  @override
  String get salesContactEditAction => 'កែសម្រួល';

  @override
  String get salesContactDeleteAction => 'លុប';

  @override
  String get salesContactPrimaryBadge => 'ចម្បង';

  @override
  String get salesContactNewTitle => 'ទំនាក់ទំនងថ្មី';

  @override
  String get salesContactEditTitle => 'កែសម្រួលទំនាក់ទំនង';

  @override
  String get salesContactNameLabel => 'ឈ្មោះ';

  @override
  String get salesContactRoleLabel => 'តួនាទី';

  @override
  String get salesContactEmailLabel => 'អ៊ីមែល';

  @override
  String get salesContactPhoneLabel => 'ទូរស័ព្ទ';

  @override
  String get salesContactPrimaryToggle => 'ទំនាក់ទំនងចម្បង';

  @override
  String get salesContactPrimaryDescription =>
      'បង្ហាញទំនាក់ទំនងនេះនៅក្បាលអតិថិជន។';

  @override
  String get salesContactSaveAction => 'រក្សាទុកទំនាក់ទំនង';

  @override
  String get salesContactSavedSnack => 'បានរក្សាទុកទំនាក់ទំនង។';

  @override
  String salesContactSaveFailed(String message) {
    return 'មិនអាចរក្សាទុកទំនាក់ទំនង៖ $message';
  }

  @override
  String get salesContactDeleteTitle => 'លុបទំនាក់ទំនង?';

  @override
  String get salesContactDeleteBody => 'ទំនាក់ទំនងនឹងត្រូវយកចេញពីអតិថិជននេះ។';

  @override
  String get salesContactDeleteConfirm => 'លុប';

  @override
  String get salesContactDeletedSnack => 'បានយកទំនាក់ទំនងចេញ។';

  @override
  String get salesActivityLogAction => 'កត់ត្រាសកម្មភាព';

  @override
  String get salesActivityFormTitle => 'កត់ត្រាសកម្មភាព';

  @override
  String get salesActivityTypeLabel => 'ប្រភេទ';

  @override
  String get salesActivitySummaryLabel => 'សង្ខេប';

  @override
  String get salesActivityActorLabel => 'កត់ត្រាដោយ';

  @override
  String get salesActivitySaveAction => 'រក្សាទុកសកម្មភាព';

  @override
  String get salesActivitySavedSnack => 'បានកត់ត្រាសកម្មភាព។';

  @override
  String salesActivitySaveFailed(String message) {
    return 'មិនអាចកត់ត្រាសកម្មភាព៖ $message';
  }

  @override
  String get salesActivityTypeNote => 'កំណត់ចំណាំ';

  @override
  String get salesActivityTypeCall => 'ការហៅ';

  @override
  String get salesActivityTypeMeeting => 'ការប្រជុំ';

  @override
  String get salesActivityTypeEmail => 'អ៊ីមែល';

  @override
  String get salesActivityTypeQuotation => 'វិក្កយបត្ររបង់';

  @override
  String get salesActivityTypeOrder => 'ការបញ្ជាទិញ';

  @override
  String get salesActivityTypePayment => 'ការបង់ប្រាក់';

  @override
  String get salesQuotationListTitle => 'វិក្កយបត្ររបង់';

  @override
  String get salesQuotationNewTooltip => 'វិក្កយបត្ររបង់ថ្មី';

  @override
  String get salesQuotationSearchHint => 'ស្វែងរកតាមលេខឬអតិថិជន';

  @override
  String get salesQuotationSortTooltip => 'តម្រៀប';

  @override
  String get salesQuotationListEmpty => 'គ្មានវិក្កយបត្ររបង់ត្រូវនឹងតម្រងទេ។';

  @override
  String salesQuotationValidUntilLabel(String date) {
    return 'សុពលភាពដល់ $date';
  }

  @override
  String get salesQuotationSortCreatedDesc => 'បង្កើត (ថ្មីបំផុត)';

  @override
  String get salesQuotationSortCreatedAsc => 'បង្កើត (ចាស់បំផុត)';

  @override
  String get salesQuotationSortTotalDesc => 'សរុប (ច្រើនបំផុត)';

  @override
  String get salesQuotationSortValidity => 'ផុតកំណត់បន្ទាប់';

  @override
  String get salesQuotationStatusDraft => 'ព្រាង';

  @override
  String get salesQuotationStatusSent => 'បានផ្ញើ';

  @override
  String get salesQuotationStatusAccepted => 'បានទទួលយក';

  @override
  String get salesQuotationStatusRejected => 'បានបដិសេធ';

  @override
  String get salesQuotationStatusExpired => 'ផុតកំណត់';

  @override
  String get salesQuotationStatusConverted => 'បានបម្លែង';

  @override
  String get salesQuotationNewTitle => 'វិក្កយបត្ររបង់ថ្មី';

  @override
  String get salesQuotationCustomerLabel => 'អតិថិជន';

  @override
  String get salesQuotationValidUntilField => 'សុពលភាពដល់';

  @override
  String get salesQuotationLinesHeading => 'បន្ទាត់ទំនិញ';

  @override
  String salesQuotationLineHeading(int index) {
    return 'បន្ទាត់ $index';
  }

  @override
  String get salesQuotationAddLineAction => 'បន្ថែមបន្ទាត់';

  @override
  String get salesQuotationRemoveLineTooltip => 'លុបបន្ទាត់';

  @override
  String get salesQuotationLineDescriptionLabel => 'ការពិពណ៌នា';

  @override
  String get salesQuotationLineQuantityLabel => 'ចំនួន';

  @override
  String get salesQuotationLineUnitPriceLabel => 'តម្លៃឯកតា';

  @override
  String get salesQuotationSaveAction => 'រក្សាទុក';

  @override
  String get salesQuotationSavedSnack => 'បានរក្សាទុកវិក្កយបត្ររបង់។';

  @override
  String salesQuotationSaveFailed(String message) {
    return 'មិនអាចរក្សាទុក៖ $message';
  }

  @override
  String get salesQuotationPickCustomer => 'សូមជ្រើសរើសអតិថិជន។';

  @override
  String get salesQuotationDetailTitle => 'វិក្កយបត្ររបង់';

  @override
  String salesQuotationNotFound(String quotationId) {
    return 'យើងរកមិនឃើញវិក្កយបត្ររបង់ដែលមាន id \"$quotationId\" ទេ។';
  }

  @override
  String get salesQuotationCreatedLabel => 'បង្កើត';

  @override
  String get salesQuotationValidUntilLabel2 => 'សុពលភាពដល់';

  @override
  String get salesQuotationDetailLinesHeading => 'បន្ទាត់ទំនិញ';

  @override
  String get salesQuotationTotalLabel => 'សរុប';

  @override
  String get salesQuotationNotesHeading => 'កំណត់ចំណាំ';

  @override
  String get salesQuotationSendAction => 'ផ្ញើទៅអតិថិជន';

  @override
  String get salesQuotationAcceptAction => 'សម្គាល់ថាបានទទួលយក';

  @override
  String get salesQuotationRejectAction => 'សម្គាល់ថាបានបដិសេធ';

  @override
  String get salesQuotationConvertAction => 'បម្លែងទៅការបញ្ជាទិញ';

  @override
  String get salesQuotationStatusUpdated =>
      'បានធ្វើបច្ចុប្បន្នភាពវិក្កយបត្ររបង់។';

  @override
  String get salesQuotationConvertedSnack => 'បានបង្កើតការបញ្ជាទិញ។';

  @override
  String salesQuotationActionFailed(String message) {
    return 'មិនអាចធ្វើបច្ចុប្បន្នភាព៖ $message';
  }

  @override
  String get salesQuotationConvertNotAccepted =>
      'មានតែវិក្កយបត្ររបង់ដែលបានទទួលយកអាចបម្លែងបាន។';

  @override
  String get salesQuotationConvertAlready =>
      'វិក្កយបត្ររបង់នេះត្រូវបានបម្លែងរួចហើយ។';

  @override
  String get salesQuotationConvertExpired => 'វិក្កយបត្ររបង់នេះផុតកំណត់ហើយ។';

  @override
  String get salesOrderListTitle => 'ការបញ្ជាទិញ';

  @override
  String get salesOrderListEmpty => 'មិនទាន់មានការបញ្ជាទិញទេ។';

  @override
  String get salesOrderStatusPending => 'កំពុងរង់ចាំ';

  @override
  String get salesOrderStatusPacking => 'កំពុងវេចខ្ចប់';

  @override
  String get salesOrderStatusShipped => 'បានដឹកជញ្ជូន';

  @override
  String get salesOrderStatusDelivered => 'បានដឹកដល់';

  @override
  String get salesOrderStatusCancelled => 'បានលុបចោល';

  @override
  String get salesOrderDetailTitle => 'ការបញ្ជាទិញ';

  @override
  String salesOrderNotFound(String orderId) {
    return 'យើងរកមិនឃើញការបញ្ជាទិញដែលមាន id \"$orderId\" ទេ។';
  }

  @override
  String get salesOrderCreatedLabel => 'បង្កើត';

  @override
  String get salesOrderSourceQuotationLabel => 'វិក្កយបត្ររបង់ប្រភព';

  @override
  String get salesOrderShippedAtLabel => 'បានដឹកជញ្ជូន';

  @override
  String get salesOrderDeliveredAtLabel => 'បានដឹកដល់';

  @override
  String get salesOrderTrackingLabel => 'តាមដាន';

  @override
  String get salesOrderDetailLinesHeading => 'បន្ទាត់ទំនិញ';

  @override
  String get salesOrderCancelAction => 'បោះបង់';

  @override
  String get salesOrderStartPackingAction => 'ចាប់ផ្តើមវេចខ្ចប់';

  @override
  String get salesOrderShipAction => 'ដឹកជញ្ជូន';

  @override
  String get salesOrderMarkDeliveredAction => 'សម្គាល់ថាបានដឹកដល់';

  @override
  String get salesOrderTrackingDialogTitle => 'ឯកសារយោងតាមដាន';

  @override
  String get salesOrderTrackingConfirm => 'បញ្ជាក់';

  @override
  String get salesOrderTrackingRequired =>
      'ត្រូវការឯកសារយោងតាមដានដើម្បីដឹកជញ្ជូន។';

  @override
  String salesOrderAdvancedSnack(String status) {
    return 'បានសម្គាល់ការបញ្ជាទិញជា $status។';
  }

  @override
  String salesOrderAdvanceFailed(String message) {
    return 'មិនអាចធ្វើបច្ចុប្បន្នភាពការបញ្ជាទិញ៖ $message';
  }

  @override
  String get salesAnalyticsTitle => 'ការវិភាគការលក់';

  @override
  String get salesAnalyticsRevenueHeading => 'ចំណូល';

  @override
  String get salesAnalyticsRevenueEmpty =>
      'មិនមានចំណូលក្នុងបង្អួចដែលបានជ្រើសរើស។';

  @override
  String get salesAnalyticsPeriodWeekly => 'ប្រចាំសប្តាហ៍';

  @override
  String get salesAnalyticsPeriodMonthly => 'ប្រចាំខែ';

  @override
  String get salesAnalyticsTopCustomersHeading => 'អតិថិជនកំពូល';

  @override
  String get salesAnalyticsTopCustomersEmpty =>
      'មិនទាន់មានចំណូលអតិថិជនដើម្បីចាត់ថ្នាក់ទេ។';

  @override
  String get salesAnalyticsTopProductsHeading => 'ផលិតផលកំពូល';

  @override
  String get salesAnalyticsTopProductsEmpty =>
      'មិនទាន់មានចំណូលផលិតផលដើម្បីចាត់ថ្នាក់ទេ។';

  @override
  String get salesAnalyticsLeaderboardHeading => 'តារាងចំណាត់ថ្នាក់អ្នកលក់';

  @override
  String get salesAnalyticsLeaderboardEmpty => 'មិនទាន់មានអ្នកលក់ទេ។';

  @override
  String salesAnalyticsLeaderboardDealsLabel(String count) {
    return 'បានបិទ $count កិច្ច';
  }

  @override
  String salesAnalyticsLeaderboardAttainmentLabel(String pct, String target) {
    return '$pct% នៃ $target';
  }
}
