# .gitattributes

All git repositories must have a `.gitattributes` file at the root.

Using a `.gitattributes` file effectively overrides the global `core.autocrlf` git setting, ensuring that different environments don't exhibit different behavior with newlines.

This should be the first line of the `.gitattributes` file:

```
* text=auto eol=lf
```

This causes git to change newlines from CRLF to LF when files are committed, ensuring that files on all platforms use the same newlines, and preventing files with mixed newlines from being committed.

## Changing CRLF to LF

Existing repositories with no `.gitattributes` file or a `.gitattributes` file that doesn't look like the above (e.g. with `* -text`) may have files with CRLF and/or mixed linefeeds.

Existing repositories should be changed to use LF and the `.gitattributes` setting above.

Please note that changing CRLF to LF can adversely affect blame. This can be somewhat mitigated by using a [`.git-blame-ignore-revs`](https://www.moxio.com/blog/43/ignoring-bulk-change-commits-with-git-blame) file, but GitHub [does not respect](https://github.community/t/support-ignore-revs-file-in-githubs-blame-view/3256) the file as of this writing. However, the benefits of LF everywhere (and solving the problems of mixed-line endings) outweigh the costs of difficulties with blame.

To convert a repository, follow these steps:

* Commit your working tree.
* Add or change your `.gitattributes` as documented above and commit it.
* Run `git status` to confirm that your working tree is clean.
* Normalize line endings:
  * `git add --renormalize .`
* Commit any changes.
* Delete your local files:
  * `git rm --cached -r .`
* Restore your local files:
  * `git reset --hard`
* Commit any changes.
* Add the CRLF to LF commit ID(s) to a `.git-blame-ignore-revs` file at the root of your repository.
* If you haven’t already, ensure that `git blame` ignores the commit IDs in the file:
  * `git config --global blame.ignoreRevsFile .git-blame-ignore-revs`
