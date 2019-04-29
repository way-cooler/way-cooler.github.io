---
layout: post
title: Giving up on wlroots-rs
date: 2019-04-29
category: blog
---

# Giving up on wlroots-rs

[Way Cooler](https://github.com/way-cooler/way-cooler) is a Wayland compositor
that was written in Rust using [wlc](https://github.com/Cloudef/wlc). Since
[last April](https://github.com/way-cooler/way-cooler/pull/516) I've been
rewriting it to use [wlroots](https://github.com/swaywm/wlroots). In order to do
that however I had to wrap the library so that it could be used in Rust. I
worked on [wlroots-rs](https://github.com/swaywm/wlroots-rs) and put Way Cooler
on the back burner for a long time. After over 1,000 commits I'm giving up on it.

## Problems with wlroots-rs in detail

### Ownership with handles

wlroots-rs was going to be the safe Rust wrapper for the very complicated
[wlroots library](https://github.com/swaywm/wlroots). wlroots implements large
parts of a Wayland compositor and provides pluggable modules that most
compositors will want.

The biggest problem when wrapping wlroots was defining the ownership model of
the objects that wlroots exposes. To demonstrate this I will focus on a single
resource that illustrates the problem: an output.

A Wayland "output" is the resource that represents a display device. Commonly
this means it handles a computer monitor. This resource could disappear at any
time in the life cycle of the application. This is easy enough to imagine: all
it takes is a yank of the display's power cord and the monitor goes away. This
is basically the exact opposite of the Rust memory model. Rust likes to own
things and give compile-time defined borrows of that memory. This is runtime
lifetime management that must be managed in some way.

You cannot simply define it like so:

```rust
struct Output {
    output_c_ptr: *mut wlr_output
}

impl Output {
    // Forward all the calls to the c pointer
}
```

If this was done then it would be possible to leak the memory using `Box::leak`
and say that an output will live forever -- even though it can't.

The simplest way to achieve this safely would be to use reference counted
pointers and expose only weak pointers. Here is a (fake) example of how this
could look:

```rust
// This is a _very_ simple example for clarity.
// wlroots-rs is not implemented like this.

struct RealOutput {
    lifeline: Rc<*mut wlr_output>
}

struct Output {
    lifeline: Weak<*mut wlr_output>
}

impl Output {
    /// Changes the mode (resolution) of an output.
    pub fn change_mode(&mut self, mode: Mode) -> Result<(), ()> {
        unsafe {
            let output_ptr = lifeline.upgrade().ok_or(())?;
            wlr_output_change_mode(output_ptr, mode.into());
        }
    }
}
```

This naive style implementation could work, however it would cause a lot of
branching code. Each call to wlroots will require a check to see if the handle
has been dropped, even though it almost certainly has not been dropped (it can
only be dropped between event callbacks, wlroots/Wayland is callback based).
This means there will be unnecessary paths (that are hopefully marked cold) that
either panic or return an error.

This is obviously not wanted so the next best thing is define a range where it
is safe to use the reference to the resource: i.e. we want to be able to define
a lifetime for a code block. This leads us to the _actual_ design of wlroots-rs,
using handles (note that this _is_ actual code):

```rust
/// A non-owned reference counted handle to a resource.
///
/// The resource could be destroyed at any time, it depends on the resource.
///
/// For example an output is destroyed when its physical output is
/// "disconnected" on DRM. "disconnected" depends on the output (e.g. sometimes
/// turning it off counts as "disconnected").
/// However, when the backend is instead headless an output lives until it is
/// destroyed explicitly by the library user.
///
/// Some resources are completely controlled by the user. For example although
/// you refer to a `Seat` with handles it is only destroyed when you call the
/// special destroy method on the seat handle.
///
/// Please refer to the specific resource documentation for a description of
/// the lifetime particular to that resource.
pub struct Handle<D: Clone, T, W: Handleable<D, T> + Sized> {
    pub(crate) ptr: NonNull<T>,
    pub(crate) handle: Weak<Cell<bool>>,
    pub(crate) _marker: PhantomData<W>,
    pub(crate) data: Option<D>
}


impl<D: Clone, T, W: Handleable<D, T>> Handle<D, T, W> {
    /// Upgrades a handle to a reference to the backing object.
    ///
    /// # Safety
    /// This returns an "owned" value when really you don't own it all.
    /// Depending on the type, it's possible that the resource will be freed
    /// once this returned value is dropped, causing a possible double free.
    /// Potentially it instead is just unbound, it depends on the resource.
    ///
    /// Regardless, you should not use this interface. Use the `run` method.
    #[doc(hidden)]
    pub unsafe fn upgrade(&self) -> HandleResult<W> {
        self.handle.upgrade()
            .ok_or(HandleErr::AlreadyDropped)
            // NOTE
            // We drop the Rc here because having two would allow a dangling
            // pointer to exist!
            .and_then(|check| {
                if check.get() {
                    return Err(HandleErr::AlreadyBorrowed)
                }
                let wrapper_obj = W::from_handle(self)?;
                check.set(true);
                Ok(wrapper_obj)
            })
    }

    /// Run a function with a reference to the resource if its still alive.
    ///
    /// Returns the result of the function, if successful.
    ///
    /// # Safety
    /// By enforcing a rather harsh limit on the lifetime of the resource
    /// to a short lived scope of an anonymous function,
    /// this function ensures the resource does not live longer
    /// than it exists.
    ///
    /// # Panics
    /// This function will panic if multiple mutable borrows are detected.
    /// This will happen if you call `upgrade` directly within this callback,
    /// or if a handle to the same resource was upgraded some where else up the
    /// stack.
    pub fn run<F, R>(&self, runner: F) -> HandleResult<R>
    where
        F: FnOnce(&mut W) -> R
    {
        let mut wrapped_obj = unsafe { self.upgrade()? };
        // We catch panics here to deal with an extreme edge case.
        //
        // If the library user catches panics from the `run` function then their
        // resource used flag will still be set to `true` when it should be set
        // to `false`.
        let res = panic::catch_unwind(panic::AssertUnwindSafe(|| runner(&mut wrapped_obj)));
        if let Some(check) = self.handle.upgrade() {
            // Sanity check that it hasn't been tampered with. If so, we should
            // just panic. If we are currently
            // panicking this will abort.
            if !check.get() {
                wlr_log!(WLR_ERROR, "After running callback, mutable lock was false");
                panic!("Lock in incorrect state!");
            }
            check.set(false);
        }
        match res {
            Ok(res) => Ok(res),
            Err(err) => panic::resume_unwind(err)
        }
    }
}
```

The full implementation can be found
[here](https://github.com/swaywm/wlroots-rs/blob/91a18bd541a6ec565d6ef78d18ee5cc6a413f684/src/utils/handle.rs),
its far too long and complicated to paste into a blog post.

This code is very complicated, which isn't what you want for the defining
abstraction of your safe library. As far as I'm aware though it is correct. It's
also incredibly ugly to use in practice:

```rust
fn some_wlroots_callback(output_handle: OutputHandle,
                         surface_handle: SurfaceHandle) {
    output_handle.run(|output| {
        surface_handle.run(|surface| {
            // maybe some more nested layers...
        }).unwrap()
    }).unwrap()
}
```

To avoid this callback hell, I defined two macros to help: [one normal
macro](https://github.com/swaywm/wlroots-rs/blob/91a18bd541a6ec565d6ef78d18ee5cc6a413f684/src/macros.rs#L355)
and a very complicated [procedural
macro](https://github.com/swaywm/wlroots-rs/blob/91a18bd541a6ec565d6ef78d18ee5cc6a413f684/wlroots-dehandle/src/lib.rs).
Here's what the procedural macro looks like:

```rust
// This does the same thing as the above code, but nicer.
#[wlroots_dehandle]
fn some_wlroots_callback(output_handle: OutputHandle,
                         surface_handle: SurfaceHandle) {
    #[dehandle] let output = output;
    #[dehandle] let surface = surface_handle;
}
```

This expands out the lines to use the non-proc macro, which in turn becomes the
callback hell mess. The only problem with this scheme is now that the control
flow is all wrong:

```rust
// this is actual code I had to write (simplified)
for shell in mapped_shells {
    #[dehandle]
    let surface = shell.surface();
    // If not ready to render, don't render it yet
    if !surface.is_mapped() {
        // What we _want_ to write
        // break

        // What we have to write because this is actually in a callback...
        return // actually goes to the next shell in the mapped_shells...
    }
}
```

So this solution "works" but it's not great. Ultimately it's very confusing for
users. It was too confusing for [purism to get
working](https://puri.sm/posts/end-of-year-librem-5-update/) (this
[video](https://www.youtube.com/watch?v=oX5yVyLbLZE) was very painful for me to
watch - the library was unusable). [Kiwmi](https://github.com/buffet/kiwmi)
initially tried using wlroots-rs but swiftly gave up and used wlroots itself.

### The sheer amount of API to wrap

Currently there is 11 **THOUSAND** lines of Rust in wlroots-rs. _All_ of this
code is just wrapper code, it doesn't do anything but memory management. This
isn't just repeated code either, I defined a [very complicated and ugly
macro](https://github.com/swaywm/wlroots-rs/blob/91a18bd541a6ec565d6ef78d18ee5cc6a413f684/src/macros.rs#L201)
to try to make it easier.

This wrapper code doesn't cover even half of the API surface of wlroots. It's
exhausting writing wlroots-rs code, memory management is constantly on my mind
because that's the whole purpose of the library. It's a very boring problem and
it's always at odds with usability - see the motivation for the escape from
callback hell described above.

To do all of this, and then go write Way Cooler, already a big undertaking, is too
much for me to commit to. When the benefit at the end of the day is just so I
don't have to write C, that doesn't really make it worth it. If I got this out
of the box by simply linking to the library, like I can in C++, then it would be
much more tenable.

I can always just use unsafe bindings to wlroots, just like I would with any
other language. However, the _entire point_ of Rust is that it's safe. Doing
that is not an option because at that point you lose the entire benefit of the
language.

### Custom Wayland protocols aren't possible (safely)

Even if I accepted the usability problems of the API and I powered through
writing all of the wrapper code there is still one major limitation of
wlroots-rs that I can't find a way to work around: it's impossible to allow a
compositor to safely define a custom Wayland protocol with wlroots-rs.

The way you extend compositors in Wayland is writing protocols. wlroots provides
a lot of protocols already, but many compositor will want to write custom ones.
Way Cooler will definitely need to write custom protocols to implement the
functionality Awesome users have come to expect from their Lua scripts.

The protocols are written in XML and code is generated from it. The Rust code
generator that currently exists is part of the wayland-rs project.
Unfortunately, the code generated by this tool requires using wayland-rs in its
entirety to manage the Wayland stack. This is because it uses custom data
storage exposed by Wayland to handle memory management to ensure safety, whereas
it's normally used by OpenGL (for more information, see [this blog
post](https://smithay.github.io/wayland-rs-v-0-21.html)).

This means I would have to define a _different_ scanner that would generate code
that hopefully could be made safe to use (but probably not). So now there will
need to be unsafe code in compositor code even though wlroots-rs was supposed to
handle it properly...

## Why Smithay is not a solution

[Smithay](https://github.com/Smithay) is a library similar to wlroots, but is
written entirely in Rust. I'm not interested in trying to use Smithay for Way
Cooler.

Smithay is very incomplete. Very, very incomplete compared to wlroots. It is no
where near usable and the current trajectory doesn't look like it will be usable
very soon either. wlroots is a great framework and has a strong backing in the
community so I don't see the need to abandon it just so I can keep using Rust.

Way Cooler will have to talk to C libraries any ways (the rest of the Wayland
ecosystem is all C, including libinput, DRM, and OpenGL), so either more
bindings will need to be written (again distracting from the main problem of
making a working compositor) or they will need to be RiiR.

I wish them luck, but I don't feel interested in rewriting the entire world in
Rust just so Way Cooler can be in Rust. I like Rust, but not enough to reinvent
the wheel so it doesn't have any C in it.

## Rewriting Way Cooler in C

[Starting with this PR](https://github.com/way-cooler/way-cooler/pull/609), the
compositor for Way Cooler will be written in C.

This was a difficult decision to make, not because Way Cooler must be written in
Rust, but because I was throwing away quite a bit of work that I invested in
wlroots-rs. Thought it had many problems, it came out to be surprisingly usable despite
its limitations. However, it wasn't going to be tenable for Way Cooler (for the
reasons listed above) so it must be abandoned.

Some people have seen this as controversial, politically speaking. I don't
really understand this view point, as the fact that Way Cooler is written in
Rust is an implementation incidental. Now it makes sense for it to be written in
C, given the constraints that I have discovered through painful trial and error,
so it will be written in C.

Note that the client part of Way Cooler (the part that will implement the
AwesomeWM compatibility) is still written in Rust. This is the most pragmatic
solution because it can utilize
[wayland-rs](https://github.com/Smithay/wayland-rs) and
[rlua](https://github.com/kyren/rlua).

As an interesting side note: both developers behind those particular projects
have elected to [rewrite](https://github.com/kyren/luster) their projects [in
Rust](https://smithay.github.io/wayland-rs-v-0-21.html). They are doing this
because it's difficult to write good bindings to C libraries, and so the natural
conclusion to making it work well in Rust is to rewrite it.

I want to make one (mildly controversial) thing clear: rewriting a library
for the sake of only using Rust is not good engineering. A literal rewrite of a
project to Rust is not interesting, it's not useful, it just causes churn and
splits ecosystems. Time would be better spent either working with existing
solutions that already have the effort put in to make them correct or to come up
with new green-field projects.
