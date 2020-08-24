# Internationalization

(Originally the accepted answer to "Why should I internationalize...?" from https://stackoverflow.com/c/faithlife/questions/559)

<p>Faithlife's corporate mission includes the statement:</p>

<blockquote>
  <p>We are committed to increasing biblical literacy and accessibility
  for every Christian around the world.</p>
</blockquote>

<p>Our customers already speak dozens of different languages, and our support for localized products is only going to grow over time. Recent launches of Logos Bible Software have happened simultaneously in multiple international markets. If you're building a customer-facing product, there's a high chance it will need to be translated into another language in the future, and you should code it with <a href="https://en.wikipedia.org/wiki/Internationalization_and_localization" rel="nofollow noreferrer">i18n</a> in mind. </p>

<p>There is a small up-front cost to supporting i18n, e.g., creating <code>OurResources.resx</code> or <code>localization.json</code> and setting up automated tasks to sync strings with Crowdin, etc. Once this is done, there is negligible developer cost for adding new UI strings to those files as features are developed.</p>

<p>(All programs should, of course, support full Unicode (NOTE: <code>utf8mb4</code> in MySQL) in all internal string processing and data storage.)</p>

<p>However, there is substantial cost to review an existing code base and extract only the strings that represent UI elements (as opposed to internal IDs, API parameters, keywords, HTML element names, etc.).</p>

<p>Consult the following (somewhat hand-wavy) chart (of estimated costs):</p>

<pre><code>╔══════════════════════╦═══════════╤════════╗
║ Need i18n \ Add i18n ║    No     │  Yes   ║
╠══════════════════════╬═══════════╪════════╣
║        No            ║   ZERO    │  LOW   ║
╟──────────────────────╫───────────┼────────╢
║        Yes           ║ VERY HIGH │ MEDIUM ║
╚══════════════════════╩═══════════╧════════╝
</code></pre>

<p>By supporting i18n from the beginning, you incur a small initial (and ongoing) cost, with a large payoff when (not if) localization is requested.</p>

<p>There's also an assumption (among product owners, based on historical precedent) that we build products in a localizable manner, and that it won't be <code>O(rewrite)</code> to add a new UI language to an existing product.</p>

<p>Thus, by default, all consumer-facing Faithlife products should be internationalizable by default, unless the product owner clearly communicates that localization is completely out of scope. (In that case, you are building an English-only product and YAGNI.)</p>

<hr>

<p>Note that our support for l10n usually assumes a LTR UI. Changing this assumption may come at a "VERY HIGH" cost but so far we've decided "YAGNI". Not solving every possible l10n issue doesn't mean that we can't prepare for the general principle of "this UI element may need to be displayed in a different language."</p>
