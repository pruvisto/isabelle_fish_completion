# Overview

This project provides experimental shell completion support for Isabelle. The main feature is the ability to complete session names in invocations such as `isabelle build …` and `isabelle jedit -l …`.

The available Isabelle sessions are determined by running `isabelle sessions -a`. If additional session include directories are specified with `-d` or `-D` in commands that support these parameters, the `ROOT`/`ROOTS` files in these directories are additionally scraped for sessions using some ad-hoc `sed` invocations. Such ‘local’ sessions are also displayed before the ‘global’ ones in the completion suggestions.

Additional completion support exists for:

- Isabelle subcommands, e.g. `isabelle comp<tab>` → `isabelle components`
  (scraped from the output of `isabelle -?`)
- Session groups, e.g. `isabelle build -X ver<tab>` → `isabelle build -X very_slow`
  (scraped from the `ROOT` files of all components listed in `$ISABELLE_COMPONENTS`)
- Isabelle components in e.g. the `isabelle components` subcommand, e.g. `isabelle components pol<tab>` → `isabelle components polyml-5.9.1`
  (scraped from the output of `isabelle components`)
- Path completion (file or directory) for arguments that take files or directories in the most important commands such as `build`, `jedit`, `sessions`
- Flag completion (with description) for tools without hard-coded completion support such as `console`, `client`, `getenv`
  (scraped from the output of `isabelle <tool> -?`; only works if the tool in question outputs a suitable help page)

# Issues
## Performance
Completion of anything scraped from the output of the invocation of an `isabelle` command takes some time (roughly a second). It is not entirely clear to me why that is – perhaps it is related to the startup of Scala. 
On my machine the delay is small enough for me to be deemed acceptable (a bit less than a second). One could easily circumvent this for most applications 
(such as completion of subcommands, session groups, components, flags) using caching since these things are unlikely to change very much in a release version of Isabelle (although it might change in a development version).

For sessions however, caching is more problematic since e.g. a typical use case is to have the AFP registered as a component and regularly update it when new entries appear.
Caching might still make sense for sessions, but it is not clear to me when and how often this cache should ideally be updated. One possible solution would be to store the value of `$ISABELLE_COMPONENTS` and hashes of all 
the ROOTS files (and possibly ROOT files) in these components and check whether any of them have changed and invalidate the cache if so.
This check is probably still much faster than calling `isabelle sessions`.

## Auto-detection of subcommands

New Isabelle subcommands are added on a regular basis, and existing ones change sometimes. To make this tool as robust as possible,
I avoid hard-coding too much support for subcommands I deem less important for everyday use. The support for these is thus implemented
via auto-detection of their options via their help pages. Most Isabelle tools have such help pages (accessed via `-?`) or at least display
one when given the `-?` option while complaining about it being an unrecognised option. Some, like `isabelle scala` (which is only a wrapper
around the packaged Scala compiler) do not and therefore don't work, but that's probably not a big problem.

Currently, we only scrape the list of available flags and their descriptions but don't attempt to also determine what arguments they
take (e.g. files, directories, sessions, session groups, etc) and complete these. This is difficult to achieve in general, since the help page 
often just says something like `-g NAME` but not what the `NAME` actually determines (e.g. a session or a session group or a theory). But one could
probably get a pretty decent result with some simple heuristics (e.g. checking whether the words ‘session’ and ‘group’ appear in the description), 
or change the help page accordingly for future Isabelle releases.
