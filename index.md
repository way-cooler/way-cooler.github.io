---
# You don't need to edit this file, it's empty on purpose.
# Edit theme's home layout instead if you wanna make some changes
# See: https://jekyllrb.com/docs/themes/#overriding-theme-defaults
layout: home
---

Way Cooler is a tiling [Wayland](https://wayland.freedesktop.org) window manager, written in [Rust](https://www.rust-lang.org), configurable using [Lua](https://lua.org), and extendable with [D-Bus](https://dbus.freedesktop.org).

# Extendable
Way Cooler gives the user full control in extending the capabilities of the window manager, without having to write a single line of Rust. Core functionality is implemented as D-Bus clients, allowing programs such as the lock screen and status bar to be implemented in any language that can speak the D-Bus protocol. 

[Consult our D-Bus documentation for more details](/docs/d-bus)

# Configurable
Lua is a first class citizen of Way Cooler. Tiling options, window rules, and theme options are controlled by the integrated Lua thread. Short scripts, that are otherwise too short to be proper client programs, can also be written to extend the capabilities of the window manager.

[Consult our Lua documentation for more details](/docs/lua)

# Secure
Way Cooler is designed from the ground up to be secure. Rust prevents Way Cooler from ever having a data race, use after free, or a segfault. Security vulnerabilities from buffer overruns are a thing of the past. 

In order to maximize the security guarantees of Wayland, all client programs must first be authenticated using Lua, and are only granted the permissions they require in order to do their task. Applications can no longer read your keystrokes unless you give them explicit permission to do so.
