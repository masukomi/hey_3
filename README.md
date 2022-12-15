NAME
====

Hey - A time and interruption tracker.





DESCRIPTION
===========

Hey is a command line tool that tracks your time spent on various projects and any interruptions that may have happened along the way. 


USAGE
=====

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




SYNOPSIS
========


AUTHOR
======

    <>

COPYRIGHT AND LICENSE
=====================

Copyright 2022 

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

