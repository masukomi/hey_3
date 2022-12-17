#!/usr/bin/env bash


XDG_DATA_HOME="./temp"
mkdir -p temp

# timers

XDG_DATA_HOME=$XDG_DATA_HOME hey start 4 hours ago @hey +tooling
XDG_DATA_HOME=$XDG_DATA_HOME hey stop 183 minutes ago

XDG_DATA_HOME=$XDG_DATA_HOME hey start 3 hours ago @dogs +walking
XDG_DATA_HOME=$XDG_DATA_HOME hey stop 125 minutes ago


XDG_DATA_HOME=$XDG_DATA_HOME hey start 2 hours ago @cooking +food
XDG_DATA_HOME=$XDG_DATA_HOME hey stop 75 minutes ago

# interruptions

XDG_DATA_HOME=$XDG_DATA_HOME hey mary 190 minutes ago @project_x +questions
XDG_DATA_HOME=$XDG_DATA_HOME hey bob 2 hours ago +chat
XDG_DATA_HOME=$XDG_DATA_HOME hey bob 1 hours ago +chat
XDG_DATA_HOME=$XDG_DATA_HOME hey bob 30 minutes ago +@project_x +questions

XDG_DATA_HOME=$XDG_DATA_HOME hey log 1 day
XDG_DATA_HOME=$XDG_DATA_HOME hey log-interrupts 1 day

rm -rf temp
