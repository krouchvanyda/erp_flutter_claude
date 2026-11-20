# Step 3.1 — Login (model · repository · ViewModel BLoC · form)

> Step 3 is split in two:
> - **3.1 (this lesson):** a real login: form → BLoC → repository → server →
>   save tokens → open the session.
> - **3.2 (next):** splash auto-login from saved tokens + real logout →
>   [08-auto-login-logout.md](08-auto-login-logout.md).

This is the **first real feature**, built the way your MVVM template builds
features: `model/ · repository/ · viewmodel/ · view/`, a `…ViewModelBloc` with
`part` event/state files, states named `…LoadingState / …ErrorState /
…SuccessState`.

## 1. Why

Steps 1–2 built the **roads** (theme, DI, navigation, network, tokens). Now
the first **car** drives on them. Login touches every layer:

```mermaid
flowchart LR
    V["view/<br/>LoginPage"] -->|"event"| B["viewmodel/<br/>LoginViewModelBloc"]
    B -->|"login()"| R["repository/<br/>AuthRepository"]
    R -->|"send(post, login)"| A["core/network<br/>AppService"]
    A --> S["🛠 POST /api/v1/auth/login"]
    R -->|"save"| T["TokenStorage<br/>(Step 2.2)"]
    R -->|"open"| SE["AuthSession<br/>(Step 1.4)"]
    SE -.->|"notifies"| G["AuthGate → Home"]

    classDef feat fill:#fff4d6,stroke:#d4a017,color:#5a4300
    classDef core fill:#dbe9ff,stroke:#3b6fd8,color:#123
    classDef ok fill:#d9f7e6,stroke:#00a86b,color:#063
    class V,B,R feat
    class A,T,SE core
    class G ok
```

🟨 new in this step (the feature) · 🟦 built before (core) · 🟩 result

## 2. Picture

### Login, end to end

```mermaid
sequenceDiagram
    autonumber
    actor U as User
    participant P as LoginPage
    participant B as LoginViewModelBloc
    participant R as AuthRepository
    participant A as AppService
    participant S as 🛠 Server
    participant T as TokenStorage
    participant G as AuthGate

    U->>P: type email + password, tap Sign in
    Note over P: Form.validate()<br/>phone-side checks
    P->>B: add(OnLoginSubmittedEvent)
    B-->>P: LoginLoadingState → spinner, fields locked
    B->>R: login(email, password)
    R->>A: send(post, ApiEndPoint.login, data)
    A->>S: POST /api/v1/auth/login
    S-->>A: envelope: tokens + user
    A-->>R: Right(AuthResponseModel)
    R->>T: write(tokens)
    R->>G: session.markAuthenticated()
    Note over G: swaps Login → Home (fade)
    R-->>B: Right(UserModel)
    B-->>P: LoginSuccessState
```

**The page never navigates.** Step 1.4's rule: pages flip the session,
`AuthGate` moves the screen.

### Two kinds of errors, two places to show them

```mermaid
flowchart TD
    TAP["tap Sign in"] --> F{"Form.validate()<br/>on the PHONE"}
    F -->|"empty / bad email /<br/>password under 6"| FE["red text under the field<br/>(no request sent)"]
    F -->|"ok"| REQ["request to the server"]
    REQ --> R{"server answer"}
    R -->|"400 + fieldErrors"| SE["red text under the field<br/>(from the SERVER)"]
    R -->|"401 wrong password ·<br/>offline · 500"| CARD["AppSnackBar.error<br/>error.title + error.description"]
    R -->|"200"| OK["tokens saved → Home"]

    classDef err fill:#fde2e2,stroke:#d64545,color:#611
    classDef ok fill:#d9f7e6,stroke:#00a86b,color:#063
    classDef none fill:#eeeeee,stroke:#999,color:#555
    class FE,SE,CARD err
    class OK ok
    class TAP,REQ none
```

| Error | Checked by | Shown |
|---|---|---|
| Empty field, bad email, password under 6 | the **phone** (`FormValidators`) | under the field, **before** any request |
| `400 VALIDATION_ERROR` + `fieldErrors` | the **server** | under the field (`errorText`) |
| `401` wrong password, offline, server down | the **server** / `AppService` | a red **`AppSnackBar`** at the **top** |

#### Bug we hit: "Session expired" on a wrong password

```
POST /api/v1/auth/login  → 401
{ "success": false, "message": "Invalid email or password", "errorCode": "UNAUTHORIZED" }
```

The card said **"Session expired · Please sign in again."** because
`AppService` turned **every** 401 into `UnauthorizedError` and threw the
server's `message` away. But on login, 401 means *wrong email or password*,
not *your session ended*.

```dart
// core/network/app_service.dart → _fromDio, case badResponse
if (status == 401) {
  if (ApiEndPoint.isPublic(e.requestOptions.path) && envelope != null) {
    return _serverError(envelope, status, title: Constants.error);   // "Error: Invalid email or password"
  }
  return const UnauthorizedError();                                   // "Session expired"
}
```

```mermaid
flowchart TD
    R["401 from the server"] --> P{"ApiEndPoint.isPublic(path)?<br/>login · register · refresh · health"}
    P -->|"yes"| SE["ServerError<br/>title: 'Error'<br/>description: server message"]
    P -->|"no (private)"| UE["UnauthorizedError<br/>'Session expired'"]
    SE --> CARD["login card:<br/>Error · Invalid email or password ✅"]

    classDef err fill:#fde2e2,stroke:#d64545,color:#611
    classDef ok fill:#d9f7e6,stroke:#00a86b,color:#063
    classDef app fill:#dbe9ff,stroke:#3b6fd8,color:#123
    class R,P app
    class SE,UE err
    class CARD ok
```

- **Same list as the interceptor.** `ApiEndPoint.isPublic` is the list Step
  2.2 uses to skip refresh. One list, two places that agree: "a 401 on a
  public endpoint is not about the session".
- **Show the server's words.** The backend knows *why* it said no ("Invalid
  email or password", later maybe "Account disabled"). The app shouldn't
  replace that with a guess.
- Test: `app_service_test.dart` → *401 on LOGIN → ServerError with the server
  message*.

### The BLoC's states

```mermaid
stateDiagram-v2
    [*] --> LoginViewModelInitial
    LoginViewModelInitial --> LoginLoadingState: OnLoginSubmittedEvent
    LoginLoadingState --> LoginSuccessState: Right(user)
    LoginLoadingState --> LoginErrorState: Left(error)
    LoginErrorState --> LoginLoadingState: tap Sign in again
    LoginSuccessState --> [*]: AuthGate shows Home
```

### The design (phone + tablet)

The login follows design-guide Screen 1.1 (*professional, welcoming, single
column, no card around the form*) and the CLAUDE.md design skill (*clean,
elegant, works on phone **and** tablet*).

```
 PHONE (< 720 wide)                      TABLET / LANDSCAPE (≥ 720 wide)
 ┌──────────────────────────┐            ┌───────────────────┬──────────────────────────┐
 │┌────────────────────────┐│  ◄ AppSnackBar at the TOP (only on errors)
 ││ ⓘ Error             ✕  ││     slides down · tablet: 420 wide, centred
 ││   Invalid email or ... ││
 │└────────────────────────┘│
 │                          │            │                   │                          │
 │  [icon]  ERP Dev         │            │      [icon]       │   Welcome back           │
 │                          │            │     ERP Dev       │   Sign in to your account│
 │  Welcome back            │            │                   │                          │
 │  Sign in to your account │            │  Chat, voice and  │   Email                  │
 │                          │            │  video calls —    │   [ you@company.com    ] │
 │  Email                   │            │  your team, in    │   Password               │
 │  [ you@company.com     ] │            │  one place.       │   [ ••••••••        👁 ] │
 │  Password                │            │                   │                          │
 │  [ ••••••••         👁 ] │            │  (primary colour) │   [      Sign in       ] │
 │                          │            │                   │     Secured connection   │
 │  [       Sign in       ] │            │                   │                          │
 │                          │            └───────────────────┴──────────────────────────┘
 │     Secured connection   │              the form column is never wider than 420
 └──────────────────────────┘
```

```mermaid
flowchart TD
    LP["LoginPage"] --> LB{"LayoutBuilder<br/>width ≥ 720?"}
    LB -->|"no — phone"| ONE["one column<br/>LoginBrandRow on top"]
    LB -->|"yes — tablet"| TWO["Row:<br/>LoginBrandPanel (5) + form (6)"]
    ONE --> FC["LoginFormColumn<br/>max 420 · scroll · AppFadeSlideIn"]
    TWO --> FC
    FC --> T["LoginTitles"]
    FC --> F["LoginForm<br/>labels · validation · button<br/>errors → AppSnackBar"]
    FC --> N["LoginSecureNote"]

    classDef app fill:#dbe9ff,stroke:#3b6fd8,color:#123
    classDef feat fill:#fff4d6,stroke:#d4a017,color:#5a4300
    class LP,LB,FC app
    class ONE,TWO,T,F,N feat
```

| Design choice | Why |
|---|---|
| **Labels above fields** (`AppInputText(label:)`) | A hint disappears when you type; a label stays. Clearer, better for accessibility. |
| **`LayoutBuilder`** at 720 | Decides by the **available width**, not the device type — works for tablets, landscape phones, split-screen. |
| **Form max 420 wide** (`ConstrainedBox`) | 1000-px-wide text fields on an iPad look broken and are hard to read. |
| **Brand panel on wide screens** | Fills the empty half with calm brand colour instead of white space. On phones the brand moves to a small row above the form. |
| **Fade + 16 px slide in, 300 ms** (`TweenAnimationBuilder`) | Design guide motion rules: calm, no bounce. `child:` is passed in so the form isn't rebuilt every frame. |
| **Tap anywhere → hide keyboard** (`GestureDetector`) | Expected on mobile; the button is never hidden behind the keyboard. |
| **Errors in an `AppSnackBar`**, not a card in the form | The form never jumps or grows. The message slides down at the **top** (the keyboard can't hide it), can be swiped up or closed (✕), and goes away by itself after 4 s. One widget for the whole app. |
| **"Secured connection" note** | Quiet reassurance — no marketing copy (design guide). |
| **All colours from `colorScheme`** | Dark mode works with zero extra code. |

### Files

```
lib/
├── app/app_di.dart                  configureAppDependencies(): core + features   NEW
├── core/
│   ├── widgets/
│   │   ├── app_input_text.dart      AppInputText (template, themed)              NEW
│   │   ├── app_button.dart          AppButton + isLoading (template, themed)     NEW
│   │   ├── app_snack_bar.dart       AppSnackBar.error / success / info / hide    NEW
│   │   └── app_fade_slide_in.dart   AppFadeSlideIn (entry animation, reusable)   NEW
│   └── utils/validators/
│       ├── validators.dart          Validators.email / password / phone         NEW
│       ├── form_validators.dart     FormValidators.loginEmail / loginPassword    NEW
│       └── validation_messages.dart                                              NEW
└── features/auth/
    ├── model/
    │   ├── user_model.dart          UserModel: id · email · fullName · phone · avatarUrl
    │   └── auth_response_model.dart tokens + user
    ├── repository/auth_repository.dart   login → save tokens → open session
    ├── viewmodel/
    │   └── login/login_view_model_bloc.dart   + part …_event.dart, …_state.dart (one folder per BLoC)
    ├── view/
    │   ├── login_page.dart          LAYOUT only: responsive column / row (Screen 1.1)
    │   └── splash_page.dart         moved from views/
    ├── widgets/                     one widget per file (pieces of the login page)
    │   ├── login_form_column.dart   LoginFormColumn: centred, max 420, scroll, the pieces in order
    │   ├── login_form.dart          LoginForm: fields + Sign in + BlocConsumer
    │   ├── login_titles.dart        "Welcome back" + subtitle
    │   ├── login_brand_row.dart     phone: icon + app name
    │   ├── login_brand_panel.dart   tablet: blue brand panel
    │   └── login_secure_note.dart   "Secured connection"
    └── auth_di.dart                 registerAuthModule()
test/
├── features/auth/auth_repository_test.dart        3 tests (fake server)
├── features/auth/login_view_model_bloc_test.dart  3 tests (bloc_test + mocktail)
└── core/utils/validators_test.dart                6 tests
```

## 3. Code

### Folders: the template's names

| Template | Ours | Holds |
|---|---|---|
| `model/` | `model/` | data classes (`UserModel`) |
| `repository/` | `repository/` | business rules (`AuthRepository`) |
| `viewmodel/` | `viewmodel/` | the BLoC + `part` event/state |
| `view/` | `view/` | pages |

(Steps 1.4 used `views/` — renamed to `view/` to match the template.)

### `model/user_model.dart`

The backend doc (`API_LIST_BACKEND.md`, updated 2026-11-19) now gives the
**exact** `user` shape. Login and `GET /users/me` send the same 5 fields:

```json
{ "id": 1, "email": "user@example.com", "fullName": "Jane Doe", "phone": "012345678", "avatarUrl": null }
```

```dart
factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
  id: '${json['id'] ?? ''}',                   // 1 → "1"
  email: json['email'] as String? ?? '',
  fullName: json['fullName'] as String? ?? '',
  phone: json['phone'] as String?,             // may be null
  avatarUrl: json['avatarUrl'] as String?,     // "/uploads/..." or null
);
```

```mermaid
flowchart LR
    J["JSON user<br/>id · email · fullName<br/>phone · avatarUrl"] -->|"fromJson"| U["UserModel"]
    U --> D["displayName<br/>fullName, or email if empty"]
    U --> C["copyWith(...)<br/>profile edit (Step 4)"]
    X["roles · permissions"] -.->|"NOT sent any more"| U

    classDef app fill:#dbe9ff,stroke:#3b6fd8,color:#123
    classDef ok fill:#d9f7e6,stroke:#00a86b,color:#063
    classDef none fill:#eeeeee,stroke:#999,color:#555
    class J,U app
    class D,C ok
    class X none
```

- **Match the contract, no guessing.** Our first version guessed (`fullName`
  *or* `name` *or* `displayName`, roles as strings *or* objects) because the
  old doc only said `UserDto`. Now the doc is exact, so the guesses are gone.
  Less code = fewer places for bugs.
- **No `roles` / `permissions`.** The backend only returns them on the
  **admin** user endpoints, which this app doesn't use. A field we never get
  would always be empty, so it would lie.
- `'${json['id'] ?? ''}'` — **string interpolation** turns the number `1`
  into `"1"`. One type (`String id`) everywhere in the app (chat and call ids
  get compared as strings later).
- `phone` and `avatarUrl` are **nullable** (`String?`): the doc shows
  `"avatarUrl": null`.
- `displayName` — a **getter**: never show an empty name (falls back to email).
- `copyWith` — CLAUDE.md rule for value types. Profile edit (Step 4) will
  change one field and keep the rest.
- Hand-written `==` / `hashCode` over all 5 fields. No list fields any more,
  so no `ListEquality` needed. Explained line by line below.

### `==`, `hashCode`, `toString`: line by line

```dart
@override
bool operator ==(Object other) =>
    other is UserModel &&
    other.id == id &&
    other.email == email &&
    other.fullName == fullName &&
    other.phone == phone &&
    other.avatarUrl == avatarUrl;

@override
int get hashCode => Object.hash(id, email, fullName, phone, avatarUrl);

@override
String toString() => 'UserModel($id, $email)';
```

**Without them**, Dart uses the default from `Object` (it's **implicit**): `==`
asks "is this the **same box in memory**?", not "is this the **same data**?".

```dart
final a = UserModel(id: '1', email: 'v@x.com', fullName: 'Vanyda');
final b = UserModel(id: '1', email: 'v@x.com', fullName: 'Vanyda');
a == b   // default (implicit) → false ❌    ours (explicit) → true ✅
```

**Explicit** = written by you, visible in the file (សរសេរឲ្យឃើញច្បាស់).
CLAUDE.md asks for explicit `==` / `hashCode` / `copyWith` because we removed
`freezed` / `equatable`, so nothing generates them for us.

| Line | Meaning |
|---|---|
| `@override` | "I'm replacing a method my parent (`Object`) already has." A typo in the name → analyzer warning. |
| `bool operator ==(Object other) =>` | Defines what the `==` sign means. `a == b` calls it with `this = a`, `other = b`. The parameter is `Object` (Dart's rule): `user == 5` is allowed, it's just `false`. `=>` = return this one expression. |
| `other is UserModel &&` | Check 1: same type? No → `false`, stop. After this, Dart **knows** `other` is a `UserModel` (**type promotion**), so `other.id` works. |
| `other.id == id && …` | Checks 2–6: every field equal? `&&` stops at the first `false` (**short-circuit**). `null == null` is `true`, so two users with no phone are still equal. |
| `int get hashCode => Object.hash(…)` | A number made from the **same 5 fields**. `Set` / `Map` jump to a "shelf" by `hashCode` first, then use `==` on that shelf. |
| `String toString() => 'UserModel($id, $email)'` | What `print(user)` shows. Only id + email — never the phone — so logs don't leak private data (same idea as `AuthTokens.toString`). |

```mermaid
flowchart TD
    Q["a == b ?"] --> C1{"b is UserModel?"}
    C1 -->|"no"| F["false"]
    C1 -->|"yes"| C2{"id, email, fullName,<br/>phone, avatarUrl<br/>all equal?"}
    C2 -->|"any one differs"| F
    C2 -->|"all same"| T["true"]
    T -.->|"rule"| H["a.hashCode == b.hashCode<br/>(same 5 fields)"]

    classDef ok fill:#d9f7e6,stroke:#00a86b,color:#063
    classDef err fill:#fde2e2,stroke:#d64545,color:#611
    classDef app fill:#dbe9ff,stroke:#3b6fd8,color:#123
    class T,H ok
    class F err
    class Q,C1,C2 app
```

> ⚠ **Two rules.** (1) `==` and `hashCode` always go **together** and use
> the **same fields**. Keeping `==` but dropping `hashCode` is worse than
> dropping both: `a == b` is true, but a `Set` still keeps both.
> (2) Add a field → update the constructor, `fromJson`, `==`, `hashCode`
> (and `copyWith` if it can change).

#### Keep vs remove

| | **Keep** ✅ | **Remove** ❌ |
|---|---|---|
| Code | +10 lines | 10 fewer lines |
| Today (login) | works | works — all tests still pass (they use one `const user`) |
| Compare two users | by **data** | by **memory box**: same data still "different" |
| `Set` / `Map` of users | each person once | duplicates |
| BLoC rebuilds | skips when nothing changed | rebuilds and animates for nothing |
| Tests | one `expect(user, UserModel(...))` | check each field by hand |
| Logs | `UserModel(7, v@x.com)` | `Instance of 'UserModel'` |
| Bugs | none | **quiet**: no error, just wrong behaviour — hard to find |

#### What we'll use them for

| Method | Step | Use |
|---|---|---|
| `==` | 3.2 auto-login | cached user vs fresh `/users/me`: same → don't touch the screen |
| `==` | 4 profile edit | `draft != original` → **Save** on/off; nothing changed → no `PATCH` |
| `==` | 4 profile | `buildWhen: (p, c) => p.user != c.user` → no useless rebuilds |
| `==` | every step | `expect(result, UserModel(...))` in one line |
| `hashCode` | 5 chat, new group | member picker `Set<UserModel>`: tap twice → still one person |
| `hashCode` | 5 chat, presence | `Map<UserModel, PresenceStatus>` → find a person's online dot |
| `hashCode` | 6 call | set of callees still ringing in a group call |
| `toString` | every step | readable logs and readable test failures |

### `model/auth_response_model.dart`

```dart
factory AuthResponseModel.fromData(Object? data) {
  final json = data as Map<String, dynamic>;
  return AuthResponseModel(
    tokens: AuthTokens.fromJson(json),
    user: UserModel.fromJson(json['user'] as Map<String, dynamic>),
  );
}
```

`fromData(Object? data)` has exactly the `Parser<T>` shape from Step 2.1, so we
pass it **by name**: `parse: AuthResponseModel.fromData` (a tear-off).

### `repository/auth_repository.dart`

```dart
Future<Either<NetworkErrorModel, UserModel>> login({required String email, required String password}) async {
  final result = await _appService.send(
    httpMethods: HttpMethods.post,
    endPoint: ApiEndPoint.login,
    data: {'email': email.trim(), 'password': password},
    parse: AuthResponseModel.fromData,
  );
  return result.fold<Future<Either<NetworkErrorModel, UserModel>>>(
    (error) async => Left(error),
    (response) async {
      await _tokenStorage.write(response.tokens);   // 1. save tokens
      _session.markAuthenticated();                  // 2. open the session
      return Right(response.user);
    },
  );
}
```

```mermaid
flowchart LR
    R["Right(AuthResponseModel)"] --> S1["1 · write(tokens)"] --> S2["2 · markAuthenticated()"] --> S3["return Right(user)"]
    S2 -.->|"AuthGate → Home"| H["Home's first request<br/>already has the token ✅"]

    classDef ok fill:#d9f7e6,stroke:#00a86b,color:#063
    classDef app fill:#dbe9ff,stroke:#3b6fd8,color:#123
    class S1,S2,S3 app
    class H ok
```

- **The order matters.** Save tokens **first**, open the session **second**.
  If we opened first, Home could fire `GET /users/me` before the token is
  written → 401 → logged out right after logging in.
- **`email.trim()`** — a space pasted after the email is a classic "why can't
  I log in?" bug.
- **`fold<Future<…>>`** — `fold` handles both boxes; the success side must
  `await` the save, so both sides return a `Future`. The `<…>` tells Dart the
  type, because `Left(error)` alone doesn't say what the Right side is.
- Business rules live **here**, not in the BLoC (CLAUDE.md): the BLoC doesn't
  know tokens or sessions exist.

### `viewmodel/`: the BLoC, template style

```dart
// login_view_model_bloc.dart
part 'login_view_model_event.dart';
part 'login_view_model_state.dart';
```

**`part` / `part of`** — one library split over 3 files. Events and states see
the bloc's imports, and the page imports **one** file to get all three.

```dart
// login_view_model_event.dart
@immutable
sealed class LoginViewModelEvent {}
final class OnLoginSubmittedEvent extends LoginViewModelEvent {
  OnLoginSubmittedEvent({required this.email, required this.password});
  final String email;
  final String password;
}
```

```dart
// login_view_model_state.dart
@immutable
sealed class LoginViewModelState {}
final class LoginViewModelInitial extends LoginViewModelState {}
final class LoginLoadingState extends LoginViewModelState {}
final class LoginErrorState extends LoginViewModelState {
  final NetworkErrorModel error;
  Map<String, String> get fieldErrors => switch (error) {
    ServerError(:final fieldErrors) => fieldErrors,
    _ => const {},
  };
}
final class LoginSuccessState extends LoginViewModelState { final UserModel user; }
```

- **`@immutable`** — the analyzer warns if a field isn't `final`. Events and
  states never change after they're made (CLAUDE.md rule).
- **`fieldErrors` getter** — the page asks the state "any field errors?"
  instead of digging into `ServerError` itself. Logic stays out of the widget.

```dart
// login_view_model_bloc.dart
Future<void> _onLoginSubmitted(OnLoginSubmittedEvent event, Emitter<LoginViewModelState> emit) async {
  if (state is LoginLoadingState) return;          // ignore double taps
  emit(LoginLoadingState());
  final result = await _repository.login(email: event.email, password: event.password);
  result.fold(
    (error) => emit(LoginErrorState(error: error)),
    (user) => emit(LoginSuccessState(user: user)),
  );
}
```

Exactly the template's `_onLoadProduct` shape: Loading → repository →
`fold` → Error / Loaded.

### `auth_di.dart` + `app/app_di.dart`

```dart
void registerAuthModule(ServiceLocator getIt) {
  getIt
    ..registerLazySingleton<AuthRepository>(() => AuthRepository(
        appService: getIt<AppService>(), tokenStorage: getIt<TokenStorage>(), session: getIt<AuthSession>()))
    ..registerFactory<LoginViewModelBloc>(() => LoginViewModelBloc(getIt<AuthRepository>()));
}
```

- Repository → **lazy singleton** (one for the app). BLoC → **factory** (a
  fresh one each time the page opens — Step 1.3's table).
- `..` is the **cascade**: call two methods on the same `getIt`.

```mermaid
flowchart TD
    M["main.dart · bootstrap()"] --> APPDI["app/app_di.dart<br/>configureAppDependencies()"]
    APPDI --> CORE["core/di/injection.dart<br/>configureDependencies()<br/>prefs · session · Dio · AppService · tokens"]
    APPDI --> AUTH["features/auth/auth_di.dart<br/>registerAuthModule()"]
    APPDI -.-> NEXT["profile · chat · call<br/>(Steps 4–6)"]

    classDef app fill:#dbe9ff,stroke:#3b6fd8,color:#123
    classDef feat fill:#fff4d6,stroke:#d4a017,color:#5a4300
    classDef none fill:#eeeeee,stroke:#999,color:#555
    class M,APPDI,CORE app
    class AUTH feat
    class NEXT none
```

**Why `app/app_di.dart`?** `core/di/injection.dart` must not import
`features/` (the arrows-point-down rule). The `app/` layer may import both, so
it calls core first, then each feature. (Same reason `AuthGate` lives in
`app/`.)

### `view/login_page.dart` + `widgets/`

The page file is **only the layout** (~50 lines). Every piece lives in its
own file in `widgets/`. One 400-line file was hard to read: you had to scroll
past the brand panel to find the form.

```dart
return BlocProvider(
  create: (_) => getIt<LoginViewModelBloc>(),   // an "edge": may use getIt
  child: Scaffold(body: LayoutBuilder(...)),     // phone column / tablet row
);
// LoginFormColumn: LoginBrandRow · LoginTitles · LoginForm · LoginSecureNote
```

| Where | What goes there | Example |
|---|---|---|
| `features/auth/view/` | pages: layout + `BlocProvider` | `LoginPage` |
| `features/auth/widgets/` | pieces used **only by auth**, one per file, named `Login…` | `LoginForm`, `LoginBrandPanel` |
| `core/widgets/` | pieces **any feature** can use, named `App…` | `AppButton`, `AppSnackBar`, `AppFadeSlideIn` |

- **Public names** (`LoginForm`, no `_`): a `_` class is private to its file,
  so a widget in another file must be public.
- **`const LoginForm({super.key})`**: public widgets take a `key`, like every
  Flutter widget.
- **`LoginForm` keeps its private `_LoginFormState`**: nobody outside needs
  the state class.

```mermaid
flowchart TD
    LP["LoginPage<br/>BlocProvider(create: getIt)"] --> LF["LoginForm (StatefulWidget)<br/>controllers · _obscure"]
    LF --> BB["BlocConsumer<br/>listenWhen: error, no fieldErrors<br/>buildWhen: not Success"]
    BB -.->|"listener"| SNACK["AppSnackBar.error"]
    BB --> E["AppInputText email<br/>validator + errorText"]
    BB --> P["AppInputText password<br/>👁 toggle"]
    BB --> BTN["AppButton<br/>isLoading"]

    classDef app fill:#dbe9ff,stroke:#3b6fd8,color:#123
    classDef feat fill:#fff4d6,stroke:#d4a017,color:#5a4300
    class LP,LF,BB app
    class H,E,P,BTN,SNACK feat
```

| Piece | Why |
|---|---|
| `LoginForm` is a `StatefulWidget` | it owns `TextEditingController`s (must be `dispose()`d) and `_obscure` — **UI-only** state. Business state (loading, error) lives in the BLoC. |
| `GlobalKey<FormState>` + `validate()` | runs every field's `validator` at once; returns `false` → no request. |
| `buildWhen: current is! LoginSuccessState` | on success `AuthGate` is already fading to Home — no need to rebuild the form (CLAUDE.md: `buildWhen` on every `BlocBuilder`). |
| `enabled: !loading` | fields locked while the request runs. |
| `errorText: fieldErrors['email']` | the SERVER's message under the field (`forceErrorText`). |
| `AutofillGroup` + `autofillHints` | iOS/Android password managers can fill the form. |
| `FocusScope.of(context).unfocus()` | hides the keyboard on submit. |
| `BlocConsumer` = **listener** + **builder** | The **builder** draws the form (loading, field errors). The **listener** does **one-time actions** (show a snackbar). A snackbar in the builder would show again on every rebuild. |
| `listenWhen: current is LoginErrorState && current.fieldErrors.isEmpty` | Field errors are already **under the fields** → no snackbar for them. Only "card-type" errors (401, offline, 500) pop up. |
| `AppSnackBar.hide()` in `_submit` | Tap **Sign in** again → the old error goes away at once. |

### `core/widgets/`: the template's widgets, themed

| Template | Ours | Why |
|---|---|---|
| `AppInputText(fillColor: Colors.white, Colors.grey border…)` | colors from `AppTheme.inputDecorationTheme` | hard-coded white breaks dark mode |
| no server errors | `errorText` → `forceErrorText` | show `fieldErrors` from the server |
| `AppButton(backgroundColor: Colors.blue, height: 48…)` | `FilledButton` + theme (52px, primary) | tokens, dark mode |
| no loading | `isLoading` → spinner, taps ignored | design guide 1.1; no double submit |
| `SnackBarHelper.show(context, msg)` → plain `SnackBar(Text)` at the bottom | `AppSnackBar.error / success / info(context, title:, message:)` | type → colour + icon, `AppLabel` text, **top** of the screen, ✕ close, 420 wide on tablet, replaces the old one |

#### `AppSnackBar` (at the top)

```dart
AppSnackBar.error(context, title: state.error.title, message: state.error.description);
AppSnackBar.success(context, message: 'Profile saved');   // Step 4
AppSnackBar.hide();                                       // slide it away
```

Flutter's own `SnackBar` can **only** sit at the bottom. To put it on top we
draw it ourselves in the **Overlay**: the layer that floats above every page
(the same layer dialogs and tooltips use).

```mermaid
flowchart TD
    E["AppSnackBar.error(context, ...)"] --> R["_removeNow()<br/>old bar gone (no queue)"]
    R --> I["Overlay.of(context, rootOverlay: true)<br/>.insert(OverlayEntry)"]
    I --> T["_TopBar<br/>slides down 250 ms"]
    T --> W{"what happens first?"}
    W -->|"4 s timer"| D["dismiss()<br/>slide up → remove"]
    W -->|"tap ✕"| D
    W -->|"swipe up"| G["Dismissible → remove"]
    W -->|"AppSnackBar.hide()"| D

    classDef app fill:#dbe9ff,stroke:#3b6fd8,color:#123
    classDef ok fill:#d9f7e6,stroke:#00a86b,color:#063
    class E,R,I,T,W app
    class D,G ok
```

```dart
static void show(BuildContext context, {...}) {
  _removeNow();                                          // replace, don't queue
  final key = GlobalKey<_TopBarState>();
  final entry = OverlayEntry(builder: (_) => _TopBar(key: key, ..., onGone: _removeNow));
  _key = key;
  _entry = entry;
  Overlay.of(context, rootOverlay: true).insert(entry);  // above every page
}

static void hide() => _key?.currentState?.dismiss();     // animated

// _TopBarState
late final _controller = AnimationController(vsync: this, duration: 250ms)..forward();
late final _slide = Tween(begin: Offset(0, -1.2), end: Offset.zero)
    .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
_timer = Timer(widget.duration, dismiss);                // auto-hide after 4 s

Future<void> dismiss() async {
  if (_dismissing || !mounted) return;                   // only once
  _dismissing = true;
  _timer?.cancel();
  await _controller.reverse();                           // slide up
  widget.onGone();                                       // then remove
}
```

| Piece | Why |
|---|---|
| `OverlayEntry` + `Overlay.of(context, rootOverlay: true)` | The only way to float **anywhere** (top). `rootOverlay` = the app's top layer, so it stays above every page. |
| `static _entry` / `_key` | Remember the **one** bar on screen, so a new one can replace it and `hide()` can find it — no `context` needed. |
| `_removeNow()` first | 3 wrong tries → **one** bar, not 3 stacked. |
| `SafeArea` + `Align(topCenter)` | Below the notch / status bar, centred. |
| `ConstrainedBox(maxWidth: 420)` | Tablet: not stretched across the screen. Phone: full width minus 16 each side. |
| `SlideTransition` from `Offset(0, -1.2)` | Starts just above the screen and slides down; `easeOutCubic`, 250 ms = calm (design-guide motion rules). |
| `Timer(duration, dismiss)` | Goes away by itself after 4 s. Cancelled in `dispose()` → no timer firing after the widget is gone. |
| `_dismissing` flag | Timer + ✕ at the same moment → `reverse()` and removal run only once. |
| `Dismissible(direction: up)` | Swipe up to close, like iOS notifications. |
| `Material(color: …, elevation: 6)` | Gives the bar its colour, shadow and round corners, and text/icon styles work inside the Overlay. |
| `colors.error` / `colors.onError` | From the theme: light = red + white text, dark = soft red + dark text. |
| `(background, foreground, icon) = switch …` | A Dart 3 **record**: one `switch` gives 3 values. Add a type → the compiler makes you add its colours. |

| Other way | Why not |
|---|---|
| `SnackBar` + a big bottom `margin` to push it up | A hack: the height changes with the keyboard and screen size, and Flutter warns when the margin is too big. |
| `MaterialBanner` (`showMaterialBanner`) | It's at the top, but it **pushes the page down**, has no auto-hide and needs action buttons. |
| A package (`another_flushbar`, `toastification`) | Works, but one more dependency for ~150 lines we can read and own. |

### `core/utils/validators/`: the template's validators

```dart
FormValidators.loginEmail   → Validators.email     → ValidationMessages.emailInvalid
FormValidators.loginPassword → Validators.password → ValidationMessages.passwordShort
```

Three layers, like the template: **messages** (texts) → **validators**
(rules) → **form validators** (named after the field). A rule change for
"login password" happens in one place.

## 4. 🤔 Why like this? (other ways)

| Choice we made | Other way | Why we didn't pick the other way |
|---|---|---|
| Template folders (`model · repository · viewmodel · view`) | `models · repositories · bloc · views` (old CLAUDE.md) | You know the template; one naming everywhere. |
| `…ViewModelBloc` + `part` files | One file per event / state | Template style; one import for the page. |
| `Form` + `FormValidators` for field rules, BLoC for submit + server errors | A separate "form BLoC" per field change | Phone-side rules are instant and need no state. The BLoC handles what really is state: loading, server errors, success. Less code, same safety. |
| Repository saves tokens + opens the session | BLoC does it | BLoCs never touch storage (CLAUDE.md); a future "register" flow reuses the same repository rule. |
| Save tokens **before** opening the session | Open first | Home's first request could go out without a token → 401. |
| Page doesn't navigate | `pushReplacement(Home)` on success | `AuthGate` owns Login ↔ Home (Step 1.4). |
| BLoC from `getIt` via `BlocProvider(create:)` | Pass the repository down the constructor chain | `BlocProvider.create` is an "edge" (Step 1.3); no long constructor chain. |
| `app/app_di.dart` registers features | `core/di/injection.dart` does | `core/` must never import `features/`. |
| `UserModel.id` as `String` | `int` | Backend sends a number today; chat/call ids are compared as strings later. One type everywhere. |
| `UserModel` = exactly the 5 documented fields | Keep `roles` / `permissions` and "tolerant" name guesses | The backend doc is now exact and doesn't send them to `/me` or login. Fields that are always empty only confuse. |
| Explicit `==` / `hashCode` / `toString` in `UserModel` | Leave them out (Dart's implicit default), or `equatable` / `freezed` | The default compares memory, not data → quiet bugs in profile (Save button) and chat (duplicate members). The packages were removed (CLAUDE.md). 10 hand-written lines are cheaper. |
| 401 on a public endpoint → `ServerError` with the server message | Every 401 → `UnauthorizedError` | On login, 401 = wrong password. "Session expired" would be wrong and confusing. |
| Server errors → `AppSnackBar` (via `BlocConsumer.listener`) | An inline error card in the form (our first version) | You asked for it, and it keeps the form still. The snackbar is one shared widget, so every screen shows errors the same way. |
| `AppSnackBar` = static methods (`AppSnackBar.error(context, …)`) | The template's `context.showSnackBar(msg)` extension | Same one-line call, but with a type (error / success / info), a title, theme colours and tablet width. |
| `AppSnackBar` at the **top**, drawn in the `Overlay` | Flutter's `SnackBar` (bottom only) | You asked for the top: the keyboard never covers it, and it's where the eye looks after tapping Sign in. |
| Page = layout, pieces in `widgets/` (one per file) | Everything in `login_page.dart` | One long file is hard to read and review. Small files have one job, a clear name, and are easy to find. |
| No DEV / UAT badge on the login page | A `_FlavorBadge` in the corner | Removed on request: the app name already says "ERP Dev" / "ERP UAT". |
| `bloc_test` + `mocktail` | Real repository in BLoC tests | The BLoC test checks only the BLoC: state order. The repository has its own tests. |

## 5. Try it

```bash
flutter test                                    # 48 tests → All tests passed!
flutter run --flavor dev -t lib/main_dev.dart
```

You need a **real account** on the backend (create one with
`POST /api/v1/auth/register`, or ask the backend team).

> 💡 To test the server **without** the app, the backend now ships a Postman
> collection (see `API_LIST_BACKEND.md`): import
> `ERP_API.postman_collection.json` + `ERP_Local.postman_environment.json`,
> run **Auth → Login**, and every other request uses that token. Handy to
> check "is it the app or the server?".

1. Tap **Sign in** with empty fields → red text under both fields, **no**
   request in the console log.
2. Type `abc` as email → "Invalid email address".
3. Wrong password → spinner → red bar slides down at the **top**: **"Error · Invalid email or password"** (tap ✕, swipe up, or wait 4 s).
4. Airplane mode → **"No Internet"** card.
5. Correct email + password → spinner → **Home** fades in.
6. On Home, tap **Call GET /users/me** → **✅ Signed in as your@email** —
   the token from Step 2.2 is now real!

> ⚠ Until Step 3.2, the Home **logout** icon only closes the session; the
> tokens stay saved, and a cold start always shows Login. Step 3.2 adds
> auto-login and a real logout (server revoke + clear tokens).

## 6. Check yourself

1. Why does the repository save the tokens **before** calling
   `markAuthenticated()`?
2. The email field is empty. Does a request go to the server? Which code
   stops it?
3. Where does "must be a well-formed email address" from a 400 appear, and
   which line puts it there?
4. Why is the login BLoC registered with `registerFactory`, but the
   repository with `registerLazySingleton`?
5. Why does `registerAuthModule` get called from `app/app_di.dart` and not
   from `core/di/injection.dart`?
6. We remove `==` and `hashCode` from `UserModel`. All tests still pass. Name
   one bug that shows up later.
7. We add `final String? department;` to `UserModel`. Which places must change?

<details><summary>Answers</summary>

1. `markAuthenticated()` makes `AuthGate` show Home, and Home may send a
   request right away. The token must already be in storage, or that request
   gets 401.
2. No. `_formKey.currentState!.validate()` runs `FormValidators.loginEmail`,
   which returns "This field is required", so `_submit` returns early.
3. Under the email field. `LoginErrorState.fieldErrors` picks it from the
   `ServerError`, and `AppInputText(errorText: fieldErrors['email'])` shows it.
4. Each page visit needs a fresh BLoC (old states must not leak in). The
   repository has no per-screen state, so one shared instance is enough.
5. `core/` must never import `features/`. `app/` is the top layer, allowed to
   import both.
6. Any of: the profile **Save** button never turns off (`draft != original`
   is always true); the same person shows twice in the chat member `Set`;
   screens rebuild when nothing changed. Tests pass only because they reuse
   one `const user` (same memory box).
7. The constructor, `fromJson`, `==`, `hashCode` — and `copyWith` if the user
   can edit it.

</details>
