/// Centralised route path & name registry.
///
/// Keeping these as compile-time constants (instead of magic strings sprinkled
/// across pages) gives us refactor safety and a single audit point for the URL
/// surface area. Names are used for `context.goNamed(...)` / `pushNamed(...)`;
/// paths are used for the URL.
abstract final class RoutePaths {
  // Bootstrap / shell ────────────────────────────────────────────
  static const splash = '/';
  static const splashName = 'splash';

  // Auth (Module 1) ──────────────────────────────────────────────
  static const login = '/login';
  static const loginName = 'login';

  // MFA (Phase 1.2) ──────────────────────────────────────────────
  /// OTP / TOTP entry — the multi-step auth flow lands here after the
  /// password step when the server reports an MFA challenge.
  static const otp = '/mfa/otp';
  static const otpName = 'otp';

  // Dashboard (Module 2) ─────────────────────────────────────────
  static const dashboard = '/dashboard';
  static const dashboardName = 'dashboard';

  // Shell siblings of the dashboard (Slice 2.1.1). Each is the root of
  // a `StatefulShellRoute` branch — the bottom nav / rail / drawer
  // switches between them while preserving each branch's own
  // navigation stack.
  static const modules = '/modules';
  static const modulesName = 'modules';

  static const settings = '/settings';
  static const settingsName = 'settings';

  // Generic "coming soon" landing for Slice 2.1.2 module shortcut tiles
  // whose real feature module hasn't shipped yet. The `:label` param is
  // the human-readable module name (already localised by the catalog),
  // so the page itself has no per-module copy.
  static const comingSoon = '/coming-soon/:label';
  static const comingSoonName = 'comingSoon';
  static const comingSoonLabelParam = 'label';

  // Notification inbox (Slice 2.3.3) — full-screen list reached from
  // the AppBar bell badge. Lives in the Home shell branch so the
  // bottom nav / rail stays visible and the user can swap tabs
  // without losing inbox state.
  static const notificationInbox = '/notifications';
  static const notificationInboxName = 'notificationInbox';

  // Finance — Chart of Accounts (Slice 3.1.1). Lives under /finance/*
  // so future Module 3 routes (account detail, GL, AP/AR) share the
  // prefix. Inside the Home shell branch for now; Module 3 may get
  // its own branch when its surface area justifies one.
  static const chartOfAccounts = '/finance/accounts';
  static const chartOfAccountsName = 'chartOfAccounts';

  // Finance — Account detail + transactions (Slice 3.1.2). Path param
  // is the Account.id; reached by tapping a leaf row in the chart-of-
  // accounts tree.
  static const accountDetail = '/finance/accounts/:id';
  static const accountDetailName = 'accountDetail';
  static const accountDetailIdParam = 'id';

  // Finance — Invoices (Phase 3.2).
  static const invoiceList = '/finance/invoices';
  static const invoiceListName = 'invoiceList';

  static const invoiceNew = '/finance/invoices/new';
  static const invoiceNewName = 'invoiceNew';

  /// Slice 3.2.2 — invoice detail; `:id` is the Invoice.id.
  static const invoiceDetail = '/finance/invoices/:id';
  static const invoiceDetailName = 'invoiceDetail';
  static const invoiceDetailIdParam = 'id';

  /// Slice 3.2.3 — edit existing invoice.
  static const invoiceEdit = '/finance/invoices/:id/edit';
  static const invoiceEditName = 'invoiceEdit';

  // Finance — General Ledger (Phase 3.3).
  static const journalEntries = '/finance/gl/journal-entries';
  static const journalEntriesName = 'journalEntries';

  static const journalEntryDetail = '/finance/gl/journal-entries/:id';
  static const journalEntryDetailName = 'journalEntryDetail';
  static const journalEntryDetailIdParam = 'id';

  static const trialBalance = '/finance/gl/trial-balance';
  static const trialBalanceName = 'trialBalance';

  // Sales & CRM (Module 6) ─────────────────────────────────────
  // Phase 6.1 — Customers + contacts + activity timeline.
  static const salesCustomers = '/sales/customers';
  static const salesCustomersName = 'salesCustomers';

  static const salesCustomerDetail = '/sales/customers/:id';
  static const salesCustomerDetailName = 'salesCustomerDetail';
  static const salesCustomerDetailIdParam = 'id';

  static const salesContactNew = '/sales/customers/:id/contacts/new';
  static const salesContactNewName = 'salesContactNew';

  static const salesContactEdit = '/sales/customers/:id/contacts/:contactId';
  static const salesContactEditName = 'salesContactEdit';
  static const salesContactIdParam = 'contactId';

  static const salesActivityNew = '/sales/customers/:id/activities/new';
  static const salesActivityNewName = 'salesActivityNew';

  // Phase 6.2 — Quotations + sales orders.
  static const salesQuotationList = '/sales/quotations';
  static const salesQuotationListName = 'salesQuotationList';

  /// Register the literal `/new` BEFORE the `:id` route so go_router
  /// matches "new" as the literal first.
  static const salesQuotationNew = '/sales/quotations/new';
  static const salesQuotationNewName = 'salesQuotationNew';

  static const salesQuotationDetail = '/sales/quotations/:id';
  static const salesQuotationDetailName = 'salesQuotationDetail';
  static const salesQuotationDetailIdParam = 'id';

  static const salesOrderList = '/sales/orders';
  static const salesOrderListName = 'salesOrderList';

  static const salesOrderDetail = '/sales/orders/:id';
  static const salesOrderDetailName = 'salesOrderDetail';
  static const salesOrderDetailIdParam = 'id';

  // Phase 6.3 — Analytics (revenue chart + top rankings + leaderboard).
  static const salesAnalytics = '/sales/analytics';
  static const salesAnalyticsName = 'salesAnalytics';

  // Inventory (Module 5) ────────────────────────────────────────
  static const inventoryItems = '/inventory/items';
  static const inventoryItemsName = 'inventoryItems';

  static const inventoryItemDetail = '/inventory/items/:id';
  static const inventoryItemDetailName = 'inventoryItemDetail';
  static const inventoryItemDetailIdParam = 'id';

  static const inventoryGoodsIssue = '/inventory/items/:id/issue';
  static const inventoryGoodsIssueName = 'inventoryGoodsIssue';

  static const inventoryGoodsReceipt = '/inventory/items/:id/receipt';
  static const inventoryGoodsReceiptName = 'inventoryGoodsReceipt';

  static const inventoryTransfer = '/inventory/items/:id/transfer';
  static const inventoryTransferName = 'inventoryTransfer';

  static const inventoryScanner = '/inventory/scan';
  static const inventoryScannerName = 'inventoryScanner';

  static const inventoryLowStock = '/inventory/alerts';
  static const inventoryLowStockName = 'inventoryLowStock';

  static const inventoryCycleCount = '/inventory/cycle-count';
  static const inventoryCycleCountName = 'inventoryCycleCount';

  // Procurement (Module 4) ─────────────────────────────────────
  // Phase 4.1 — Purchase requests.
  static const purchaseRequestList = '/procurement/purchase-requests';
  static const purchaseRequestListName = 'purchaseRequestList';

  /// Slice 4.1.2 — register BEFORE the `:id` route so go_router matches
  /// the literal "new" first.
  static const purchaseRequestNew = '/procurement/purchase-requests/new';
  static const purchaseRequestNewName = 'purchaseRequestNew';

  /// Slice 4.1.3 — PR detail; `:id` is the PurchaseRequest.id.
  static const purchaseRequestDetail = '/procurement/purchase-requests/:id';
  static const purchaseRequestDetailName = 'purchaseRequestDetail';
  static const purchaseRequestDetailIdParam = 'id';

  // Phase 4.2 — Purchase orders.
  static const purchaseOrderList = '/procurement/purchase-orders';
  static const purchaseOrderListName = 'purchaseOrderList';

  static const purchaseOrderDetail = '/procurement/purchase-orders/:id';
  static const purchaseOrderDetailName = 'purchaseOrderDetail';
  static const purchaseOrderDetailIdParam = 'id';

  /// Slice 4.2.3 — goods receipt entry; `:poId` is the parent PO.
  static const goodsReceiptNew =
      '/procurement/purchase-orders/:poId/receipts/new';
  static const goodsReceiptNewName = 'goodsReceiptNew';
  static const goodsReceiptPoIdParam = 'poId';

  // Phase 4.3 — Vendors.
  static const vendorList = '/procurement/vendors';
  static const vendorListName = 'vendorList';

  static const vendorNew = '/procurement/vendors/new';
  static const vendorNewName = 'vendorNew';

  static const vendorDetail = '/procurement/vendors/:id';
  static const vendorDetailName = 'vendorDetail';
  static const vendorDetailIdParam = 'id';

  /// Slice 4.3.3 — performance scorecard; `:id` is the Vendor.id.
  static const vendorScorecard = '/procurement/vendors/:id/scorecard';
  static const vendorScorecardName = 'vendorScorecard';
  static const vendorScorecardIdParam = 'id';

  // Permission-gated demo route (Slice 1.3.2 — exists so the route
  // guard's "no access → /forbidden" branch is end-to-end demoable
  // before feature modules add their own gated routes).
  static const adminDemo = '/admin-demo';
  static const adminDemoName = 'adminDemo';

  // Forbidden — landing for an authenticated user who lacks the
  // required permission for the route they tried to reach.
  static const forbidden = '/forbidden';
  static const forbiddenName = 'forbidden';

  // Catch-all ────────────────────────────────────────────────────
  static const notFoundName = 'notFound';

  /// Locations the router considers "public" — reachable without an
  /// authenticated [AuthSession]. The OTP page is included because the
  /// user is *mid-challenge* at that point (credentials submitted, no
  /// session token yet); the auth guard would otherwise bounce them to
  /// `/login` and lose the challenge context.
  static const publicLocations = <String>{splash, login, otp};
}
