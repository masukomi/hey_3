# NAME

Hey - a simple command line time tracker, written in Raku and backed by SQLite.

# DESCRIPTION

Hey is a command line tool that tracks your time spent on various projects that may have happened along the way. 


# USAGE

**Quickie Version**

``` text
Usage:
  hey start [<start_args> ...] -- Start a new timer
  hey stop [<stop_args> ...] -- stop an existing timer
  hey log <number> <duration> -- see a log of recent timers
  hey log-interrupts <number> <duration> -- see a log of recent interruptions
  hey running -- lets you know if there are any timers running & what they are for
  hey <name> [<start_args> ...] -- Record an interruption
  hey kill timer <id> -- Remove an unwanted timer.
  hey kill <name> -- Remove an unwanted person / thing from interruptions

    [<start_args> ...]    optional time adjustment, project(s), & optional tags
    [<stop_args> ...]     optional id, and optional time adjustments (e.g. 4 minutes ago)
    <number>              number of duration units
    <duration>            duration string. E.g. minutes, hours, days, etc.
    <name>                name of person / thing that interrupted you
    <id>                  the id of the timer to delete.
```

And now for some useful details to fill in the gaps...


# Timers

Starting and stopping timers is pretty straightforward. At a bare minimum you just tell it to start and give it a project name: `hey start @my_project` and stop it when you're done with `hey stop`

## Associating Projects & Tags

- Project names are prefixed with `@`. 
- Tag names are prefixed with `+`. Neither can contain spaces.
- Every timer event must be associated with _at least one_ project.
- Tags are optional.
- Order of tags and projects doesn't matter. They can be mixed too.


``` text
# simple usage
hey start @project +tag1 +tag2
hey stop

```

## Backdating Timers

The start and stop of a timer can be backdated using relative or absolute times. 

Time modifiers must come immediately after start/stop. 

### Absolute Times 
Absolute times are specified with 12 hour or 24 hour time formats. You can also just specify the hour with no minutes. The expected format is "at" followed by the time. 

``` text
hey start at 4 @project +tag
hey start at 4:30 @project +tag
hey start at 16:30 @project
```

The system will always assume you mean the most recent corresponding time. So, if for example it's 6PM and you say `at 4` it's going to assume you mean 2 hours ago.  If, however it's 3PM and you say `at 4` it's going to assume you meant `4 AM`. This will carry-over to the previous day if you leave a timer running overnight. 

### Relative Times 

Relative times come immediately after start/stop and follow the syntax of `<number> <time unit> ago`

You must include "ago" as it provides a clue to the code as to what you're intending.

``` text 
# backdating 
hey start 4 minutes ago @project +tag1
hey start 3 days ago @project
```

#### Supported Duration Words

You can use any of the following duration words. 

* second
* seconds
* minute
* minutes
* hour
* hours
* day
* days
* week
* weeks
* month
* months
* year
* years

### Multiple Timers
Hey supports multiple simultaneous timers. There's nothing fancy to it. The only special note is that `stop` will stop the most recent one unless you provide an id. 

### Stopping A Specific Timer

To stop a specific timer you just give it the integer id shown in the log.

`hey stop 12`

### Killing A Specific Timer
Sometimes, things don't go as planned. For example, I started a timer
to go walk the dogs, left my computer, and unexpectedly ended up
eating lunch. That timer was no good. 

To kill an unwanted timer say `hey kill timer <id>`

```text
hey kill timer 4
```

A timer's id is shown when you create a new timer, or when you view
the log.


## Viewing the Log

`hey log <number> <duration>`

![example log output](../readme_images/images/all_timers.png)


This uses the same duration words as in backdating. 

``` text
hey log 4 days
hey log 24 hours
```

Note: when it comes to durations of a day or larger it uses cultural meaning not literal meaning. 

So, for example:

* `hey log 1 day` is going to get you _today's_ log. 
* `hey log 1 week` is going to get you _this week's_ log. Monday is treated as the start of the week, so if it's Monday you'll only see one day worth of records. 
* `hey log 1 month` is going to get you _this month's_ log.
* `hey log 1 year` is going to get you _this year's_ log.

Day's an larger all count from midnight. All times _should_ be local.

If you want a specific and literal amount of time use seconds, minutes, or hours. 

So, for example, `hey log 1 day` doesn't get you the past 24 hours worth of logs. It gets you everything from midnight yesterday. If you really want 24 hours, just say `hey log 24 hours`.

# Interruptions

Recording an interruption is the same as recording a timer, except that you start with the name of the person / thing that interrupted you, and project is completely optional.

``` text
hey bob
hey bob at 9:15
hey bob at 10:30 +gossip
hey bob at 11:15 @project_x +questions
hey bob 20 minutes ago 
hey bob 10 minutes ago @project_x +questions
```
## Viewing the Log
This works the same as viewing your timer logs, but you say "log-interrupts" instead of "log"

`hey log-interrupts <number> <duration>`

![example log output](../readme_images/images/all_interruptions.png)

# INSTALLATION

Hey is written in [Raku](https://raku.org), and uses the
[zef](https://github.com/ugexe/zef) package manager for installation.

If you've already got Raku and `zef` installed then just run:

`zef install Hey`

If you don't have Raku installed then...

## Raku install quick-guide

My recommendation is to use [Homebrew](https://brew.sh/) to install
[Rakudo](https://rakudo.org/) Regardless of if you use Homebrew, or
download from the main site, you'll want the [Rakudo-Star](https://rakudo.org/star) package. This brings along a handful of other
useful things, like our package manager: [zef](https://github.com/ugexe/zef).

```
brew install rakudo-star
```

Now, go back and run the `zef install Hey` command from above.


## Coming soon

### Tagging After The fact
Sometimes you'll record an interruption, or some work, but forget to add a tag. 

### Reports
* Graph Interruptions over time, to find parts of the day where you're most likely to be able to focus, or need to hide.
* Graph Interruptions by people to find out who you need to talk to.
* Graph Interruptions by tag or projects to find out where you would best benefit from adding documentation.

### Configuration
It'd be nice to be able to configure things, such as when the start of the day is. Many of us work past midnight, and consider it part of the prior day's work. So, it'd be nice to have the logging use our preferred "start of day" time. [Here's the GitHub issue for that feature](https://github.com/masukomi/hey_3/issues/3).

I'm betting you might have ideas for configurations too. Like, maybe colors for specific data types in the report? 

# CONTRIBUTING

Pull Requests are _very_ welcomed. 

I'm using this daily now so there will be modifications and improvements over time. I'm especially interested in adding useful reporting and data extraction functionality. 

Let's chat [on Mastodon](https://connectified.com/@masukomi) if you've got some ideas. Alternately, just [file a new ticket on github](https://github.com/masukomi/hey_3/issues).

Note: this app's version numbers follow strict [Semantic Versioning](https://semver.org). 

## Tests

The test suite uses [bash_unit](https://github.com/pgrange/bash_unit) because testing an app where 90% of the behaviors are based upon side-effects of data that may, or may not, have been persisted in the DB is way easier to write System tests for than Unit tests. If you feel like writing some Raku unit tests with all the stubbing that that will require, I'll happily merge the PR. 

Regardless of unit tests, if you do add / change functionality please include additional bash_unit tests with your PR.

The bash_unit tests can be run by changing into the `bash_unit_tests` directory and running `bash_unit hey_test.sh`

Note that these will work on a local test database, so you don't have to worry about hurting your real time & interruption tracking data. 

# AUTHOR

masukomi (A.K.A. Kay Rhodes)

- Web: [masukomi.org](https://masukomi.org)
- Mastodon: [@masukomi@connectified.com](https://connectified.com/@masukomi)

COPYRIGHT AND LICENSE
=====================

Copyright 2022 Kay Rhodes & distributed under the GNU Affero General Public License version 3.0 or later.

