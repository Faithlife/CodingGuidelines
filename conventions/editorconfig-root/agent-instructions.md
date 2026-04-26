# Instructions

- The `.editorconfig` rules for all files have been modified in this repository.

## Remove Obsolete Rules

- The new rules are in the `DO NOT EDIT` section for `root`.
- If the `DO NOT EDIT` section for `root` is not at the top of the `.editorconfig` (but below `root = true`), move it there.
- If the rules inside the `DO NOT EDIT` section for `root` have made any rules or sections outside any `DO NOT EDIT` section obsolete, remove the obsolete rules. Do not remove obsolete rules inside `DO NOT EDIT` sections.
- Also, our guideline is to NOT specify `indent_size`, `indent_style`, `tab_width`, or `insert_final_newline` from `[*]`, so if those entries exist outside the `DO NOT EDIT` sections, remove them, and remove the `[*]` section if nothing remains there.

## Leave Changes Unstaged

- DO NOT commit any changes to the git repository. Leave your changes unstaged, but don't leave any unintentional changes.