# Accessibility

## Focus Control
Having a focus indicator is crucial to accessible navigation. Unfortunately the focus indicator is often turned off. A great source of information on this is the MDN page on [:focus-visible](https://developer.mozilla.org/en-US/docs/Web/CSS/:focus-visible)

If you only want to show the focus indicator when a user is navigating with a keyboard or assistive technology, use `:focus-visible`. This will NOT show the indicator if a mouse click sets focus.

### Example

```css
:focus {
	outline: none;
}

:focus-visible {
	outline: 1px solid blue;
}
```

## Navigation/Landmarks
When creating navigation sections (sidebars, headers, etc), they should be wrapped in the appropriate `nav` element along with `ul` to create a navigable list. Also either use a `aria-label` or `aria-labelledby` attribute to add a title to the `nav` element.

```html
<nav aria-labelledby="nav2"> 
  <h2 id="nav2">title for navigation 2<h2>
  <ul>
    <li><a href="page21.html">Link 5</a></li>
    <li><a href="page22.html">Link 6</a></li>
    <li><a href="page23.html">Link 7</a></li>
    <li><a href="page24.html">Link 8</a></li>
    .....
  </ul>
</nav>
```

For more examples, such as `main`, `banner`, `region`, etc. See [W3C Landmark General Principles](https://www.w3.org/WAI/ARIA/apg/patterns/landmarks/examples/general-principles.html)

## Semantic HTML

https://www.w3schools.com/html/html5_semantic_elements.asp

## Accessible Forms

## Mouse and Pointer Events

## Other Points for Consideration

### Setting the language {#setting-the-language}

Indicate the human language of page texts as screen reader software uses this to select the correct voice settings:

- [WebAIM - Document Language](https://webaim.org/techniques/screenreader/#language)

### Setting the document title {#setting-the-document-title}

Set the document `<title>` to correctly describe the current page content as this ensures that the user remains aware of the current page context:

- [WCAG - Understanding the Document Title Requirement](https://www.w3.org/TR/UNDERSTANDING-WCAG20/navigation-mechanisms-title.html)

We can set this in React using the [React Document Title Component](https://github.com/gaearon/react-document-title).

### Color contrast {#color-contrast}

Ensure that all readable text on your website has sufficient color contrast to remain maximally readable by users with low vision:

- [WCAG - Understanding the Color Contrast Requirement](https://www.w3.org/TR/UNDERSTANDING-WCAG20/visual-audio-contrast-contrast.html)
- [Everything About Color Contrast And Why You Should Rethink It](https://www.smashingmagazine.com/2014/10/color-contrast-tips-and-tools-for-accessibility/)
- [A11yProject - What is Color Contrast](https://a11yproject.com/posts/what-is-color-contrast/)

## Development and Testing Tools {#development-and-testing-tools}
### The keyboard {#the-keyboard}
By far the easiest and also one of the most important checks is to test if your entire website can be reached and used with the keyboard alone. Do this by:
1. Disconnecting your mouse.
1. Using `Tab` and `Shift+Tab` to browse.
1. Using `Enter` to activate elements.
1. Where required, using your keyboard arrow keys to interact with some elements, such as menus and dropdowns.

### Development Assistance {#development-assistance}
We can check some accessibility features directly in our JSX code. Often intellisense checks are already provided in JSX aware IDE’s for the ARIA roles, states and properties. We also have access to the following tool:
`eslint-plugin-jsx-a11y`
The `eslint-plugin-jsx-a11y` plugin for ESLint provides AST linting feedback regarding accessibility issues in your JSX. Many IDE’s allow you to integrate these findings directly into code analysis and source code windows.

If you want to enable even more accessibility rules, you can create an `.eslintrc` file in the root of your project with this content:
```
{
  "extends": ["react-app", "plugin:jsx-a11y/recommended"],
  "plugins": ["jsx-a11y"]
}
```

### Browser Testing {#browser-testing}
In some browsers we can easily view the accessibility information for each element in the accessibility tree:
- [Using the Accessibility Inspector in Firefox](https://firefox-source-docs.mozilla.org/devtools-user/accessibility_inspector/index.html)
- [Using the Accessibility Inspector in Chrome](https://developer.chrome.com/docs/devtools/accessibility/reference)
- [Using the Accessibility Inspector in OS X Safari](https://developer.apple.com/documentation/accessibility/accessibility-inspector)

In addition, there are some helpful tools to help with accessibility.
[Accessibility Insights](https://accessibilityinsights.io) performs a full accessibility audit, including clear explanations of what the standards on and how to test them. 
[ARIA Dev Tools]() is a great tool for visualizing what ARIA tags are describing the page as. Use this to get a sense of how well things are described to assistive technologies.

### Screen readers {#screen-readers}

Testing with a screen reader should form part of your accessibility tests.

Please note that browser / screen reader combinations matter. It is recommended that you test your application in the browser best suited to your screen reader of choice.

### Commonly Used Screen Readers {#commonly-used-screen-readers}

#### NVDA in Firefox {#nvda-in-firefox}

[NonVisual Desktop Access](https://www.nvaccess.org/) or NVDA is an open source Windows screen reader that is widely used.

Refer to the following guides on how to best use NVDA:

- [WebAIM - Using NVDA to Evaluate Web Accessibility](https://webaim.org/articles/nvda/)
- [Deque - NVDA Keyboard Shortcuts](https://dequeuniversity.com/screenreaders/nvda-keyboard-shortcuts)

#### VoiceOver in Safari {#voiceover-in-safari}

VoiceOver is an integrated screen reader on Apple devices.

Refer to the following guides on how to activate and use VoiceOver:

- [WebAIM - Using VoiceOver to Evaluate Web Accessibility](https://webaim.org/articles/voiceover/)
- [Deque - VoiceOver for OS X Keyboard Shortcuts](https://dequeuniversity.com/screenreaders/voiceover-keyboard-shortcuts)
- [Deque - VoiceOver for iOS Shortcuts](https://dequeuniversity.com/screenreaders/voiceover-ios-shortcuts)

#### JAWS in Internet Explorer {#jaws-in-internet-explorer}

[Job Access With Speech](https://www.freedomscientific.com/Products/software/JAWS/) or JAWS, is a prolifically used screen reader on Windows.

Refer to the following guides on how to best use JAWS:

- [WebAIM - Using JAWS to Evaluate Web Accessibility](https://webaim.org/articles/jaws/)
- [Deque - JAWS Keyboard Shortcuts](https://dequeuniversity.com/screenreaders/jaws-keyboard-shortcuts)

### Other Screen Readers {#other-screen-readers}

#### ChromeVox in Google Chrome {#chromevox-in-google-chrome}

[ChromeVox](https://www.chromevox.com/) is an integrated screen reader on Chromebooks and is available [as an extension](https://chrome.google.com/webstore/detail/chromevox/kgejglhpjiefppelpmljglcjbhoiplfn?hl=en) for Google Chrome.

Refer to the following guides on how best to use ChromeVox:

- [Google Chromebook Help - Use the Built-in Screen Reader](https://support.google.com/chromebook/answer/7031755?hl=en)
- [ChromeVox Classic Keyboard Shortcuts Reference](https://www.chromevox.com/keyboard_shortcuts.html)

Some content from [https://legacy.reactjs.org/docs/accessibility.html](https://legacy.reactjs.org/docs/accessibility.html)
