---
layout: post
title: Way Cooler Post Mortem
date: 2020-01-09
categories: blog
---

# Way Cooler Postmortem

I started Way Cooler 4 years ago today. No real significant process has been
made on the project for about 2 years now and my interest has waned
considerably. I'm officially ending the project. As no one else has contributed
seriously to it no successor is named. Anyone is free to fork it or use the name
(as long as attribution for the original source is given, per the MIT license).

It being my biggest open source undertaking to date I would be remiss if I did
not spend some time reflecting on the project. What I did right, what I did
wrong, but fair warning it's a bit long!

## Way Cooler: A recap of 4 years

Way Cooler was a Wayland compositor started by me and [Snirkimmington
](https://github.com/snirkimmington)(Snirk for short) in college. It began as an
effort to understand what Wayland was and to experiment with making a better
desktop environment. We had both used AwesomeWM, and though I had switched to i3
by that point, the flexibility of AwesomeWM was something I sometimes missed and
was something we wanted to include in our hypothetical desktop environment.

### Choosing a language and a framework (January-February 2016)

My original plan was to write it in C, since that seemed to be the prevalent
language for compositors (at the time there was only Gnome, KDE, Weston, E,
Orbment, and an early version of Sway). Snirk convinced me to look into Rust. He
was interested in it for its strong reliability guarantees (his area of research
being compiler and language design). It's unique approach to memory management
drew me in and after experimenting with the language we began work on Way
Cooler.

Back in 2016 there was really only three generic Wayland frameworks: libweston,
swc, and wlc. Libweston allows custom compositors to be implemented on top of
Weston, the reference Wayland compositor, using a plugin system.

> Today, libweston is still only used in Weston as far as I'm aware. The plugin
> based model has not taken off. In my opinion, this model has its merits
> however libweston did not give enough control to merit the simpler codebase
> that would result from using it. Something similar could be done today by
> building on top of wlroots. I'm aware of wltrunk which, while not trying to be
> a plugin-based library per-say, is trying to provide a more
> works-out-of-the-box experience similar to libweston or wlc.

swc I don't know much about. It did not have an X11 backend which made
development in it a bit hard, which is at least why Sway didn't use it.

wlc was a more generic framework that required you to do more of the heavy
lifting than libweston. However, it was still a very high level library: it
provided input handling (e.g. via libinput), output handling (via DRM, X11 and
Wayland nesting), and rendering (through a simple "redraw the world" on any
client update).

> wlc is long since deprecated and no modern compositor uses it (except Way
> Cooler 0.8.1, the last release). It had a multitude of technical limitations
> that were unable to be fixed without a complete rewrite. This deserves a post
> by itself, but the final result is that Sway developers made wlroots to make
> up for wlc's limitations.

We went with wlc for 3 reasons:

1. It was more clear how to wrap the API to be used by Rust. It had a very
   simple memory model and a very small API surface.
2. Sway was already using it and had kicked the tires, as it were. It had also
   proven that it was possible to make a tiling compositor with this framework
   when there was some doubt such a thing was possible in libweston.
3. No one else used libweston, tiling or otherwise. It was easier to go with a
   framework that others already relied upon

We toyed around with the example compositor and began wrapping the wlc library
so that it can be used in Rust. We set a short-term goal of converting the ~400
line example compositor from C to idiomatic Rust.

> Setting a short term goal like this was a great idea and something I will
> continue to do today. Previous attempts at big projects failed because the
> long term vision did not pan out before my initial enthusiasm petered out.
> Setting a short term goal helped me feel like I accomplished something before
> the compositor was usable.
>
> However, there were two mistakes that were made at this stage that, at first
> glance, seem contradictory: we jumped too quickly into wrapping wlc, but at
> the same time spent too much time on it.
>
> Wrapping a C library to be used by Rust is no small feat, and if we knew what
> problems we were unintentionally causing for our future selves we probably
> would have given up then. The library was very unsound -- meaning it was
> possible to cause memory unsafety from what we erroneously reported was "safe"
> Rust code. If we spent more time learning the language and sought help from
> the wider Rust community in wrapping the library we would have avoided a lot
> of headache. Instead, we plunged ahead despite not knowing the language well.
>
> Despite rushing into wlc development we also spent far too much time on it. It
> took about 2-3 months before we had the basic example working in "safe" (as
> far as we were aware) idiomatic Rust. The API surface is very small, it should
> not have taken that much time (especially if we had sought help). A large part
> of this is due to having classes at the time, so I'm perhaps being too harsh
> on my past self here. Still, work in the Way Cooler repository didn't really
> begin until April. Much later when working on wlroots-rs, I tried to switch to
> a more pipeline based approach, only working on Way Cooler again once I was
> sure wlroots-rs was sound. This took a while but was ultimately the best bet
> because I would have otherwise had a much less sound base than even wlc. That
> approach takes longer, but when correctness is on the line (as it always is in
> Rust) it's best to pay that cost upfront.

Within two months we converted the example to Rust and used that as a jumping
off point for Way Cooler in a separate repository. rust-wlc would continue to be
updated as the API improved and we wrapped more of the interface, but most
effort went into Way Cooler after this.

### Designing a personal compositor (Throughout 2016)

In conjunction with our work on wlc, Snirk and I brainstormed on what we wanted
Way Cooler to be. From the get-go our goal was to be a blend of i3 and
AwesomeWM. This blend came naturally from our existing desktop environments: he
made heavy use of AwesomeWM's flexibility and I couldn't live without i3's
tiling system.

For the tiling I wanted nothing changed, except for the option to use an
Awesome-based tiling mechanism using Lua. I knew others (Snirk included) who
found i3's tiling to be too complicated. Giving them the option to use something
else, while at the same time having a strong, common default, seemed reasonable.

Snirk had much he wanted to change about the AwesomeWM API. It had evolved
haphazardly over the years and thus had a few issues. There was constant
instability between versions as APIs were deprecated and removed far too
quickly. Async versions of functions were added which led to a split in the
ecosystem. 3.x -> 4.x was a massive, incompatible jump similar to Python's 2 ->
3 jump. Many systems are still stuck on 3.x configurations. Finally, it was all
too complicated. The default `rc.lua` is ~500 lines. If these lines are removed
the window manager is essentially unusable. Key functionality should either be
moved into the compositor or the layout of the default configuration should be
better annotated (perhaps in multiple files or layered like in spacemacs).

During this early design phase we also wanted to allow users to code their
extensions in languages other than Lua. We added D-Bus support that mirrors the
Lua functionality to accommodate this. A colleague of ours had interest in
writing a status bar for Way Cooler, but he wanted to write it in NodeJS. Since
it was just the two of us, we begrudgingly agreed to ship that if he ended up
writing it. These two features were included in the initial announcement we made
later in 2017. These was our first major design mistakes.

> My mindset at the time was that of a product designer. It was how we were
> taught to think both by school and society -- we were designing a product to
> sell, despite the fact that the price was $0. This is a misguided way to
> approach open source. Though I had been aware of and had taken advantage of
> open source since high school I still fell victim to treating my open source
> project like a business. Specifically, like a startup. I made major
> concessions because growing the project was my main objective. Maintaining a
> D-Bus bridge just so users don't have to write Lua is a waste of a development
> effort. A status bar written in NodeJS is an objectively terrible idea and was
> the most wide-spread criticism once the project was announced. Ultimately the
> D-Bus bindings were left to languish and the NodeJS bar was swiftly canceled.
>
> Concessions always need to be made in a project, but these were major
> concessions I did because I had some vague idea that these were popular and
> thus my project would become popular. While I ultimately chose Rust because it
> was a good fit (at the start) this was also seen as "hip" technology I was
> using.
>
> This mindset would continue to dominate my thought process, up until a few
> months ago. Oddly enough this was the hardest thing to accept, despite how
> obviously misguided the exercise was. At the start I was simply delighted in
> making something and then using it. That act of creating something that I
> could then use was extremely delightful. After that faded however I chased
> after being popular. There was real delight in seeing the Github star count
> and download numbers tick up. Seeing the first post of Way Cooler in
> /r/unixporn felt like a real triumph despite how poorly designed the whole
> thing was.

We also sketched out plans for standard utilities that Sway also included at the
time: a background program, a lock screen, and a screen shot tool. Like Sway, we
were limited by wlc so we could not make our own custom Wayland protocols (which
would allow generic background programs to be used, instead of
compositor-specific ones). These programs were more or less implemented as
hacks, either in Way Cooler (e.g. the background was just like a regular client
so we had to detect it and treat it specially) or in wlc (an explicit API was
exposed to grab pixels from the output buffer that was otherwise not exposed).

### Mistakes with unsafe Rust (Summer 2016)

During the summer there was finally time to devote more time to Way Cooler (even
though both Snirk and I had summer classes, they were light work loads). He made
significant progress on the Lua side whilst I focused on the tiling. We quickly
achieved a few milestones.

He was able to get a callback to trigger in Lua on mouse movement after just a
week or two. He used [hlua](https://github.com/tomaka/hlua), a library that
wrapped the C Lua implementation. hlua has since been supplanted by
[rlua](https://github.com/kyren/rlua), since hlua had severe soundness issues
similar to wlc. We eventually switched to rlua, but at the beginning hlua worked
well for us. Snirk also worked on the D-Bus interface, since that went
hand-in-hand. This progress was much slower. He reported to me that the D-Bus
library for Rust was awkward to use, and so he was spending time making it
easier to use with a macro. I didn't understand Rust macros at this point, as
that is an advanced topic, except that they functioned similar to Racket's macro
system (which I did know, albeit only at a surface level). I trusted him to
spend his time wisely on it.

Initially since we were working on disjoint parts of the codebase we didn't
really review each others code. This was both of our faults. We were
essentially blind to what the other was doing. We were unable to effectively
determine if the other's design made sense since we lacked context. Our reviews
thus consisted of surface level flaws -- e.g. style and idiomatic Rust usage.
While useful, we were the worst off for not understanding what the other was
doing. He expressed later that he felt cut off from what I was doing since it
was so hard to read and understand my code. Having worked with him on other
projects in other languages I don't think this is due to the language choice.
Code written by others is hard to read and by this point we were still very
inexperienced. We could write code, but reading code is an oft neglected skill
for early self-taught programmers (i.e. both of us).

> The inability to read and make meaningful judgment on code written by others
> is a problem I've seen beyond just this personal project. This has come up before
> in my various day jobs. I'm not sure how best to combat this, except for
> defining a good process and practicing it. This is something I plan to work on
> personally.

My work on tiling was limited at first because we went through 3 designs of a
tree in Rust. This is a basic data structure, however Rust does not provide one
(beyond a binary search tree). Because of the borrow checker this is a
much harder problem than it is in other languages. This is a hidden cost of
Rust: it makes certain patterns that are common in most other "common" languages
nearly impossible because of the lack of a garbage collector coupled with its
strong safety guarantees.

The first attempt was more or less what every Rust newbie does when they need to
make a tree that needs mutable pointers to its parent:

```rust
pub struct Node {
    parent: Option<Weak<RefCell<Node>>>,
    children: Vec<Rc<RefCell<Node>>>
}
```

This is basically unusable type soup. Even with type aliases its so error prone
that it was swiftly abandoned. Snirk wrote the second attempt, as he was more
experienced in the language at the time. His version used `unsafe`, and the
parent pointer was now a `*const Node` - i.e. a raw, unsafe pointer. We used
this version for a while until I encountered an odd bug once I added workspaces.

> Whilst developing the tree I had "debug" code that would validate the state of
> the tree. It had to be a valid "i3 tree": i.e. one root, with n outputs, which
> had workspaces, which had containers, which had views. It validated that there
> were no loops, parents matched the children, that nothing pointed to the root,
> only root pointed to the outputs, workspaces were unique across all outputs,
> etc. This debug code was enabled only on debug builds, since an abort would take
> down the entire environment. This was essentially "fail early, fail often"
> which I learned from "Pragmatic Programmer" (which I highly recommend, though
> it is slightly dated it is still relevant).

Thanks to my debug code I was able to quickly catch that when I switched from
workspaces 1 through 5 it would segfault after going to workspace 5. At first I
suspected that there was a bug in wlc -- after all we had gotten a few already
from other misuses of the API so it seemed reasonable. Once I enabled my debug
code though I realized that it would crash much earlier -- the entire tree was
screwed up after switching to the 5th workspace, every time. I was still new to
debugging memory issues, but I was more experienced than Snirk so I tackled it
with the amount of unearned confidence that only someone who has know idea what
their doing can feel.

It became clear that our tree was not sound once I consulted the rules of unsafe
more. Because we used a vector it would allocate 4 spaces (for some reasonable
default) and when the 5th workspace was allocated all of our parent pointers
would become dangling.

This was a valuable, if late and painful, lesson on how Rust's unsafe keyword
actually works.

> I'm not sure what I could have done differently here, except to reach out to
> the wider community the moment I started using unsafe Rust. I have seen time
> and time again someone post in /r/rust something obviously unsafe. They are
> always helpfully corrected and they avoid the pain that I went through. Though
> Rust's unsafe is a unique and unusual feature, escape hatches should be not
> abused as readily when one is a beginner.
>
> One feature of Rust that I see abused again and again even by experienced
> programmers is macros. With procedural macros the problem has only gotten
> worse. Macros can be useful, in niche contexts. But when over applied it leads
> to unreadable code. C++ programmers who convert to Rust are the main culprits
> here. This seems to be a general mindset issue, where idioms are translated
> more or less directly even if it's not idiomatic. Rust has this problem worse
> than other languages since its 1) new and 2) constantly adding features. This
> is my major problem with the language, which is shared by C++. A more stable
> language would not have this problem.

We switched to use petgraph, a Rust library for graphs. A graph is just a more
general tree, and though it was less efficient (and a complicated dependency) it
stayed the basis for the tree until the very end. The tree wrapper code was
written by Snirk. Though a hack, the adaptor pattern as applied here helped us
get to the important parts and it was not a major bottle neck as far as I'm
aware. When strapped for time, or when integrating with an old system this is a
great pattern to utilize.

### The first release (August, 2016)

On Friday, August 12 2016 Snirk and I cut the 0.3 release and officially
announced Way Cooler to the Linux and Rust communities. We posted in /r/rust,
/r/linux, /r/programming, and hacker news. The posts did really well and we were
happy to answer all the questions we had. We didn't have a website at the time,
instead we spruced up the README with a video demonstration. At the end of the
day I happened to check our star count and was floored to see it was already at
400 stars from the first day. Snirk and I couldn't believe it, we didn't expect
the level of attention it got, especially in the very welcoming Rust community.
We were extremely excited for the future of the project. The gitter chat we set
up for the project was suddenly active with potential users. We were quick to
explain our plans, with a few people promising to contribute patches (few did,
the most significant patch being much later fixing server side borders for
tabbed and stacked containers).

It was a very good idea to announce the project once there was something to
present. Announcing intent without anything to show for it looks bad (e.g. the V
language received flack for that in 2019). Though it was very rough it was
enough to garner significant interest.

Though I tried to debug Way Cooler as well as I could (even attempting to use it
for a full day) there was still one significant bug that got through. In
rust-wlc there was a misuse of `CString`, a somewhat common though serious
footgun in Rust where a pointer is left dangling because of a temporary (a much
more common problem in C++). This particular instance that was blowing up was
the configuration that would configure which keybinding did which action. It
never blew up on my machine because it was UB. Some users reported crashes,
others reported keybindings simply not working. Using user coredumps (a new
thing for me, all previous coredumps were from my local machine) I was able to
apply a fix within the week.

> I don't think there's any way we could have caught this particular bug without
> investing much more in automated tests. Ultimately this always seems to
> happen, even to the best of us, so I don't see this as a mistake so much as
> just another reason that testing is important.
>
> What's much more telling from this anecdote is how much unsoundness was in
> early versions of Way Cooler. A large part of the marketing message for Way
> Cooler was that it was memory safe because Rust (and thus more reliable).
> Though this became more true, it was certainly not the case at the start.
> Many, many Rust projects use this inherit feature of Rust as a selling point
> for their own software. As someone who once touted this as a feature, I'm
> hesitant to do this in the future.
>
> Many Rust projects do this explicitly in their marketing, to the point that if
> you're application is written in Rust it implicitly sends the message "because
> this is written in Rust it is better". Way Cooler and Actix are counterpoints
> to this message: they both relied on UB because the developers were ignorant
> of how difficult unsafe Rust is to use. Even for projects that are safe, this
> is a feature to the _developer_, not the user. Projects need to stop
> advertising "Written in Rust" as a feature.

I started adding more i3 tiling features in earnest. Before long I was using it
as my main window manager, which only increased my output.

> Dogfooding is an amazing way to encourage yourself to be productive.
> Especially in something you use everyday. If your day job makes something you
> use every day then you'll be much more productive. Alternatively, being able
> to see the impact of your work on others (either through direct user feedback
> or numbers) can have a similar effect.

Snirk was not as productive since he did not use the window manager full time
ever, as far as I'm aware. He was used to a much more integrated system with his
Lua scripts and Lua-based tiling.

### Snirk Leaving (October 2016)

Snirk's contributions slowed to a stream, to a trickle, and finally stopped in
late 2016. I can only speculate to his decreased interest, but there are 3 main
factors that I think led to me talking to him about stepping down from the
project.

First, he wasn't using Way Cooler. This made it less delightful to add new
features. In order to use Way Cooler he would need to add his own tiling and a
significant portion of existing functionality he enjoys in AwesomeWM. Even just
a subset of that functionality (like my initial i3 features) would have taken
considerable effort.

> One way I could have solved this problem would be to talk with him about a
> subset of features that he desires and help him implement them.

Second, he was focusing more on school at the time. This might be the main
reason, as he spent too much time on Way Cooler during the previous summer and
his grades were suffering. Mine suffered too, alas he was more responsible than
I.

> Nothing can be done about this from my perspective, except more open lines of
> communication so that he would not promise things that he could not accomplish
> because of his school commitments.

Third, I was overbearingly obsessed with the growth of the project. After the
amazing response I spent hundreds of hours over 3 years trying to grow the
project. Because I treated it like a product I set up expectations from him like
he was a fellow employee, not the volunteer that he actually was. This
ultimately pushed him away as I was demanding too much of his time.

> This is my biggest regret, by far, in the project. Even if the effect is not
> as big as I perceived, my treatment of him put a strain on our relationship. A
> project should never come before more important things in life, and I should
> have handled this much more gracefully.

### i3 compatibility, doubts on next features (2017)

By the end of 2017 (and the release of `0.7.0`) [I had implemented all the
features I needed to feel comfortable in Way
Cooler](http://way-cooler.org/blog/2017/12/24/way-cooler-2017.html). The i3
tiling was even better than Sway, in some regard (one specific feature I had
first was remembering the last focused container for an arbitrarily long
history, not just the last one), I had a custom IPC mechanism as well (although
via D-Bus and not a unix socket), and I had a custom background, lock screen,
and screenshot taker apps (again just like Sway).

> though the screenshot taker (still) has a bug that causes the colors to be off

The features that were based on AwesomeWM, specifically the parts that were
scriptable were considerably lacking however. You could change the colors of the
borders around windows, change keybindings, and specify programs to run on
startup. These were all features that could be done with a static configuration,
but Way Cooler was achieving it through an entire embedded Turing-complete
language that was more or less going to waste.

During the last half of 2017 I thought about where the project should go and
came to the conclusion that Way Cooler wasn't solving any real problem that
others had. It was half solving both the i3 and AwesomeWM niches.

### Pivoting to AwesomeWM clone (Late half of 2017)

I decided to pivot the project to fit what I perceived as a "gap in the market":
a full Wayland AwesomeWM clone. Because it's technically possible to have i3
tiling in AwesomeWM (you just need to implement it yourself in Lua) I decided I
could still use Way Cooler if it was an AwesomeWM clone. I reached out to the
AwesomeWM maintainers and it seemed like a good idea so I started profiling
exactly what will need to be done.

I went through a few false starts. I had switched to rlua by this point, which
was a very high level library for Lua. It didn't allow me to do certain unsafe
operations that AwesomeWM was doing in their Lua code that I would need for full
compatibilty. At first I tried to just bind to the Lua libraries myself, but
there was so much unsafe code that had to be written that instead I decided to
fix the pain points in rlua itself. I submitted a few patches and issues that
let me do various things (namely around user data and including the Lua debug
library).

I essentially started Way Cooler over from scratch, trying to build one massive
binary that would be both compositor and Lua interpreter. I was starting from
scratch since at the same time I was moving from wlc to wlroots.

### Committing to wlroots, wlroots-rs (2017)

By this point wlc was far too limiting and a big discussion was had [in the Way
Cooler issue tracker](https://github.com/way-cooler/way-cooler/issues/248) about
the future of the project. The main stakeholders were Way Cooler, Fireplace (the
second Wayland compositor written in C), and Sway. The Fireplace devs reached
out to me because [Sway was fed up with
wlc](https://github.com/swaywm/sway/issues/1076) and the discussion evolved from
there.

> This was a critical point not just in Way Cooler's development, but Sway's and
> Wayland as a whole as well. Because of the discussion that went on there and
> on IRC wlroots was born which has had a massive positive impact on Wayland
> as an alternative to X11. The power of these disparate projects collaborating
> on a shared design helped create a generic platform that future compositors
> can be built on. If nothing else, I think wlroots makes a great open
> source development success story.

Way Cooler went with wlroots. To reiterate my position at the time, I didn't
think it was feasible to build a library in Rust. Not enough developers knew
Rust, so the ability to get contributors was low, and it would be more work to
expose a C API alongside a Rust one. It would make more sense to make a better
solution for the problems wlc solved and then wrap it, like what we were doing
before.

I still stand by that decision. I think the "Rewrite it in Rust" mentality is
dangerously pervasive and a sign of poor engineering. A pragmatic programmer
tries to work with the existing ecosystem and rewriting everything in your pet
language is not working with the existing ecosystem.

My main contribution to wlroots, apart from a few direct patches, was to write
wlroots-rs. Unlike rust-wlc and hlua it would be a safe library, akin to the
safety guarantees of rlua. This design would hopefully encourage others to use
the library as well, not just Way Cooler.

I would spend most of 2017 and 2018 trying to make this library safe.

### Splitting up the binaries (2018)

In 2018 while I was working on rewriting Way Cooler to use wlroots-rs and be
AwesomeWM compatible I ran into a bug once I got timers working. If I
"restarted" by throwing away the old Lua context and making a new one it would
trigger a segfault. This bug was not in rlua, but rather in glib. This library
is used by AwesomeWM to implement timers. The library would keep pointers to the
old Lua context, because it was designed to trigger some arbitrary code after
some time, and in this case the arbitrary code was Lua code. All of this was by
design.

The way AwesomeWM handled this was a "restart" in AwesomeWM just re-`exec` the
binary. This was possible in X11 because a WM is just a client. This _isn't_
feasible in Wayland because a compositor is the server, and so to re-`exec
way-cooler` would cause all clients to be disconnected. This is a terrible user
experience so I had to redesign the project again.

This set me back even more time as I had to spend time re-architecturing the
project. Eventually I figured I would just have to emulate X11 here -- there
would be a privileged client process that would implement the AwesomeWM
compatibilty and I would implement the compositor as a program it would talk to.
The main way they would share data was through custom Wayland protocols. In
essence I was recreating X11 in Wayland.

> At this point, I should have realized this wasn't feasible and considered
> whether it was worthwhile to continue. However, after writing code for this
> project for 2 and a half years I was committed to seeing this through to the
> end. Even though this was an objectively bad design I didn't want to have to
> start over for the 4th time.
>
> I would waste another year and a half on this poor design just because I
> didn't want the project to fail. By this point though I had already caused the
> crucial design flaw: I was no longer designing something for myself. My
> motivation would never be the same if I was just conforming to an already made
> spec for something that fundamentally went against the ideas of the platform.
> AwesomeWM will _never_ be ported to Wayland, unless terrible hacks are used in
> order to do so. Instead, a fresh new attempt at something _like_ AwesomeWM
> needs to be considered and built. The weight of backwards compatibilty
> forcing unpleasant design decisions will kill any other attempt.

### Hibernation excuse (2018)

By 2018 my motivation for the project was at an all time low. wlroots-rs was
causing an unnecessary amount of stress. I was obsessed with making sure it was
100% safe, which required thinking of every major edge case possible. I would
constantly have days where I would find a safety hole in my design and I would
have to rip everything up and start basically from scratch.

All the safety code I added made it nearly unusable so I had to make obtuse,
awkward macros (and later proc macros) in an attempt to keep the library
ergonomic.

There was roughly zero work done on Way Cooler during this year, all of my
efforts went into wlroots-rs.

My efforts were further dampened by two internships I had at major companies:
Microsoft in the summer and Google in autumn. For the Google internship I was
disallowed from working on any side projects without them having copyright over
the code.

> For an internship, which is short lived, I'm willing to make this compromise.
> However, I'm strongly unwilling to make this compromise for a full-time
> position.

When I worked at Google I decided to make a public post describing my
circumstances, in part to excuse my long hiatus. I also briefly described that I
would need to split up the binaries and attempted to spin it like it was a good
thing.

### Giving up on wlroot-rs (April 2019)

In April I [officially gave up on
wlroots-rs](http://way-cooler.org/blog/2019/04/29/rewriting-way-cooler-in-c.html).
It was far too much effort to maintain, was stressing me out every day, and I
was able to so quickly rewrite the compositor portion of Way Cooler in C that it
seemed silly I wasted so much time wrapping so little of the API.

I knew this would have mixed reception, since I was essentially rewriting (at
least part of) my project that was originally in Rust into C. I gave my
justification well enough in that post I think.

### Renewed interest as I switched back to C (August 2019)

In August I was annoyed enough at the project to consider giving it up. It was
requiring considerable effort to rewrite the AwesomeWM object model in Rust +
rlua, even with the ergonomics of the latter. As a last ditch attempt I decided
to see how quickly I could hack the AwesomeWM binary to work under the (mostly
working) `way-cooler` compositor written in C. To my surprise, I deleted 15
lines of code and I had something that was working better than the Rust version
I had been writing for a year or so at that point.

I decided to switch tracks, instead forking AwesomeWM and building Wayland
support into it that way.

> Assuming this was viable (spoiler: it's not) I should have done this from the
> get go. There's only a small part of AwesomeWM that deals with X11 code, the
> rest defines a Lua API that is quite complex. It defines an entire object
> model with inheritance and signals. Reimplementing that because of Rust is a
> silly decision when only a small part (the underlying backend of these
> objects) needs to change.

I actually quite far. I have a system where you can run `way-cooler -c
/path/to/awesome` and you get a semi-functioning system. It can spawn programs
defined in the keybindings, the status bar renders (and renders using
layer-shell, not via X11), and lets you spawn things with dmenu. If there aren't
client side borders you can't move things, and it will crash the moment it tries
to execute an X11 code path but it mostly works.

### Finally cutting ties (January 2020, i.e. now)

I made some strides with this new version of Way Cooler, even going so far as
being able to dog food a (hacked up version) on my laptop.

Ultimately there were a few things that finally got me to become so bored with
the work that I couldn't continue.

The first and most obvious is I don't particularly like AwesomeWM. I like i3 a
lot more and I was only writing this to solve other people's problems first. I
don't need an entire Turing complete language to describe my desktop
environment.

The second issue is that AwesomeWM is heavily tied to the X11 model. Trying to
make a clone of it for Wayland led to basically recreating X11. The point of
Wayland is to move _away_ from the X11 model, not to recreate it.

I really enjoyed working on this project. Even though 2017 was the hayday, it
always felt so great to work on something that could be self-hosted (e.g. I could
write Way Cooler code in Way Cooler) and was something that I was designing for
myself first. It taught me Rust (which I currently use everyday in my day job,
hi guys!), how Wayland works, how the Linux graphics pipeline works, how to deal
with user requests, how to review patches, how to market a project, and now it's
teaching me how to walk away from a big, awful thing you created that you have
to let go of even if you don't want to.

Thanks to everyone that helped me over the years to build Way Cooler. Special
thanks to [Snirk](https://github.com/SnirkImmington) for starting the project
with me, Alexa for designing and drawing the logo, and
[platipo](https://github.com/platipo) for making the [official
background](https://github.com/way-cooler/way-cooler/issues/141). If your name
is not here, I did not forget you this blog post is just long enough as it is
:).

Until the next adventure.
