# Instructions

- The `.editorconfig` rules for all files have been modified in this repository.

## Remove Redundant Rules

- The new rules are in the `DO NOT EDIT` section for `root`.
- If the `DO NOT EDIT` section for `root` is not before all other `.editorconfig` sections, move it there.
- If there's a redundant `root = true` outside the `DO NOT EDIT` section for `root`, remove it.
- If the rules inside the `DO NOT EDIT` section for `root` have made any rules or sections outside any `DO NOT EDIT` section redundant, remove the redundant rules. Do not remove redundant rules inside `DO NOT EDIT` sections.
- Also, our guideline is to NOT specify `indent_size`, `indent_style`, `tab_width`, or `insert_final_newline` from `[*]`, so if there is a `[*]` section outside the `DO NOT EDIT` sections with those rules, remove them, and remove any empty `[*]` section that may remain.

## Leave Changes Unstaged

- DO NOT commit any changes to the git repository. Leave your changes unstaged, but don't leave any unintentional changes.