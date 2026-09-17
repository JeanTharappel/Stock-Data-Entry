# Stock Data Entry

A Flutter Web data-entry app for two flat-file record types — **Dividend
Rate** and **Price Range** — originally specified as COBOL-style fixed-width
records. It runs entirely in the browser, stores records locally (survives a
reload and a browser restart), and can export back out as CSV, XLSX, or a
fixed-width TXT file that matches the original record layout byte for byte.

The design is deliberately plain: flat colours, thick borders, large text,
full-word buttons, no icons without labels, no animation. It was built for an
elderly user, but the side effect is that it's also unusually easy to read as
code — there's no styling ambiguity to untangle before you can see what a
screen actually does.

## Features

- **Two entry screens** — Dividend Rate and Price Range — switched by large
  labelled tabs, always showing which one is active.
- **Forms matching each record's fields**, each validated against the
  original field widths (company code max 10 chars, date as `DDMMYY`,
  dividend rate as 3 digits with 1 implied decimal, price values as 5
  digits).
- **Real calendar-date validation** — `31/02/26` is rejected as not a real
  date, not just as badly-formatted text. A two-digit year is windowed to a
  4-digit one (`00`–`69` → 2000s, `70`–`99` → 1900s).
- **A results table per entry screen**, sorted oldest-date-first, with EDIT
  and DELETE buttons on every row (full words, never icon-only). The same
  table, without those buttons, shows the inquiry results.
- **Delete confirmation** — a plain yes/no modal, no swipe-to-delete.
- **Inquiry tab**, with two searches. **One company**: a company code and a
  FROM and TO date shows how many dividend rates and price ranges fall in
  that range, each list opening on its own page (dividend: date and rate;
  price: date, low and high). **One month**: a month and year as `MM` and
  `YY` lists every company's dividend rates for that month — dividend records
  only. Every result page is read-only; records are added, changed and
  deleted on the entry tabs.
- **Duplicate-record warning** — saving a company code + date combination
  that already exists asks for confirmation before creating a second one.
- **Export as CSV, XLSX, or TXT**, triggered as a browser download. CSV and
  XLSX add a spelled-out date column for readability; TXT reproduces the
  original fixed-width layout exactly, padded to spec.
- **Import from CSV, XLSX, or TXT** — reads back any file the export
  wrote, so an export doubles as a backup. Every row is checked with the same
  rules as the forms; if any row is bad nothing is imported and the problem
  rows are listed. It asks before adding anything, skips records already
  saved with the same values, and never changes or deletes what is there. A
  price range file chosen on the dividend rate tab (or the other way round)
  is recognised and named.
- **Local persistent storage** (Hive, backed by the browser's IndexedDB) —
  nothing is sent to a server, nothing is lost on refresh.
- **Light/dark mode** and a **compact "fit on one page" layout** (two
  columns, smaller type), both remembered between visits.
- **Live record counts** ("YOU HAVE 4 RECORDS SAVED") on every screen.

## Architecture

If your last serious programming was COBOL or Fortran, most of what follows
will look familiar with different names. The mapping, roughly:

| What you'd call it        | What this project calls it                          |
| -------------------------- | ----------------------------------------------------- |
| Copybook / record layout   | A class in `lib/models/`, plus its field-width spec in `lib/core/record_spec.dart` |
| Indexed/keyed file (VSAM)  | A Hive "box" — an on-disk key→record store, opened once at startup |
| A validation subroutine    | The static functions in `lib/core/validators.dart`  |
| A batch print/report program | `lib/export/export_service.dart` |
| The main program driving everything | `lib/main.dart` |

The app is split into layers, and — this is the important part — **each
layer only knows about the layer below it**. The screen doesn't know how
records are stored; the storage code doesn't know what a screen looks like.
That separation is what lets you change one thing (say, add a field) without
having to trace through the whole program to find every place that assumes
the old shape.

```
main.dart
   |
   v
screens/          <- what the user sees and does
   |
   v
data/             <- read/write records, one controller per record type
   |
   v
models/           <- one class per record type ("the copybook")
   |
   v
hive_ce (library) <- the actual on-disk storage engine
```

Two things cut across all of that:

- **`core/`** — rules that don't belong to any one layer: what a valid date
  is, what a valid field value is, and the field widths themselves (taken
  straight from the original record spec, in COBOL `PIC` clause comments —
  see `lib/core/record_spec.dart`).
- **`theme/` and `widgets/`** — the visual design system. Every screen pulls
  colours, sizes, and button/field styles from one place rather than each
  screen inventing its own, the same way a shop of COBOL programs would all
  `COPY` a shared layout rather than each hard-coding column positions.

### Where "business logic" actually lives

A field's rules are **not** scattered across the form. For the Price Range
record's LOW VALUE field, for example:

1. Its width (5 digits) is declared once, in `PriceRangeSpec` (`lib/core/record_spec.dart`).
2. Its validation reads that width — it doesn't hard-code `5` again (`lib/core/validators.dart`).
3. The form field reads the same width for its on-screen hint text and its
   `maxLength` (`lib/screens/price_range_screen.dart`).
4. The fixed-width TXT export reads the same width to pad the field
   correctly (`lib/export/export_service.dart`).

Change the width in one place — `record_spec.dart` — and validation, the
form, and the export all follow. This is the single most important habit in
the codebase: **a fact is stated once, and everything else reads it from
there.** If you ever find yourself typing the same number (a width, a
column name, a colour) in two different files, that's usually a sign
something should have been read from `record_spec.dart` or `brutal_skin.dart`
instead.

### State management (Riverpod)

Dart doesn't have global `COMMON` blocks, and that's deliberate — instead,
each record type has a **controller** (`lib/data/dividend_rate_controller.dart`,
`lib/data/price_range_controller.dart`) that holds the current in-memory list
of records and is the *only* code allowed to read or write the Hive box for
that type. A screen doesn't touch storage directly; it asks the controller
to `add`, `update`, or `delete`, and the controller republishes the new list.
Every widget that displays the list is automatically rebuilt with the new
data — there's no manual "now go refresh the screen" step to remember, which
is the class of bug (stale data left on screen after an update) this pattern
exists specifically to prevent.

### Generated code

Two kinds of file end in `.g.dart` — `lib/models/dividend_rate.g.dart`,
`lib/models/price_range.g.dart`, and `lib/hive_registrar.g.dart`. These are
**not written by hand.** They're generated from the `@HiveType`/`@HiveField`
annotations in the model classes by a build tool, the way a copybook
expander might generate working-storage from a shorter source form. They're
checked into the repo (so the project builds without a build step) but
you regenerate them any time you change a model — see the demo walkthrough
below.

## Folder structure

```
lib/
  main.dart                    Entry point: opens storage, builds the app
  core/
    record_spec.dart           Field widths for both record types (the "copybook")
    ddmmyy.dart                DDMMYY date parsing/formatting/validation
    validators.dart            Field-level and cross-field validation rules
    inquiry.dart               The two inquiry search rules: one company between two dates, or one month
  models/
    dividend_rate.dart         DividendRate record class
    dividend_rate.g.dart       Generated storage adapter (do not hand-edit)
    price_range.dart           PriceRange record class
    price_range.g.dart         Generated storage adapter (do not hand-edit)
  data/
    boxes.dart                 Opens the two storage boxes at startup
    dividend_rate_controller.dart   All reads/writes for DividendRate records
    price_range_controller.dart     All reads/writes for PriceRange records
    app_settings.dart          Remembers light/dark and compact/roomy choice
    navigation.dart            Which tab is showing
  export/
    export_service.dart        Builds the CSV / XLSX / TXT file contents
    file_download.dart         Picks the right "save this file" code for the platform
    file_download_web.dart     The browser-download implementation
  import/
    import_service.dart        Reads exported CSV / XLSX / TXT files back into records
    picked_file.dart           The chosen file, and the swappable file-picker provider
    file_pick.dart             Picks the right "choose a file" code for the platform
    file_pick_web.dart         The browser file-dialog implementation
  theme/
    brutal_skin.dart           Every colour, size, and text style, as one object
    brutal_theme.dart          Wires the skin into Flutter's own widgets (calendar, scrollbars)
  widgets/
    brutal_button.dart         The button widget every screen uses
    brutal_text_field.dart     The labelled text-input widget every form uses
    brutal_table.dart          The results-table widget both screens use
    brutal_dialogs.dart        Confirm dialogs and the date-picker dialog
    brutal_blocks.dart         Panels, section headers, notice/message blocks
    ddmmyy_field.dart          The DAY/MONTH/YEAR date-entry widget
    export_section.dart        The three export buttons
    import_section.dart        The import button, its confirm step and messages
  screens/
    home_shell.dart            The outer frame: title bar, tabs, toggles
    dividend_rate_screen.dart  The Dividend Rate form + table + export
    price_range_screen.dart    The Price Range form + table + export
    entry_screen_layout.dart   Shared page layout both screens sit inside
    inquiry_screen.dart        The Inquiry tab: the company search and the month search
    inquiry_results_page.dart  The three read-only result pages they open
    record_deletion.dart       The shared "are you sure?" delete step

test/
  record_spec_test.dart        Tests for validation, date rules, fixed-width padding
  import_test.dart             Tests that every export format imports back unchanged
  app_smoke_test.dart          Tests that build the real app and interact with it

web/                           Browser shell (index.html, icons) — Flutter fills this in
.github/workflows/             Auto-builds and deploys the app to GitHub Pages
```

A rule of thumb for finding your way around: **if you're looking for what a
field is allowed to contain, look in `core/`. If you're looking for what
happens when you press a button, look in `screens/`. If you're looking for
what's actually stored, look in `models/` and `data/`.**

## Setting up on Windows

This gets a working copy of the project onto your machine, running in a
browser, ready to edit.

### 1. Install Git

Download from [git-scm.com](https://git-scm.com/download/win) and run the
installer — the defaults are fine. This is what downloads (`clone`s) the
project and lets you save (`commit`) your own changes to it later.

Confirm it worked by opening **PowerShell** (search for it in the Start
menu) and running:

```powershell
git --version
```

### 2. Install the Flutter SDK

1. Download the Windows install bundle from
   [docs.flutter.dev/get-started/install/windows](https://docs.flutter.dev/get-started/install/windows).
2. Unzip it somewhere permanent with no spaces in the path — for example
   `C:\src\flutter` (not `C:\Program Files\flutter`, and not your Downloads
   folder).
3. Add `C:\src\flutter\bin` to your `PATH`: Start menu → search "Edit the
   system environment variables" → **Environment Variables** → under
   **User variables**, select `Path` → **Edit** → **New** → paste
   `C:\src\flutter\bin`.
4. Close and reopen PowerShell (PATH changes only take effect in new
   windows), then run:

   ```powershell
   flutter --version
   ```

   If that prints a version number, it worked.

5. Run Flutter's own setup checker:

   ```powershell
   flutter doctor
   ```

   It's fine if this reports missing Android/iOS/Visual Studio tooling —
   this project only targets the web, so those aren't needed. What matters
   is that **Chrome** shows a checkmark.

### 3. Install a code editor

**VS Code** is the simplest choice:

1. Download from [code.visualstudio.com](https://code.visualstudio.com/).
2. Open it, go to the Extensions panel (the four-squares icon on the left,
   or `Ctrl+Shift+X`), search for **"Flutter"**, and install the official
   extension published by Dart Code — it pulls in Dart support
   automatically.

### 4. Install Google Chrome

If it isn't already installed: [google.com/chrome](https://www.google.com/chrome/).
Flutter runs this app *as* a Chrome window during development — there's no
separate "run" step beyond launching Chrome under Flutter's control.

### 5. Clone the repository

In PowerShell, move to wherever you'd like the project folder to live, then:

```powershell
cd E:\Code\Flutter
git clone https://github.com/<your-username>/stock_data_entry.git
cd stock_data_entry
```

(Replace the URL with wherever the repo actually ends up once it's pushed to
GitHub.)

### 6. Fetch dependencies and generate the storage code

```powershell
flutter pub get
dart run build_runner build --delete-conflicting-outputs
```

The first line downloads the libraries this project depends on (listed in
`pubspec.yaml`) — the equivalent of linking in a copylib. The second line
regenerates the `.g.dart` files mentioned above; it's safe to run any time,
and only actually changes anything if a model class changed since the last
run.

### 7. Run it

```powershell
flutter run -d chrome
```

This opens a Chrome window running the app. Leave the terminal open — while
it's running, saving a `.dart` file and pressing `r` in that terminal
**hot-reloads** the change into the running app in under a second, without
losing whatever was in the form. `R` (capital) does a full restart if a
change doesn't hot-reload cleanly (this happens for changes to model classes
or `main()`).

### 8. Before committing a change

```powershell
flutter analyze
flutter test
```

`analyze` is static checking — the equivalent of a compile that catches
type errors and unreachable code before you ever run anything. `test` runs
the automated test suite in `test/`. Both should report clean before you
commit.

## Demo walkthrough: adding a field to a form

This walks through everything that has to change to add a new field, using
a concrete example: adding a **REMARKS** field (a short free-text note, up
to 20 characters) to the **Price Range** form. Nothing here is
implemented — this is meant as a first hands-on exercise. Follow it in
order; each step depends on the one before it.

### Step 1 — declare the field's width

Open `lib/core/record_spec.dart`. Find `PriceRangeSpec` and add a width
constant the same way `valueWidth` is declared:

```dart
abstract final class PriceRangeSpec {
  static const int ccodeWidth = 10;
  static const int dateWidth = 6;
  static const int valueWidth = 5;
  static const int remarksWidth = 20;          // <- add this

  static int get maxValue => _pow10(valueWidth) - 1;

  static const int recordWidth =
      ccodeWidth + dateWidth + valueWidth + valueWidth + remarksWidth; // <- widen this
}
```

This is the "copybook" change — the one fact every other file will read
from, rather than each restating `20` on its own.

### Step 2 — add the field to the record class

Open `lib/models/price_range.dart`. Add a new field with the next unused
`@HiveField` index (the existing fields use 0–3, so this one is 4):

```dart
  /// A short free-text note, up to 20 characters.
  @HiveField(4)
  String remarks;
```

Add `required this.remarks` to the constructor's parameter list, and add
`remarks` to the `toString()` at the bottom while you're there.

`@HiveField` numbers are permanent once used — never reuse or renumber an
existing one, only add new ones at the end. This is exactly the discipline
of appending fields to the end of a COBOL record rather than inserting one
in the middle: existing stored records were written under the old layout,
and Hive uses these numbers, not field order, to know which stored value
maps to which field.

### Step 3 — regenerate the storage code

```powershell
dart run build_runner build --delete-conflicting-outputs
```

This rewrites `lib/models/price_range.g.dart` to match the class you just
edited. You should never hand-edit that file — always change the model and
regenerate.

### Step 4 — add validation (if the field needs any)

Open `lib/core/validators.dart`. REMARKS is optional free text, so it might
only need a length check. Following the shape of the existing `ccode`
validator:

```dart
  static String? remarks(String? raw, {int maxLength = 20}) {
    final value = (raw ?? '').trim();
    if (value.length > maxLength) {
      return 'REMARKS IS TOO LONG. USE $maxLength CHARACTERS AT MOST.';
    }
    return null;
  }
```

A `null` return means "valid" — that convention is used throughout the file.

### Step 5 — wire it into storage (the controller)

Open `lib/data/price_range_controller.dart`. Both `add(...)` and
`update(...)` need a `remarks` parameter threaded through to the
`PriceRange(...)` constructor call and the `existing.remarks = remarks`
assignment, the same way `lowVal` and `highVal` already are.

### Step 6 — add the field to the form

Open `lib/screens/price_range_screen.dart`. Three things, following the
existing LOW VALUE / HIGH VALUE fields as the template:

1. A `TextEditingController _remarksController` alongside `_lowController` —
   declared near the top, disposed in `dispose()`, cleared in `_clearForm()`,
   and populated from the record in `_startEditing()`.
2. A `BrutalTextField` for it in the form, sized with
   `skin.sizes.fieldWidth` like the others.
3. `remarks: _remarksController.text.trim()` added to both the `add(...)`
   and `update(...)` calls inside `_save()`.

### Step 7 — show it in the results table

Still in `price_range_screen.dart`, find the `BrutalTable` in `_buildTable`.
Add a column:

```dart
BrutalColumn('REMARKS', 200),
```

and a matching cell value in the `cells:` list for each row:

```dart
record.remarks,
```

Column order in `columns:` must match cell order in `cells:` — the table
widget pairs them up positionally, the same way a report layout lines up
column headings with the print line beneath them.

### Step 8 — include it in exports

Open `lib/export/export_service.dart`. Three places need it:

- `priceRangeHeader` — add `'REMARKS'` to the header list.
- `priceRangeRows` — add `record.remarks` to each row's value list.
- `priceRangeFixedWidth` — add
  `padAlpha(record.remarks, PriceRangeSpec.remarksWidth)` to the line being
  built, in the same position you want it to appear in the fixed-width
  file.

This is the same field-width constant from Step 1, doing the same job it
does everywhere else — nothing here restates `20`.

### Step 9 — run it

```powershell
flutter analyze
flutter test
flutter run -d chrome
```

`analyze` will point at anything still missing the new parameter (a very
common first error: forgetting to add `remarks:` to one of the two places
that construct or update a `PriceRange`). Once it's clean, the running app
should show the new field on the form, in the table, and in every export.

### What this walkthrough is really demonstrating

Nine steps sounds like a lot for one field, but notice what *didn't* need
touching: the theme, the button widgets, the table's rendering logic, the
duplicate-check code, the date handling, the other record type entirely.
Each layer only had to learn about the new field in the one place that was
actually its job. That's the payoff of the layering described above — and
it's the same reason a well-structured COBOL system lets you add a field to
one record without an afternoon spent grepping the whole codebase for every
place that assumed the old layout.
