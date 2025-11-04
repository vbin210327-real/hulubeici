# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

葫芦背词 (Hulu Beici) is a native iOS vocabulary learning app built with SwiftUI. The app features a spaced repetition system with page-based progress tracking, word visibility controls, and support for multiple vocabulary books.

## Build & Run

```bash
# Open project in Xcode
open "葫芦背词/葫芦背词.xcodeproj"

# Build from command line (requires Xcode)
xcodebuild -project "葫芦背词/葫芦背词.xcodeproj" -scheme "葫芦背词" -configuration Debug build

# Run tests
xcodebuild test -project "葫芦背词/葫芦背词.xcodeproj" -scheme "葫芦背词" -destination 'platform=iOS Simulator,name=iPhone 15'
```

**Note:** This is a Chinese-language app. File paths and UI text use Chinese characters.

## Architecture

### Core Data Models

All data models are defined in `ContentView.swift`:

- **WordEntry** (`ContentView.swift:2542`): Individual vocabulary items with `word` and `meaning` fields
- **WordSection** (`ContentView.swift:2558`): Collections of words with title, subtitle, targetPasses, and an array of WordEntry
- **BundledWordBookLoader** (`ContentView.swift:2861`): Loads pre-packaged vocabulary sets from Resources/*.txt files

### State Management

Three ObservableObject stores handle app state:

1. **WordBookStore** (`ContentView.swift:685`)
   - Manages all WordSection collections
   - Persists to `wordbook.json` in Documents directory

## Supabase Email Login

- Client auth configuration lives in `葫芦背词/AuthSessionStore.swift`, `SupabaseAuthService.swift`, `SignInView.swift`, and `SupabaseConfig.swift`.
- Before building, edit `SupabaseConfig.swift` and replace `YOUR_SUPABASE_ANON_KEY` with the project's anon API key (Dashboard → Settings → API).
- Users must exist in Supabase Auth with email/password credentials. Enable email sign-up or create users manually in the Supabase dashboard.
- The app stores the Supabase session in `UserDefaults` and automatically restores it on launch. Sign-out clears local state and calls Supabase `/auth/v1/logout`.
   - Auto-loads bundled word books from Resources/ on first launch
   - Provides CRUD operations: `addSection()`, `updateSection()`, `updateWords()`, `deleteSection()`

2. **SectionProgressStore** (`ContentView.swift:2600`)
   - Tracks learning progress per section (completed pages and passes)
   - Persists to UserDefaults
   - Page-based tracking: 10 words per page (constant `wordsPerPage = 10`)
   - Progress state: `completedPages` and `completedPasses`

3. **WordVisibilityStore** (`ContentView.swift:2713`)
   - Manages word/meaning visibility toggles (for testing oneself)
   - Persists to UserDefaults
   - Per-word granular control of visibility

### UI Structure

Three-tab navigation system:

- **Home Tab**: Word book list and study interface
- **Progress Tab**: Statistics and completion tracking
- **Profile Tab**: Settings, data management, batch import

Key UI components:
- `WordSectionDetailView` (`ContentView.swift:1416`): Paginated word study interface
- `WordPageView` (`ContentView.swift:1598`): Displays 10 words per page
- `WordRowView` (`ContentView.swift:1364`): Individual word display with visibility controls
- `BottomTabBar` (`ContentView.swift:61`): Custom tab bar with haptic feedback

### Vocabulary File Format

Text files in `葫芦背词/Resources/` follow this format:
```
word [pronunciation] part_of_speech definition
```

Example:
```
or [ə(r), ɔː(r)] conj. 或；就是；否则
garden [ˈɡɑːd(ə)n] n. 花园，果园，菜园
```

Bundled vocabulary sets:
- `2 中考-乱序.txt` - Middle school (CET-4 prep) vocabulary
- `3 四级-乱序.txt` - CET-4 vocabulary
- `highschool3500_shuffled.txt` - High school vocabulary (3500 words)
- `4 六级-乱序.txt` - CET-6 vocabulary
- `5 考研-乱序.txt` - Graduate entrance exam vocabulary
- `6 托福-乱序.txt` - TOEFL vocabulary

### Haptic Feedback

`HapticManager.swift` provides `Haptic.trigger()` with intensity levels:
- `.light` - Subtle interactions
- `.medium` - Tab switches, confirmations
- `.heavy` - Important actions, resets
- `.rigid` / `.selection` - Special cases

## Key Implementation Details

### Progress Calculation

Progress is page-based, not word-based:
- Function `studiedWordCount()` (`ContentView.swift:52`) calculates studied words from completed pages
- Formula: `completedPages × 10` (capped at total word count)
- This means progress granularity is 10 words at a time

### Data Persistence

- **Word books**: JSON file at `Documents/wordbook.json`
- **Progress**: UserDefaults with key pattern based on section UUID
- **Visibility**: UserDefaults with word entry UUID keys

### Single-File Architecture

The entire app logic resides in `ContentView.swift` (~2900 lines). This includes:
- All data models
- All view components
- All state management classes
- Sample data and bundled loaders

This architecture choice simplifies navigation but requires careful attention to:
- Proper use of `private` access control
- Clear struct/class naming conventions
- Section-based code organization via comments

## Development Workflow

When modifying the app:

1. **Adding new vocabulary sets**: Place .txt file in `葫芦背词/Resources/`, update `BundledWordBookLoader.descriptors` array
2. **UI changes**: Most views are in `ContentView.swift`, organized as private structs
3. **State changes**: Modify the appropriate Store class and ensure persistence is triggered
4. **Testing visibility/progress**: Use the Profile tab's reset functions during development

## Project Structure

```
葫芦背词/
├── 葫芦背词.xcodeproj/          # Xcode project
├── 葫芦背词/
│   ├── ____App.swift           # App entry point
│   ├── ContentView.swift        # Main app logic (single file architecture)
│   ├── HapticManager.swift      # Haptic feedback utilities
│   ├── Assets.xcassets/         # App icons and images
│   └── Resources/               # Bundled vocabulary text files
├── 葫芦背词Tests/               # Unit tests
└── 葫芦背词UITests/             # UI tests
```
