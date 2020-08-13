
# Android Kotlin Coding Guidelines

Follow the [Android Kotlin Style Guide](https://developer.android.com/kotlin/style-guide) from Google with minimal deviations.

## Enforcement

[ktlint](https://github.com/pinterest/ktlint/) is used to enforce style checks. It supports a large subset of the official coding guidelines, but aspires to support the complete set. When the android style guide is unclear, fall back to the [Kotlin Guidelines](kotlin.md).

Be sure to use the Android CLI flag when running ktlint on Android code.

## Android Lint

Android Lint is generally more concerned with semantic issues than syntatic issues. It's recommended for CI builds. Faithlife's [Android Lint ruleset](https://github.com/Faithlife/AndroidLint/) specifies additional rules and is extendable to enforce house rules.
