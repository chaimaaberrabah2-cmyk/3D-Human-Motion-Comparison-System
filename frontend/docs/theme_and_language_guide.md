# Global Theme & Language Architecture

This document provides a detailed explanation of how the application handles global theming (Light/Dark mode) and localization (English/French).

## 1. Theming Architecture

The application uses a `ThemeProvider` based on the `Provider` pattern to manage the global theme state.

### Key Components

#### 1.1 `AppTheme` Class
**File:** `lib/core/theme/app_theme.dart`

This class defines the static `ThemeData` for both light and dark modes. It ensures consistency across the app by defining:
- **Color Schemes**: `ColorScheme.light` and `ColorScheme.dark`.
- **Text Styles**: Standardized text styles for headers and body text.
- **Component Themes**: Specific styles for `AppBar`, `ElevatedButton`, `InputDecoration`, etc.

```dart
static final ThemeData lightTheme = ThemeData(
  brightness: Brightness.light,
  scaffoldBackgroundColor: const Color(0xFFF8FAFC),
  primaryColor: AppColors.accentBlue,
  // ... other properties
);

static final ThemeData darkTheme = ThemeData(
  brightness: Brightness.dark,
  scaffoldBackgroundColor: AppColors.background, // Dark background
  // ... other properties
);
```

#### 1.2 `ThemeProvider` Class
**File:** `lib/core/theme/theme_provider.dart`

Manages the active `ThemeMode` (`ThemeMode.light` or `ThemeMode.dark`) and persists the user's preference using `shared_preferences`.

- **State**: Holds the current `_themeMode`.
- **Persistence**: Loads the saved theme on startup and saves changes when the user toggles the mode.
- **Notification**: Extends `ChangeNotifier` to rebuild the app when the theme changes.

#### 1.3 Usage in `MaterialApp`
**File:** `lib/main.dart`

The `MaterialApp` is wrapped in a `Consumer<ThemeProvider>` to listen for changes.

```dart
Consumer2<LocaleProvider, ThemeProvider>(
  builder: (context, localeProvider, themeProvider, child) {
    return MaterialApp(
      // ...
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeProvider.themeMode, // Dynamic switching
      // ...
    );
  },
)
```

## 2. Localization (Language) Architecture

The application uses the official `flutter_localizations` package and ARB (Application Resource Bundle) files for managing translations.

### Key Components

#### 2.1 ARB Files
**Location:** `lib/l10n/`

- `app_en.arb`: English translations (Source).
- `app_fr.arb`: French translations.

These files contain key-value pairs for all user-facing text.

```json
// app_en.arb
{
    "helloWorld": "Hello World!",
    "@helloWorld": {
      "description": "The conventional newborn programmer greeting"
    }
}
```

#### 2.2 `LocaleProvider` Class
**File:** `lib/core/l10n/locale_provider.dart`

Similar to `ThemeProvider`, this class manages the active `Locale`.

- **State**: Holds the current `_locale` (e.g., `Locale('en')` or `Locale('fr')`).
- **Persistence**: Saves the user's language preference using `shared_preferences`.
- **Localization**: Notifies the app to rebuild with the new language.

#### 2.3 Integration in `MaterialApp`
**File:** `lib/main.dart`

The `MaterialApp` is configured with the necessary localization delegates.

```dart
localizationsDelegates: const [
  AppLocalizations.delegate, // Generated delegate
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
],
supportedLocales: L10n.all, // List of supported locales [en, fr]
locale: localeProvider.locale, // Dynamic switching
```

## 3. How to Use in UI

### 3.1 Applying Theme Colors
To ensure the app adapts to both modes automatically, **never hardcode colors**. Always use `Theme.of(context)`.

**Bad:**
```dart
Container(color: Colors.white) // Will be white even in dark mode!
```

**Good:**
```dart
Container(color: Theme.of(context).cardColor) // Adapts to theme
```

### 3.2 Accessing Translations
Use the generated `AppLocalizations` class to access translated strings.

```dart
final l10n = AppLocalizations.of(context)!;

Text(l10n.helloWorld);
```

### 3.3 Switching Theme/Language
To switch the theme or language from a widget (e.g., Settings Page), use the providers:

```dart
// Switch Theme
final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
themeProvider.toggleTheme(isDark);

// Switch Language
final localeProvider = Provider.of<LocaleProvider>(context, listen: false);
localeProvider.setLocale(Locale('fr'));
```
