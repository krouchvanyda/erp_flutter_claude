# Step 2.2 — Tokens + auth interceptor (attach, refresh, log out)

## 1. Why

Our backend protects almost everything: you must send
`Authorization: Bearer <accessToken>` on **every** request. Tokens expire.
Without help, every repository would have to:

```mermaid
flowchart LR
    subgraph BAD["❌ Every repository by itself"]
        direction TB
        B1["read the token"]
        B2["add the header"]
        B3["401? call refresh"]
        B4["save the new pair"]
        B5["send the request again"]
        B6["refresh failed? log out"]
    end
    subgraph GOOD["✅ One AuthInterceptor"]
        direction TB
        G1["runs on EVERY request automatically"]
        G2["repositories don't know tokens exist"]
    end
    BAD -.->|"move into one place"| GOOD

    classDef err fill:#fde2e2,stroke:#d64545,color:#611
    classDef ok fill:#d9f7e6,stroke:#00a86b,color:#063
    class B1,B2,B3,B4,B5,B6 err
    class G1,G2 ok
```

**Two tokens, two jobs** (`AuthResponse` in `API_LIST_BACKEND.md`):

| Token | Lives | Sent | Job |
|---|---|---|---|
| `accessToken` | short (minutes/hours) | on **every** request | "I am Vanyda" |
| `refreshToken` | long (weeks) | **only** to `/auth/refresh` | get a new pair when the access token expires |

The refresh token is **rotated**: every refresh returns a **new** refresh
token, and the old one stops working. That detail drives a big part of the
design (see "3 requests at once" below).

### What the real server does (we tested it)

| Request | Real answer |
|---|---|
| `GET /users/me` with no token | **401** `UNAUTHORIZED` "Authentication required" |
| `GET /users/me` with a bad token | **401** `UNAUTHORIZED` |
| `POST /auth/refresh` with a bad refresh token | **401** "Invalid or expired token" |
| `POST /auth/login` with a **wrong password** | **401** "Invalid email or password" ⚠ |

⚠ The last row is a trap: a wrong password **also** returns 401. If the
interceptor treated it like "token expired", a typo in the password would
trigger a refresh and log you out. So **public endpoints never refresh**.

## 2. Picture

### The happy path: token expired → fixed by itself

```mermaid
sequenceDiagram
    autonumber
    participant R as Repository
    participant A as AppService
    participant I as AuthInterceptor
    participant T as TokenStorage (Keychain)
    participant S as 🛠 Server

    R->>A: send(get, ApiEndPoint.me)
    A->>I: onRequest
    I->>T: read()
    T-->>I: old access + old refresh
    I->>S: GET /users/me + Bearer old-access
    S-->>I: 401 (access token expired)
    Note over I: onError: protected endpoint,<br/>not retried yet → refresh
    I->>S: POST /auth/refresh (old-refresh)<br/>via refreshDio
    S-->>I: 200 new access + NEW refresh (rotated)
    I->>T: write(new pair)
    I->>S: GET /users/me + Bearer new-access<br/>(retry, marked as retried)
    S-->>I: 200 user
    I-->>A: Response (as if nothing happened)
    A-->>R: Right(User)
```

The repository **never knows** a refresh happened.

### Every decision in `onError`

```mermaid
flowchart TD
    E["onError(err)"] --> Q1{"status 401?"}
    Q1 -->|"no"| PASS["pass the error on<br/>(AppService maps it)"]
    Q1 -->|"yes"| Q2{"public endpoint?<br/>login · register · refresh · health"}
    Q2 -->|"yes"| PASS
    Q2 -->|"no"| Q3{"already retried?"}
    Q3 -->|"yes"| PASS
    Q3 -->|"no"| Q4{"tokens stored?"}
    Q4 -->|"no"| OUT1["onSessionExpired()<br/>→ Login"]
    Q4 -->|"yes"| Q5{"token already changed<br/>by another request?"}
    Q5 -->|"yes"| RETRY["retry with the<br/>current token"]
    Q5 -->|"no"| REF["POST /auth/refresh"]
    REF -->|"RefreshOk"| SAVE["save new pair"] --> RETRY
    REF -->|"RefreshRejected<br/>400 / 401 / 403"| OUT2["clear tokens +<br/>onSessionExpired() → Login"]
    REF -->|"RefreshFailed<br/>offline / timeout / 5xx"| KEEP["keep tokens,<br/>pass the error on"]
    RETRY --> DONE["handler.resolve(response)"]

    classDef ok fill:#d9f7e6,stroke:#00a86b,color:#063
    classDef err fill:#fde2e2,stroke:#d64545,color:#611
    classDef wait fill:#fff4d6,stroke:#d4a017,color:#5a4300
    classDef none fill:#eeeeee,stroke:#999,color:#555
    class DONE,SAVE,RETRY ok
    class OUT1,OUT2 err
    class KEEP wait
    class PASS none
```

<a id="pic-rejected"></a>

### Rejected vs failed: why the difference matters

```mermaid
flowchart LR
    R["refresh call"] --> REJ["Server answered NO<br/>400 / 401 / 403"]
    R --> FAIL["Server did NOT answer<br/>offline · timeout · 5xx"]
    REJ --> L["the session is really over<br/>→ clear tokens → Login"]
    FAIL --> K["NOT the user's fault<br/>→ keep tokens, stay logged in,<br/>show 'No Internet' + Retry"]

    classDef err fill:#fde2e2,stroke:#d64545,color:#611
    classDef wait fill:#fff4d6,stroke:#d4a017,color:#5a4300
    class REJ,L err
    class FAIL,K wait
```

Imagine walking into a lift with no signal while the token expires. Without
this rule, you'd be **logged out** just for losing the internet for 5 seconds.

<a id="pic-queued"></a>

### 3 requests get 401 at the same time

The chat screen loads conversations, the profile and presence **together**.
If the token just expired, all 3 get 401.

```mermaid
sequenceDiagram
    participant A as request A
    participant B as request B
    participant C as request C
    participant I as AuthInterceptor (queued)
    participant S as 🛠 Server

    A->>I: 401
    B->>I: 401 (waits in the queue)
    C->>I: 401 (waits in the queue)
    Note over I: A first: token = old → refresh
    I->>S: POST /auth/refresh (old-refresh)
    S-->>I: new pair (old-refresh is now DEAD)
    I-->>A: retried with new token ✅
    Note over I: B: header was old, storage is new<br/>→ token already changed → just retry
    I-->>B: retried with new token ✅
    Note over I: C: same → just retry
    I-->>C: retried with new token ✅
```

**ONE refresh, not three.** With a normal `Interceptor`, all 3 would refresh
in parallel with the **same** old refresh token. The first wins, and since
the token is rotated, the other 2 get "Invalid token" → **logout**. That's
why we use `QueuedInterceptor`.

### Two Dio objects

```mermaid
flowchart LR
    subgraph APPDIO["App Dio (used by AppService)"]
        direction LR
        AI["AuthInterceptor"] --> LG1["logger"]
    end
    subgraph REFDIO["refresh Dio (no AuthInterceptor)"]
        direction LR
        LG2["logger"]
    end
    AS["AppService"] --> APPDIO --> S["🛠 Server"]
    AI -->|"refresh call + retry"| REFDIO --> S

    classDef app fill:#dbe9ff,stroke:#3b6fd8,color:#123
    classDef wait fill:#fff4d6,stroke:#d4a017,color:#5a4300
    class AS,AI,LG1 app
    class LG2 wait
```

If the refresh call went through the **app** Dio, a 401 on refresh would come
back into the same interceptor → refresh again → 401 → … an endless loop. The
refresh Dio has **no** auth interceptor, so that can't happen.

### Files

```
lib/core/network/
├── auth_tokens.dart        AuthTokens: access + refresh (+ expiry)
├── token_storage.dart      TokenStorage: Keychain / Keystore (read · write · clear)
├── auth_interceptor.dart   AuthInterceptor + RefreshResult (Ok · Rejected · Failed)
├── api_endpoints.dart      + register, publicEndpoints, isPublic()
└── dio_factory.dart        createDio(flavor, interceptors: [...])
test/core/network/
├── token_storage_test.dart     5 tests
└── auth_interceptor_test.dart  9 tests
```

## 3. Code

<a id="code-tokens"></a>

### `auth_tokens.dart`

```dart
class AuthTokens {
  final String accessToken;
  final String refreshToken;
  final DateTime? accessTokenExpiresAt;
  final DateTime? refreshTokenExpiresAt;

  factory AuthTokens.fromJson(Map<String, dynamic> json) => …
  Map<String, dynamic> toJson() => …
  @override bool operator ==(Object other) => …   // CLAUDE.md: value types get ==
  @override String toString() => 'AuthTokens(access: ***, refresh: ***)';
}
```

- **Hand-written `==` / `hashCode`** (project rule, no `freezed`): two pairs
  with the same values are equal. Tests use it: `expect(read, tokens)`.
- **`toString` hides the tokens.** If someone writes `print(tokens)`, the log
  shows `***`, not a working token.
- `DateTime.tryParse(...)` returns `null` instead of crashing on a missing or
  bad date.

<a id="code-storage"></a>

### `token_storage.dart`

```dart
class TokenStorage {
  TokenStorage(this._storage);
  final FlutterSecureStorage _storage;
  static const String _key = 'auth_tokens';

  Future<AuthTokens?> read() async { … }
  Future<void> write(AuthTokens tokens) => _storage.write(key: _key, value: jsonEncode(tokens.toJson()));
  Future<void> clear() => _storage.delete(key: _key);
}
```

```mermaid
flowchart LR
    TS["TokenStorage"] --> FSS["flutter_secure_storage"]
    FSS --> IOS["🍎 iOS Keychain<br/>first_unlock"]
    FSS --> AND["🤖 Android Keystore<br/>encryptedSharedPreferences"]
    TS -.->|"never"| NO["❌ SharedPreferences<br/>(plain text file)"]

    classDef app fill:#dbe9ff,stroke:#3b6fd8,color:#123
    classDef ok fill:#d9f7e6,stroke:#00a86b,color:#063
    classDef err fill:#fde2e2,stroke:#d64545,color:#611
    class TS,FSS app
    class IOS,AND ok
    class NO err
```

- **One key, one JSON value.** Access and refresh are always written
  **together**. With two keys, a crash between the two writes could leave a
  new access token with an old (dead) refresh token.
- **`read()` heals itself:** a broken value → `clear()` → `null` ("no
  session"), instead of crashing every request.
- **`FlutterSecureStorage` is injected** → tests use
  `FlutterSecureStorage.setMockInitialValues({})`, an in-memory fake.

➡ Why not SharedPreferences, Hive, or memory? [All options compared](#why-secure-storage)

<a id="code-first-unlock"></a>

**The options (in `TokenStorage.secureStorage`):**

| Option | Why |
|---|---|
| Android `encryptedSharedPreferences: true` | values encrypted with a Keystore key |
| iOS `KeychainAccessibility.first_unlock` | readable after the **first** unlock since boot — even while the phone is **locked**. Step 7: a call arrives at a killed app in your pocket → the background code must read the token to talk to the server. The default (`unlocked`) would fail there. |

➡ What do the other Keychain levels do? [All options compared](#why-first-unlock)

<a id="code-public"></a>

### `api_endpoints.dart`: public endpoints

```dart
static const Set<String> publicEndpoints = {health, login, register, refresh};
static bool isPublic(String path) => publicEndpoints.contains(path);
```

Matches the backend doc's "Public endpoints" list. **One** place decides
"no token, no refresh" — not each repository.

<a id="code-interceptor"></a>

### `auth_interceptor.dart`

```dart
class AuthInterceptor extends QueuedInterceptor {
  AuthInterceptor({
    required TokenStorage tokenStorage,
    required Dio refreshDio,
    required void Function() onSessionExpired,
  });
```

All 3 needs come by **constructor** (Step 1.3 rule):

| Parameter | Real app (DI) | Test |
|---|---|---|
| `tokenStorage` | `TokenStorage(Keychain)` | `TokenStorage(mock)` |
| `refreshDio` | `createDio(flavor)` (no auth) | Dio + fake server |
| `onSessionExpired` | `getIt<AuthSession>().markLoggedOut` | `() => sessionExpired++` |

`onSessionExpired` is a **function**, not `AuthSession` itself. The
interceptor doesn't need to know *how* logout works — only *that* it should
happen. A test just counts the calls.

#### `onRequest`

```dart
if (!ApiEndPoint.isPublic(options.path)) {
  final tokens = await _tokenStorage.read();
  if (tokens != null) options.headers['Authorization'] = 'Bearer ${tokens.accessToken}';
}
handler.next(options);
```

`handler.next(options)` = "continue to the next interceptor / the server".
Forget it and the request hangs forever.

<a id="code-onerror"></a>

#### `onError`: the 3 handler choices

| Call | Meaning |
|---|---|
| `handler.next(err)` | "I can't fix it" → the error continues → `AppService` turns it into a `NetworkErrorModel` |
| `handler.resolve(response)` | "I fixed it" → the caller gets this response as if no error happened |
| (`handler.reject(err)`) | stop with an error (we don't need it) |

<a id="code-refresh-result"></a>

#### `RefreshResult`: a sealed family (again)

```dart
sealed class RefreshResult {}
final class RefreshOk extends RefreshResult { final AuthTokens tokens; }
final class RefreshRejected extends RefreshResult {}
final class RefreshFailed extends RefreshResult {}

switch (result) {
  case RefreshOk(:final tokens): …       // save + retry
  case RefreshRejected(): …              // clear + logout
  case RefreshFailed(): …                // keep tokens
}
```

Same idea as `NetworkErrorModel` and `_Registration` in DI: the compiler checks
the `switch` covers all 3. A `bool?` (`true` / `false` / `null`) could say the
same thing, but nobody remembers what `null` means six months later.

<a id="code-retried"></a>

#### `_retriedKey`: no endless loop

```dart
extra: {...request.extra, _retriedKey: true},
```

`extra` is a bag of notes that travels **with** a request (not sent to the
server). We mark the retry. If the retry also gets 401, `onError` sees the
mark and gives up instead of refreshing forever.

#### `{...request.headers, …}`: the spread operator

```dart
headers: {...request.headers, _header: 'Bearer ${tokens.accessToken}'},
```

`...map` copies all entries into a **new** map, then we override one key. The
original request is not changed.

<a id="code-two-dio"></a>

### `dio_factory.dart` + DI

```dart
Dio createDio(Flavor flavor, {List<Interceptor> interceptors = const []}) { … }
```

```dart
getIt.registerLazySingleton<Dio>(
  () => createDio(Flavor.current, interceptors: [
    AuthInterceptor(
      tokenStorage: getIt<TokenStorage>(),
      refreshDio: createDio(Flavor.current),               // no interceptor
      onSessionExpired: getIt<AuthSession>().markLoggedOut,
    ),
  ]),
);
```

```mermaid
flowchart TD
    subgraph BOX["📦 getIt"]
        direction TB
        FSS["FlutterSecureStorage<br/>(Keychain options)"] --> TS["TokenStorage"]
        SES["AuthSession"]
        TS --> AI["AuthInterceptor"]
        SES -->|"markLoggedOut"| AI
        RD["refresh Dio<br/>createDio(flavor)"] --> AI
        AI --> D["app Dio<br/>createDio(flavor, interceptors: [AI])"]
        D --> AS["AppService"]
    end
    SES -.->|"notifies"| GATE["AuthGate → Login"]

    classDef app fill:#dbe9ff,stroke:#3b6fd8,color:#123
    classDef ok fill:#d9f7e6,stroke:#00a86b,color:#063
    class FSS,TS,SES,RD,AI,D,AS app
    class GATE ok
```

When the session expires anywhere, `AuthSession.markLoggedOut()` fires →
`AuthGate` (Step 1.4) closes all pages and shows Login. No screen code needed.

### The demo: "Call GET /users/me (needs a token)"

The demo login (Step 1.4) stores **no** tokens. So the button shows the
"no session" path with the real server:

```mermaid
sequenceDiagram
    autonumber
    actor U as You
    participant H as Home (demo)
    participant I as AuthInterceptor
    participant S as 🛠 Server
    participant G as AuthGate

    U->>H: tap "Call GET /users/me"
    H->>I: GET /users/me
    Note over I: no tokens stored → no header
    I->>S: GET /users/me
    S-->>I: 401 Authentication required
    Note over I: tokens stored? NO
    I->>G: onSessionExpired() → markLoggedOut
    G-->>U: back to Login
    Note over U: snackbar: 401 Session expired
```

In Step 3 the **real** login saves tokens → the same button shows
"✅ Signed in as …".

## 4. 🤔 Why like this? (other ways)

Each **Choice we made** links back to where it is explained.

| Choice we made | Other way | Why we didn't pick the other way |
|---|---|---|
| [An interceptor adds the token](#code-interceptor) | The template's `getToken()` inside `AppService` / each repo | One place, automatic, and it can also **fix** a 401. `getToken()` only adds. |
| [`flutter_secure_storage`](#code-storage) | `SharedPreferences` (the template) | SharedPreferences is a plain file — readable on rooted phones and in backups. Tokens = your identity. **All options compared below** ↓ |
| [One JSON key for the pair](#code-storage) | Two keys | A crash between two writes could leave a mismatched pair. |
| [iOS `first_unlock`](#code-first-unlock) | The default (`unlocked`) | Step 7: background code must read the token while the phone is locked. **All options compared below** ↓ |
| [`QueuedInterceptor`](#pic-queued) | `Interceptor` | Parallel 401s would refresh in parallel; our refresh token is rotated → 2 of 3 fail → logout. |
| [A separate refresh Dio](#code-two-dio) | Refresh through the app Dio | A 401 on refresh would re-enter the interceptor → loop. |
| [Rejected vs Failed](#pic-rejected) | "Any refresh error → logout" | Losing signal for 5 s would log the user out. |
| [Public endpoints skip auth](#code-public) | Treat every 401 the same | Wrong password on login is 401 → would refresh + log out. |
| [`_retriedKey` mark](#code-retried) | No mark | A server that always says 401 would loop forever. |
| [Refresh **after** a 401](#code-onerror) | Refresh **before** expiry using `accessTokenExpiresAt` (flutter-chat does this) | Simpler and always correct (phone clock may be wrong). We store the expiry, so a "refresh 60 s early" step can be added later without changing callers. |
| [`onSessionExpired` as a function](#code-interceptor) | Pass `AuthSession` | The interceptor needs *one* action, not the whole session. Tests count calls. |

<a id="why-secure-storage"></a>

### 🔐 Where can tokens live? All options

[← back to the code](#code-storage)

```mermaid
flowchart TD
    Q{"Where do we keep<br/>the token pair?"}
    Q --> M["Memory only<br/>(a variable)"]
    Q --> SP["SharedPreferences"]
    Q --> HV["Hive / SQLite<br/>(+ our own encryption)"]
    Q --> FSS["flutter_secure_storage"]

    M --> M1["❌ lost when the app is killed<br/>→ log in on EVERY start"]
    SP --> SP1["❌ plain text file on disk<br/>rooted phone / backup can read it"]
    HV --> HV1["⚠ we must store the encryption KEY<br/>somewhere safe… → Keychain anyway"]
    FSS --> FSS1["✅ the OS vault does the encryption<br/>iOS Keychain · Android Keystore"]

    classDef err fill:#fde2e2,stroke:#d64545,color:#611
    classDef wait fill:#fff4d6,stroke:#d4a017,color:#5a4300
    classDef ok fill:#d9f7e6,stroke:#00a86b,color:#063
    classDef none fill:#eeeeee,stroke:#999,color:#555
    class Q none
    class M,M1,SP,SP1 err
    class HV,HV1 wait
    class FSS,FSS1 ok
```

| Option | Survives app kill? | Encrypted? | Who holds the key? | Verdict |
|---|---|---|---|---|
| Memory (a variable) | ❌ no | — | — | ❌ no auto-login (Step 3 needs it) |
| `SharedPreferences` | ✅ | ❌ plain text | nobody | ❌ the template's choice — not for secrets |
| Hive / SQLite + our own encryption | ✅ | ✅ | **we** must hide it… in the Keychain | ⚠ more code, same Keychain in the end |
| **`flutter_secure_storage`** | ✅ | ✅ by the OS | the **OS** (Secure Enclave / TEE) | ✅ **our choice** |

**Rule of thumb** (also in CLAUDE.md):

| Data | Where |
|---|---|
| Tokens, passwords, keys (secrets) | `flutter_secure_storage` |
| Cached user name, theme, language (not secret) | `shared_preferences` |

<a id="why-first-unlock"></a>

### 🍎 iOS Keychain: when can the app read the token? All options

[← back to the code](#code-first-unlock)

The iOS Keychain lets each item choose **when** it can be read. Our token
must be readable when a call arrives and the app is **killed** and the phone
is **locked** in your pocket (Step 7).

```mermaid
flowchart LR
    BOOT["📱 phone turned on"] --> L1["🔒 locked<br/>(never unlocked yet)"]
    L1 -->|"first unlock"| U["🔓 unlocked"]
    U -->|"screen off"| L2["🔒 locked again<br/>(in your pocket)"]
    L2 -->|"unlock"| U
    L2 -.->|"📞 call arrives,<br/>app killed"| BG["background code<br/>must read the token"]

    classDef ok fill:#d9f7e6,stroke:#00a86b,color:#063
    classDef wait fill:#fff4d6,stroke:#d4a017,color:#5a4300
    classDef err fill:#fde2e2,stroke:#d64545,color:#611
    class U ok
    class L2,BG wait
    class L1 err
```

| `KeychainAccessibility` | 🔒 never unlocked since boot | 🔓 unlocked | 🔒 locked again (pocket) | Fits us? |
|---|---|---|---|---|
| `unlocked` (default) | ❌ | ✅ | ❌ | ❌ a call to a locked phone can't read the token |
| `unlocked_this_device` | ❌ | ✅ | ❌ | ❌ same, and not in backups |
| **`first_unlock`** | ❌ | ✅ | ✅ | ✅ **our choice** |
| `first_unlock_this_device` | ❌ | ✅ | ✅ | ✅ also OK — but not restored to a new iPhone from backup |
| `passcode` | ❌ | ✅ only if a passcode is set | ❌ | ❌ too strict |

- **`first_unlock`** = "after the user unlocked the phone **once** since it was
  turned on". That covers the pocket case, and it's what Apple recommends for
  background tasks.
- The only time it can't read: right after a reboot, before the first unlock.
  Then the user isn't using the phone anyway.
- **Android** has no such levels: `encryptedSharedPreferences: true` stores the
  values encrypted with a Keystore key, readable whenever the app runs.

## 5. Try it

```bash
flutter test                                    # 35 tests → All tests passed!
flutter run --flavor dev -t lib/main_dev.dart
```

1. Sign in (demo) → Home → **Call GET /users/me (needs a token)**.
2. The server answers 401, the interceptor finds no tokens → you're sent
   back to **Login**, with a snackbar **❌ 401 Session expired**.
3. **Check server (GET /health)** still works — it's public, no token needed.

The refresh path (401 → refresh → retry) needs a real token pair, which
arrives with the real login in **Step 3**. Until then it's proven by the 9
interceptor tests.

## 6. Check yourself

1. Why does a wrong password on login **not** trigger a refresh?
2. 3 requests get 401 together. How many refresh calls happen, and why does
   it matter for **our** backend?
3. The refresh call times out in a lift. Is the user logged out? Why?
4. Why does the refresh go through a **different** Dio?
5. Why `first_unlock` on iOS?

<details><summary>Answers</summary>

1. `/auth/login` is in `ApiEndPoint.publicEndpoints`, so `onError` passes the
   401 on without refreshing. (The real server answers 401 for a wrong
   password.)
2. One. `QueuedInterceptor` handles them one by one; requests 2 and 3 see the
   token already changed and just retry. Our refresh token is **rotated**, so
   parallel refreshes with the old one would fail → logout.
3. No. A timeout is `RefreshFailed` (no answer), not `RefreshRejected`. Tokens
   are kept; the user sees "No Internet" and can retry.
4. So a 401 on the refresh call can't come back into the same interceptor and
   loop forever.
5. So code running in the background while the phone is locked (a call to a
   killed app, Step 7) can still read the token.

</details>
