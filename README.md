# DbSmo PowerShell Module by Cody Konior

![DbSmo logo][1]

[![Build status](https://ci.appveyor.com/api/projects/status/yhocdjkg8eq5scqa?svg=true)](https://ci.appveyor.com/project/codykonior/dbsmo)

Read the [CHANGELOG][3]

<b>Test this extremely carefully before deploying to Production. This isn't a trivial module.</b>

## Description

DbSmo iterates a SQL SMO Server or WMI object and writes the contents of every readable property to a database schema it builds
and updates and maintains on-the-fly as it discovers new information in your environment. Where possible (SQL 2016+) those tables
are automatically made temporal tables to keep a history of your servers over time.

Configuration settings? CPU affinities? Registry information? Logins? Databases? Database settings? Pretty much everything, all
neatly ordered in tables named after the SMO objects and linked with foreign keys (exactly as if it had been built by hand).

This makes it excellent to find out what changed on your servers on this day last year, or comparing settings across hundreds of
servers at once with simple T-SQL.

## Installation

- `Install-Module DbSmo`

## Major functions

- `Add-DbSmo`
- `Add-DbWmi`

## Demo

![DbSmo completely parsers a server in seconds][51]

## Tips
- The destination database should be SQL 2016 or higher to take advantage of temporal tables, otherwise there is no historical
  data kept.
- The module uses [Jojoba][4] so if you pipe in a list of server names they'll be processed in parallel.
- On the very first run when the bulk of the database is being constructed, there is a higher chance of deadlocking if multiple
  threads are trying to write at the same time. This will reduce in frequency on subsequent runs.

[1]: Images/dbsmo.ai.svg
[3]: CHANGELOG.md
[4]: https://codykonior.github.io/Jojoba

[51]: Images/dbsmo.gif
