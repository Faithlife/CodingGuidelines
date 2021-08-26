# Describe Merge Commits Well

Branch labels in git are ephemeral, so it's important to use the commit message to preserve information about the branches that were involved in a merge.

* **Do** override the default commit message. At the command line, use `git merge --no-commit `*`other_branch`*, then `git commit` with a custom message. In SmartGit, a commit dialog should be shown; edit the message there.
* **Do** name the branches being merged in the commit, for example, "Merge sync topic branch into master.", or "Merge 4.2a into 4.2b.". You may omit "into master" if `master` is the first parent of the merge commit.
* **Consider** explicitly naming the person whose forked repository you're merging from if it's important. (Most of the time, the purpose of the branch that is being merged is more important than the person--if any--who owns the fork that's being merged.)
* **Do not** use commit IDs in the message. The parent commit IDs are always included in the merge commit itself.
