---
layout: post
title: April wlroots Hackathon Recap
date: 2018-04-25
category: blog
---
Hi all! Sorry for the radio silence. I've been extremely busy with school but that should be finishing up very soon (I'm typing this up as I wait for my last exam to start in fact).

As a recap of what's happened over the past two months:
* Attended the wlroots hackathon in Philadelphia with the Sway team, which was a lot of fun and very productive.
* Started moving Way Cooler over to wlroots (this is reflected in the master branch now).
* Begun to stabilize the wlroots-rs API.

# Pretty Picture Update
I know I showed you a similar image last time, but there's a lot more going on to make this picture possible:

![](/assets/awesome_bar_in_way_cooler_wlroots.png)

That is the awesome bar being drawn in Lua using Cairo, rendered in Way Cooler using wlroots, with the weston-terminal being fully usable. So this is much closer to working.


# Left to do
The stuff left to do is, in order of interestingness (to me):
* Design a better architecture for Awesome to work on Wayland
  - Since this is basically a rewrite it's possible to change how this works fairly drastically. Right now the design is based on multi-threads, but I'm going to see if I can't get it down to one thread using `poll`
* Write the code for compositing windows
* Continue implementing the Awesome API

This is also the order I'm going to tackle this, since that list is in order of descending difficulty.

For anyone who wants to get involved, the gitter channel has now been deprecated! I will no longer be checking it and all communication should now be through #awesome on OFTC.
