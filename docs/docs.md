---
layout: page
title: Documentation
permalink: /docs/
---

Way Cooler documentation is split into two modules. 

// TODO Use lua\_doc\_sections to generate these
{{ site.lua_doc_sections }}
* [Lua documentation](/docs/lua) - describes how to configure your `init.lua` and how to use `util` functions to communicate with Way Cooler.
  + [Configuration](/docs/lua#configuration)
    - [`programs`](/docs/lua#configuration-programs)
    - [`windows`](/docs/lua#configuration-windows)
    - [`mouse`](/docs/lua#configuration-mouse)
  + [Utils](/docs/lua#utls)
    - [`program`](/docs/lua#utils-program)
* [D-Bus documentation](/docs/d-bus) - describes the various signals and methods exposed to IPC clients.
  + 
