# Android Coding Guidelines

## Use .editorconfig

See [.editorconfig for Android](editorconfig.md).

## Use Android Lint

Android Lint is a static analysis tool that integrates with Android Studio and the Android Gradle Plugin. As such, it is generally more concerned with semantic issues than syntactic issues. It's recommended for CI builds. Faithlife's [Android Lint ruleset](https://github.com/Faithlife/AndroidLint/) specifies additional rules and is extendable to enforce house rules.

The app module should enable `checkDependencies` such that when lint is run against the app module, it also runs against each dependency module.

```kotlin
plugins {
    id("com.android.application")
}

android {
    defaultConfig {
        lint.checkDependencies = true
    }
}
```

Consider enabling treat warnings as errors on each gradle module in the project. Usually, you'll want to enable warnings as errors in each module individually so that if lint is explicitly run against a dependency module e.g. `./gradlew :data:lint`, the lint error semantics will be consisitent.

```kotlin
android {
    defaultConfig {
        lint.warningsAsErrors = true
    }
}
```

## Languages

Defer to the appropriate guide per language. Gradle plugins like [Spotless](https://github.com/diffplug/spotless) can coordinate several formatting tools and apply them appropriately throughout the codebase.
