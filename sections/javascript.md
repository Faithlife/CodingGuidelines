
# JavaScript Coding Guidelines

## Use TypeScript
Prefer TypeScript over JavaScript for all new projects.

When possible, use the `strict` compiler setting to opt in to strict null checks and improved flow analysis. This setting significantly improves the capabilities of TypeScript's tooling. It's usually prohibitively costly to migrate existing projects to pass the stricter requirements, so enable it when the project is bootstrapped.

## Use Strict Comparison Operators
Using strict comparisons makes code more explicit by clarifying which specific values are expected. It also saves readers from having to memorize coercion rules.

```js
// bad
if (foo != null) {
	doThing(foo);
}

// good
if (foo !== null && foo !== undefined) {
	doThing(foo);
}

// also fine
if (foo) {
	doThing(foo);
}
```

Boolean coercion is acceptable, but don't abuse it. Strive to write code that clearly communicates intent over code that's short.

```js
// confusing
if (foo || foo === 0) {
	doThing(foo);
}

// clear
if (typeof foo === 'number') {
	doThing(foo);
}
```

## Use Default Exports
Files exposing a single primary API should use a default export.

Files exporting a collection of utilities can use named exports, but prefer splitting utilities into separate files with default exports and re-exporting from an index file when the collection gets excessively large. It is also acceptable to use named exports for ancillary APIs or types in files that use a default export for the primary API.

Many files that each export one thing is easier to read and maintain than a single file that exports many things. Use of default exports for primary entry points is also standard-practice in the JavaScript ecosystem.

## File Names Should Match Export Names
This consistency makes code easier to locate, and it works better with refactoring tools like VSCode fixes that default to files names matching the name of the function or class being extracted.

```js
// bad
// user-account.ts
export default UserAccount;

// good
// UserAccount.ts
export default UserAccount;
```

## Avoid Importing Sibling or Ancestor Index
Use `index.js` files to expose a focused API for the modules in a directory. Modules within that directory should reference their sibling dependencies directly. Do not import the `index.js` from a sibling or ancestor directory, as this creates circular references and makes code organization difficult to reason about.

```js
// bad
import { HelperComponent } from './';
import { util } from '../../';

// good
import HelperComponent from './HelperComponent';
import util from '../../util';
```

## Handle Cancellation in Async Work
Support cancellation in code that performs async work.

In projects that have established patterns for cancellation, be consistent. In new projects or projects that have no established patterns, prefer using the standard [`AbortController`](https://developer.mozilla.org/en-US/docs/Web/API/AbortController) API.

API clients and fetch helpers should generally accept and respect an [AbortSignal](https://developer.mozilla.org/en-US/docs/Web/API/AbortController/signal) in each `Promise`-returning method. Utilities that use `setTimeout` or `setInterval` should expose a mechanism for clearing the timeout or interval.

Async code should always clean up after itself. Avoid writing code that may produce surprising side effects or error messages if a caller doesn't wait for an async action to complete. `setTimeout` and `setInterval` should generally have a corresponding `clearTimeout` or `clearInterval`, even if the duration is very short. debounced and throttled functions should be canceled when they're no longer needed. Avoid making assumptions about mutable state inside async continuations (e.g., check if a React component is still mounted before setting local component state).

## Justify `eslint-disable` With Explanatory Comment
If you use an `eslint-disable` comment to disable a lint rule, add another rule on the preceding line describing the reason for disabling the rule.

## Be Mindful of Dependency Weight
While it's beneficial to leverage existing solutions, it's also important to consider the associated costs. JavaScript applications tend to have deep dependency trees that can bloat the application bundle. Once a dependency is added and built upon, it can be prohibitively difficult to remove later when application performance is suffering.

When considering a new dependency, always investigate the cost to your application's bundle size. Ideal dependencies contain code that is fully exercised by your applications requirements, leaving no "dead code" in the application bundle. Some libraries are quite large, but distribute multiple entry points or support tree-shaking, letting you import just the functionality from the library that you actually need. Take care to ensure you're not shipping dead code to your users, and ensure you're importing responsible. Investigate or build alternatives when the weight of a dependency doesn't justify the functionality it provides.

While this is primarily relevant to front-end projects, node.js is not immune to this issue. Node must parse and compile all scripts at import time, and large dependencies can noticeably slow down the startup of scripts and servers.

```bash
$ npx weigh lodash
Approximate weight of lodash:
  Uncompressed: 541 kB
  Minified (uglify): 70.4 kB
  Minified and gzipped (level: default): 24.7 kB
```

```bash
$ npx weigh lodash.debounce lodash.throttle
Approximate weight of lodash.debounce and lodash.throttle:
  Uncompressed: 25 kB
  Minified (uglify): 4.2 kB
  Minified and gzipped (level: default): 1.15 kB
```
