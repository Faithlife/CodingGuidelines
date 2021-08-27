# Delete Unused Code

As code is written, previously used variables become unused, previously called functions become uncalled, etc. Be sure to delete this old, unused code lest it become a distraction for readers of your code.

Any code that will never be executed doesn’t belong in the source files. If the code may be valuable in the future, move it somewhere else, or at least make sure that the code is in the source control history before deleting it, and consider adding a comment describing the code and where to find it.
