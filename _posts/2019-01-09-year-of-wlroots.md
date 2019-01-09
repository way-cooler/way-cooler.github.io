---
layout: post
title: Year of wlroots
date: 2019-01-09
category: blog
---
# Way Cooler
Today is the third anniversary of Way Cooler's initial commit. Three years is a
long time, a significant milestone for any project especially one that has been
basically a one-man-show for two years now.

To be frank, I didn't achieve my overly ambitious goal [from last
year](/blog/2017/12/24/way-cooler-2017.html). Way Cooler is no where near usable
as a drop in AwesomeWM replacement. It was quite a long shot considering I am
basically the only programmer working on it and I had school and two internships
last year at major companies [taking up valuable
time](/blog/2018/07/27/prehibernate-update.html). However, I should have planned
better and in the future I'm going to try not to make such broad proclamations.

That being said...

# 2019: Year of wlroots
If you haven't heard, [wlroots](https://github.com/swaywm/wlroots) is a hip new
Wayland compositor framework that Way Cooler has been using for about a year
now. It has made major strides in advancing Wayland. The library is entirely
modular, unlike wlc and libweston, so you only use what you want to use. They
have their [own host of protocols](https://github.com/swaywm/wlr-protocols) that
they are not only pushing for standardization but also are
implementing in wlroots so compositors that are using wlroots can get that
functionality for free if you opt-in. It implements the basics that every
compositor will need to implement, e.g. rendering on DRM, getting seat
information from libinput, and a solid xwayland implementation.

So I'm going to go ahead and declare 2019 the year of wlroots. Most of the work
was done in 2018, but this year is when major compositors will begin to use it.
Currently the only usable Wayland compositor that uses wlroots is sway, which is
[fast approaching a stable 1.0](https://github.com/swaywm/sway/issues/1735).
However there is a [long list of startup compositors (including Way
Cooler)](https://github.com/swaywm/wlroots/wiki/Projects-which-use-wlroots) that
are using wlroots. At least some of them are expected to come into their own as
alternatives to traditional X11 based systems this year, and it's all thanks to
wlroots.

# wlroots-rs
Thus far my main contribution to wlroots has been maintaining the
[wlroots-rs](https://github.com/swaywm/wlroots-rs) library. It has been very
unstable and has had major periods of no updates. This is because I was
splitting up my time between Way Cooler and wlroots-rs to the detriment of both.

This year I'm going to put all of my Wayland related efforts into two
initiatives:

* Making wlroots-rs stable, ergonomic, and safe.
* [Writing a book](/book/index.html) to make it easy for _anyone_ to make a
  Wayland compositor using Rust.
  
# Future of Way Cooler

Way Cooler is going on the back burner. This was a tough decision to make, as I
still use (a very ancient) version of Way Cooler every day and still mentor what
few contributors I get. However I can't commit the time to work on this, my last
semester of college, and the things I've committed to above. 

I'm not going to promise I'll ever come back to it. However, by finishing
wlroots-rs and the book I want to make it viable for others to either continue
my work or to make compositors themselves.

I'm still going to be maintaining [the
repo](https://github.com/way-cooler/way-cooler) - if anyone wants to send patches
or be mentored on working on Way Cooler, feel free to reach out.


