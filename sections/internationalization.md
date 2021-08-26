# Internationalization

Faithlife's corporate mission includes the statement:

> We are committed to increasing biblical literacy and accessibility for every Christian around the world.

Our customers already speak dozens of different languages, and our support for localized products is only going to grow over time. Recent launches of Logos Bible Software have happened simultaneously in multiple international markets. If you're building a customer-facing product, there's a high chance it will need to be translated into another language in the future, and you should code it with [internationalization (i18n) and localization (l10n)](https://en.wikipedia.org/wiki/Internationalization_and_localization) in mind.

There is a small up-front cost to supporting i18n, e.g., creating `OurResources.resx` or `localization.json` and setting up automated tasks to sync strings with Crowdin, etc. Once this is done, there is negligible developer cost for adding new UI strings to those files as features are developed.

(All programs should, of course, support full Unicode (NOTE: `utf8mb4` in MySQL) in all internal string processing and data storage.)

However, there is substantial cost to review an existing code base and extract only the strings that represent UI elements (as opposed to internal IDs, API parameters, keywords, HTML element names, etc.).

Consult the following (somewhat hand-wavy) chart (of estimated costs):

Need i18n \ Add i18n | No | Yes
--- | --- | ---
No | ZERO  | LOW
Yes | VERY HIGH | MEDIUM

By supporting i18n from the beginning, you incur a small initial (and ongoing) cost, with a large payoff when (not *if*) localization is requested.

There's also an assumption (among product owners, based on historical precedent) that we build products in a localizable manner, and that it won't be `O(rewrite)` to add a new UI language to an existing product.

Thus, by default, all consumer-facing Faithlife products should be internationalizable by default, unless the product owner clearly communicates that localization is completely out of scope. (In that case, you are building an English-only product and YAGNI.)

<hr>

Note that our support for l10n usually assumes a LTR UI. Changing this assumption may come at a "VERY HIGH" cost but so far we've decided "YAGNI". Not solving every possible l10n issue doesn't mean that we can't prepare for the general principle of "this UI element may need to be displayed in a different language."
