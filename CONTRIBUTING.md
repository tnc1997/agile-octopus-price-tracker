# Contributing

Thanks for contributing to Price Tracker for Agile Octopus. This document explains
how the app is laid out, how to set up a development environment, the conventions
its widgets/services/tests follow, and how a change gets from a local branch to a
tagged release.

See [README.md](README.md) first for a tour of what the app does and how its pieces
fit together (with diagrams) — this document is about *contributing* to it, not
about its behavior.

## Contents

- [Development Setup](#development-setup)
- [Continuous Integration](#continuous-integration)
- [Project Layout](#project-layout)
- [Architecture and Conventions](#architecture-and-conventions)
  - [Screens and Widgets](#screens-and-widgets)
  - [Reading and Writing Preferences](#reading-and-writing-preferences)
  - [Providers and Dependency Injection](#providers-and-dependency-injection)
  - [Adding a Route](#adding-a-route)
  - [Doc Comments](#doc-comments)
- [Testing](#testing)
- [Datasets](#datasets)
  - [Agile Octopus price data](#agile-octopus-price-data)
  - [NESO generation data](#neso-generation-data)
- [Price forecast model](#price-forecast-model)
  - [Dependencies](#dependencies)
  - [Training](#training)
  - [Export to ONNX](#export-to-onnx)
- [Commit Messages and Pull Requests](#commit-messages-and-pull-requests)
- [Releasing](#releasing)

## Development Setup

The app targets the Flutter SDK range declared in `pubspec.yaml` (`sdk: ^3.0.0`). Two
routed files (`lib/common/shell_route.dart`, `lib/welcome/welcome_route.dart`) are
backed by generated `*.g.dart` counterparts produced by `go_router_builder`, so a
fresh checkout needs one code-generation pass before the app will build.

```shell
# Fetch dependencies.
flutter pub get

# Generate the go_router *.g.dart files (needed after a fresh clone, and again
# whenever you add or change a @TypedGoRoute/@TypedShellRoute annotation).
dart run build_runner build --delete-conflicting-outputs

# Run the app.
flutter run

# Format every file (the repository is fully `dart format`-clean).
dart format .

# Static analysis. Must be clean before you open a pull request.
flutter analyze

# Run the test suite.
flutter test
```

Analysis is configured in `analysis_options.yaml`: the
`package:flutter_lints/flutter.yaml` recommended set plus the `directives_ordering`
lint, so keep import/export directives alphabetically ordered within each of Dart's
conventional groups (`dart:`, then `package:`, then relative imports).

Before pushing, the bar is: **`dart format .` makes no changes, `flutter analyze`
reports no issues, and `flutter test` passes.** These same three checks run
automatically on every pull request (see [Continuous Integration](#continuous-integration)),
but running them locally first keeps the feedback loop fast.

The `assets/price_forecast_model.onnx` file the app bundles at build time is
committed to the repository, so the steps above are all you need for ordinary app
development. You only need Python and the [Datasets](#datasets)/
[Price forecast model](#price-forecast-model) pipeline below if you are changing the
forecasting model itself or the data it trains on.

## Continuous Integration

Every pull request targeting `main` runs the workflow in
`.github/workflows/pull_request.yml`, which checks out the code and runs three
independent jobs, each mirroring one of the local checks above:

1. **Format** — `dart format --output=none --set-exit-if-changed .`, which fails
   if any file is not formatted.
2. **Analyze** — `flutter analyze --fatal-infos`, which fails on any analyzer
   issue, including info-level lints such as `directives_ordering`.
3. **Test** — `flutter test`, which fails if any test does not pass.

All three must pass before a pull request can be merged, so running them
locally first (see [Development Setup](#development-setup)) is the quickest way
to avoid a red build. This workflow is separate from
`.github/workflows/release.yml`, which only runs when a `v*` tag is pushed — see
[Releasing](#releasing).

## Project Layout

`lib/` is organized **by feature**, mirroring the three tabs the app's shell
presents plus the cross-cutting pieces they share:

```
lib/
├── main.dart      # Providers, theming, router, GSP/tariff constants shared app-wide
├── common/         # Shell scaffold (tab bar / nav rail), shared widgets, functions, constants
├── forecast/        # ForecastService, NesoApiClient, PriceForecastModelService — no UI
├── home/             # Home screen and everything only it uses
├── history/           # History screen and everything only it uses
├── settings/          # Settings screen, its forms, and everything only it uses
└── welcome/           # First-run onboarding screen
```

- A file belongs in a feature directory (`home/`, `history/`, `settings/`,
  `welcome/`) if only that feature's screen uses it. It belongs in `common/`
  only once a **second** feature needs it too — don't pre-emptively generalize a
  widget into `common/` before it has a second caller.
- `forecast/` is the one non-UI feature directory: it holds the `ForecastService`,
  the handwritten `NesoApiClient`, and `PriceForecastModelService`, none of which
  import `package:flutter/material.dart`. Keep it that way — forecasting logic
  should stay testable without pumping a widget tree.
- `test/` mirrors `lib/` exactly, directory for directory and file for file (e.g.
  `lib/home/historical_charge_chart_card.dart` ↔
  `test/home/historical_charge_chart_card_test.dart`). When you add a file under
  `lib/`, its test goes at the matching path under `test/`. `test/helpers.dart` is
  the one exception — shared test scaffolding with no `lib/` counterpart (see
  [Testing](#testing)).
- Two features intentionally duplicate similarly named widgets rather than
  sharing them: `home/historical_charge_chart.dart` and
  `history/historical_charge_chart.dart` (and their `_card` counterparts) look
  alike but serve different screens with different data (forecast-aware vs.
  date-range-aware). Keep them separate rather than merging them into one
  configurable widget unless a change would otherwise need to touch both in
  lockstep.

## Architecture and Conventions

### Screens and Widgets

- Each screen (`HomeScreen`, `HistoryScreen`, `SettingsScreen`, `WelcomeScreen`) is
  a `StatefulWidget` (or `StatelessWidget`, for `SettingsScreen`/`WelcomeScreen`,
  which delegates their state to the form-card widgets they compose) that owns the
  data it fetches and hands it down to small, focused child widgets — a
  `HistoricalChargeChartCard`, a `HistoricalChargeSummary`, a
  `HistoricalChargeWindowWrap`, and so on. Prefer this shape for a new
  screen/feature: one stateful "controller" widget that fetches data in
  `initState`, plus several stateless presentational widgets underneath it that
  take that data as constructor parameters.
- Widgets read their dependencies through `context.read<T>()` (once, in
  `initState`, for values that don't change for the widget's lifetime) or
  `context.watch<T>()` (in `build`, for values — like `ForecastService?` — whose
  *presence* can flip from `null` to non-`null` and should trigger a rebuild). See
  `HomeScreen._HomeScreenState` for both patterns side by side.
- Asynchronous data is held as a `Future<T>` field resolved once in `initState`
  and rendered with `FutureBuilder`, **or** resolved into a nullable field via
  `.then(...)`/`setState` when the screen needs to rebuild another state around it
  mid-flight (e.g. `HistoryScreen`'s `_historicalCharges`, which needs a
  generation counter to guard against a stale, slow request overwriting a newer
  one — see `_HistoryScreenState._load`). Prefer `FutureBuilder` unless you have
  a concrete reason (like that guard) to manage the `setState` calls by hand.
- Constructor parameters, named parameters in a method signature, and each
  parameter's own line: this codebase consistently puts **one parameter per
  line**, trailing comma included, even for calls that would fit on one line
  (`dart format` will not collapse them because the trailing comma is present —
  this is deliberate, not an oversight). Match this in new code; it keeps diffs
  small when a call gains or loses a single parameter.

### Reading and Writing Preferences

All persisted settings go through `SharedPreferencesAsync` (from
`package:shared_preferences`), accessed via small helper functions in
`lib/common/functions.dart` (`getColorStops`, `getHoursBelowThreshold`,
`getTariffComparisonRate`, `getImportProductCodeAndImportTariffCode`,
`getGridSupplyPointGroupId`, and their `set*`/`save*` counterparts). Add a new
preference the same way:

1. Pick a `snake_case` key and add a `get*`/`set*` (or `save*`) pair of functions
   to `lib/common/functions.dart`, following the existing functions' pattern of
   falling back to a sensible built-in default when the key is unset.
2. Read it once in the owning screen's `initState` (see the existing `_colorStops`,
   `_hoursBelowThreshold`, `_tariffComparisonRate` fields on `HomeScreen`) rather
   than re-reading it from every child widget that needs it.
3. If the preference gates onboarding completion the way
   `grid_supply_point_group_id` does, remember that `main.dart`'s router
   `redirect` checks `preferences.containsKey(...)` on **that specific key** to
   decide whether to send the user to `/welcome` — a new gating preference needs
   the same treatment there.

### Providers and Dependency Injection

`lib/main.dart` wires every app-wide dependency through a single `MultiProvider`.
A new dependency that should be available anywhere in the widget tree is added
there, following the existing shape:

- A plain, synchronous dependency (an API client, the preferences store) is a
  `Provider<T>`.
- A dependency that must load asynchronously before it's usable (like the ONNX
  model) is a `FutureProvider<T?>` with `initialData: null` and `lazy: false`, so
  loading starts immediately at app start-up rather than waiting for the first
  widget that reads it; consumers read `T?` and treat `null` as "still loading".
- A dependency composed of one or two others — like `ForecastService?`, built
  from `NesoApiClient` and `PriceForecastModelService?` — is a
  `ProxyProvider2<A, B, T?>` (or `ProxyProvider`/`ProxyProviderN` for other
  arities) whose `update` callback returns `null` while any input it depends on
  is still `null`.

### Adding a Route

Routes are declared with `go_router`'s typed-route annotations
(`@TypedGoRoute`/`@TypedShellRoute`) in `lib/common/shell_route.dart` (for routes
inside the persistent tab shell) or `lib/welcome/welcome_route.dart` (for routes
outside it, i.e., before onboarding is complete). To add a new route inside the
shell:

1. Add a `TypedGoRoute<YourRoute>(path: '/your-path')` entry to the
   `@TypedShellRoute<ShellRoute>(routes: [...])` list in `shell_route.dart`.
2. Add the matching `class YourRoute extends GoRouteData with $YourRoute` with a
   `build` method returning your screen, following `HomeRoute`/`HistoryRoute`/
   `SettingsRoute`.
3. Re-run code generation (`dart run build_runner build
   --delete-conflicting-outputs`) so `shell_route.g.dart` picks up the `$YourRoute`
   mixin — the app won't compile until you do.
4. Add the new tab/destination to `ShellBottomNavigationBar` and
   `ShellNavigationRail` if it should appear in the persistent navigation (a route
   that's reachable but not shown in the tab bar, like a detail screen pushed from
   another screen, can skip this).

### Doc Comments

Almost every public class, field and method in `lib/` carries a `///` doc comment
that explains **why**, not just what — the reasoning behind a design choice, a
non-obvious invariant, or a gotcha a future reader would otherwise have to
rediscover (see `PriceForecastModelService`, `ForecastCharge`, or `HomeScreen`'s
field comments for the standard this codebase holds itself to). When you add a
public symbol whose purpose, ordering, unit, or timezone/nullability handling
isn't obvious from its name and type alone, document *why* it's built that way,
referencing the specific field/script/constant it must stay in sync with (e.g.
`PriceForecastModelService._gspCodes`'s comment pointing at the training script's
`GSP_CODES`). A comment that only restates the signature in prose is not useful
here — prefer none over that.

## Testing

Every widget, service and function has a test file whose path mirrors its source
file under `test/` (see [Project Layout](#project-layout)). Tests use
`package:flutter_test`, structured as a `group` named after the widget/class under
test containing one `testWidgets`/`test` per behavior, with a descriptive,
lower-case sentence as the description (e.g. `'computes hours below as a fraction
of an hour when only part of a slot qualifies'` — describe the *behavior*, not
the input).

`test/helpers.dart` holds the shared scaffolding reused across test files, so
check there before writing a new setup:

- `inMemoryPreferences`/`throwingPreferences` — an in-memory
  `SharedPreferencesAsync` for tests that read or write settings, including one
  that can be made to throw on specific keys to exercise a failure path.
- `historicalCharge`/`historicalChargeRelativeToNow` — fixed-epoch or
  now-relative `HistoricalCharge` builders, so a test doesn't have to hand-build
  `DateTime`s (use the fixed-epoch builder unless the widget under test actually
  splits charges into today/yesterday/upcoming relative to `DateTime.now()`, in
  which case use the relative one).
- `materialApp`/`bareMaterialApp`/`materialAppRouter`/`testRouter` — the minimal
  ancestor widget tree a widget needs (a `Scaffold`, a live `GoRouter`, or
  neither), so pick the narrowest one your widget actually requires.
- `pathRoutedClient` — a fake `http.Client` that dispatches by `Uri.path`, for a
  widget or service that calls more than one endpoint through a single API
  client.
- `historicalChargeListResponse`/`gridSupplyPointListResponse`/
  `productsListResponse`/`productResponse` — canned JSON fixtures for the
  Octopus Energy API responses this app reads.

When you add a new fixture or ancestor-widget helper that a second test file
would also need, add it to `test/helpers.dart` rather than duplicating it.

Run the full suite with:

```shell
flutter test
```

## Datasets

The `script/data/` directory contains CSV datasets that the app depends on. These files are not committed to the repository because of their size, so you will need to generate them locally before building the app.

Both collection scripts use only the Python standard library — no additional packages are required. Python 3.7 or later is required (the scripts use `from __future__ import annotations`, so the modern type-hint syntax they contain works without a newer interpreter).

The model scripts described under [Price forecast model](#price-forecast-model) below have heavier requirements: a modern Python (3.9 or later) and the third-party packages listed in `requirements.txt`.

### Prerequisites

Verify that Python 3.7 or later is available on your system:

```shell
python3 --version
```

### Agile Octopus price data

This script fetches every half-hour unit rate from 1 January 2020 to 31 December 2024 from the Octopus Energy API. It queries all known Agile product codes across all 14 Grid Supply Point (GSP) regions in Great Britain, averages the rates across regions for each half-hour slot, and writes the result to `script/data/agile_octopus_price_data.csv`.

```shell
python3 script/collect_agile_octopus_price_data.py
```

The script makes a large number of paginated API requests and may take several minutes to complete. Progress is logged to the terminal as it runs.

No authentication is required — the Octopus Energy API endpoint used here is publicly accessible.

### NESO generation data

This script fetches two datasets published by the National Energy System Operator (NESO) covering the same date range and merges them into a single file at `script/data/neso_generation_data.csv`:

- **Embedded wind and solar forecasts** — downloaded as yearly archive CSV files from the NESO data portal. These cover smaller generators connected to the local distribution network, whose output is estimated rather than directly metered.
- **Historic day-ahead wind forecasts** — queried via SQL against the NESO datastore API. These cover large wind farms connected to the national transmission grid.

```shell
python3 script/collect_neso_generation_data.py
```

Progress is logged to the terminal as it runs.

## Price forecast model

Octopus publishes Agile unit rates only about a day ahead, but the app shows a seven-day forecast. To fill the gap between the last published slot and the end of that window, the app predicts a plausible rate for each future half-hour slot from the conditions expected at the time — chiefly how much wind and solar generation the NESO forecasts. Earlier versions answered that question with a seasonal average lookup table (`assets/seasonal_average_lookup.json`, built by `script/build_seasonal_average_lookup.py`), which can only ever return the historical average for a bucket of conditions. The model described here replaces that lookup with a learned, continuous mapping from conditions to price, so it can interpolate between conditions and weigh features against one another rather than reading back a bucket average.

The model runs **on device**: the app performs inference locally through [onnxruntime](https://onnxruntime.ai/) rather than calling out to a server, so forecasting works offline and sends nothing about the user anywhere. That is why the shipped model is an [ONNX](https://onnx.ai/) file — a portable, framework-independent representation of the trained model that onnxruntime can load on every platform the app targets.

Producing that file is a two-step pipeline that builds on the datasets above: **training**, which fits the model, and **export to ONNX**, which converts the fitted model into the portable format and verifies the conversion is faithful. Run the two [dataset collection scripts](#datasets) first — the pipeline reads the CSVs they produce — then run the two steps below in order. Only the final `assets/price_forecast_model.onnx` is committed to the repository (it is bundled with the app as a Flutter asset); the intermediate model files that training produces are treated like the datasets and left in the git-ignored `script/data/` directory.

If you change the model's feature set, retrain it, or otherwise touch this pipeline, remember that `lib/forecast/price_forecast_model_service.dart` hard-codes several of the model's training-time contracts on the Dart side (the `_gspCodes` ordinal encoding, the `_peakHourStart`/`_peakHourEnd` window, and the feature order in `getFeatures`) because the ONNX runtime doesn't surface the model's embedded metadata back to the app. Update those constants — and their doc comments pointing at the training script — in lockstep with any change to `script/train_price_forecast_model.py`'s `GSP_CODES`, peak-hour constants, or `FEATURES` list; a silent mismatch feeds the model the wrong inputs with no error.

### Dependencies

Unlike the collection scripts, which use only the Python standard library, these two steps depend on third-party packages (XGBoost, scikit-learn, and the ONNX toolchain — see `requirements.txt` for the full list and the reasons some versions are pinned). Install them into a [virtual environment](https://docs.python.org/3/library/venv.html) — a self-contained Python installation that keeps these packages isolated from the rest of your system:

```shell
python3 -m venv .venv
.venv/bin/pip install -r requirements.txt
```

This creates the environment in a `.venv/` directory (git-ignored) and installs the dependencies into it. The commands below invoke Python from inside that environment (`.venv/bin/python`), so the packages are available without affecting any other Python you have installed. You only need to create and populate the environment once; reuse it for later runs.

### Training

```shell
.venv/bin/python script/train_price_forecast_model.py
```

This script fits a regularized [XGBoost](https://xgboost.readthedocs.io/) regressor — a model made of many small decision trees, each correcting the errors of the ones before it. It joins the price and generation datasets on their shared settlement date and period (aligning the UTC price timestamps to the UK local clock time the NESO data uses), derives the model's input features for each slot (the half-hour of the day, whether it is a weekend, whether it falls in the evening peak, the month, the GSP region, and the three wind and solar generation forecasts), and trains the model to predict `value_inc_vat`, the unit rate in pence per kWh including VAT.

The data is split chronologically — the earliest slots train the model, a middle slice tunes it, and the most recent slots are held back to test it — so the reported accuracy reflects how well the model forecasts slots it has never seen, rather than being flattered by peeking at neighboring future slots. Training stops early once accuracy on the tuning slice stops improving. The script logs its progress, the relative importance of each feature, and the final accuracy metrics (RMSE, MAE, and R²) measured on the held-out test slice; it runs in well under a minute.

It writes the trained model to `script/data/` in two forms: `price_forecast_model.json`, XGBoost's own portable format (with the training details — feature order, encodings, and metrics — embedded in it), and `price_forecast_model.joblib`, the fitted scikit-learn object pickled to disk. Both describe the same model; the export step uses the first and cross-checks it against the second.

### Export to ONNX

```shell
.venv/bin/python script/export_price_forecast_model.py
```

This script converts the trained model into the ONNX format the app loads. Crucially, it **verifies that the conversion is faithful before writing anything**: it feeds a large batch of inputs — constructed to exercise every decision branch in the trees — through both the original Python model and the freshly converted ONNX graph, and compares the two sets of predictions. If they ever diverge by more than a negligible rounding margin, the script reports the discrepancy and aborts without writing a file, so a broken conversion can never silently ship. As a further safeguard, it also confirms the model's two on-disk forms (the `.json` and the `.joblib`) agree with each other. It copies the training details into the ONNX file's metadata as well, so the exported model is self-describing, and the app can read back the exact feature order it must supply.

Only when every check passes does it write `assets/price_forecast_model.onnx`. Because that file is the committed artifact the app ships, **re-run this step whenever you retrain the model** so the asset stays in sync with the model it was produced from. The export and its verification should be complete in a second or two.

## Commit Messages and Pull Requests

Commits follow [Conventional Commits](https://www.conventionalcommits.org/) with a
scope naming the feature directory the change touches:

```
<type>(<scope>): <description in the imperative, lower case>
```

- **Types** in use, with their usual Conventional Commits meaning:
  - `feat` — new user-facing capability (a new card, a new setting, a new
    behavior on an existing screen).
  - `fix` — a bug fix.
  - `refactor` — restructuring without changing behavior. This is the most
    common type in the repository's history — this codebase is iterated on in
    small, frequent restructurings rather than large rewrites, so prefer several
    small `refactor` commits over one big one.
  - `build` — dependency and build-tooling changes (`build(deps): bump x from
    a to b`, matching the automated dependency-bump commits already in the
    history).
  - `chore` — routine maintenance that isn't a dependency bump (housekeeping,
    config tweaks).
  - `style` — formatting-only changes with no code meaning change.
  - `docs` — documentation only.
  - `test` — adding or updating tests without changing production behavior.
  - `ci` — changes to `.github/workflows/`.
- **Scope** is the feature directory the change lives in: `home`, `history`,
  `settings`, `welcome`, `common`, `forecast`. Omit the scope for a change that
  spans several directories or doesn't belong to one feature.
- **Breaking changes** use the `!` marker, e.g. `refactor!: ...`, though this is
  rare in an application (as opposed to a published package) — it generally
  signals a change to a persisted preference's shape that isn't backward
  compatible with data an existing installation already has on disk.

For pull requests:

- Branch from `main`; PRs target `main`.
- Run `dart format .`, `flutter analyze`, and `flutter test` locally before
  opening the PR. These are enforced automatically by the
  [pull request workflow](#continuous-integration), but running them locally
  first keeps the feedback loop fast.
- Keep the PR focused on one change; write the title in the same Conventional
  Commit style so it reads well once squashed or merged.
- `CHANGELOG.md` is regenerated from Conventional Commit history with
  [git-cliff](https://git-cliff.org/) as part of [cutting a release](#releasing),
  not on every PR — you don't need to touch it, but getting the commit `type`,
  scope, and `!` marker right is how your change will be described in it later.
- Never commit real credentials or personal data. `archive.tar.gpg` is an
  encrypted archive of signing material used only by the release workflow —
  don't add new secrets to the repository in plaintext.

## Releasing

There is no automated version-bump or tagging step — releasing is a manual,
two-part process:

1. **Bump the version and regenerate the changelog in a single commit.**
   Update `version:` in `pubspec.yaml` (`<major>.<minor>.<patch>+<build>`) and
   regenerate `CHANGELOG.md` from the Conventional Commit history since the
   last release using [git-cliff](https://git-cliff.org/):

   ```shell
   git cliff --output CHANGELOG.md --tag <version>
   ```

   Commit both changes together as `chore(release): prepare for v<version>`.
   Do not hand-edit `CHANGELOG.md` otherwise — its content is only as
   accurate as the commit messages it's generated from, which is why getting
   the `type`/scope/`!` right in [Commit Messages and Pull Requests](#commit-messages-and-pull-requests)
   matters.
2. **Tag the release commit** as `v<version>` (matching the version just set in
   `pubspec.yaml`, e.g. `v1.0.0`) and push the tag:

   ```shell
   git tag v<version>
   git push origin v<version>
   ```

Pushing a `v*` tag triggers `.github/workflows/release.yml`, which:

- Creates a GitHub release for the tag.
- Decrypts `archive.tar.gpg` (release signing material; the passphrase is a
  repository secret) and builds the Flutter Android App Bundle and
  per-ABI (arm64 and x64) Application Packages, uploading all three as release
  assets.

The other platforms this app targets (iOS, Windows, macOS, Linux, web) currently
have no equivalent automated build step in this workflow.
