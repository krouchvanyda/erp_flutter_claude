// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'ERP Mobile';

  @override
  String get loginAppBarTitle => 'Sign in';

  @override
  String get loginButton => 'Sign in (placeholder)';

  @override
  String get dashboardTitle => 'Dashboard';

  @override
  String get dashboardPlaceholder =>
      'Dashboard placeholder — Module 2 will fill this in.';

  @override
  String get signOutTooltip => 'Sign out';

  @override
  String get notFoundTitle => 'Not found';

  @override
  String notFoundBody(String location) {
    return 'No route matches \"$location\"';
  }

  @override
  String get goHome => 'Go home';

  @override
  String get loginOtpDemoLink => '[demo] Try MFA code';

  @override
  String get otpPageTitle => 'Verification';

  @override
  String get otpSubtitle =>
      'Enter the 6-digit code from your authenticator app or SMS.';

  @override
  String otpDevHint(String code) {
    return 'Demo: enter $code to continue';
  }

  @override
  String get otpVerifyButton => 'Verify';

  @override
  String get otpErrorIncorrect => 'Code is incorrect. Please try again.';

  @override
  String get otpErrorExpired => 'This code has expired. Request a new one.';

  @override
  String get otpErrorTooManyAttempts =>
      'Too many attempts. Please try again later.';

  @override
  String get otpErrorNetwork =>
      'Couldn\'t reach the server. Check your connection.';

  @override
  String get forbiddenTitle => 'Access denied';

  @override
  String forbiddenBody(String location) {
    return 'You don\'t have permission to access \"$location\".';
  }

  @override
  String get adminDemoTitle => 'Admin demo';

  @override
  String get adminDemoBody =>
      'You reached the admin-only demo route — RBAC works.';

  @override
  String get dashboardAdminDemoLink => '[demo] Open admin-only page';

  @override
  String get permissionGuardDemoGranted =>
      '[demo] PermissionGuard: admin granted';

  @override
  String get permissionGuardDemoDenied =>
      '[demo] PermissionGuard: admin denied';

  @override
  String get shellHome => 'Home';

  @override
  String get shellModules => 'Modules';

  @override
  String get shellSettings => 'Settings';

  @override
  String get modulesTitle => 'Modules';

  @override
  String get modulesPlaceholder =>
      'Module shortcut tiles land here in Slice 2.1.2.';

  @override
  String get modulesEmpty =>
      'No modules are available for your role yet. Ask an admin to grant the permissions you need.';

  @override
  String get shortcutAdminDemo => 'Admin demo';

  @override
  String get shortcutFinance => 'Finance';

  @override
  String get shortcutProcurement => 'Procurement';

  @override
  String get shortcutInventory => 'Inventory';

  @override
  String get shortcutSales => 'Sales';

  @override
  String get shortcutHr => 'HR';

  @override
  String get shortcutProjects => 'Projects';

  @override
  String comingSoonBody(String module) {
    return '$module ships in a future release.';
  }

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsPlaceholder => 'Real preferences land here in Module 9.';

  @override
  String get globalSearchTooltip => 'Search';

  @override
  String get globalSearchHint => 'Search modules, records, people…';

  @override
  String get globalSearchPrompt =>
      'Type to search across every module you can access.';

  @override
  String globalSearchNoResults(String query) {
    return 'No results for \"$query\".';
  }

  @override
  String globalSearchError(String message) {
    return 'Search failed: $message';
  }

  @override
  String get kpiTrendUp => 'up';

  @override
  String get kpiTrendDown => 'down';

  @override
  String get kpiTrendFlat => 'flat';

  @override
  String get kpiTrendUpTooltip => 'Up vs prior period';

  @override
  String get kpiTrendDownTooltip => 'Down vs prior period';

  @override
  String get kpiTrendFlatTooltip => 'No meaningful change vs prior period';

  @override
  String get chartRevenueTrendTitle => 'Revenue trend';

  @override
  String get chartSalesByRegionTitle => 'Sales by region';

  @override
  String get chartSeriesRevenue => 'Revenue';

  @override
  String get chartSeriesTarget => 'Target';

  @override
  String get chartSeriesSales => 'Sales';

  @override
  String get realtimeStatusLive => 'Live';

  @override
  String get realtimeStatusConnecting => 'Connecting';

  @override
  String get realtimeStatusReconnecting => 'Reconnecting';

  @override
  String get realtimeStatusOffline => 'Offline';

  @override
  String get pushDemoButton => '[dev] Simulate push';

  @override
  String pushDemoTitle(int count) {
    return 'Demo notification #$count';
  }

  @override
  String get pushDemoBody =>
      'Routed through PushMessageRouter into the inbox cache.';

  @override
  String get pushDemoSnack => 'Pushed to inbox.';

  @override
  String get notificationsBadgeTooltip => 'Notifications';

  @override
  String get notificationInboxTitle => 'Notifications';

  @override
  String get notificationInboxEmpty =>
      'You\'re all caught up. New notifications will appear here.';

  @override
  String notificationInboxError(String message) {
    return 'Couldn\'t load notifications: $message';
  }

  @override
  String get notificationInboxMarkAllRead => 'Mark all as read';

  @override
  String get notificationInboxDismissedSnack => 'Notification dismissed.';

  @override
  String notificationDeepLinkError(String message) {
    return 'Couldn\'t open this notification: $message';
  }

  @override
  String get notificationDeepLinkViewAction => 'View';

  @override
  String get pushDemoRoutedButton => '[dev] Simulate routed push';

  @override
  String get pushDemoRoutedBody =>
      'Tap this notification — or the Snackbar\'s View — to deep-link to the target.';

  @override
  String get chartOfAccountsTitle => 'Chart of accounts';

  @override
  String get chartOfAccountsEmpty => 'No accounts have been loaded yet.';

  @override
  String chartOfAccountsError(String message) {
    return 'Couldn\'t load the chart of accounts: $message';
  }

  @override
  String get chartOfAccountsExpandAll => 'Expand all';

  @override
  String get chartOfAccountsCollapseAll => 'Collapse all';

  @override
  String get dashboardChartOfAccountsLink => '[demo] Open chart of accounts';

  @override
  String get accountTypeAsset => 'Asset';

  @override
  String get accountTypeLiability => 'Liability';

  @override
  String get accountTypeEquity => 'Equity';

  @override
  String get accountTypeRevenue => 'Revenue';

  @override
  String get accountTypeExpense => 'Expense';

  @override
  String get accountDetailTitle => 'Account';

  @override
  String get accountDetailNoTransactions =>
      'No transactions have been posted to this account yet.';

  @override
  String accountDetailNotFound(String accountId) {
    return 'We couldn\'t find an account with id \"$accountId\".';
  }

  @override
  String accountDetailError(String message) {
    return 'Couldn\'t load this account: $message';
  }

  @override
  String get invoiceListTitle => 'Invoices';

  @override
  String get invoiceListSearchHint => 'Search by number or customer';

  @override
  String get invoiceListSortTooltip => 'Sort';

  @override
  String get invoiceListEmpty => 'No invoices match your filters.';

  @override
  String invoiceListError(String message) {
    return 'Couldn\'t load invoices: $message';
  }

  @override
  String invoiceListDueLabel(String date) {
    return 'due $date';
  }

  @override
  String get invoiceStatusDraft => 'Draft';

  @override
  String get invoiceStatusPendingApproval => 'Pending approval';

  @override
  String get invoiceStatusApproved => 'Approved';

  @override
  String get invoiceStatusRejected => 'Rejected';

  @override
  String get invoiceSortIssuedDesc => 'Issued (newest)';

  @override
  String get invoiceSortIssuedAsc => 'Issued (oldest)';

  @override
  String get invoiceSortDueAsc => 'Due (soonest)';

  @override
  String get invoiceSortAmountDesc => 'Amount (largest)';

  @override
  String get invoiceSortNumberAsc => 'Invoice number';

  @override
  String get invoiceDetailTitle => 'Invoice';

  @override
  String get invoiceDetailIssuedLabel => 'Issued';

  @override
  String get invoiceDetailDueLabel => 'Due';

  @override
  String get invoiceDetailLinesHeading => 'Line items';

  @override
  String get invoiceDetailSubtotalLabel => 'Subtotal';

  @override
  String get invoiceDetailTaxLabel => 'Tax';

  @override
  String get invoiceDetailTotalLabel => 'Total';

  @override
  String get invoiceDetailNotesHeading => 'Notes';

  @override
  String get invoiceDetailPdfHeading => 'PDF preview';

  @override
  String get invoiceDetailPdfPlaceholder =>
      'PDF rendering ships with the backend that serves it.';

  @override
  String invoiceDetailNotFound(String invoiceId) {
    return 'We couldn\'t find an invoice with id \"$invoiceId\".';
  }

  @override
  String invoiceDetailError(String message) {
    return 'Couldn\'t load this invoice: $message';
  }

  @override
  String get invoiceApproveAction => 'Approve';

  @override
  String get invoiceRejectAction => 'Reject';

  @override
  String get invoiceSubmitAction => 'Submit for approval';

  @override
  String get invoiceReopenAction => 'Re-open for revision';

  @override
  String get invoiceActionCancel => 'Cancel';

  @override
  String get invoiceApproveSheetTitle => 'Approve this invoice?';

  @override
  String invoiceApproveSheetBody(String invoiceNumber) {
    return 'You\'re about to approve $invoiceNumber. The invoice will be locked once approved.';
  }

  @override
  String get invoiceRejectSheetTitle => 'Reject this invoice?';

  @override
  String invoiceRejectSheetBody(String invoiceNumber) {
    return '$invoiceNumber will be returned to the requester with the reason below.';
  }

  @override
  String get invoiceRejectReasonLabel => 'Reason';

  @override
  String get invoiceRejectReasonHint => 'Why is this invoice being rejected?';

  @override
  String get invoiceRejectReasonRequired => 'Please give a reason.';

  @override
  String invoiceActionSuccess(String status) {
    return 'Invoice marked as $status.';
  }

  @override
  String get invoiceActionForbidden =>
      'You don\'t have permission to action this invoice.';

  @override
  String get invoiceActionNotFound => 'That invoice no longer exists.';

  @override
  String get invoiceActionInvalidState =>
      'This invoice has already been actioned.';

  @override
  String get invoiceActionUnauthorized =>
      'Sign-in expired — please sign in again.';

  @override
  String invoiceActionGenericError(String message) {
    return 'Couldn\'t action the invoice: $message';
  }

  @override
  String get invoiceAuditApprovedHeading => 'Approved';

  @override
  String get invoiceAuditRejectedHeading => 'Rejected';

  @override
  String invoiceAuditActorLine(String userId) {
    return 'by $userId';
  }

  @override
  String invoiceAuditWhenLine(String when) {
    return 'at $when';
  }

  @override
  String invoiceAuditReasonLine(String reason) {
    return 'Reason: $reason';
  }

  @override
  String get invoiceFormCreateTitle => 'New invoice';

  @override
  String get invoiceFormEditTitle => 'Edit invoice';

  @override
  String get invoiceFormSaveTooltip => 'Save';

  @override
  String get invoiceFormSaveAction => 'Save invoice';

  @override
  String get invoiceFormSavedSnack => 'Invoice saved.';

  @override
  String get invoiceFormCustomerLabel => 'Customer';

  @override
  String get invoiceFormIssuedLabel => 'Issued date';

  @override
  String get invoiceFormDueLabel => 'Due date';

  @override
  String get invoiceFormLineHeading => 'Line item';

  @override
  String get invoiceFormLineDescriptionLabel => 'Description';

  @override
  String get invoiceFormLineQuantityLabel => 'Quantity';

  @override
  String get invoiceFormLineUnitPriceLabel => 'Unit price';

  @override
  String get validatorRequired => 'Required';

  @override
  String get validatorInvalidNumber => 'Must be a number';

  @override
  String get validatorMustBePositive => 'Must be greater than 0';

  @override
  String get validatorMustBeNonNegative => 'Cannot be negative';

  @override
  String get validatorDueBeforeIssued =>
      'Due date must be on or after the issued date';

  @override
  String get journalEntriesTitle => 'Journal entries';

  @override
  String get journalEntriesEmpty => 'No journal entries posted in this period.';

  @override
  String get journalEntryDetailTitle => 'Journal entry';

  @override
  String journalEntryNotFound(String id) {
    return 'Journal entry \"$id\" was not found.';
  }

  @override
  String get journalEntryAccountColumn => 'Account';

  @override
  String get journalEntryDebitColumn => 'Debit';

  @override
  String get journalEntryCreditColumn => 'Credit';

  @override
  String get journalEntryTotalLabel => 'Total';

  @override
  String get trialBalanceTitle => 'Trial balance';

  @override
  String get trialBalanceEmpty => 'No accounts have non-zero balances yet.';

  @override
  String get trialBalanceColumnCode => 'Code';

  @override
  String get trialBalanceColumnName => 'Account';

  @override
  String get trialBalanceColumnDebit => 'Debit';

  @override
  String get trialBalanceColumnCredit => 'Credit';

  @override
  String trialBalancePageOf(int current, int total) {
    return 'Page $current of $total';
  }

  @override
  String get trialBalanceExportCsvTooltip => 'Export CSV';

  @override
  String trialBalanceExportSuccess(String path) {
    return 'CSV saved to $path';
  }

  @override
  String trialBalanceExportError(String message) {
    return 'CSV export failed: $message';
  }

  @override
  String get validatorInvalidEmail => 'Please enter a valid email';

  @override
  String get prListTitle => 'Purchase requests';

  @override
  String get prListNewTooltip => 'New PR';

  @override
  String get prListSearchHint => 'Search by number, requester, cost center';

  @override
  String get prListSortTooltip => 'Sort';

  @override
  String get prListEmpty => 'No purchase requests match your filters.';

  @override
  String prListError(String message) {
    return 'Couldn\'t load purchase requests: $message';
  }

  @override
  String get prStatusDraft => 'Draft';

  @override
  String get prStatusSubmitted => 'Submitted';

  @override
  String get prStatusApproved => 'Approved';

  @override
  String get prStatusRejected => 'Rejected';

  @override
  String get prStatusConverted => 'Converted';

  @override
  String get prSortCreatedDesc => 'Created (newest)';

  @override
  String get prSortCreatedAsc => 'Created (oldest)';

  @override
  String get prSortTotalDesc => 'Total (largest)';

  @override
  String get prSortNumberAsc => 'PR number';

  @override
  String get prFormCreateTitle => 'New purchase request';

  @override
  String get prFormSaveTooltip => 'Submit';

  @override
  String get prFormSubmitAction => 'Submit request';

  @override
  String get prFormSavedSnack => 'Purchase request submitted.';

  @override
  String prFormSaveFailed(String message) {
    return 'Couldn\'t submit the request: $message';
  }

  @override
  String get prFormRequesterLabel => 'Requester';

  @override
  String get prFormCostCenterLabel => 'Cost center';

  @override
  String get prFormApproverLabel => 'Approver';

  @override
  String get prFormJustificationLabel => 'Justification (optional)';

  @override
  String get prFormLinesHeading => 'Line items';

  @override
  String prFormLineHeading(int index) {
    return 'Line $index';
  }

  @override
  String get prFormAddLineAction => 'Add line';

  @override
  String get prFormRemoveLineTooltip => 'Remove line';

  @override
  String get prFormLineDescriptionLabel => 'Description';

  @override
  String get prFormLineQuantityLabel => 'Qty';

  @override
  String get prFormLineUnitPriceLabel => 'Unit price';

  @override
  String get prDetailTitle => 'Purchase request';

  @override
  String prDetailNotFound(String prId) {
    return 'We couldn\'t find a purchase request with id \"$prId\".';
  }

  @override
  String prDetailError(String message) {
    return 'Couldn\'t load this purchase request: $message';
  }

  @override
  String get prDetailRequesterLabel => 'Requester';

  @override
  String get prDetailCostCenterLabel => 'Cost center';

  @override
  String get prDetailApproverLabel => 'Approver';

  @override
  String get prDetailCreatedLabel => 'Created';

  @override
  String get prDetailJustificationHeading => 'Justification';

  @override
  String get prDetailLinesHeading => 'Line items';

  @override
  String get prDetailTotalLabel => 'Total';

  @override
  String get prApproveAction => 'Approve';

  @override
  String get prRejectAction => 'Reject';

  @override
  String get prSubmitAction => 'Submit';

  @override
  String get prConvertAction => 'Convert to PO';

  @override
  String get prSubmittedSnack => 'Purchase request submitted.';

  @override
  String prApprovedSnack(String status) {
    return 'Purchase request marked as $status.';
  }

  @override
  String get prRejectedSnack => 'Purchase request rejected.';

  @override
  String get prConvertedSnack => 'Purchase order created.';

  @override
  String prApprovalNotAllowed(String action) {
    return 'This request can\'t be $action from its current status.';
  }

  @override
  String prApprovalFailed(String message) {
    return 'Couldn\'t update the request: $message';
  }

  @override
  String get prRejectDialogTitle => 'Reject request';

  @override
  String get prRejectReasonLabel => 'Reason';

  @override
  String get prRejectReasonHint => 'Why is this request being rejected?';

  @override
  String get prRejectReasonRequired => 'Please give a reason.';

  @override
  String get prRejectCancel => 'Cancel';

  @override
  String get prRejectConfirm => 'Reject request';

  @override
  String get prConvertDialogTitle => 'Convert to purchase order';

  @override
  String get prConvertVendorLabel => 'Vendor';

  @override
  String get prConvertExpectedLabel => 'Expected delivery';

  @override
  String get prConvertVendorRequired => 'Please pick a vendor.';

  @override
  String get prConvertConfirm => 'Create PO';

  @override
  String get prConvertCancel => 'Cancel';

  @override
  String get poListTitle => 'Purchase orders';

  @override
  String get poListEmpty => 'No purchase orders yet.';

  @override
  String poListExpectedLabel(String date) {
    return 'expected $date';
  }

  @override
  String get poStatusOpen => 'Open';

  @override
  String get poStatusPartial => 'Partial';

  @override
  String get poStatusFull => 'Received';

  @override
  String get poStatusClosed => 'Closed';

  @override
  String get poStatusCancelled => 'Cancelled';

  @override
  String get poDetailTitle => 'Purchase order';

  @override
  String poDetailNotFound(String poId) {
    return 'We couldn\'t find a purchase order with id \"$poId\".';
  }

  @override
  String get poDetailCreatedLabel => 'Created';

  @override
  String get poDetailExpectedLabel => 'Expected';

  @override
  String get poDetailSourcePrLabel => 'Source PR';

  @override
  String get poDetailLinesHeading => 'Line items';

  @override
  String get poDetailTotalLabel => 'Total';

  @override
  String get poDetailReceiptsHeading => 'Goods receipts';

  @override
  String get poDetailReceiptsEmpty => 'No receipts recorded yet.';

  @override
  String poDetailReceiptItemsBadge(int count) {
    return '$count item(s)';
  }

  @override
  String get poDetailRecordReceiptAction => 'Record goods receipt';

  @override
  String poLineOrderedLabel(String qty) {
    return 'ordered $qty';
  }

  @override
  String poLineReceivedLabel(String qty) {
    return 'received $qty';
  }

  @override
  String poLineOutstandingLabel(String qty) {
    return 'outstanding $qty';
  }

  @override
  String get goodsReceiptFormTitle => 'Goods receipt';

  @override
  String goodsReceiptFormForPo(String number) {
    return 'Receiving against $number';
  }

  @override
  String get goodsReceiptReceivedByLabel => 'Received by';

  @override
  String get goodsReceiptNoteLabel => 'Note (optional)';

  @override
  String get goodsReceiptLinesHeading => 'Quantities received';

  @override
  String get goodsReceiptQuantityLabel => 'Receiving now';

  @override
  String get goodsReceiptSubmitAction => 'Record receipt';

  @override
  String get goodsReceiptSavedSnack => 'Goods receipt recorded.';

  @override
  String goodsReceiptSaveFailed(String message) {
    return 'Couldn\'t record receipt: $message';
  }

  @override
  String get goodsReceiptErrorPoClosed =>
      'This PO is closed and can\'t take more receipts.';

  @override
  String get goodsReceiptErrorNoLines =>
      'Enter a quantity for at least one line.';

  @override
  String get goodsReceiptErrorNonPositive => 'Quantity must be greater than 0.';

  @override
  String get goodsReceiptErrorUnknownLine =>
      'One of the lines doesn\'t belong to this PO.';

  @override
  String get goodsReceiptErrorExceedsOutstanding =>
      'You can\'t receive more than the outstanding quantity.';

  @override
  String get vendorListTitle => 'Vendors';

  @override
  String get vendorListEmpty => 'No vendors onboarded yet.';

  @override
  String get vendorListNewTooltip => 'Onboard vendor';

  @override
  String get vendorStatusActive => 'Active';

  @override
  String get vendorStatusOnHold => 'On hold';

  @override
  String get vendorStatusArchived => 'Archived';

  @override
  String get vendorDetailTitle => 'Vendor';

  @override
  String vendorDetailNotFound(String vendorId) {
    return 'We couldn\'t find a vendor with id \"$vendorId\".';
  }

  @override
  String get vendorDetailTaxIdLabel => 'Tax ID';

  @override
  String get vendorDetailOnboardedLabel => 'Onboarded';

  @override
  String get vendorDetailContactHeading => 'Contact';

  @override
  String get vendorDetailContactPersonLabel => 'Contact person';

  @override
  String get vendorDetailEmailLabel => 'Email';

  @override
  String get vendorDetailPhoneLabel => 'Phone';

  @override
  String get vendorDetailAddressLabel => 'Address';

  @override
  String get vendorDetailNotesHeading => 'Notes';

  @override
  String get vendorDetailScorecardAction => 'View performance scorecard';

  @override
  String get vendorFormTitle => 'Onboard vendor';

  @override
  String get vendorFormSaveTooltip => 'Save';

  @override
  String get vendorFormSaveAction => 'Save vendor';

  @override
  String get vendorFormSavedSnack => 'Vendor onboarded.';

  @override
  String vendorFormSaveFailed(String message) {
    return 'Couldn\'t save the vendor: $message';
  }

  @override
  String get vendorFormNameLabel => 'Vendor name';

  @override
  String get vendorFormTaxIdLabel => 'Tax ID';

  @override
  String get vendorFormEmailLabel => 'Email';

  @override
  String get vendorFormPhoneLabel => 'Phone';

  @override
  String get vendorFormAddressLabel => 'Address';

  @override
  String get vendorFormContactPersonLabel => 'Contact person (optional)';

  @override
  String get vendorFormNotesLabel => 'Notes (optional)';

  @override
  String get vendorScorecardTitle => 'Vendor scorecard';

  @override
  String get vendorScorecardCompositeLabel => 'Composite score';

  @override
  String get vendorScorecardOnTimeLabel => 'On-time delivery';

  @override
  String get vendorScorecardDefectLabel => 'Defect rate';

  @override
  String get vendorScorecardDisputesLabel => 'Open disputes';

  @override
  String get vendorScorecardSpendLabel => 'Total spend';

  @override
  String get inventoryItemsTitle => 'Inventory items';

  @override
  String get inventoryScanTooltip => 'Scan barcode';

  @override
  String get inventoryLowStockAlertsTooltip => 'Low stock alerts';

  @override
  String get inventoryItemsSearchHint =>
      'Search by SKU, name, location, barcode';

  @override
  String get inventoryItemsSortTooltip => 'Sort';

  @override
  String get inventoryItemsEmpty => 'No items match the current filters.';

  @override
  String inventoryItemsError(String message) {
    return 'Couldn\'t load inventory: $message';
  }

  @override
  String inventoryItemsOnHand(String qty) {
    return 'on-hand $qty';
  }

  @override
  String inventoryReorderBadge(String qty) {
    return 'reorder at $qty';
  }

  @override
  String get inventoryLowStockChip => 'Low stock only';

  @override
  String get inventorySortNameAsc => 'Name (A–Z)';

  @override
  String get inventorySortSkuAsc => 'SKU';

  @override
  String get inventorySortOnHandAsc => 'On-hand (low first)';

  @override
  String get inventorySortOnHandDesc => 'On-hand (high first)';

  @override
  String get inventoryItemDetailTitle => 'Item';

  @override
  String inventoryItemNotFound(String itemId) {
    return 'We couldn\'t find an item with id \"$itemId\".';
  }

  @override
  String get inventoryDetailWarehouseLabel => 'Warehouse';

  @override
  String get inventoryDetailLocationLabel => 'Location';

  @override
  String get inventoryDetailReorderLabel => 'Reorder point';

  @override
  String get inventoryDetailUnitCostLabel => 'Unit cost';

  @override
  String get inventoryDetailBarcodeLabel => 'Barcode';

  @override
  String get inventoryDetailMovementsHeading => 'Movement history';

  @override
  String get inventoryDetailMovementsEmpty => 'No movements recorded yet.';

  @override
  String get inventoryMovementTypeReceipt => 'Goods receipt';

  @override
  String get inventoryMovementTypeIssue => 'Goods issue';

  @override
  String get inventoryMovementTypeTransfer => 'Transfer';

  @override
  String get inventoryMovementTypeAdjustment => 'Adjustment';

  @override
  String inventoryMovementRunningLabel(String qty) {
    return 'balance $qty';
  }

  @override
  String get inventoryIssueAction => 'Issue';

  @override
  String get inventoryReceiptAction => 'Receive';

  @override
  String get inventoryTransferAction => 'Transfer';

  @override
  String get inventoryLowStockTitle => 'Low stock';

  @override
  String get inventoryLowStockEmpty => 'Every item is above its reorder point.';

  @override
  String get inventoryScannerTitle => 'Scan barcode';

  @override
  String get inventoryScannerEmpty => 'Scan or enter a code.';

  @override
  String inventoryScannerUnknown(String code) {
    return 'No item matches \"$code\".';
  }

  @override
  String inventoryScannerError(String message) {
    return 'Scanner error: $message';
  }

  @override
  String get inventoryScannerNoCamera =>
      'Camera not available on this platform — use manual entry below.';

  @override
  String get inventoryScannerManualHeading => 'Manual entry';

  @override
  String get inventoryScannerManualLabel => 'Barcode';

  @override
  String get inventoryScannerManualHint => 'Type or paste a code';

  @override
  String get inventoryScannerManualUseAction => 'Use';

  @override
  String get inventoryScannerBrowseFallback => 'Browse the catalog instead';

  @override
  String get inventoryReceiptFormTitle => 'Receive stock';

  @override
  String get inventoryIssueFormTitle => 'Issue stock';

  @override
  String get inventoryReceiptSuccessSnack => 'Stock received.';

  @override
  String get inventoryIssueSuccessSnack => 'Stock issued.';

  @override
  String get inventoryMovementGenericSuccess => 'Movement recorded.';

  @override
  String inventoryMovementFailed(String message) {
    return 'Couldn\'t record movement: $message';
  }

  @override
  String inventoryFormCurrentOnHand(String qty) {
    return 'Current on-hand: $qty';
  }

  @override
  String get inventoryFormQuantityLabel => 'Quantity';

  @override
  String get inventoryFormReferenceLabel => 'Reference (optional)';

  @override
  String get inventoryFormReferenceReceiptHint => 'e.g. PO-2026-001';

  @override
  String get inventoryFormReferenceIssueHint => 'e.g. SO-2026-014';

  @override
  String get inventoryFormNoteLabel => 'Note';

  @override
  String get inventoryQtyExceedsOnHand =>
      'Quantity exceeds the current on-hand.';

  @override
  String get inventoryTransferFormTitle => 'Transfer stock';

  @override
  String get inventoryTransferSourceHeading => 'From';

  @override
  String get inventoryTransferDestinationLabel => 'Destination bin';

  @override
  String get inventoryTransferNoDestinations =>
      'No active destination bins available for this SKU.';

  @override
  String get inventoryTransferReferenceHint => 'Internal transfer note';

  @override
  String get inventoryTransferPickDestination =>
      'Please pick a destination bin.';

  @override
  String get inventoryTransferSuccess => 'Stock transferred.';

  @override
  String get inventoryCycleCountTitle => 'Cycle count';

  @override
  String get inventoryCycleNoItems => 'No items to count.';

  @override
  String get inventoryCycleAllWarehouses => 'All warehouses';

  @override
  String inventoryCycleExpectedLabel(String qty) {
    return 'expected $qty';
  }

  @override
  String get inventoryCycleCountedLabel => 'Counted';

  @override
  String get inventoryCycleEmpty =>
      'Enter a counted quantity for at least one item.';

  @override
  String get inventoryCycleSubmitAction => 'Submit count';

  @override
  String inventoryCycleSuccess(int count, String variance) {
    return 'Posted $count adjustment(s); variance $variance.';
  }

  @override
  String get salesCustomersTitle => 'Customers';

  @override
  String get salesAnalyticsTooltip => 'Analytics';

  @override
  String get salesCustomersSearchHint => 'Search by name, email, industry';

  @override
  String get salesCustomersSortTooltip => 'Sort';

  @override
  String get salesCustomersEmpty => 'No customers match your filters.';

  @override
  String salesCustomersError(String message) {
    return 'Couldn\'t load customers: $message';
  }

  @override
  String salesCustomersOnboardedLabel(String date) {
    return 'since $date';
  }

  @override
  String get salesCustomersSortName => 'Name (A–Z)';

  @override
  String get salesCustomersSortLtv => 'Lifetime value';

  @override
  String get salesCustomersSortRecent => 'Recently added';

  @override
  String get salesStatusProspect => 'Prospect';

  @override
  String get salesStatusActive => 'Active';

  @override
  String get salesStatusOnHold => 'On hold';

  @override
  String get salesStatusChurned => 'Churned';

  @override
  String get salesSegmentSmb => 'SMB';

  @override
  String get salesSegmentMidMarket => 'Mid-market';

  @override
  String get salesSegmentEnterprise => 'Enterprise';

  @override
  String get salesCustomerDetailTitle => 'Customer';

  @override
  String salesCustomerNotFound(String customerId) {
    return 'We couldn\'t find a customer with id \"$customerId\".';
  }

  @override
  String get salesCustomerDetailEmailLabel => 'Email';

  @override
  String get salesCustomerDetailPhoneLabel => 'Phone';

  @override
  String get salesCustomerDetailAddressLabel => 'Billing address';

  @override
  String get salesCustomerDetailLifetimeValueLabel => 'Lifetime value';

  @override
  String get salesCustomerDetailSinceLabel => 'Customer since';

  @override
  String get salesCustomerDetailNotesHeading => 'Notes';

  @override
  String get salesCustomerDetailContactsHeading => 'Contacts';

  @override
  String get salesCustomerDetailContactsEmpty => 'No contacts linked yet.';

  @override
  String get salesCustomerDetailTimelineHeading => 'Activity';

  @override
  String get salesCustomerDetailTimelineEmpty => 'No activity yet.';

  @override
  String get salesContactAddAction => 'Add contact';

  @override
  String get salesContactEditAction => 'Edit';

  @override
  String get salesContactDeleteAction => 'Delete';

  @override
  String get salesContactPrimaryBadge => 'Primary';

  @override
  String get salesContactNewTitle => 'New contact';

  @override
  String get salesContactEditTitle => 'Edit contact';

  @override
  String get salesContactNameLabel => 'Name';

  @override
  String get salesContactRoleLabel => 'Role';

  @override
  String get salesContactEmailLabel => 'Email';

  @override
  String get salesContactPhoneLabel => 'Phone';

  @override
  String get salesContactPrimaryToggle => 'Primary contact';

  @override
  String get salesContactPrimaryDescription =>
      'Show this contact in the customer header.';

  @override
  String get salesContactSaveAction => 'Save contact';

  @override
  String get salesContactSavedSnack => 'Contact saved.';

  @override
  String salesContactSaveFailed(String message) {
    return 'Couldn\'t save contact: $message';
  }

  @override
  String get salesContactDeleteTitle => 'Delete contact?';

  @override
  String get salesContactDeleteBody =>
      'The contact will be removed from this customer.';

  @override
  String get salesContactDeleteConfirm => 'Delete';

  @override
  String get salesContactDeletedSnack => 'Contact removed.';

  @override
  String get salesActivityLogAction => 'Log activity';

  @override
  String get salesActivityFormTitle => 'Log activity';

  @override
  String get salesActivityTypeLabel => 'Type';

  @override
  String get salesActivitySummaryLabel => 'Summary';

  @override
  String get salesActivityActorLabel => 'Logged by';

  @override
  String get salesActivitySaveAction => 'Save activity';

  @override
  String get salesActivitySavedSnack => 'Activity logged.';

  @override
  String salesActivitySaveFailed(String message) {
    return 'Couldn\'t log activity: $message';
  }

  @override
  String get salesActivityTypeNote => 'Note';

  @override
  String get salesActivityTypeCall => 'Call';

  @override
  String get salesActivityTypeMeeting => 'Meeting';

  @override
  String get salesActivityTypeEmail => 'Email';

  @override
  String get salesActivityTypeQuotation => 'Quotation';

  @override
  String get salesActivityTypeOrder => 'Order';

  @override
  String get salesActivityTypePayment => 'Payment';

  @override
  String get salesQuotationListTitle => 'Quotations';

  @override
  String get salesQuotationNewTooltip => 'New quotation';

  @override
  String get salesQuotationSearchHint => 'Search by number or customer';

  @override
  String get salesQuotationSortTooltip => 'Sort';

  @override
  String get salesQuotationListEmpty => 'No quotations match your filters.';

  @override
  String salesQuotationValidUntilLabel(String date) {
    return 'valid until $date';
  }

  @override
  String get salesQuotationSortCreatedDesc => 'Created (newest)';

  @override
  String get salesQuotationSortCreatedAsc => 'Created (oldest)';

  @override
  String get salesQuotationSortTotalDesc => 'Total (largest)';

  @override
  String get salesQuotationSortValidity => 'Expiring next';

  @override
  String get salesQuotationStatusDraft => 'Draft';

  @override
  String get salesQuotationStatusSent => 'Sent';

  @override
  String get salesQuotationStatusAccepted => 'Accepted';

  @override
  String get salesQuotationStatusRejected => 'Rejected';

  @override
  String get salesQuotationStatusExpired => 'Expired';

  @override
  String get salesQuotationStatusConverted => 'Converted';

  @override
  String get salesQuotationNewTitle => 'New quotation';

  @override
  String get salesQuotationCustomerLabel => 'Customer';

  @override
  String get salesQuotationValidUntilField => 'Valid until';

  @override
  String get salesQuotationLinesHeading => 'Line items';

  @override
  String salesQuotationLineHeading(int index) {
    return 'Line $index';
  }

  @override
  String get salesQuotationAddLineAction => 'Add line';

  @override
  String get salesQuotationRemoveLineTooltip => 'Remove line';

  @override
  String get salesQuotationLineDescriptionLabel => 'Description';

  @override
  String get salesQuotationLineQuantityLabel => 'Qty';

  @override
  String get salesQuotationLineUnitPriceLabel => 'Unit price';

  @override
  String get salesQuotationSaveAction => 'Save quotation';

  @override
  String get salesQuotationSavedSnack => 'Quotation saved.';

  @override
  String salesQuotationSaveFailed(String message) {
    return 'Couldn\'t save quotation: $message';
  }

  @override
  String get salesQuotationPickCustomer => 'Please pick a customer.';

  @override
  String get salesQuotationDetailTitle => 'Quotation';

  @override
  String salesQuotationNotFound(String quotationId) {
    return 'We couldn\'t find a quotation with id \"$quotationId\".';
  }

  @override
  String get salesQuotationCreatedLabel => 'Created';

  @override
  String get salesQuotationValidUntilLabel2 => 'Valid until';

  @override
  String get salesQuotationDetailLinesHeading => 'Line items';

  @override
  String get salesQuotationTotalLabel => 'Total';

  @override
  String get salesQuotationNotesHeading => 'Notes';

  @override
  String get salesQuotationSendAction => 'Send to customer';

  @override
  String get salesQuotationAcceptAction => 'Mark accepted';

  @override
  String get salesQuotationRejectAction => 'Mark rejected';

  @override
  String get salesQuotationConvertAction => 'Convert to order';

  @override
  String get salesQuotationStatusUpdated => 'Quotation updated.';

  @override
  String get salesQuotationConvertedSnack => 'Sales order created.';

  @override
  String salesQuotationActionFailed(String message) {
    return 'Couldn\'t update quotation: $message';
  }

  @override
  String get salesQuotationConvertNotAccepted =>
      'Only accepted quotations can be converted.';

  @override
  String get salesQuotationConvertAlready =>
      'This quotation has already been converted.';

  @override
  String get salesQuotationConvertExpired => 'This quotation has expired.';

  @override
  String get salesOrderListTitle => 'Sales orders';

  @override
  String get salesOrderListEmpty => 'No orders yet.';

  @override
  String get salesOrderStatusPending => 'Pending';

  @override
  String get salesOrderStatusPacking => 'Packing';

  @override
  String get salesOrderStatusShipped => 'Shipped';

  @override
  String get salesOrderStatusDelivered => 'Delivered';

  @override
  String get salesOrderStatusCancelled => 'Cancelled';

  @override
  String get salesOrderDetailTitle => 'Sales order';

  @override
  String salesOrderNotFound(String orderId) {
    return 'We couldn\'t find an order with id \"$orderId\".';
  }

  @override
  String get salesOrderCreatedLabel => 'Created';

  @override
  String get salesOrderSourceQuotationLabel => 'Source quotation';

  @override
  String get salesOrderShippedAtLabel => 'Shipped';

  @override
  String get salesOrderDeliveredAtLabel => 'Delivered';

  @override
  String get salesOrderTrackingLabel => 'Tracking';

  @override
  String get salesOrderDetailLinesHeading => 'Line items';

  @override
  String get salesOrderCancelAction => 'Cancel';

  @override
  String get salesOrderStartPackingAction => 'Start packing';

  @override
  String get salesOrderShipAction => 'Ship';

  @override
  String get salesOrderMarkDeliveredAction => 'Mark delivered';

  @override
  String get salesOrderTrackingDialogTitle => 'Tracking reference';

  @override
  String get salesOrderTrackingConfirm => 'Confirm';

  @override
  String get salesOrderTrackingRequired =>
      'A tracking reference is required to ship.';

  @override
  String salesOrderAdvancedSnack(String status) {
    return 'Order marked as $status.';
  }

  @override
  String salesOrderAdvanceFailed(String message) {
    return 'Couldn\'t update order: $message';
  }

  @override
  String get salesAnalyticsTitle => 'Sales analytics';

  @override
  String get salesAnalyticsRevenueHeading => 'Revenue';

  @override
  String get salesAnalyticsRevenueEmpty => 'No revenue in the selected window.';

  @override
  String get salesAnalyticsPeriodWeekly => 'Weekly';

  @override
  String get salesAnalyticsPeriodMonthly => 'Monthly';

  @override
  String get salesAnalyticsTopCustomersHeading => 'Top customers';

  @override
  String get salesAnalyticsTopCustomersEmpty =>
      'No customer revenue to rank yet.';

  @override
  String get salesAnalyticsTopProductsHeading => 'Top products';

  @override
  String get salesAnalyticsTopProductsEmpty =>
      'No product revenue to rank yet.';

  @override
  String get salesAnalyticsLeaderboardHeading => 'Sales rep leaderboard';

  @override
  String get salesAnalyticsLeaderboardEmpty => 'No reps yet.';

  @override
  String salesAnalyticsLeaderboardDealsLabel(String count) {
    return '$count deals closed';
  }

  @override
  String salesAnalyticsLeaderboardAttainmentLabel(String pct, String target) {
    return '$pct% of $target';
  }
}
