---
layout: post
title: Pre-hibernate Update
date: 2018-07-27
categories: blog
---

# What's happening

Way Cooler is going to be entering an official hibernation period for the next three months (as opposed to the unofficial hibernation period that it's currently in).

I will not be pushing any code for three months due to contractual obligations I have with Google. This limitation will be lifted on November 2nd, 2018.

Patches will still be accepted during that time, there just won't be any from me.

# Wait is this still being worked on??

I still fully intend to see Way Cooler through to completion, however it's been very difficult to work on it recently due to various personal complications (back-to-back internships and schooling, constantly moving, aforementioned contractual obligations, and being forced to use Windows for three months a as a development environment which I wouldn't wish on my worst enemy). This will change in after November, as I'll have no obligations whatsoever for the rest of the year.

# So why is this thing taking so long?
You can thank Gnome for that.

Gnome has had performance problems and [part of the problem](https://anholt.github.io/twivc4/2018/05/30/twiv/) is having Javascript, an interpreted GC language, in the same thread as the compositor handling input and drawing to the screen. [A hypothetical Gnome 4](https://wiki.gnome.org/Initiatives/Wayland/GnomeShell/GnomeShell4) would fix those problems, but for now it's too late for Gnome 3.

Way Cooler would run into similar problems with the current design as of [today's master](https://github.com/way-cooler/way-cooler/tree/46940d02bcef7c6980021da2244b5af8ab085a9e). I'm looking to fix those problems before they happen by splitting the program up into two binaries: `way-cooler` the compositor and `awesome` which acts just like today's awesome but written in Rust and talking Wayland to `way-cooler`.

This will mean more work, but a better experience at the end. In fact it already enables a feature that I couldn't do before with the old system: in place restart of the Lua thread without dropping clients. It's assumed `awesome` can be killed and restarted at any time, but `way-cooler` must always be running.
