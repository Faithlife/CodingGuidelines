
# React Coding Guidelines

## Write Focused Components
Like functions, well-designed React components should focus on a specific piece of functionality. Prefer factoring code into many small, focused components over monolithic components that cover major feature areas. Most apps tend to have a few large components that pull together several unrelated features. These should be rare, and in cases where they're needed prefer composing many smaller components rather than implementing functionality directly within the monolithic component.

Small and focused components are easier to read and understand. They're also easier to reuse if the need arises, and they provide React with optimization opportunities because you can easily use `React.memo` to avoid unnecessary re-renders.

* Component state should generally be focused on one specific thing. Unrelated data in state is a sign that you could consider extracting components or custom hooks.
* Component handlers should be strictly related to the UI rendered. Consider extracting components or hooks for custom behavior that's not necessarily tied to specific UI.
* You shouldn't have to scroll through pages of JSX in a render method. If you can't fit the JSX on a page, consider extracting helper components.
* Most components shouldn't need a ton of props. Components that accept a lot of props, or components whose props are unrelated to one another are often good candidates for refactoring.

Tip: Rather than adding a feature to an existing component and then considering whether it should be extracted, implement new features first as a new component and then consider if the new component should be kept or be merged into its consumer.

## Use Hooks Functions for New Components
All new components should prefer hooks functions over class components.

Hooks APIs are far easier to consume correctly than class lifecycle methods. They're also more succinct, help keep related code together, and work better with TypeScript.

## Use Custom Hooks for Async Work
Async work is often complicated, and function components that manage async work inline tend to get messy fast. Prefer extracting a private custom hook to manage the work, exposing a simpler hook to your component.

## Internationalize All User-Visible Text
All components should be internationalized by default.

See [Internationalization.md].

## Destructure Props and State
Props and state should be destructured into locals at the top of the methods that use them. In class components, this makes it easy to see which data a method uses, reduces bloat in the method body, and makes the code easier to extract out of the component or convert to a function component. In function components, it makes it easier to quickly understand the component's API, and reduces code bloat.

## import React, { useEffect } from 'react';
Use named imports for built-in hooks. Use React's default export for everything else.

Many of React's exports use overly generic names, or shadow globals. e.g., `Component`, `lazy`, `MouseEvent`. Using named imports for these makes code harder to read because additional context is required to understand that these are React APIs. Hooks get an exception because they use a very specific naming convention that's unlikely to conflict, and function components are easier to read when built-in hooks don't get special treatment over custom hooks.

We write a lot of React code, and consuming the React API in a consistent way makes code easier to read, and team transitions smoother.

```js
// bad
import * as React from 'react';

// bad
import React, { Component, TouchEvent, useEffect } from 'react';

// good
import React from 'react';

// good
import { useState } from 'react';
```

## Prefer Extracting Components Over Introducing Helper Render Functions
When a render method gets too large, extract a React component. Avoid using "helper render functions" that are directly invoked.

"Helper render functions" bloat components and unnecessarily avoid obvious opportunities for building smaller, more focused components.

```jsx
// bad
renderMenu() {
	return (
		<Menu>
			<MenuButton onClick={this.handleAction}>Action</MenuButton>
		</Menu>
	);
}

render() {
	return (
		<Header>
			{this.renderMenu()}
		</Header>
	);
}

// good
render() {
	return (
		<Header>
			<HeaderMenu onAction={this.handleAction} />
		</Header>
	);
}

const HeaderMenu = ({ onAction }) => (
	<Menu>
		<MenuButton onClick={onAction}>Action</MenuButton>
	</Menu>
);
```

## Clean Up After Yourself
All components should cancel any outstanding async work when they unmount. This includes network requests, timers, intervals, debounced or throttled functions, etc.. Avoid assuming that the component is still mounted in async continuations, as interacting with unmounted components often causes generates confusing errors. Remove any event listeners or subscription that were manually set up while the component was mounted.

## Avoid Assumptions About Component Use
Components should avoid making assumptions about how they will used. React components are fundamentally modular and designed for reuse. Avoid building components that make assumptions about the environment they're rendered in, the number of times they're used in a page, the frequency with which their props will change, etc. In particular, …

## Assume All Components Will be Server-Rendered
React's API was designed to clearly communicate when it is safe to perform certain actions, and when it's not. Following that API will not only result in components that are more easily reused or adapted, but are also more consistent and easier to understand. Avoid assumptions about the environment that code is running in, and leverage React's API instead.

## Assume All Components Will Unmount
All components eventually unmount. Test environments may unmount and remount components. Components are often reused in different environments. Follow best-practices for React component design in *all* components, and do not write code that assumes a component will never unmount. Top-level application components should clean up after themselves, too.

## Assume All Components Are Multi-Instance
Components that assume they're singletons are often difficult to test, and commonly cause problems when designs change.

## Avoid Props Spreading
Props spreading frequently leads to confusing component APIs, and code that's difficult to maintain because it's difficult to determine which props are used by which components. Prefer to explicitly pass each prop along to the child component, and consider alternate component designs when passing excessive props.

## Reduce Props Drilling
It's common for components to accept props that they don't need themselves, for the purpose of passing the prop downward to a descendant component. This is often necessary, but it commonly leads to components that become difficult to maintain. Components that drill many props tend to lose their focus and have access to more data and APIs than they need, making it unclear what their responsibility should be. It's also annoying to thread props through many layers of components when you add a new feature.

Props drilling is not necessarily a bad thing, but the drawbacks can often be alleviated by leveraging different component design patterns.

* Build presentational layout components that only establish layout or styling, and then render `props.children` to allow a consuming component to pass props directly to the components that need them.
* Build utility wrapper components or custom hooks for fetching data.
* Leverage React context to distribute APIs or data through a deep component tree (but don't overuse it).

Sidebar components are a good example of this. It's common for a sidebar to have a few tabs, each of which requires different props. A common approach is to build a `Sidebar` component that accepts all props needed by all tabs. `Sidebar` renders some tab layout and has some state for tracking the active tab, and it passes a bunch of props down to the tabs. It's then common for tabs to perform some data-fetching before rendering its contents.

A better solution to this is to build a `Sidebar` component that only renders the sidebar layout, and accepts `Sidebar.Tab` components as `children`. `Sidebar` doesn't have to pass props along because rendering of the tab contents is left up to the consuming component, and the props-drilling is reduced by 1 layer.

Data-fetching logic can be moved upward in a similar fashion. Say there's an `Account` tab that needs to fetch the current user. Instead of passing a `getUser` prop to it, and complicating that component with data-fetching logic, build a `WithUser` utility component that accepts a user ID and exposes the result through a render callback. This separates the fetching logic from the presentational `Account` component. As projects transition to use more function components with hooks, those utility components are easily translated into custom hooks, reducing JSX nesting by removing render callbacks.

```js
// deep component tree with props-drilling, and data-fetching intermingled with presentational components
<Sidebar
	resources={resources}
	getUser={this.getUser}
	currentUserId={currentUserId}
	findWidgets={this.findWidgets}
/>

// small, focused components in a flatter component tree
<Sidebar>
	<Sidebar.Tab title={resources.AccountTabTitle}>
		<WithUser
			getUser={this.getUser}
			userId={currentUserId}
			render={({ user }) => <Account user={user} />}
		/>
	</Sidebar.Tab>
	<Sidebar.Tab title={resources.SearchTabTitle}>
		<WithSearch
			findWidgets={this.findWidgets}
			render={({ query, setQuery, results }) => (
				<Search query={query} setQuery={setQuery} results={results} />
			)}
		/>
	</Sidebar.Tab>
</Sidebar>
```

## Avoid id Attributes in React Components
`id`s must be unique in an HTML document. Since Components are fundamentally reusable, and you're avoiding assumptions about component use, `id`s are incompatible with React components. The most common use-case for `id`s is for labeling form components. Instead, nest form controls inside label elements.

Sometimes 3rd party APIs require the use of `id`s, and that's a bummer. Avoid them, if possible.

Sometimes SVGs include `id`s. If possible, ask design for an alternate implementation. If `id`s are required, use a tool or webpack plugin to ensure they are unique in the project.

## Use Focus to Dismiss Modals
Generally, the easiest way to dismiss a modal dialog or menu is with an "outer click" pattern. When the modal opens, you add a `click` event listener to body, and check if you see any clicks outside the modal, you close it. This is fundamentally broken for keyboard users, who will get stuck in dialogs they cannot dismiss. The correct way to dismiss a modal is to track focus, and close the modal when focus moves outside the modal container. It's more work, but it results in a far better user experience.

## Avoid `event.stopPropagation()`
Stopping propagation is a common source of bugs, and frequently makes debugging difficult. The need to stop propagation so a parent component doesn't observe an event is often an indication that a component hierarchy should be reconsidered. Avoid it, if possible.

## Do Not Start Async Work Before Component Mounts
The earliest point at which you can safely start async work in a React component is in `componentDidMount`, or in a `useEffect` callback. Do not start async work outside the component at module evaluation time, in constructors, or lifecycle methods like `componentWillMount`.

## Use CSS Variables for Computed Styles
When applying computed styles to React elements, prefer setting CSS variables and then applying the styling in CSS over using inline styles. This keeps all the component styling in one place, and makes it clear which styles use dynamic data.

```js
// bad
<div className={styles.badWidget} style={{ top: offset.top }} />

// good
<div className={styles.goodWidget} style={{ '--offset-top': offset.top }} />
```

```css
.badWidget {
	position: absolute;
	left: 0;
}

.goodWidget {
	position: absolute;
	top: var(--offset-top);
	left: 0;
}
```

## Do Not Share Style Files when using CSS Modules
When using CSS Modules, component files should import at most 1 CSS file, and each CSS file should be imported by at most 1 component file.

Sharing style files between multiple components makes it harder to tell which styles are used, and how they relate to one another. Prefer Splitting out separate style files, even if they only contain a single rule.

CSS files may import LESS variables or mixins, or compose from common styles.

## Use Custom Hooks to Expose Context
When using React Context, avoid directly exporting the `Consumer`. Instead, export a custom hook that returns the result of `useContext()`, so consumers don't have care about the source of the data.

```js
// bad
const context = React.createContext(null);
const { Provider, Consumer } = context;
export { Provider, Consumer };

// good
const context = React.createContext(null);
const ThingProvider = context.Provider;
const useThing = () => useContext(context);

export { ThingProvider, useThing };
```
