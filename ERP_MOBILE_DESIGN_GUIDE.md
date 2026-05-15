# ERP Mobile Flutter — Complete Design & Coding Standards
> Single source of truth for all 57 screens. Use this file when prompting Claude Code.
> Covers: design tokens · component patterns · coding rules · per-screen layout intent · BLoC/drift spec · prompt template.

---

## Table of Contents

1. [Design Philosophy](#1-design-philosophy)
2. [Design Tokens (AppTheme singleton)](#2-design-tokens-apptheme-singleton)
3. [Shared Component Patterns](#3-shared-component-patterns)
4. [Navigation Structure](#4-navigation-structure)
5. [Motion & Animation Rules](#5-motion--animation-rules)
6. [Coding Standards & Architecture Rules](#6-coding-standards--architecture-rules)
7. [Screen Specifications — All 57 Screens](#7-screen-specifications--all-57-screens)
   - [Module 0 — App Entry](#module-0--app-entry)
   - [Module 1 — Authentication & Identity](#module-1--authentication--identity)
   - [Module 2 — Dashboard & Home](#module-2--dashboard--home)
   - [Module 3 — Finance & Accounting](#module-3--finance--accounting)
   - [Module 4 — Procurement](#module-4--procurement)
   - [Module 5 — Inventory & Warehouse](#module-5--inventory--warehouse)
   - [Module 6 — Sales & CRM](#module-6--sales--crm)
   - [Module 7 — Human Resources](#module-7--human-resources)
   - [Module 8 — Project Management](#module-8--project-management)
   - [Module 9 — Settings & Administration](#module-9--settings--administration)
8. [Screen Complexity Summary](#8-screen-complexity-summary)
9. [Claude Code Prompt Template](#9-claude-code-prompt-template)

---

## 1. Design Philosophy

**Clean. Spacious. Data-first.**

This is an enterprise tool used daily by real workers — accountants, warehouse staff, HR managers. The design must feel modern but never trendy. Every pixel must earn its place.

**Three principles:**

- **Clarity over decoration** — users need to find data fast, not admire animations
- **Density with breathing room** — ERP has a lot of data; use cards and sections, never walls of text
- **Calm confidence** — muted colors, consistent spacing, no aggressive CTAs

---

## 2. Design Tokens (AppTheme singleton)

> All values live in a single `AppTheme` singleton.
> **Never hardcode colors, sizes, or fonts anywhere in widget code.**

### 2.1 Colors

```dart
// Primary palette — deep indigo, professional
primary:            Color(0xFF3B4FE8)   // buttons, active states, links
onPrimary:          Color(0xFFFFFFFF)
primaryContainer:   Color(0xFFE8EBFF)  // chip backgrounds, light badges

// Surface
surface:            Color(0xFFF8F9FC)  // page background (light)
surfaceVariant:     Color(0xFFEEF0F5)  // card background, input fill
onSurface:          Color(0xFF1A1D23)  // primary text
onSurfaceVariant:   Color(0xFF6B7280)  // secondary text, placeholders

// Status colors
success:  Color(0xFF16A34A)  // APPROVED, in-stock, on-time
warning:  Color(0xFFD97706)  // PENDING, low-stock, expiring
error:    Color(0xFFDC2626)  // REJECTED, overdue, failed
info:     Color(0xFF0284C7)  // neutral status, info banners

// Status container variants (backgrounds for chips/badges)
successContainer: Color(0xFFDCFCE7)
warningContainer: Color(0xFFFEF3C7)
errorContainer:   Color(0xFFFEE2E2)
infoContainer:    Color(0xFFE0F2FE)

// Dark mode overrides
// surface → Color(0xFF0F1117), cards → Color(0xFF1A1D23)
```

### 2.2 Typography — AppLabel

```dart
// All text uses Inter font family
// Register in AppLabel singleton — never use raw TextStyle in widgets

AppLabel.displayLarge   // 32sp, w700 — splash app name only
AppLabel.headlineLarge  // 24sp, w700 — page titles
AppLabel.headlineMedium // 20sp, w600 — section headers, card titles
AppLabel.titleMedium    // 16sp, w600 — list tile titles, tab labels
AppLabel.bodyLarge      // 16sp, w400 — body text, descriptions
AppLabel.bodyMedium     // 14sp, w400 — secondary info, subtitles
AppLabel.bodySmall      // 12sp, w400 — timestamps, captions, version text
AppLabel.labelLarge     // 14sp, w600 — button labels
AppLabel.labelSmall     // 11sp, w500 — status chips, badges
```

### 2.3 Spacing — AppSpacing

```dart
AppSpacing.xs   =  4.0
AppSpacing.sm   =  8.0
AppSpacing.md   = 16.0
AppSpacing.lg   = 24.0
AppSpacing.xl   = 32.0
AppSpacing.xxl  = 48.0
```

### 2.4 Border Radius — AppRadius

```dart
AppRadius.sm   =  8.0   // chips, small badges
AppRadius.md   = 12.0   // input fields, small cards
AppRadius.lg   = 16.0   // main cards, bottom sheets
AppRadius.xl   = 24.0   // FAB, large modal sheets
AppRadius.full = 999.0  // pill-shaped chips
```

### 2.5 Elevation / Shadows

```dart
AppShadow.card = BoxShadow(
  color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 2),
)
AppShadow.modal = BoxShadow(
  color: Color(0x1A000000), blurRadius: 24, offset: Offset(0, 8),
)
```

### 2.6 Module Icon Colors

```
Finance      → indigo (primary)
Inventory    → orange
HR           → purple
Sales        → green
Procurement  → teal
Projects     → blue
```

---

## 3. Shared Component Patterns

### AppCard
Every content block lives in a card. **Never raw containers.**
```
white bg · AppRadius.lg · AppShadow.card · padding AppSpacing.md
```

### StatusChip
```
pill shape · AppRadius.full · labelSmall text · status color map:

  DRAFT            → surfaceVariant bg,    onSurfaceVariant text
  PENDING_APPROVAL → warningContainer bg,  warning text
  APPROVED         → successContainer bg,  success text
  REJECTED         → errorContainer bg,    error text
  ACTIVE           → successContainer bg,  success text
  ON_HOLD          → warningContainer bg,  warning text
  COMPLETED        → infoContainer bg,     info text
```

### SectionHeader
```
headlineMedium text · left-aligned · bottom padding AppSpacing.sm
optional trailing TextButton (labelLarge)
```

### EmptyState
```
centered column · illustration (80×80) · headlineMedium title
· bodyMedium subtitle · optional FilledButton CTA
```

### LoadingShimmer
```
shimmer skeleton matching real layout shape — never blank screen
never CircularProgressIndicator alone on lists
```

### FAB
```
primary color · AppRadius.xl · icon+label (extended) on tablet
icon only on mobile · bottom-right · never covers key content
```

### InputField (all forms)
```
filled style · surfaceVariant fill · no border at rest
primary border 2px on focus · AppRadius.md
prefixIcon where applicable · error text below on invalid
```

### ApprovalTimeline
```
vertical list with connector line between steps
each step: avatar · name · action chip · timestamp
used in: Invoice Detail, PR Detail, Leave Approval
```

### PermissionGuard
```
wraps any widget that requires a specific RBAC scope
PermissionGuard(scope: 'finance.approve') { ... }
renders nothing (or disabled state) if user lacks permission
```

---

## 4. Navigation Structure

```
BottomNavigationBar (mobile):
  Dashboard · Finance · Inventory · HR · More (→ side sheet)

NavigationRail (tablet, always visible left):
  Same 5 items + expanded text labels

"More" side sheet expands to show:
  Procurement · Sales · Projects · Settings
```

**Page transitions:**
- Bottom nav: fade-through
- Push routes: slide-from-right
- Back: slide-to-right (default)

---

## 5. Motion & Animation Rules

| Element | Animation | Duration |
|---|---|---|
| Page (bottom nav) | fade-through | system default |
| Page (push) | slide-from-right | system default |
| List items | staggered fade-in, 50ms delay per item | 300ms max total |
| Bottom sheets | slide up | 300ms ease-out |
| Status chips | AnimatedSwitcher crossfade on status change | 200ms |
| Buttons | AnimatedScale 0.97 on press | 100ms |
| Errors | horizontal shake on PIN fail / form submit fail | 300ms |
| Loading | LoadingShimmer skeleton | — |
| Splash logo | fade + scale | 900ms easeOutBack |
| Biometric icon | soft pulse scale 1.0→1.08→1.0 | 1.5s repeat |

**Never:** bounce, spin, or add gratuitous motion — this is a work tool.

---

## 6. Coding Standards & Architecture Rules

### 6.1 Non-negotiable rules

- **Never hardcode** colors, sizes, or fonts — use `AppTheme`, `AppLabel`, `AppSpacing`, `AppRadius` exclusively
- **Never use raw containers** as content blocks — always `AppCard`
- **Never show a blank screen** while loading — always `LoadingShimmer` on lists
- **Never unguard admin actions** — wrap with `PermissionGuard(scope: '...')`
- **Never use raw `TextStyle`** in widget code — always `AppLabel`

### 6.2 Widget architecture

- Split into **small private widget classes** — one per visual section
- Add `buildWhen` on **every `BlocBuilder`** to minimise rebuilds
- Show `EmptyState` widget whenever any list is empty
- Use `StatusChip` from the shared status color map — no custom chips
- Use `LoadingShimmer` instead of `CircularProgressIndicator` on list screens

### 6.3 BLoC patterns

```dart
// Standard BLoC shape — all screens follow this
Events: [Entity]Loaded, [Action]Requested, FilterChanged, etc.
States: [Entity]Initial → [Entity]Loading → [Entity]Loaded / [Entity]Failure

// Forms use this extended pattern
States: [Form]Initial → [Form]Valid / [Form]Invalid → [Form]Saving
      → [Form]Success / [Form]Failure
```

### 6.4 Data / state rules

- All drift reads happen in BLoC — never in widget `build()`
- Admin screens (`/settings/admin/*`) read from API only — no local cache (security)
- Splash screen uses only local drift + `flutter_secure_storage` — no network calls
- PIN hash stored in `flutter_secure_storage`, not drift
- Offline transactions enqueue to `sync_queue` drift table; `SyncStatusBLoC` surfaces status
- Optimistic UI updates for stock transactions — revert on API failure

### 6.5 Form rules

- All forms use `FormBLoC` for validation state
- Save Draft = upsert to drift; Submit = POST to API
- Line item forms must support dynamic add/remove rows
- Show running totals reactively as fields change

### 6.6 Approval flow pattern

Used in: Invoice (3.4), Purchase Request (4.3), Leave (7.6)

```
DetailBLoC   — loads the document
ActionBLoC   — handles approve/reject
  Events:    [Entity]Approved(id) / [Entity]Rejected(id, reason)
  States:    ActionLoading → ActionSuccess / ActionFailure

UI pattern:
  ActionRow (sticky bottom, visible only when status=PENDING + user has permission)
    RejectButton (OutlinedButton, error color, half width)
    ApproveButton (FilledButton, success color, half width)

  RejectBottomSheet (modal):
    drag handle · "Reason for rejection" headlineMedium
    ReasonTextField (multiline, 3 rows min) · character count
    ConfirmRejectButton (FilledButton, error, full width)
```

### 6.7 List screen pattern

Used universally across all list screens:

```
FilterChips row (horizontal scroll, if applicable)
SearchBar (surfaceVariant fill, AppRadius.md)
ListView
  LoadingShimmer while state = Loading
  EmptyState if state = Empty
  ListView.separated of [Entity]Tile (AppCard, AppSpacing.sm gap) if Loaded
FAB (create action, if user has create permission)
```

### 6.8 Detail screen pattern

Used universally across all detail screens:

```
AppBar: entity name/number · optional overflow menu
SingleChildScrollView
  [Entity]HeaderCard (AppCard) — key metadata in 2-column grid
  StatusChip (large, centered, pill) — if entity has status
  SectionHeader "[Section Name]"
  [Content] (AppCard)
  ...more sections...
  ActionRow (sticky bottom, conditional on status + permission)
```

---

## 7. Screen Specifications — All 57 Screens

> For each screen: **Feel** = design intent. **Layout** = widget tree. **BLoC** = state machine. **Drift** = local tables used.

---

### Module 0 — App Entry

---

#### Screen 0.1 — Splash Screen
**Complexity: M** | **Route:** `/` (initial, always replaced)

**Feel:** Calm, minimal, centered. Brand moment before work begins.

**Layout:**
```
Full screen, surface bg
  ├── Center (flex 1)
  │     ├── Rounded square icon (96×96, AppRadius.xl, primary bg)
  │     │     fade + scale animation 900ms easeOutBack
  │     └── App name — displayLarge, AppSpacing.md below icon
  └── Bottom pinned, AppSpacing.xxl from bottom
        ├── CircularProgressIndicator (24×24, strokeWidth 2) while loading
        │     AnimatedSwitcher → invisible once routing done
        └── Version text — bodySmall, onSurfaceVariant
        │     If DB migration needed: "MigratingDatabaseText" replaces version text
```

**Do:** Logo + name + subtle spinner only.
**Don't:** No gradients, no marketing copy, no network calls.

**BLoC:** `AppInitBLoC`
```
Events: AppStarted
States: AppInitLoading → AppInitAuthenticated / AppInitUnauthenticated / AppInitLocked

On AppStarted:
  1. Check flutter_secure_storage for existing tokens
  2. Read cached_user from drift — if present and TTL valid, user is known
  3. Read biometric_on flag from drift
  4. Decide redirect:
     - No token            → /login
     - Token + biometric   → /biometric-unlock
     - Token + PIN policy  → /lock
     - Token valid         → /dashboard
```

**Drift tables:** `cached_user` (read id, biometric_on, last_login_at, cached_at for TTL check)

**Notes:**
- Only screen with no back navigation — always replaced, never pushed
- Keep animation under 1.5s; do not block on network calls

---

### Module 1 — Authentication & Identity

---

#### Screen 1.1 — Login
**Complexity: M** | **Route:** `/login`

**Feel:** Professional, welcoming. Single column, no clutter.

**Layout:**
```
Scaffold, surface bg, SingleChildScrollView
  padding: horizontal AppSpacing.lg, vertical AppSpacing.xl
  ├── App icon (52×52, AppRadius.md, primaryContainer bg)
  ├── AppSpacing.lg
  ├── "Welcome back" — headlineLarge
  ├── "Sign in to your account" — bodyMedium, onSurfaceVariant
  ├── AppSpacing.xxl
  ├── EmailField (prefixIcon: email)
  ├── AppSpacing.md
  ├── PasswordField (suffixIcon: visibility toggle)
  ├── "Forgot password?" — Align.right TextButton, bodySmall
  ├── AppSpacing.xl
  ├── SignInButton — FilledButton, full width, 52px height
  │     loading: replace label with CircularProgressIndicator 20×20
  │     disabled: 38% opacity
  ├── AppSpacing.md
  ├── BiometricButton — OutlinedButton, full width (hidden if biometric_on=false)
  │     icon: fingerprint + "Sign in with Biometrics"
  └── ErrorCard (AnimatedSwitcher, errorContainer bg)
        error icon + message text, AppRadius.md
```

**Don't:** No card wrapping the whole form. No "create account" link.

**BLoC:** `AuthBLoC`
```
Event: LoginSubmitted(email, password)
States: AuthInitial → AuthLoading → AuthSuccess / AuthFailure
On success → go_router redirects to /dashboard
```

**Drift tables:** `cached_user` (read biometric_on flag on init)

---

#### Screen 1.2 — Biometric Unlock
**Complexity: S** | **Route:** `/biometric-unlock`

**Feel:** Secure, reassuring. OS lock screen energy.

**Layout:**
```
Full screen, centered column
  ├── User avatar (64×64 circle, initials fallback)
  ├── User name — titleMedium
  ├── AppSpacing.xl
  ├── Biometric icon (72×72, primary color)
  │     soft pulse animation: scale 1.0→1.08→1.0, repeat, 1.5s
  ├── "Touch sensor to unlock" — bodyMedium, onSurfaceVariant
  ├── AppSpacing.xl
  └── "Use password instead" — TextButton → /login
```

**BLoC:** `BiometricBLoC`
```
Event: BiometricRequested
States: BiometricPrompting → BiometricSuccess / BiometricFailure
```

**Drift tables:** `cached_user` (read biometric_on, last_login_at)

---

#### Screen 1.3 — OTP / MFA Verification
**Complexity: M** | **Route:** `/mfa`

**Feel:** Focused, single-task. Nothing distracting.

**Layout:**
```
Scaffold
  ├── Back arrow (top left)
  ├── padding AppSpacing.lg
  ├── Shield icon (48×48, primaryContainer bg circle)
  ├── "Verification code" — headlineLarge
  ├── "Sent to +66 *** 1234" — bodyMedium, onSurfaceVariant
  ├── AppSpacing.xl
  ├── OtpInputRow — 6 boxes, 48×56 each, AppRadius.md
  │     active: primary border · filled: surfaceVariant bg + titleMedium digit
  │     auto-advance on input, auto-retreat on delete
  ├── AppSpacing.lg
  ├── VerifyButton — FilledButton full width (enabled when 6 digits filled)
  └── "Resend code (29s)" — TextButton, disabled during cooldown timer
```

**BLoC:** `MfaBLoC`
```
Event: OtpSubmitted(code)
States: MfaInitial → MfaLoading → MfaSuccess / MfaFailure
```

**Drift tables:** None — OTP is memory only (ephemeral)

---

#### Screen 1.4 — Forgot Password
**Complexity: S** | **Route:** `/forgot-password`

**Feel:** One job. Enter email, receive link.

**Layout:**
```
Scaffold
  ├── Back arrow
  ├── padding AppSpacing.lg
  ├── Email icon (48×48, primaryContainer bg)
  ├── "Reset password" — headlineLarge
  ├── "We'll send a reset link to your email" — bodyMedium, onSurfaceVariant
  ├── AppSpacing.xl
  ├── EmailField
  ├── AppSpacing.md
  └── SendResetButton — FilledButton, full width
        success state: swap to green checkmark + "Check your email"
```

**BLoC:** `ForgotPasswordBLoC`
```
Event: ResetRequested(email)
States: ForgotPasswordInitial → ForgotPasswordLoading
      → ForgotPasswordSent / ForgotPasswordFailure
```

**Drift tables:** None

---

### Module 2 — Dashboard & Home

---

#### Screen 2.1 — Dashboard Home
**Complexity: L** | **Route:** `/dashboard`

**Feel:** Control room. Data-rich, breathing room. KPIs are the hero.

**Layout:**
```
Scaffold
  ├── AppBar: app logo (left) · search icon · NotificationBadge (right)
  ├── SyncStatusBanner (slide-in below AppBar, warningContainer bg)
  │     only visible on SyncPending or SyncFailed state
  └── SingleChildScrollView
        ├── GlobalSearchBar (surfaceVariant fill, AppRadius.md, search icon)
        ├── AppSpacing.md
        ├── SectionHeader "Overview"
        ├── KpiCardGrid — 2-column GridView, shrinkWrap
        │     Each KpiCard (AppCard):
        │       module icon circle (24×24, colored by module)
        │       KPI label — bodySmall, onSurfaceVariant
        │       Value — headlineMedium
        │       Trend row — arrow icon + % change (success/error color)
        │       Sparkline — fl_chart LineChart, 40px height, no axes
        ├── AppSpacing.md
        ├── SectionHeader "Quick Access"
        └── ModuleShortcutGrid — 3-column, permission-filtered
              Each tile: icon (40×40 circle) + module name (bodySmall)
  BottomNavigationBar (mobile) / NavigationRail (tablet)
```

**BLoC:**
- `KpiBLoC` — Event: `KpiRefreshRequested`; streams from `KpiRepository` (WebSocket + drift fallback)
- `SyncStatusBLoC` — listens to sync engine; emits `SyncIdle / SyncPending / SyncFailed`
- `NotificationBadgeBLoC` — reads unread count from drift

**Drift tables:** `cached_kpi`, `cached_dashboard_layout`, `cached_notifications` (unread count)

---

#### Screen 2.2 — Global Search
**Complexity: M** | **Route:** `/search`

**Feel:** Fast, instant results as you type.

**Layout:**
```
Scaffold (no AppBar — search IS the top element)
  ├── padding AppSpacing.md
  ├── SearchRow: back arrow + SearchTextField (autofocus) + clear X
  ├── Divider
  ├── RecentSearchesRow — horizontal scroll chips (bodySmall, surfaceVariant)
  └── SearchResultList
        grouped by module with SectionHeader per group
        Each SearchResultTile (ListTile):
          leading: module color icon circle (40×40)
          title: titleMedium
          subtitle: bodySmall, onSurfaceVariant
          trailing: chevron right
        EmptyState if no results: magnifier illustration + "No results found"
```

**BLoC:** `GlobalSearchBLoC`
```
Event: SearchQueryChanged(query)
States: SearchInitial → SearchLoading → SearchResults(results) / SearchEmpty
```

**Drift tables:** None (search hits remote API; results not cached)

---

#### Screen 2.3 — Notification Center
**Complexity: M** | **Route:** `/notifications`

**Feel:** Inbox. Clear read/unread hierarchy.

**Layout:**
```
Scaffold
  ├── AppBar: "Notifications" · "Mark all read" TextButton trailing
  └── Body
        EmptyState (bell illustration) if empty
        ListView of NotificationTile (AppCard, AppSpacing.sm gap):
          ├── Leading: module icon circle (40×40, color by notification type)
          ├── Unread indicator: 3px primary left border + primaryContainer bg tint
          ├── Title — titleMedium (w600 if unread, w400 if read)
          ├── Body — bodySmall, onSurfaceVariant, max 2 lines
          └── Timestamp — bodySmall, onSurfaceVariant, right-aligned
```

**BLoC:** `NotificationBLoC`
```
Events: NotificationsLoaded, NotificationMarkedRead(id), AllNotificationsMarkedRead
States: NotificationInitial → NotificationLoaded(list) / NotificationEmpty
```

**Drift tables:** `cached_notifications` (read, update is_read)

---

### Module 3 — Finance & Accounting

---

#### Screen 3.1 — Chart of Accounts
**Complexity: M** | **Route:** `/finance/accounts`

**Feel:** Tree navigator. Hierarchy is the structure.

**Layout:**
```
Scaffold
  ├── AppBar: "Chart of Accounts"
  ├── AccountSearchBar — filters tree inline
  └── ListView (tree structure, indented per level)
        Each AccountNode:
          ├── Expand/collapse chevron (if has children)
          ├── AccountTypeBadge — colored chip (Asset/Liability/Equity/Revenue/Expense)
          ├── Account name — titleMedium
          ├── Account code — bodySmall, onSurfaceVariant
          └── Balance — titleMedium, right-aligned
        Parent nodes: surfaceVariant bg row
        Child nodes: white bg, indented AppSpacing.lg per level
        Tap leaf node → Account Detail
```

**BLoC:** `ChartOfAccountsBLoC`
```
Events: AccountsLoaded, AccountNodeExpanded(id)
States: AccountsLoading → AccountsLoaded(tree) / AccountsFailure
```

**Drift tables:** `cached_accounts` (id, parent_id, name, type, cached_at)

---

#### Screen 3.2 — Account Detail
**Complexity: M** | **Route:** `/finance/accounts/:id`

**Feel:** Ledger view. Header then scrollable transaction history.

**Layout:**
```
Scaffold
  ├── AppBar: account name · account code (subtitle)
  └── SingleChildScrollView
        ├── AccountHeaderCard (AppCard)
        │     2-column grid: Type · Balance · Code · Status
        ├── AppSpacing.md
        ├── DateRangeFilterRow — "From" + "To" date chips, inline
        ├── AppSpacing.md
        ├── SectionHeader "Transactions"
        └── ListView of TransactionTile (AppCard, AppSpacing.xs gap)
              Date (bodySmall) · Reference (bodyMedium) · Debit · Credit
              Debit: error color · Credit: success color
              Running balance (right, bodySmall, onSurfaceVariant)
```

**BLoC:** `AccountDetailBLoC`
```
Events: AccountDetailLoaded(id), DateRangeChanged(from, to)
States: AccountDetailLoading → AccountDetailLoaded / AccountDetailFailure
```

**Drift tables:** `cached_accounts`, `cached_transactions`

---

#### Screen 3.3 — Invoice List
**Complexity: M** | **Route:** `/finance/invoices`

**Feel:** Scannable. Status chips carry the meaning at a glance.

**Layout:**
```
Scaffold
  ├── AppBar: "Invoices" · sort icon
  ├── FilterChips row: All · Draft · Pending · Approved · Rejected
  ├── InvoiceSearchBar
  └── ListView of InvoiceTile (AppCard, AppSpacing.sm gap)
        ├── Top row: invoice number (titleMedium) · StatusChip (right)
        ├── Middle: vendor/customer name (bodyMedium)
        └── Bottom: date (bodySmall, onSurfaceVariant) · amount (titleMedium, right)
  FAB: + Create Invoice → /finance/invoices/new
```

**BLoC:** `InvoiceListBLoC`
```
Events: InvoicesLoaded, InvoiceFilterChanged(status), InvoiceSortChanged(field)
States: InvoiceListLoading → InvoiceListLoaded(list) / InvoiceListFailure
```

**Drift tables:** `cached_invoices`

---

#### Screen 3.4 — Invoice Detail + Approve/Reject
**Complexity: L** | **Route:** `/finance/invoices/:id`

**Feel:** Document view. Header → status → items → actions.

**Layout:**
```
Scaffold
  ├── AppBar: invoice number · overflow menu (PDF, share)
  └── SingleChildScrollView
        ├── InvoiceHeaderCard (AppCard)
        │     2-column grid: Invoice# · Date · Due Date · Vendor · Amount
        ├── AppSpacing.md
        ├── StatusChip — large, centered, pill
        ├── AppSpacing.md
        ├── SectionHeader "Line Items"
        ├── LineItemsTable (AppCard)
        │     rows: description · qty · unit price · total
        │     footer: subtotal · tax · TOTAL (titleMedium bold)
        ├── AppSpacing.lg
        └── ActionRow (sticky bottom, PENDING_APPROVAL + has permission only)
              RejectButton (OutlinedButton, error, half width)
              ApproveButton (FilledButton, success, half width)

RejectBottomSheet (modal, AppRadius.xl top):
  drag handle · "Reason for rejection" headlineMedium
  ReasonTextField (multiline, 3 rows min)
  character count (bodySmall, right)
  ConfirmRejectButton (FilledButton, error, full width)
```

**BLoC:**
- `InvoiceDetailBLoC` — Event: `InvoiceDetailLoaded(id)`
- `InvoiceActionBLoC` — Events: `InvoiceApproved(id)` / `InvoiceRejected(id, reason)`

**Drift tables:** `cached_invoices` (status, approved_by, rejected_reason, actioned_at)

**Permission:** `ApproveButton` + `RejectButton` wrapped in `PermissionGuard(scope: 'finance.approve')`

---

#### Screen 3.5 — Create / Edit Invoice
**Complexity: L** | **Route:** `/finance/invoices/new` · `/finance/invoices/:id/edit`

**Feel:** Document builder. Dynamic line items, live totals.

**Layout:**
```
Scaffold
  ├── AppBar: "New Invoice" / "Edit Invoice" · "Save Draft" TextButton
  └── SingleChildScrollView, padding AppSpacing.md
        ├── VendorCustomerPickerCard (AppCard)
        │     search icon + selected name / "Select vendor or customer"
        ├── AppSpacing.md
        ├── DatesCard (AppCard, 2-column row)
        │     Invoice date picker · Due date picker
        ├── AppSpacing.md
        ├── SectionHeader "Line Items" · "+ Add Item" trailing
        ├── LineItemsList
        │     Each LineItemCard (AppCard):
        │       Description field (full width)
        │       Qty · Unit Price · Tax % (3-column row)
        │       Line total (bodyMedium, right, primary color)
        │       Remove icon (error color, top-right)
        ├── AppSpacing.md
        ├── TotalSummaryCard (AppCard, right-aligned)
        │     Subtotal · Tax · TOTAL (titleMedium bold)
        └── SubmitForApprovalButton — FilledButton, full width
```

**BLoC:** `InvoiceFormBLoC`
```
Events: FieldChanged(field, value), LineItemAdded, LineItemRemoved(index),
        InvoiceSaved (draft), InvoiceSubmitted
States: InvoiceFormInitial → InvoiceFormValid / InvoiceFormInvalid
      → InvoiceFormSaving → InvoiceFormSuccess
```

**Drift tables:** `cached_invoices` (upsert on save draft)

---

#### Screen 3.6 — Journal Entry List
**Complexity: S** | **Route:** `/finance/journal`

**Feel:** Accounting log. Date + reference + balanced amounts.

**Layout:**
```
Scaffold
  ├── AppBar: "Journal Entries"
  ├── DateRangeFilterRow — from/to date chips
  └── ListView of JournalEntryTile (AppCard, AppSpacing.sm gap)
        ├── Top row: reference (titleMedium) · date (bodySmall, right)
        ├── Description — bodyMedium, onSurfaceVariant
        └── Bottom row: Debit total (error color) · Credit total (success color)
        Tap → Journal Entry Detail bottom sheet
```

**BLoC:** `JournalBLoC`
```
Events: JournalEntriesLoaded, DateRangeChanged
States: JournalLoading → JournalLoaded(list) / JournalFailure
```

**Drift tables:** `cached_journal_entries`

---

#### Screen 3.7 — Trial Balance Report
**Complexity: M** | **Route:** `/finance/trial-balance`

**Feel:** Financial statement. Paginated table, export action.

**Layout:**
```
Scaffold
  ├── AppBar: "Trial Balance" · export CSV icon
  ├── PeriodSelector — month + year picker row (AppCard)
  └── SingleChildScrollView
        ├── SummaryRow (AppCard, 2-column)
        │     Total Debits (error color) · Total Credits (success color)
        └── TrialBalanceTable (AppCard)
              Header row: Account · Debit · Credit (surfaceVariant bg, sticky)
              Each data row: account name (bodyMedium) · debit · credit
              alternating row tint (surfaceVariant every other row)
```

**BLoC:** `TrialBalanceBLoC`
```
Events: TrialBalanceLoaded(period)
States: TrialBalanceLoading → TrialBalanceLoaded(rows) / TrialBalanceFailure
```

**Drift tables:** `cached_trial_balance`

---

### Module 4 — Procurement

---

#### Screen 4.1 — Purchase Request List
**Complexity: M** | **Route:** `/procurement/requests`

**Feel:** Approval queue. Status is the priority signal.

**Layout:**
```
Scaffold
  ├── AppBar: "Purchase Requests"
  ├── FilterChips: All · Draft · Pending · Approved · Rejected
  └── ListView of PRTile (AppCard, AppSpacing.sm gap)
        ├── Top row: PR number (titleMedium) · StatusChip (right)
        ├── Middle: requester name + department (bodyMedium)
        └── Bottom: date (bodySmall) · estimated amount (titleMedium, right)
  FAB: + New Request → /procurement/requests/new
```

**BLoC:** `PurchaseRequestListBLoC`
```
Events: PRListLoaded, PRFilterChanged(status)
States: PRListLoading → PRListLoaded(list) / PRListFailure
```

**Drift tables:** `cached_purchase_requests`

---

#### Screen 4.2 — Create Purchase Request
**Complexity: L** | **Route:** `/procurement/requests/new`

**Feel:** Structured request form. Line items + approver selection.

**Layout:**
```
Scaffold
  ├── AppBar: "New Purchase Request" · "Save Draft" TextButton
  └── SingleChildScrollView, padding AppSpacing.md
        ├── CostCenterCard (AppCard row — building icon + dropdown)
        ├── AppSpacing.md
        ├── ApproverPickerCard (AppCard row — person icon + searchable dropdown)
        ├── AppSpacing.md
        ├── SectionHeader "Items" · "+ Add Item" trailing
        ├── LineItemsList
        │     Each LineItemCard (AppCard):
        │       Description · Qty · Estimated cost (3 fields)
        │       Remove icon (error, top-right)
        ├── AppSpacing.md
        ├── AttachmentRow (AppCard) — paperclip icon + "Attach file" + file list
        └── SubmitButton — FilledButton, full width
```

**BLoC:** `PRFormBLoC`
```
Events: FieldChanged, LineItemAdded, LineItemRemoved, PRSubmitted
States: PRFormInitial → PRFormValid / PRFormInvalid → PRFormSuccess
```

**Drift tables:** `cached_purchase_requests` (upsert draft)

---

#### Screen 4.3 — Purchase Request Detail + Approval
**Complexity: L** | **Route:** `/procurement/requests/:id`

**Feel:** Document + decision. Timeline shows approval history.

**Layout:**
```
Scaffold
  ├── AppBar: PR number · overflow menu
  └── SingleChildScrollView
        ├── PRHeaderCard (AppCard)
        │     2-column grid: PR# · Date · Requester · Dept · Cost Center
        ├── AppSpacing.md
        ├── StatusChip — large, centered
        ├── AppSpacing.md
        ├── SectionHeader "Requested Items"
        ├── LineItemsTable (AppCard)
        ├── AppSpacing.md
        ├── SectionHeader "Approval History"
        ├── ApprovalTimeline (AppCard)
        │     each step: avatar · name · action chip · date · connector line
        └── ActionRow (sticky bottom, PENDING + has permission only)
              RejectButton (OutlinedButton, error, half width)
              ApproveButton (FilledButton, success, half width)
```

**BLoC:** `PRDetailBLoC`, `PRActionBLoC` (same pattern as Invoice 3.4)

**Drift tables:** `cached_purchase_requests` (status, approved_by, actioned_at)

**Permission:** `PermissionGuard(scope: 'procurement.approve')`

---

#### Screen 4.4 — Purchase Order List
**Complexity: M** | **Route:** `/procurement/orders`

**Feel:** Order tracker. Same scannable pattern as PRs and invoices.

**Layout:**
```
Scaffold
  ├── AppBar: "Purchase Orders"
  ├── FilterChips: All · Draft · Confirmed · Received · Cancelled
  └── ListView of POTile (AppCard, AppSpacing.sm gap)
        ├── Top row: PO number (titleMedium) · StatusChip (right)
        ├── Middle: vendor name (bodyMedium)
        └── Bottom: order date (bodySmall) · total amount (titleMedium, right)
  FAB: + New Order
```

**BLoC:** `PurchaseOrderListBLoC`

**Drift tables:** `cached_purchase_orders`

---

#### Screen 4.5 — Purchase Order Detail
**Complexity: M** | **Route:** `/procurement/orders/:id`

**Feel:** Order document. Header + line items + goods receipt trigger.

**Layout:**
```
Scaffold
  ├── AppBar: PO number · overflow menu
  └── SingleChildScrollView
        ├── POHeaderCard (AppCard)
        │     PO# · Vendor · Order date · Expected delivery · Total
        ├── AppSpacing.md
        ├── StatusChip — large, centered
        ├── AppSpacing.md
        ├── SectionHeader "Line Items"
        ├── LineItemsTable (AppCard)
        │     Item · Qty ordered · Qty received · Unit price · Total
        │     Received qty: success color if full, warning if partial
        └── GoodsReceiptButton — OutlinedButton, full width (if status=Confirmed)
              "Record Goods Receipt" + truck icon
```

**BLoC:** `PODetailBLoC`

**Drift tables:** `cached_purchase_orders`

---

#### Screen 4.6 — Goods Receipt Entry
**Complexity: M** | **Route:** `/procurement/orders/:id/receipt`

**Feel:** Receiving dock form. Large tap targets, confirm quantities per line.

**Layout:**
```
Scaffold
  ├── AppBar: "Goods Receipt" · PO number subtitle
  └── SingleChildScrollView, padding AppSpacing.md
        ├── VendorInfoCard (AppCard, infoContainer bg)
        │     Vendor name · Expected delivery date
        ├── AppSpacing.md
        ├── ReceiptDateCard (AppCard row — calendar icon + date picker)
        ├── AppSpacing.md
        ├── SectionHeader "Received Items"
        ├── ReceivedQtyList
        │     Each ReceivedItemRow (AppCard):
        │       Item name (titleMedium)
        │       Ordered qty (bodySmall, onSurfaceVariant)
        │       ActualQtyInput (48×48 number field, right-aligned)
        │       Variance badge: success=match · warning=over · error=under
        └── ConfirmReceiptButton — FilledButton, success color, full width
```

**BLoC:** `GoodsReceiptBLoC`
```
Event: GoodsReceiptSubmitted(orderId, lines)
States: GoodsReceiptLoading → GoodsReceiptSuccess / GoodsReceiptFailure
```

**Drift tables:** `cached_purchase_orders` (update received quantities)

---

#### Screen 4.7 — Vendor List
**Complexity: S** | **Route:** `/procurement/vendors`

**Feel:** Supplier directory. Rating stars give instant quality signal.

**Layout:**
```
Scaffold
  ├── AppBar: "Vendors"
  ├── VendorSearchBar
  └── ListView of VendorTile (AppCard, AppSpacing.sm gap)
        ├── Leading: vendor initial circle (40×40, primary bg)
        ├── Title: vendor name — titleMedium
        ├── Subtitle: category chip + payment terms (bodySmall)
        └── Trailing: star rating row (3–5 stars, warning color fill)
  FAB: + Add Vendor
```

**BLoC:** `VendorListBLoC`

**Drift tables:** `cached_vendors`

---

#### Screen 4.8 — Vendor Detail
**Complexity: M** | **Route:** `/procurement/vendors/:id`

**Feel:** Supplier profile + performance scorecard.

**Layout:**
```
Scaffold
  ├── AppBar: vendor name · edit icon
  └── SingleChildScrollView
        ├── VendorProfileCard (AppCard)
        │     Name · Category · Contact · Email · Payment Terms · Bank info
        ├── AppSpacing.md
        ├── SectionHeader "Performance"
        ├── ScorecardCard (AppCard, 2-column grid)
        │     On-time delivery % (success/warning/error by value)
        │     Quality rating (star row)
        │     Total spend · Active POs
        ├── AppSpacing.md
        ├── SectionHeader "Recent Orders"
        └── ListView of POHistoryTile (AppCard, AppSpacing.xs gap)
              PO# · date · amount · StatusChip
```

**BLoC:** `VendorDetailBLoC`

**Drift tables:** `cached_vendors`, `cached_purchase_orders`

---

### Module 5 — Inventory & Warehouse

---

#### Screen 5.1 — Item Catalog
**Complexity: M** | **Route:** `/inventory/items`

**Feel:** Warehouse inventory. Low-stock items demand attention.

**Layout:**
```
Scaffold
  ├── AppBar: "Inventory"
  ├── SearchBar + WarehouseFilterDropdown (inline row)
  └── ListView of ItemTile (AppCard, AppSpacing.sm gap)
        ├── Leading: item image or SKU initials circle (40×40)
        ├── Title: item name — titleMedium
        ├── SKU — bodySmall, onSurfaceVariant
        ├── Stock qty badge:
        │     above min: successContainer bg
        │     near min (≤20%): warningContainer bg
        │     below min: errorContainer bg + "LOW" label
        └── Trailing: unit (bodySmall)
  FAB: barcode scan shortcut → Screen 5.3
```

**BLoC:** `ItemCatalogBLoC`
```
Events: ItemsLoaded, WarehouseFilterChanged(warehouseId), SearchQueryChanged
States: ItemCatalogLoading → ItemCatalogLoaded(items) / ItemCatalogFailure
```

**Drift tables:** `cached_items` (id, sku, name, unit, warehouse_id, stock_qty, min_stock, cached_at)

---

#### Screen 5.2 — Item Detail
**Complexity: M** | **Route:** `/inventory/items/:id`

**Feel:** Stock card. Quantity indicator + movement history.

**Layout:**
```
Scaffold
  ├── AppBar: item name · edit icon
  └── SingleChildScrollView
        ├── ItemHeaderCard (AppCard)
        │     SKU · Category · Unit · Warehouse · Location
        ├── AppSpacing.md
        ├── StockLevelCard (AppCard)
        │     ├── Current qty — headlineLarge, color by level
        │     ├── Min stock level — bodySmall, onSurfaceVariant
        │     └── StockProgressBar (AppRadius.full, colored fill)
        │           below min: error · near min: warning · above: success
        ├── AppSpacing.md
        ├── SectionHeader "Movement History"
        └── ListView of MovementTile (AppCard, AppSpacing.xs gap)
              Date · Type chip (Issue/Receipt/Transfer) · Qty · Reference
              Issue qty: error color · Receipt qty: success color
```

**BLoC:** `ItemDetailBLoC`

**Drift tables:** `cached_items`, `cached_stock_movements`

---

#### Screen 5.3 — Barcode / QR Scanner
**Complexity: L** | **Route:** `/inventory/scan`

**Feel:** Utility tool. Full camera. Instant result feedback.

**Layout:**
```
Full screen (no AppBar — camera fills screen)
  ├── Camera preview (full screen, mobile_scanner package)
  ├── ScanOverlayPainter (CustomPainter)
  │     dark dim outside scan zone
  │     240×240 frame with white corner brackets
  │     animated scan line (top→bottom, 1.5s loop, primary color)
  │     "Align barcode within frame" bodySmall white below frame
  ├── CloseButton — top-left, white icon on 40% black circle
  └── ResultBottomSheet (slides up 280px on successful scan)
        drag handle
        item name — titleMedium
        SKU — bodySmall, onSurfaceVariant
        StockBadge — qty + color by level
        ActionButtonRow (3 equal OutlinedButtons, icons above labels):
          Goods Issue · Goods Receipt · Transfer
```

**BLoC:** `ScanBLoC`
```
Event: BarcodeDetected(code)
States: ScanIdle → ScanDetected(item) / ScanNotFound / ScanFailure
```

**Drift tables:** `cached_items` (lookup by SKU/barcode)

---

#### Screen 5.4 — Goods Issue / Receipt Flow
**Complexity: M** | **Route:** `/inventory/transaction`

**Feel:** Step-by-step transaction. Large tap targets for warehouse use.

**Do:** Large inputs — warehouse workers may type with gloves.

**Layout:**
```
Scaffold
  ├── AppBar: "Goods Issue" or "Goods Receipt" · close X
  └── SingleChildScrollView, padding AppSpacing.md
        ├── TypeTag — pill chip (errorContainer=Issue, successContainer=Receipt)
        ├── AppSpacing.md
        ├── SectionHeader "Item"
        ├── ItemScanOrSearchCard (AppCard)
        │     scan icon button (left) · search text field (right)
        │     selected item shows name + SKU below field
        ├── AppSpacing.md
        ├── SectionHeader "Details"
        ├── DetailsCard (AppCard)
        │     QtyInput — large number input (titleMedium, 56px height)
        │     Divider
        │     ReferenceField — "PO# or SO#"
        │     WarehouseLocationPicker — dropdown row
        └── ConfirmButton — FilledButton full width, 52px
              Issue: error color · Receipt: success color
```

**BLoC:** `StockTransactionBLoC`
```
Event: TransactionSubmitted(type, itemId, qty, reference)
Online:  POST to API
Offline: enqueue to sync_queue
```

**Drift tables:** `cached_items` (optimistic qty update), `sync_queue`

---

#### Screen 5.5 — Stock Transfer
**Complexity: M** | **Route:** `/inventory/transfer`

**Feel:** Two-sided form. Directional flow is the visual anchor.

**Layout:**
```
Scaffold
  ├── AppBar: "Stock Transfer"
  └── SingleChildScrollView, padding AppSpacing.md
        ├── TransferDirectionCard (AppCard)
        │     FromWarehousePicker row (warehouse icon + dropdown)
        │     arrow icon center (primary, pointing down)
        │     ToWarehousePicker row (warehouse icon + dropdown)
        ├── AppSpacing.md
        ├── SectionHeader "Items" · "+ Add Item" trailing
        ├── ItemTransferList
        │     Each ItemTransferRow (AppCard):
        │       item name (titleMedium)
        │       QtyInput (inline, 48px wide)
        │       remove icon (error color, right)
        └── ConfirmTransferButton — FilledButton, full width
```

**BLoC:** `StockTransferBLoC`

**Drift tables:** `cached_items`, `sync_queue`

---

#### Screen 5.6 — Inventory Count / Cycle Count
**Complexity: L** | **Route:** `/inventory/count`

**Feel:** Counting mode. Variances highlighted immediately as user types.

**Layout:**
```
Scaffold
  ├── AppBar: "Cycle Count" · warehouse · date
  ├── ProgressRow — "12 / 48 counted" LinearProgressIndicator (primary)
  └── ListView of CountItemRow (AppCard, AppSpacing.sm gap)
        ├── SKU (bodySmall, onSurfaceVariant) + name (titleMedium)
        ├── Expected qty badge (surfaceVariant)
        ├── ActualQtyInput (48×48, outlined, numeric keyboard)
        └── VarianceFeedback (shown after input):
              match   → green checkmark
              surplus → warning icon + "+N surplus"
              missing → error icon + "−N missing"
  Bottom sticky:
    "X items have variances" — error color bodyMedium (if any)
    SubmitCountButton — FilledButton, full width
```

**BLoC:** `InventoryCountBLoC`
```
Events: CountStarted, CountItemUpdated(itemId, actualQty), CountSubmitted
States: CountInProgress(items) → CountSubmitting → CountSuccess / CountFailure
```

**Drift tables:** `cached_items`, `cached_count_sessions`

---

### Module 6 — Sales & CRM

---

#### Screen 6.1 — Customer List
**Complexity: S** | **Route:** `/sales/customers`

**Feel:** CRM directory. Faces first, fast to call.

**Layout:**
```
Scaffold
  ├── AppBar: "Customers"
  ├── SearchBar
  └── ListView of CustomerTile (AppCard, AppSpacing.sm gap)
        ├── Leading: avatar circle 40×40 (photo or initials)
        ├── Title: customer name — titleMedium
        ├── Subtitle: last order date — bodySmall, onSurfaceVariant
        └── Trailing: phone icon button (direct call)
  FAB: + Add Customer
```

**BLoC:** `CustomerListBLoC`

**Drift tables:** `cached_customers`

---

#### Screen 6.2 — Customer Detail
**Complexity: M** | **Route:** `/sales/customers/:id`

**Feel:** Full profile. Info → contacts → activity history.

**Layout:**
```
Scaffold
  ├── AppBar: customer name · edit icon
  └── SingleChildScrollView
        ├── CustomerProfileCard (AppCard)
        │     avatar (56×56) + name (headlineMedium) + category chip
        │     Divider
        │     2-column grid: Phone · Email · Address · Payment Terms · Credit Limit
        ├── AppSpacing.md
        ├── SectionHeader "Contacts" · "+ Add" trailing
        ├── ContactsList (AppCard)
        │     Each ContactRow: avatar 32×32 · name · role · call+email icons
        ├── AppSpacing.md
        ├── SectionHeader "Activity"
        └── ActivityTimeline
              each item (left border line + dot):
                icon (order/call/note, colored by type)
                title — titleMedium
                date — bodySmall, onSurfaceVariant
  FAB: + New Quotation
```

**BLoC:** `CustomerDetailBLoC`

**Drift tables:** `cached_customers`, `cached_contacts`, `cached_activities`

---

#### Screen 6.3 — Sales Quotation List
**Complexity: M** | **Route:** `/sales/quotations`

**Feel:** Same scannable pattern as invoices.

**Layout:**
```
Scaffold
  ├── AppBar: "Quotations"
  ├── FilterChips: All · Draft · Sent · Accepted · Rejected
  └── ListView of QuotationTile (AppCard, AppSpacing.sm gap)
        ├── Top row: quotation number (titleMedium) · StatusChip
        ├── Middle: customer name (bodyMedium)
        └── Bottom: validity date (bodySmall) · total (titleMedium, right)
  FAB: + New Quotation
```

**BLoC:** `QuotationListBLoC`

**Drift tables:** `cached_quotations`

---

#### Screen 6.4 — Create / Edit Quotation
**Complexity: L** | **Route:** `/sales/quotations/new` · `/sales/quotations/:id/edit`

**Feel:** Proposal builder. Live total as items are added.

**Layout:**
```
Scaffold
  ├── AppBar: "New Quotation" · "Save Draft" TextButton
  └── SingleChildScrollView, padding AppSpacing.md
        ├── CustomerPickerCard (AppCard row)
        ├── ValidityDateCard (AppCard row — calendar icon + date)
        ├── AppSpacing.md
        ├── SectionHeader "Line Items" · "+ Add" trailing
        ├── LineItemsList
        │     Each LineItemCard (AppCard):
        │       Product name field
        │       Qty · Unit price · Discount% · Tax% (4-column row)
        │       Line subtotal (bodyMedium right, primary color)
        │       remove icon (error, top-right)
        ├── TotalSummaryCard (AppCard, right-aligned column)
        │     Subtotal · Discount · Tax · TOTAL (titleMedium bold)
        └── SendToCustomerButton — FilledButton, full width
```

**BLoC:** `QuotationFormBLoC`

**Drift tables:** `cached_quotations` (upsert draft)

---

#### Screen 6.5 — Sales Order Detail
**Complexity: M** | **Route:** `/sales/orders/:id`

**Feel:** Fulfillment tracker. Stepper shows where the order is.

**Layout:**
```
Scaffold
  ├── AppBar: SO number · overflow menu
  └── SingleChildScrollView
        ├── OrderHeaderCard (AppCard)
        │     SO# · Customer · Order date · Delivery date
        ├── AppSpacing.md
        ├── FulfillmentStepper (AppCard)
        │     Confirmed → Picking → Shipped → Delivered
        │     active: primary circle · done: success checkmark · pending: surfaceVariant
        ├── AppSpacing.md
        ├── SectionHeader "Line Items"
        └── LineItemsTable (AppCard)
              Product · Qty ordered · Qty shipped · Status
              Shipped=success · partial=warning · pending=surfaceVariant
```

**BLoC:** `SalesOrderDetailBLoC`

**Drift tables:** `cached_sales_orders`

---

#### Screen 6.6 — Sales Analytics
**Complexity: L** | **Route:** `/sales/analytics`

**Feel:** Executive dashboard. Period selector controls all charts.

**Layout:**
```
Scaffold
  ├── AppBar: "Sales Analytics"
  ├── PeriodToggle — segmented: Week · Month · Quarter · Year
  └── SingleChildScrollView
        ├── RevenueCard (AppCard)
        │     RevenueLineChart (fl_chart, 200px, primary color line)
        ├── AppSpacing.md
        ├── SectionHeader "Top Customers"
        ├── TopCustomersTable (AppCard)
        │     rank · name · total spend (bodyMedium)
        ├── AppSpacing.md
        ├── SectionHeader "Sales Leaderboard"
        └── SalesRepLeaderboard (AppCard)
              ranked list: avatar (32×32) + name + total sales (right, primary)
```

**BLoC:** `SalesAnalyticsBLoC`
```
Event: AnalyticsLoaded(period)
States: AnalyticsLoading → AnalyticsLoaded(data) / AnalyticsFailure
```

**Drift tables:** `cached_sales_analytics` (TTL-based, refreshed per period change)

---

### Module 7 — Human Resources

---

#### Screen 7.1 — Employee Directory
**Complexity: S** | **Route:** `/hr/employees`

**Feel:** Company phonebook. Avatar + name + role at a glance.

**Layout:**
```
Scaffold
  ├── AppBar: "Employees"
  ├── EmployeeSearchBar
  ├── DepartmentFilterDropdown
  └── ListView of EmployeeTile (AppCard, AppSpacing.sm gap)
        ├── Leading: avatar circle 40×40 (photo or initials)
        ├── Title: name — titleMedium
        └── Subtitle: title + department — bodySmall, onSurfaceVariant
```

**BLoC:** `EmployeeListBLoC`

**Drift tables:** `cached_employees`

---

#### Screen 7.2 — Employee Profile
**Complexity: M** | **Route:** `/hr/employees/:id`

**Feel:** HR record. Avatar header, tabbed detail sections.

**Layout:**
```
Scaffold
  ├── AppBar: employee name · overflow menu
  └── SingleChildScrollView
        ├── EmployeeAvatarHeader (AppCard, primaryContainer bg)
        │     photo (72×72 circle) · name (headlineMedium)
        │     title (bodyMedium) · department chip
        │     email + phone row (bodySmall, onSurfaceVariant)
        ├── AppSpacing.md
        ├── TabBar: Personal · Employment · Documents
        └── TabBarView
              Personal: birthdate, address, emergency contact
              Employment: start date, contract type, manager, salary grade
              Documents: list of DocumentTile (name + download icon)
        OrgChartButton — TextButton → /hr/orgchart?focusId=:id
```

**BLoC:** `EmployeeDetailBLoC`

**Drift tables:** `cached_employees`

---

#### Screen 7.3 — Org Chart
**Complexity: L** | **Route:** `/hr/orgchart`

**Feel:** Company hierarchy. Zoomable, pannable tree.

**Layout:**
```
Scaffold
  ├── AppBar: "Org Chart" · search icon
  └── InteractiveViewer (zoomable, pannable)
        OrgChartTreeWidget (CustomPainter)
          connector lines between nodes (grey, 0.5px)
          Each OrgChartNode:
            avatar (40×40 circle)
            name — titleMedium
            title — bodySmall, onSurfaceVariant
          FocusEmployeeHighlight: primary border on focused node
```

**BLoC:** `OrgChartBLoC`
```
Events: OrgChartLoaded, NodeFocused(id)
States: OrgChartLoading → OrgChartLoaded(tree) / OrgChartFailure
```

**Drift tables:** `cached_employees` (id, name, title, manager_id, avatar_url)

---

#### Screen 7.4 — Leave Request Form
**Complexity: M** | **Route:** `/hr/leave/new`

**Feel:** Structured request. Balance shown inline to prevent over-requesting.

**Layout:**
```
Scaffold
  ├── AppBar: "New Leave Request"
  └── SingleChildScrollView, padding AppSpacing.md
        ├── LeaveTypeCard (AppCard)
        │     LeaveTypePicker — Annual / Sick / Unpaid / Maternity / etc.
        ├── AppSpacing.md
        ├── DateRangeCard (AppCard)
        │     inline calendar (compact month view, range highlight)
        │     LeaveDayCount: "5 working days" — titleMedium, primary color
        ├── AppSpacing.md
        ├── LeaveBalanceCard (AppCard)
        │     balance bar: used (primary fill) / remaining (surfaceVariant)
        ├── AppSpacing.md
        ├── ReasonTextField (AppCard, multiline 3 rows)
        └── SubmitLeaveButton — FilledButton, full width
```

**BLoC:** `LeaveRequestFormBLoC`
```
Events: LeaveTypeChanged, DateRangeChanged, LeaveSubmitted
States: LeaveFormInitial → LeaveFormValid / LeaveFormInvalid → LeaveFormSuccess
```

**Drift tables:** `cached_leave_balances`, `cached_leave_requests`

---

#### Screen 7.5 — My Leave List
**Complexity: M** | **Route:** `/hr/leave`

**Feel:** Personal record. Balance summary + history in one view.

**Layout:**
```
Scaffold
  ├── AppBar: "My Leaves"
  ├── LeaveBalanceSummaryRow (horizontal scroll of AppCards)
  │     Each card: icon · type name · "X days left"
  │     success if plenty · warning if low · error if zero
  ├── FilterChips: All · Pending · Approved · Rejected
  └── ListView of LeaveTile (AppCard, AppSpacing.sm gap)
        ├── Top row: LeaveTypeChip · StatusChip (right)
        ├── Date range — bodyMedium
        └── Duration — bodySmall, onSurfaceVariant ("3 working days")
  FAB: + Request Leave
```

**BLoC:** `LeaveListBLoC`

**Drift tables:** `cached_leave_requests`, `cached_leave_balances`

---

#### Screen 7.6 — Manager Leave Approval
**Complexity: M** | **Route:** `/hr/leave/approvals`

**Feel:** Decision queue. All context in the card — no tap-in required.

**Don't:** No swipe-to-approve — too easy to trigger accidentally while scrolling.

**Layout:**
```
Scaffold
  ├── AppBar: "Leave Approvals" · pending count badge (warningContainer)
  └── ListView of PendingLeaveCard (AppCard, AppSpacing.sm gap)
        ├── Top row: employee avatar (40×40) + name (titleMedium) + date range (right)
        ├── LeaveTypeChip + duration badge
        ├── Reason — bodyMedium, onSurfaceVariant, max 2 lines
        └── ActionRow:
              RejectButton (OutlinedButton, error, half width)
              ApproveButton (FilledButton, success, half width)
```

**BLoC:** `LeaveApprovalBLoC`

**Drift tables:** `cached_leave_requests` (status update on action)

**Permission:** `PermissionGuard(scope: 'hr.approve')`

---

#### Screen 7.7 — Attendance Log
**Complexity: M** | **Route:** `/hr/attendance`

**Feel:** Personal clock. Today is the hero. History is secondary.

**Layout:**
```
Scaffold
  ├── AppBar: "Attendance"
  └── SingleChildScrollView
        ├── TodayCard (AppCard, primaryContainer bg)
        │     "Today, Mon 12 May" — titleMedium
        │     Clock-in time — headlineLarge (or "Not clocked in" onSurfaceVariant)
        │     Elapsed time — bodyMedium ("4h 23m on shift")
        │     ClockInOutButton — large FilledButton 56px height
        │       "Clock In" (success color) / "Clock Out" (error color)
        ├── AppSpacing.md
        ├── SectionHeader "This Month"
        ├── AttendanceCalendar (AppCard)
        │     compact month view, each day = colored dot:
        │     present=success · absent=error · late=warning · weekend=surfaceVariant
        ├── AppSpacing.md
        ├── SectionHeader "Log"
        └── ListView of AttendanceDayRow (AppCard, AppSpacing.xs gap)
              Date · Clock-in · Clock-out · Total hours · status dot
```

**BLoC:** `AttendanceBLoC`
```
Events: ClockInRequested, ClockOutRequested, AttendanceLoaded(month)
States: AttendanceLoading → AttendanceLoaded(log) / AttendanceFailure
```

**Drift tables:** `cached_attendance`

---

#### Screen 7.8 — Payslip Viewer
**Complexity: M** | **Route:** `/hr/payslips`

**Feel:** Financial statement. Net pay is the hero. Breakdown below.

**Layout:**
```
Scaffold
  ├── AppBar: "Payslip" · download PDF icon
  ├── MonthPickerRow — horizontal scroll of month chips
  └── SingleChildScrollView
        ├── NetPayCard (AppCard, primaryContainer bg)
        │     "Net Pay" — bodyMedium, onSurfaceVariant
        │     Amount — displayLarge, primary color
        ├── AppSpacing.md
        ├── EarningsCard (AppCard)
        │     SectionHeader "Earnings"
        │     Basic · Overtime · Allowances (each: label + amount right)
        │     Total earnings — titleMedium bold, success color
        ├── AppSpacing.md
        ├── DeductionsCard (AppCard)
        │     SectionHeader "Deductions"
        │     Tax · Social security · Other
        │     Total deductions — titleMedium bold, error color
        └── ViewPdfButton — OutlinedButton, full width, file icon
```

**BLoC:** `PayslipBLoC`
```
Event: PayslipLoaded(month, year)
States: PayslipLoading → PayslipLoaded(data) / PayslipFailure
```

**Drift tables:** `cached_payslips`

---

### Module 8 — Project Management

---

#### Screen 8.1 — Project List
**Complexity: S** | **Route:** `/projects`

**Feel:** Portfolio. Progress at a glance.

**Layout:**
```
Scaffold
  ├── AppBar: "Projects"
  ├── FilterChips: All · Active · On Hold · Completed
  └── ListView of ProjectTile (AppCard, AppSpacing.sm gap)
        ├── Top row: project name (titleMedium) · StatusChip
        ├── Manager avatar (24×24) + name (bodySmall)
        ├── ProgressBar — full width, AppRadius.full, success color fill
        └── Bottom row: "Due {date}" (bodySmall) · "X% complete" (bodySmall, right)
  FAB: + New Project
```

**BLoC:** `ProjectListBLoC`

**Drift tables:** `cached_projects`

---

#### Screen 8.2 — Project Detail / Gantt
**Complexity: L** | **Route:** `/projects/:id`

**Feel:** Planning tool. Timeline is the hero element.

**Layout:**
```
Scaffold
  ├── AppBar: project name · StatusChip · overflow menu
  ├── ProjectHeaderCard (AppCard)
  │     Budget · Start · End (3-column)
  │     ProgressBar full width below
  ├── TabBar: Gantt · Board · Team · Files
  └── TabBarView
        Gantt tab:
          DateRangeHeader (sticky, horizontal scroll)
            week/month column labels, surfaceVariant bg
          GanttRows (horizontal scroll synced with header)
            each row: task name fixed left 140px · bar (colored by status)
              active=primary · done=success · pending=surfaceVariant
            dependency arrows: thin grey lines between bars
        Board tab: renders Screen 8.3 Kanban inline
        Team tab: list of assigned members (avatar + name + role)
        Files tab: list of attached documents
```

**BLoC:** `ProjectDetailBLoC`
```
Event: ProjectDetailLoaded(id)
States: ProjectDetailLoading → ProjectDetailLoaded(project, tasks) / ProjectDetailFailure
```

**Drift tables:** `cached_projects`, `cached_tasks`

---

#### Screen 8.3 — Task Kanban Board
**Complexity: L** | **Route:** `/projects/:id/board`

**Feel:** Visual workflow. Cards are content. Columns are structure.

**Layout:**
```
Scaffold
  ├── AppBar: project name · filter icon
  └── HorizontalScrollView of columns
        Each column (240px wide, surfaceVariant bg, AppRadius.lg, margin AppSpacing.sm):
          ├── ColumnHeader: status label (titleMedium) · count badge (primary)
          └── DragTarget → ListView of KanbanCard (AppCard, AppSpacing.sm gap)
                ├── Title — titleMedium
                ├── AssigneeAvatarRow (24×24 circles, overlapping -8px)
                ├── PriorityBadge — colored dot + label (High/Medium/Low)
                └── DueDateRow — calendar icon + date
                      overdue: error color · today: warning · future: onSurfaceVariant
          AddTaskButton — dashed border card at bottom of each column
```

**BLoC:** `KanbanBLoC`
```
Events: TaskMoved(taskId, newStatus), TasksLoaded(projectId)
States: KanbanLoading → KanbanLoaded(columns) / KanbanFailure
```

**Drift tables:** `cached_tasks` (status update on drag)

---

#### Screen 8.4 — Task Detail
**Complexity: M** | **Route:** `/projects/:projectId/tasks/:taskId`

**Feel:** Work item + conversation. Description then comments.

**Layout:**
```
Scaffold
  ├── AppBar: task title (truncated) · overflow menu (edit, delete)
  └── SingleChildScrollView
        ├── TaskHeaderCard (AppCard)
        │     StatusChip + PriorityBadge (row)
        │     AssigneeRow: avatar 32×32 + name + "Assigned to" label
        │     DueDateRow: calendar icon + date (error if overdue)
        ├── AppSpacing.md
        ├── DescriptionCard (AppCard) — bodyLarge, selectable text
        ├── AppSpacing.md
        ├── SectionHeader "Subtasks"
        ├── SubtaskList (AppCard)
        │     Each SubtaskRow: Checkbox · name (strikethrough if done)
        ├── AppSpacing.md
        ├── SectionHeader "Comments"
        └── CommentThread
              Each CommentTile: avatar 32×32 · name+time (bodySmall) · comment text
  Bottom sticky: CommentInputRow
    current user avatar (32×32)
    CommentTextField (surfaceVariant fill, AppRadius.full)
    SendButton (icon, primary, enabled when text not empty)
```

**BLoC:** `TaskDetailBLoC`, `CommentBLoC`

**Drift tables:** `cached_tasks`, `cached_comments`

---

#### Screen 8.5 — Timesheet Entry
**Complexity: L** | **Route:** `/projects/timesheets`

**Feel:** Spreadsheet adapted for mobile. Every cell is a tap target.

**Layout:**
```
Scaffold
  ├── AppBar: "Timesheet" · week label · prev/next arrows
  ├── StickyHeaderRow (surfaceVariant bg, horizontal scroll)
  │     Mon · Tue · Wed · Thu · Fri · Sat · Sun · Total
  └── ListView of TimesheetTaskRow (AppCard, AppSpacing.xs gap)
        ├── Task name — bodyMedium, fixed left 120px
        └── 7 HoursCells (48×48 each)
              empty: dashed border, "—" onSurfaceVariant
              filled: surfaceVariant bg, titleMedium hours value
              tap → HoursInputBottomSheet (numpad, confirm button)
        Footer row: daily totals + week total (titleMedium bold)
  Bottom sticky: SubmitTimesheetButton — FilledButton, full width
```

**BLoC:** `TimesheetBLoC`
```
Events: TimesheetLoaded(week), HoursUpdated(taskId, day, hours), TimesheetSubmitted
States: TimesheetLoading → TimesheetLoaded(grid) / TimesheetSuccess / TimesheetFailure
```

**Drift tables:** `cached_timesheets`

---

#### Screen 8.6 — Utilization Report
**Complexity: M** | **Route:** `/projects/utilization`

**Feel:** Team performance dashboard. Charts + ranked list.

**Layout:**
```
Scaffold
  ├── AppBar: "Utilization"
  ├── PeriodSelector — segmented: Week · Month · Quarter
  └── SingleChildScrollView
        ├── TeamSummaryCard (AppCard, primaryContainer bg)
        │     Avg utilization — headlineLarge, primary
        │     "X of Y members above target" — bodyMedium
        ├── AppSpacing.md
        ├── UtilizationBarChart (AppCard, 200px)
        │     fl_chart BarChart · one bar per member
        │     above target: success · below: warning
        │     target: dashed horizontal line (error color)
        ├── AppSpacing.md
        ├── SectionHeader "By Member"
        └── ListView of MemberUtilizationRow (AppCard, AppSpacing.xs gap)
              avatar 40×40 · name (titleMedium) · hours (bodyMedium)
              utilization % bar (AppRadius.full, color by level)
```

**BLoC:** `UtilizationBLoC`

**Drift tables:** `cached_timesheets` (aggregated)

---

### Module 9 — Settings & Administration

---

#### Screen 9.1 — Settings Home
**Complexity: S** | **Route:** `/settings`

**Feel:** Clean menu. User identity at top, grouped options below.

**Layout:**
```
Scaffold
  ├── AppBar: "Settings"
  └── SingleChildScrollView
        ├── UserProfileCard (AppCard, primaryContainer bg)
        │     avatar 56×56 · name titleMedium · role chip + email bodySmall
        ├── AppSpacing.md
        ├── SectionHeader "Preferences"
        ├── SettingsGroup (AppCard)
        │     ThemeRow · LanguageRow · NotificationsRow
        │     each row: leading icon · label titleMedium · trailing arrow or value
        ├── AppSpacing.md
        ├── SectionHeader "Security"
        ├── SettingsGroup (AppCard)
        │     SessionsRow · AuditLogRow · PinLockRow
        ├── AppSpacing.md
        ├── SectionHeader "Admin" (PermissionGuard — admin only)
        ├── SettingsGroup (AppCard)
        │     UsersRow · RolesRow · EnvironmentRow
        ├── AppSpacing.lg
        └── LogoutButton — OutlinedButton, error color, full width
```

**BLoC:** None (static navigation screen)

**Drift tables:** `cached_user` (read name, avatar)

---

#### Screen 9.2 — User Preferences
**Complexity: S** | **Route:** `/settings/preferences`

**Feel:** Clean toggles. Theme change previews instantly.

**Layout:**
```
Scaffold
  ├── AppBar: "Preferences"
  └── SingleChildScrollView
        ├── SectionHeader "Appearance"
        ├── ThemeCard (AppCard)
        │     3-option segmented button:
        │     Light (sun icon) · Dark (moon icon) · System (phone icon)
        ├── AppSpacing.md
        ├── SectionHeader "Language"
        ├── LanguageCard (AppCard, ListTile)
        │     current language label + chevron
        │     tap → LanguagePickerBottomSheet (list of locales)
        ├── AppSpacing.md
        ├── SectionHeader "Notifications"
        └── NotificationCard (AppCard)
              Each NotificationPrefRow: icon · label · Switch (right)
              types: Approvals · Inventory alerts · Leave updates · System
```

**BLoC:** `PreferencesBLoC`
```
Events: ThemeChanged(mode), LanguageChanged(locale), NotificationPrefToggled(type)
States: PreferencesLoaded(prefs) → PreferencesUpdated
```

**Drift tables:** `cached_user_preferences` (theme, locale, notif_prefs JSON)

---

#### Screen 9.3 — Active Sessions
**Complexity: M** | **Route:** `/settings/sessions`

**Feel:** Security panel. Current device highlighted, easy revoke.

**Layout:**
```
Scaffold
  ├── AppBar: "Active Sessions"
  ├── CurrentSessionBanner (infoContainer bg, AppSpacing.md padding)
  │     "This device" label · device name + OS
  └── ListView of SessionTile (AppCard, AppSpacing.sm gap)
        ├── Device icon circle (40×40, surfaceVariant): phone/tablet/desktop
        ├── Device name — titleMedium
        ├── OS + "Last active {time}" — bodySmall, onSurfaceVariant
        └── RevokeButton — TextButton, error color (hidden for current device)
  Bottom: "Revoke all other sessions" OutlinedButton, error, full width
```

**BLoC:** `SessionManagementBLoC`
```
Events: SessionsLoaded, SessionRevoked(sessionId), AllOtherSessionsRevoked
States: SessionsLoading → SessionsLoaded(list) / SessionsFailure
```

**Drift tables:** None (reads from API only — no local cache for security)

---

#### Screen 9.4 — Audit Log Viewer
**Complexity: M** | **Route:** `/settings/audit`

**Feel:** Read-only record. Filterable, tappable for full detail.

**Layout:**
```
Scaffold
  ├── AppBar: "Audit Log"
  ├── FilterRow (horizontal scroll chips):
  │     User · Module · Action type · Date range
  └── ListView of AuditLogTile (AppCard, AppSpacing.xs gap)
        ├── Leading: action icon circle (40×40, color by action type)
        │     create=success · update=info · delete=error · approve=primary
        ├── Center: action label (titleMedium) · user + module (bodySmall)
        └── Trailing: timestamp (bodySmall, onSurfaceVariant)
        tap → AuditLogDetailBottomSheet (360px):
          full action description
          record reference (tappable deep link)
          raw payload (monospace bodySmall, scrollable)
```

**BLoC:** `AuditLogBLoC`
```
Event: AuditLogsLoaded(filters)
States: AuditLogLoading → AuditLogLoaded(entries) / AuditLogFailure
```

**Drift tables:** `cached_audit_logs`

---

#### Screen 9.5 — User Management (Admin)
**Complexity: M** | **Route:** `/settings/admin/users`

**Feel:** Admin directory. Status badge is the key signal.

**Layout:**
```
Scaffold
  ├── AppBar: "Users" · invite icon button
  └── ListView of UserManagementTile (AppCard, AppSpacing.sm gap)
        ├── Avatar (40×40 circle)
        ├── Name — titleMedium
        ├── Role chip + email — bodySmall, onSurfaceVariant
        └── StatusBadge: Active (successContainer) / Inactive (surfaceVariant)
        trailing overflow menu: Edit role · Reset password · Deactivate
```

**BLoC:** `UserManagementBLoC`

**Drift tables:** None (admin reads from API only)

**Permission:** `PermissionGuard(scope: 'admin.users')`

---

#### Screen 9.6 — Role & Permission Editor (Admin)
**Complexity: L** | **Route:** `/settings/admin/roles`

**Feel:** Admin matrix. Dense but readable. Switches over checkboxes.

**Layout:**
```
Scaffold
  ├── AppBar: "Roles & Permissions" · Save TextButton (top-right)
  └── Body
        ├── RoleFilterChips — horizontal scroll (filter visible roles)
        └── PermissionMatrix (2D scroll: horizontal roles, vertical scopes)
              Header row: role names (surfaceVariant bg, titleMedium, fixed height)
              Left column: scope labels (fixed 140px width, bodyMedium)
              Each cell: Switch widget (compact)
                on: primary color · off: surfaceVariant
              Save → PATCH full matrix → invalidate + re-fetch drift user_permissions
```

**BLoC:** `RoleEditorBLoC`
```
Events: RolesLoaded, PermissionToggled(role, scope), RolesSaved
States: RoleEditorLoading → RoleEditorLoaded(matrix) → RoleEditorSaving
      → RoleEditorSuccess
```

**Drift tables:** `user_permissions` (invalidated and re-fetched after save)

---

#### Screen 9.7 — API / Environment Config (Admin)
**Complexity: S** | **Route:** `/settings/admin/config`

**Feel:** Developer settings. Functional, no decoration.

**Layout:**
```
Scaffold
  ├── AppBar: "Environment Config"
  └── SingleChildScrollView, padding AppSpacing.md
        ├── EnvironmentCard (AppCard)
        │     3-option segmented button:
        │     Production (lock icon) · Staging (flask icon) · Custom (edit icon)
        ├── AppSpacing.md
        ├── ConnectionCard (AppCard, visible for Custom only)
        │     BaseUrlTextField · TenantIdTextField
        ├── AppSpacing.md
        ├── TestConnectionButton — OutlinedButton, full width
        │     idle: "Test Connection"
        │     success: success color + checkmark + "Connected"
        │     failure: error color + "Connection failed · check URL"
        └── SaveButton — FilledButton, full width
```

**BLoC:** `EnvConfigBLoC`
```
Events: ConfigLoaded, ConfigSaved(env, baseUrl, tenantId), ConnectionTested
States: ConfigLoading → ConfigLoaded / ConfigSaving / ConfigTestSuccess / ConfigTestFailure
```

**Drift tables:** `cached_env_config` (baseUrl, tenantId, environment, updated_at)

---

#### Screen 9.8 — PIN Lock / Biometric Re-Auth
**Complexity: M** | **Route:** `/lock`

**Feel:** Secure gate. Minimal UI. Phone lock screen energy.

**Layout:**
```
Full screen, surface bg, centered column
  ├── App icon (48×48, top area)
  ├── User name — titleMedium, onSurfaceVariant
  ├── "Enter your PIN to continue" — bodyMedium
  ├── AppSpacing.xl
  ├── PinDotsRow (4–6 dots)
  │     each dot 14×14 circle: primary=filled, surfaceVariant=empty
  │     failure: dots shake (horizontal 300ms) + momentary error color then clear
  ├── AppSpacing.lg
  ├── PinPad — 3-column grid
  │     each button: 72×72, surfaceVariant bg, AppRadius.xl, headlineMedium
  │     0–9 · backspace icon · biometric icon (if available)
  ├── "X attempts remaining" — error color bodySmall (after 3rd fail)
  └── "Log out instead" — TextButton, error color, bodySmall
```

**BLoC:** `AppLockBLoC`
```
Events: PinSubmitted(pin), BiometricRequested, LogoutRequested
States: AppLocked → AppUnlocking → AppUnlocked / AppLockFailure(attemptsRemaining)
```

**Drift tables:** `cached_user` (read biometric_on); PIN hash in `flutter_secure_storage`

---

## 8. Screen Complexity Summary

| Module | S | M | L | Total |
|---|---|---|---|---|
| Module 0 — App Entry | 0 | 1 | 0 | 1 |
| Module 1 — Auth & Identity | 2 | 2 | 0 | 4 |
| Module 2 — Dashboard & Home | 0 | 2 | 1 | 3 |
| Module 3 — Finance & Accounting | 1 | 3 | 3 | 7 |
| Module 4 — Procurement | 1 | 4 | 3 | 8 |
| Module 5 — Inventory & Warehouse | 0 | 3 | 3 | 6 |
| Module 6 — Sales & CRM | 1 | 3 | 2 | 6 |
| Module 7 — Human Resources | 1 | 6 | 1 | 8 |
| Module 8 — Project Management | 1 | 2 | 3 | 6 |
| Module 9 — Settings & Admin | 3 | 4 | 1 | 8 |
| **Total** | **10** | **30** | **17** | **57** |

### Effort guide
- **S — Simple (10 screens):** 1–2 days each. Single BLoC, 1–3 widgets, straightforward read/display.
- **M — Medium (30 screens):** 3–5 days each. Multiple widgets, form validation or list+detail, 1–2 BLoCs.
- **L — Large (17 screens):** Full sprint per screen. Custom painters, multi-BLoC, offline sync, complex state machines.

---

## 9. Claude Code Prompt Template

Place this file as `DESIGN_GUIDE.md` in your repo root.

Use this prompt for every screen:

```
Build [Screen X.X — Name] for the ERP Mobile Flutter app.

Context file in this repo:
- DESIGN_GUIDE.md — complete reference: design tokens, component patterns,
  coding rules, per-screen layout + BLoC + drift spec for all 57 screens

Rules:
- Use AppTheme, AppLabel, AppSpacing, AppRadius — no hardcoded values
- Split into small private widget classes, one per visual section
- buildWhen on every BlocBuilder to minimise rebuilds
- AppCard for every content block
- StatusChip from the shared status color map
- EmptyState widget when list is empty
- LoadingShimmer while data loads (not CircularProgressIndicator alone on lists)
- PermissionGuard wraps any action requiring a specific scope
- BLoC pattern: use the Events/States specified in DESIGN_GUIDE.md §7
- Drift: read from the tables listed in the screen spec; never read drift in build()

Screen complexity: [S / M / L]
```

### Quick reference — common mistakes to avoid

| Wrong | Right |
|---|---|
| `Color(0xFF3B4FE8)` hardcoded | `AppTheme.primary` |
| `TextStyle(fontSize: 16)` | `AppLabel.bodyLarge` |
| `SizedBox(height: 16)` | `SizedBox(height: AppSpacing.md)` |
| `BorderRadius.circular(16)` | `BorderRadius.circular(AppRadius.lg)` |
| `Container()` as content block | `AppCard()` |
| `CircularProgressIndicator()` on list | `LoadingShimmer()` |
| Empty `SizedBox()` when list empty | `EmptyState()` |
| Admin button without guard | `PermissionGuard(scope: '...') { button }` |
| Reading drift in `build()` | Read drift in BLoC, expose via stream |
| `BlocBuilder` without `buildWhen` | Always add `buildWhen` |
