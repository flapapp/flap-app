# App Context

## App name

**FLAP** — package id `flap_app`; `MaterialApp` title and branding use **FLAP** (see `lib/main.dart`, welcome/onboarding UI).

## What the app does

FLAP is a **football-focused social product** built in Flutter with **Supabase** as the backend. It lets people **create and join pickup matches**, **organize and browse teams (“clubs”)**, **upload and browse a public video library**, and **run skill challenges** with registration, video submissions, voting, and staged lifecycle. Users have **profiles with ratings and stats**, **friends**, **in-app notifications**, optional **subscriptions** (tiered, football-themed naming), **badges**, and an **admin** surface for destructive challenge management.

## Main problem it solves

It addresses **fragmented pickup football coordination**—finding players and matches, tracking reputation, and sharing highlights—by combining **match discovery**, **team/club structure**, **video content**, and **community challenges** in one place, with **UA/EN** copy aimed at Ukrainian and English speakers.

## Target users

- **Amateur / recreational football players** who want to find matches, track performance, and see leaderboards.
- **Small teams or clubs** that want rosters, invites, and a simple competitive table (“golden boot”, stats).
- **Content-oriented users** who upload or watch football-related videos and participate in **challenges**.

## Main features

- **Authentication & onboarding**: Supabase auth; first-launch **intro** (random startup image, tap/keyboard to continue); **welcome** with Ukrainian/English language toggle; **login** and **register**.
- **Profile completion gate**: Until `profiles.profile_complete` is satisfied, users are steered to **profile creation** (`ProfileCompletionGuard`); fields include name, surname, phone, city, age, position, experience, avatar (image picker + Supabase storage).
- **Mode hub (“home”)**: **Mode selection** screen with personalized greeting, rating/match count summary, **activity/news** pulled from Supabase (matches, videos, teams), and entry points into major areas via `AutoRoute` (`MatchesRoute`, `TeamHubRoute`, `VideoMainRoute`).
- **Matches**: Tabbed **matches** experience—find matches, my matches, history, and **ratings**; filters (city, level, time, sort, search); **create match**; **match details** and **match management** (tabs/depth in code); **post-match rating** (`MatchRatingScreen`); sharing via `share_plus`; player chips/avatars link to **player profile**.
- **Ratings**: Global/player rating concepts via `RatingService`, criteria on `PlayerRating` in the match model, and dedicated **ratings** UI (including `RatingsScreen` / tabs inside matches).
- **Teams / clubs**: **Team hub** with leaderboard stream, “my teams”, create team (modal flow to `TeamCreateScreen`), **team details**, invites, stats-derived presentation (e.g. golden boot section).
- **Video library & upload**: **Video main** hub with library stream, filters (city, category, rating thresholds, sort modes), separation of general vs challenge-linked videos, **video upload**, and **video playback** (`video_player` / `chewie`); comments and ratings are supported in the videos domain/repository layer.
- **Challenges**: **Challenge list** with status/type/city/search filters; **challenge create**; **challenge details** with participation, submissions, voting stages; **challenge video player** for submission playback and voting UX; repository supports stages described in repo docs (`CHALLENGE_SYSTEM_README.md` aligns with code concepts).
- **Friends**: **Friends** screen with search, requests, accept/reject/remove (backed by `FriendsRepository` / BLoC).
- **Notifications**: **Notifications** screen and `NotificationService` initialization; notification model includes actionable URLs (e.g. profile, friends, video hub, challenge details, match flows).
- **Profile (current user)**: **App profile** (`profile_screen_new.dart`, routed as `AppProfileRoute`)—legacy profile map stream, badges, friends count, teams/invites, match-derived W/D/L stats, optional **donation** dialog (Privat24 links, dismiss persisted in settings), navigation to **subscription**, **badge store**, team flows, **stats** screen.
- **Profile settings** and **stats** as dedicated routes.
- **Player profile** (other users): `PlayerProfileRoute` with id/name args.
- **Subscriptions**: Tiers **free**, **europa**, **champions** with status (active, trial, expired, cancelled); **Champions trial** can be granted on bootstrap when a user exists (`main.dart`); `SubscriptionScreen` with BLoC (load, purchase, trial, cancel) — **implementation is server/repository driven** (not audited here for real payment provider wiring).
- **Badges**: Badge repository with default initialization on startup; **badge store** UI presented from profile flow.
- **Admin**: **Admin** route with BLoC; primary exposed action in UI is **delete all challenges** (high-impact, role/trust assumptions live in backend policies—not fully visible in Flutter-only review).

## Core screens

- **IntroVideoScreen** — First launch only; full-screen branded imagery; dismiss to welcome or mode hub if already signed in.
- **WelcomeScreen** — Marketing-style entry, language selection, paths to login/register.
- **LoginScreen / RegisterScreen** — Credential and registration flows.
- **ProfileCreationScreen** — Required profile data and avatar; editing mode supported via args.
- **ModeSelectionScreen** — Signed-in “home”: greeting, stats teaser, news cards, navigation into matches/teams/video modes.
- **MatchesScreen** — Four-tab matches hub (find / mine / history / ratings).
- **CreateMatchScreen** — Match creation.
- **MatchDetailsScreen / MatchManagementScreen** — Deep match views and organizer/participant tooling.
- **MatchRatingScreen** — Ratings after matches.
- **RatingsScreen** — Standalone ratings route (also related tab content in matches).
- **TeamHubScreen** — Clubs leaderboard, my teams, FAB speed-dial for mode shortcuts and create team.
- **TeamDetailsScreen / TeamCreateScreen** (create is pushed manually, not in `app_router` table) — Team lifecycle UI.
- **VideoMainScreen** — Video + challenge discovery hub (large composite UI).
- **VideoUploadScreen** — Upload; optional challenge context args.
- **VideoPlayerScreen** (and related) — In-app playback.
- **ChallengeListScreen / ChallengeCreateScreen / ChallengeDetailsScreen** — Challenge CRUD and participation.
- **ChallengeVideoPlayerScreen** — Challenge submission playback/voting (pushed as a normal `MaterialPageRoute` from flows, not a top-level `AutoRoute` entry).
- **FriendsScreen** — Social graph.
- **NotificationsScreen** — In-app notification list and actions.
- **Profile screen (routed)** — `ProfileScreen` in `profile_screen_new.dart` for the signed-in user profile hub.
- **ProfileSettingsScreen / StatsScreen** — Settings and statistics.
- **PlayerProfileScreen** — Other users’ profiles.
- **AdminScreen** — Administrative tools (challenge deletion).
- **SubscriptionScreen** — Paywall/subscription management (pushed from profile, not listed as its own `AutoRoute` in `app_router.dart`).

## User flow

1. **First open**: `IntroVideoScreen` → tap/key → **Welcome** (guest) or **ModeSelection** (if already authenticated).
2. **Guest**: Welcome → **Register** or **Login** → on success, if profile incomplete → **ProfileCreation**; else → **ModeSelection**.
3. **Mode hub**: From **ModeSelection**, user opens **Matches**, **Team hub**, or **Video** via explicit routing (`context.pushRoute` / guards allow stack navigation).
4. **Matches**: User browses **Find** tab with filters, joins or follows match flows → **Match details** / **Management**; tracks **My matches** and **History**; checks **Ratings** tab; may **Create match** from FAB/speed-dial patterns.
5. **Teams**: **Team hub** shows leaderboard and personal teams → **Create team** or open **Team details**; invites and stats appear in profile/hub contexts.
6. **Videos & challenges**: **Video main** to browse library (filters, “my” content toggles, challenge vs general) → **Upload** or open **Video player**; challenge-specific flows go to **Challenge details** / **Challenge video player** and voting where applicable.
7. **Social**: **Friends** for requests; **Notifications** deep-link style actions toward profile, friends, videos, challenges, matches.
8. **Profile**: User opens **Profile** for self, edits via **Profile settings** or **Profile creation** (editing), views **Stats**, **Subscriptions**, **Badges store**, donation prompt (dismissible), sign-out helpers.

## Current UX observations

**What works well**

- Clear **football metaphors** (clubs, matches, challenges, “Champions” subscription naming) consistent with the domain.
- **Bilingual** support is first-class in many flows (`I18n` keys + `I18n.inline` for screen-local copy).
- **Guards** enforce a sensible **auth + profile completion** order before main features.
- **Mode speed dial** and repeated **AppBar patterns** give a recognizable rhythm between major hubs (matches, teams, video).

**What is confusing**

- **Two navigation styles** coexist: declarative **`auto_route`** routes vs many **`Navigator.pushNamed('/...')`** calls. The router file lists **flat `AutoRoute` entries without explicit path names** matching those strings—**behavior depends on AutoRoute’s integration with the root navigator**; this is a **consistency and predictability risk** for users and developers.
- **“Mode” vs “home”** naming: code and UI mix **ModeSelection**, “clubs”, “teams”, and speed-dial “modes”—the mental model may need clearer product language.
- **Admin** capability is powerful (delete all challenges) with a minimal screen—**appropriate gating** is critical and not obvious from Flutter UI alone.

**What feels outdated or inconsistent**

- **Global theme** uses Material 3 seed green and **Roboto via Google Fonts**, while individual screens often **hard-code** backgrounds (`Color(0xFF1e7d32)`, `0xFF04070f`, `0xFF0f0f23)`, etc.), producing **multiple visual systems**.
- **Very large screen files** (e.g. matches and video hubs) suggest **UI logic, layout, and data fetching intertwined**, which usually hurts consistency and iteration speed for design refreshes.
- **Legacy / duplicate artifacts**: `lib/features/home/.../main_screen.dart` composes older **VideosScreen** / **ChallengesScreen** tabs but **is not referenced** by `app_router.dart` (dead entrypoint). A separate **`profile_screen.dart`** exists alongside **`profile_screen_new.dart`** (the routed implementation), increasing confusion for maintainers.

## Design gaps

**UI issues (spacing, hierarchy, colors, etc.)**

- **No single design token layer** visible: repeated magic colors and one-off gradients instead of a shared semantic palette (primary surface, elevated card, danger, etc.).
- **AppBar theme** in `ThemeData` assumes **white foreground on transparent bars**, which **breaks** on screens that do not use dark hero backgrounds.
- **Emoji and mixed typographic treatments** in titles (e.g. challenge list) may clash with a cohesive brand system.

**UX issues (navigation, clarity, friction, etc.)**

- **Hub-and-spoke** navigation across three major modes without a persistent **tab bar** or shell—users rely on **speed dials**, **named routes**, and **back stack**, which can feel **disorienting**.
- **Profile completion** is mandatory for most routes but **ModeSelection** is still a **hub**—ensure users always understand **why** they are blocked and **what** to do next (inferred need; copy exists in guards indirectly).
- **Notification actions** encode string URLs like `/profile`—must stay in sync with actual navigation; risk of **broken taps** if named routes are not wired.

## Desired brand feeling (inferred)

- **Energetic / sporty** — football imagery, challenges, leaderboards.
- **Social** — friends, teams, comments, sharing.
- **Modern** — Material 3 baseline, gradients, dark hubs.
- **Grounded / grassroots** — pickup matches, cities, donation toward real-world support (Privat24).
- **Bilingual community-oriented** — Ukrainian and English parity in many strings.

## UI patterns currently used

- **buttons**: `ElevatedButton`, `TextButton`, `IconButton`, custom **gradient FAB** in `ModeSpeedDial`, `InkWell` on branded app bar titles.
- **cards**: `Container`/`DecoratedBox` with borders and gradients rather than a single `Card` style; list tiles and custom rows in hubs.
- **lists**: `ListView`, `StreamBuilder`/`FutureBuilder` for Supabase-driven data; heavy use of scroll views with manual sections.
- **forms**: `Form`/`TextFormField` on auth and profile creation; city autocomplete widget; filters as chips/dropdowns.
- **navigation type**: **`MaterialApp.router`** with **`auto_route`** (`AppRouter`) plus **imperative** `Navigator.push`, **`Navigator.pushNamed`**, and **`context.pushRoute`** in places like `ModeSelectionScreen`.

## Technical overview

**Flutter structure summary**

- **`lib/features/<feature>/`** — feature modules with `data`, `domain`, `presentation` (screens, blocs) for auth, admin, badges, challenges, friends, matches, notifications, onboarding, profile, subscription, teams, videos.
- **`lib/core/`** — router, guards, Supabase config, auth/profile contexts, storage helpers, shared options.
- **`lib/models/`** — shared models (`match`, `challenge`, `submission`, `app_team`, `team_stats`, `notification`, `subscription`, etc.).
- **`lib/widgets/`** — reusable UI (avatars, chips, rating display, video preview, city field, speed dial).
- **`lib/utils/`** — `i18n`, `app_navigator` (global key), catalogs.
- **`supabase/migrations/`** — SQL schema (e.g. library videos) backing features.

**State management used**

- **`flutter_bloc`** for **Auth**, **Teams**, **Admin**, **Friends**, **Notifications**, **Challenges**, **Videos**, **Subscription**, **Badge store** (providers wired in `main.dart` or locally per screen).
- Many screens use **`StatefulWidget` + `setState`** with **`StreamBuilder`** / futures and direct **`RepositoryProvider`** reads.

**Important packages**

- **`supabase_flutter`** — backend/auth/realtime/data.
- **`auto_route`** — route generation and guards.
- **`flutter_bloc`**, **`equatable`** — structured state.
- **`google_fonts`** — typography overlay on theme.
- **`video_player`**, **`chewie`**, **`video_thumbnail`**, **`wakelock_plus`** — media.
- **`image_picker`**, **`path_provider`** — media capture/storage paths.
- **`share_plus`**, **`url_launcher`** — share and external links.
- **`shared_preferences`** — first-launch flag for intro.
- **`json_annotation` / `json_serializable`** — serialization where generated models exist.

**Responsiveness status**

- No dedicated **`responsive_framework`** or documented breakpoint system found; layouts appear **mobile-first** with standard `Scaffold`/`SingleChildScrollView` patterns. **Tablet/desktop polish is not evident** from structure alone.

**Theming approach**

- **Base `ThemeData`** from `ColorScheme.fromSeed(seedColor: Color(0xFF4caf50))`, **Material 3**, **transparent AppBar** with white icon/title styling globally.
- **Per-screen overrides** dominate actual appearance (dark greens, near-black blues, custom gradients).

## Missing pieces

- **features that seem incomplete or legacy**
  - **`MainScreen`** under `features/home/` appears **unwired** to the router—likely superseded by **VideoMainScreen** and separate challenge routes.
  - **Duplicate profile UI** (`profile_screen.dart` vs **`profile_screen_new.dart`**)—risk of editing the wrong file.
  - **Subscription/payment**: UI and repository exist; **end-to-end payment provider integration** is not described in Flutter code reviewed (treat as **verify in backend/business**).
- **UX gaps**
  - **Unified navigation model** (replace or correctly bridge `pushNamed` with `auto_route`) to avoid **dead ends** and ease notification deep links.
  - **Discoverability** of challenges from matches/teams (and vice versa) relies on user exploration of hubs—no single “home shell” in the router.
- **design inconsistencies**
  - Multiple **background palettes** and **AppBar** treatments vs global theme.
  - Mix of **i18n key-based** and **inline bilingual** strings—harder for designers and translators to own copy in one place.

---

*Document generated from static analysis of the repository. Items marked as risks or “verify” should be confirmed in runtime builds and Supabase policies. No UI redesign is prescribed here.*
