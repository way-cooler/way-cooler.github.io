---
layout: post
title: Why Rust? A Two Year Retrospective
date: 2018-01-09
category: blog
---

# Why Rust?
That was a question I asked exactly two years ago when I started Way Cooler (by the way, happy 2nd birthday Way Cooler!).

When considering Rust for a Wayland window manager I had two basic requirements: 
* Is it possible?
* Is it better than C?

## Is it possible to write a Wayland window manager in Rust?
This first question was easy enough to answer. The Wayland ecosystem is almost entirely C, with the reference implementation server, client, and compositor written in C. All other non-toy compositors (Mutter, Kwin, Sway) are written in C for the simple reason that to use Wayland you need to know (and at some point write) C.

So in order to write a Wayland compositor in something that's _not_ C, you need to write some bindings that interact with Wayland. That requires a language that has good FFI support with C. Just about every language has some level of support, but the overhead and the complexity of using these bindings differs wildly between languages.

Rust has excellent FFI compatibility with C, better than most other languages by far. The choice to keep the runtime small and not have a GC allows it to interoperate much better than other languages.<sup>[1](#go-footnote)</sup> Due to these decisions, Rust is a solid enough choice to consider it as an alternative to C.

But using Rust comes at an additional cost of complexity. Maintaining bindings, especially safe bindings, can be complicated. Using a less well known language like Rust means it's harder to solve problems because there's less developer buy-in, which means it's more difficult to find programmers that know enough Rust to contribute or enough information to solve the problems I'll need to solve. 

Rust requires a lot of nice benefits to offset these problems. Just because it was being billed as a "systems programming language" doesn't mean much if it can't offer me something C can't.

## Is Rust a better language than C?
Yes.<sup>[2](#but...)</sup>

## Is Rust better than C at being a systems programming language?
No.<sup>[3](#it-can-be)</sup>

Normally when people answer this question, they usually point to the following features to justify why Rust is a better choice than C:

* ML-like type system
* Lifetimes
  
Having a more strict type system that is designed around memory safety while also having the expressive type power from more "academic" languages gives Rust the ability to safely and securely abstract over unsafe system code. This feature can't be overstated in terms of the power it brings to the programmer to build safe abstractions compared to C++.

However, those features are features of *safe* Rust. Safe Rust is a decidedly different language from Unsafe Rust. The main goal of unsafe Rust is to **provide those features** as a safe abstraction over unsafe implementations.

While the majority (roughly 90% I'd say) of Rust written is safe Rust, that last 10% is just as, if not more, important. The standard library is almost entirely unsafe Rust. Most large libraries in some way use either a C library (which requires good unsafe Rust to abstract it) or uses unsafe Rust for performance reasons. 

There are exceptions to this, of course. [ripgrep](https://github.com/BurntSushi/ripgrep), the fast alternative to grep, has exactly two lines of unsafe code. Many other projects have 0 lines of unsafe code in their core codebase. [But 60% (including ripgrep) of crates on crates.io depend transitively on the libc crate](https://user-images.githubusercontent.com/1940490/33252553-b71b9ec0-d2f3-11e7-8abf-720cf00ac3ce.png). This isn't a problem at all, it's good to depend on old, proven C libraries over new, unproven, and possibly bug-riddled implementations. But writing correct unsafe Rust code is hard. [Very hard](https://blog.rust-lang.org/2017/02/09/Rust-1.15.1.html). [Very, very hard](https://github.com/rust-lang/rust/issues/41622).

Right now I'm in the middle of wrapping a new framework for Wayland, [wlroots](https://github.com/swaywm/wlroots). [wlroots-rs](https://github.com/swaywm/wlroots-rs) is going to be a 100% safe Rust wrapper around wlroots that allows compositors like Way Cooler to be written in safe Rust. In order to do that, wlroots-rs is going to have to be written in unsafe Rust. As of today, it is over 25% unsafe Rust code. If there is a bug in this code, this will have huge ramifications for Way Cooler. So I care a lot about my ability to write correct Unsafe Rust code

## How can Unsafe Rust be better?
In the past, [I've made some huge mistakes when writing unsafe code](http://way-cooler.org/blog/2016/08/14/designing-a-bi-mutable-directional-tree-safely-in-rust.html). When you start using the `unsafe` keyword, the Rust compiler almost immediately stops helping you. It doesn't try to do any inspection whatsoever and instead relies entirely on the programmer to do the correct thing. For programmers coming from C or especially C++ this environment should feel familiar. You're making a promise to the compiler, and it's entirely up to you to uphold it and then safely abstract over it.

This is the point of Unsafe Rust. The whole point of `unsafe` is to tell the compiler "get out of my way, you can't prove this correct". You _need_ a mechanism like this in order to extend the capabilities of Safe Rust. 

Today, however, Unsafe Rust feels no better than writing in plain C. In fact, it can feel clumsy and like the language is almost fighting you. The compiler doesn't warn you when you try to do something potentially dumb. So how can we make it better to write Unsafe Rust?

### Unsafe Warnings

There are very basic checks that it should be performing that it's just not right now.


Take, for example, this type signature (stolen from a bug that slipped into Rust 1.15):


```rust
pub fn as_mut_slice<'a>(&'a self) -> &'a mut [T];
```

Just by looking at the type signature, this is _probably_ incorrect. If you have just an immutable reference given to a function, you probably can't return a mutable reference with the same lifetime. The Rust compiler should look at this signature and issue a warning that this could be incorrect.

This might seem like a contrived example, but this bug actually slipped through the cracks during a Rust release triage! Programmers are people too, we make mistakes. That's why we need to build tools into the compiler to warn us of these mistakes so we can fix them before they happen.

I don't expect these checks to always be correct. Remember, the point of Unsafe Rust is to get the compiler out of your way. That's why there should be a way to suppress these warnings with an optional proof explaining why it's safe. 

E.g To demonstrate this, let us imagine a slightly different signature:

```rust
pub fn next_3_elements<'a>(&'a self) -> Option<&'a mut [T]>;
```

Based purely on the type signature again, this should throw up some sort of warning in the compiler. As you may have deduced by the `next_3_elements` name though, this structure might have an internal counter (e.g using `Cell` for internal mutability) that steps through and returns disjoint mutable slices three elements at a time.

But the onerous is on the programmer to prove to the compiler that this is correct. So to stop such a warning you should be able to do:


```rust
#[allow(fishy_type_signature, reason = "Slices returned are from a monotonically increasing counter that guarantees disjoint slices")]
pub fn next_3_elements<'a>(&'a self) -> Option<&'a mut [T]>;
```

To make this even better, you can make this reason automatically insert itself into the function documentation so that it's visible to consumers of the library why this is safe.

I already do something similar to this [using comments in wlroots-rs](https://github.com/swaywm/wlroots-rs/search?q=Rationale&type=).

Now obviously all of those can't be caught with such a simple lint like the example above, but more should be done to catch these "obvious" mistakes so that it's easier to write unsafe code.


### Clearly defined rules for unsafe code
[The Rustnomicon](https://doc.rust-lang.org/nomicon/) is the unsafe version of the Rust book. It introduces and explains some of the problems that come up from writing unsafe Rust code. It's a very good primer, and I suggest anyone who has to write unsafe code check it out. But when the first few words of the book are:
## NOTE: This is a draft document that discusses several unstable aspects of Rust, and may contain serious errors or outdated information

it makes me question the stability of my Unsafe Rust code.

There are rules today that highlight cases of undefined behavior (e.g mutable aliasing for references), which is good. However, there's also behavior [that just hasn't been defined period](https://www.reddit.com/r/rust/comments/4tz6e5/are_aliased_mutable_raw_pointers_ub/d5ljyfw/). Is having two raw, mutable pointers to the same piece of memory undefined? According to that thread, maybe! The rules haven't been defined yet.

As bad as it is that C has so many cases of undefined behavior, it's so much worse to work in a language where you don't even know if doing something is undefined behavior or not.

For 2018 I propose that there should be a team that should seek out defining, very clearly, at least some of these rules so that we understand what is and isn't permitted in Unsafe Rust code. Part of this effort should be partly standardizing the nomicon so that new users can learn Unsafe Rust just as easily as they can learn Safe Rust.


### Verification process for unsafe crates
Recently, I wrote a [lockscreen program for Way Cooler](https://github.com/way-cooler/way-cooler-lock). Part of a lockscreen's job is to handle passwords securely. The main way do that on Unix-likes is using something called [PAM](https://en.wikipedia.org/wiki/Pluggable_authentication_module). If you [search "pam" on crates.io](https://crates.io/search?q=pam), you get a lot of random crates that haven't been updated in a while or are poorly documented. 

If you choose the most popular one, [pam-auth](https://github.com/1wilkens/pam-auth), you'll find that (at least at the time I was using it, in early June) to be thoroughly unusable. Trying to use it as described would invoke a segfault. This was eventually fixed (I think by [this commit](https://github.com/1wilkens/pam-auth/commit/cc9cb5a0b995b48fffe83c9780b4dcb7837fd4d0)), but by that point I resigned to [just using C](https://github.com/way-cooler/way-cooler-lock/blob/d1fc5f54243f0aed8628eba3d48d941bdbc37d78/src/pam/wrapper.c).

The point is not to pick on the author of that crate. My library, [rust-wlc](https://github.com/way-cooler/rust-wlc), has much bigger issues that I will never fix (and instead were fixed by [wlc.rs](https://github.com/Drakulix/wlc.rs)). Instead crates.io should offer a more explicit way of showing that a crate that utilizes a non-negligible amount of unsafe code to be somewhat correct.

This probably can never be done in an automated fashion. There's no way to tell the difference between a "negligible" and "non-negligible" amount of Unsafe Rust code. 

One alternative that I've yet to see discussed is to have crate owners offer their crate up for inspection by the wider community through some sort of standard process. There should be a suite of fuzzer test suites and a host of manual testing done on these crates to ensure that they are sound. Once they have been verified as such, they should be given a higher preference in the crates.io search and maybe even a special badge.

The fight against unsafety is, of course, never ending. So for crates in this "special club" they should be locked from releasing new versions on crates.io until a sufficient consensus is made by experts in the community. Saying your crate is safe is never a one-and-done thing. By advertising the crate as safe, the author (and the community!) needs to take on the responsibility that the code has been properly vetted.


### Unsafe ergonomics
I admit this is relatively minor, but there's no reason why this has to be the case that I can tell.

Writing unsafe Rust is _very_ unergonomic. To a certain extent, this is deliberate. Writing unsafe code should be a last resort and by having awkward syntax it discourages the programmer from using it. However, the fact that I have to write this to access a field behind a raw pointer makes it much harder to both write _and_ read code:

```rust
(*(*some_struct).foo).another_thing
```

C, meanwhile, has very nice syntax for this:

```C
some_struct->foo->another_thing
```

I _really_ don't think we should use `.`, because a raw pointer is very different from a reference, and I understand that there's probably huge parsing issues with using `->` but there must be some sort of shorthand syntax to make this easier to write.


## Conclusion
Still, there's a reason I used Rust for Way Cooler. Though the unsafe portions may not be enough of an improvement over C, the fact of the matter is that the majority of code in Way Cooler will be Safe Rust and Safe Rust is a wonderful language that is improving all the time. More than any other language, the Rust dev team are committed to making Rust as good as it can be. For the vast majority of users and use cases, Safe Rust is more than good enough as a replacement for a lot of code.

However, the goal of Rust, for me at least, has always been as a replacement to C. To be a full replacement for C, effort must be made on bringing the Unsafe portion of Rust up to the ergonomic and rigorous standard that Safe Rust has. 

Not all of what I proposed can probably be implemented, but I implore the Rust dev team to not forget about the Unsafe portion of the language during this year's implementation period. Last year we saw some great strides in making Safe Rust more ergonomic and expressive. This year, I hope we see Rust become an even better alternative to C, in the safe _and_ unsafe space.

---
<sup><a name="go-footnote">1</a></sup> For the record, Go, I hear, also has a good FFI story with C even though it does have a heavier runtime (along with a GC).

<sup><a name="but...">2</a></sup> Like all language preferences, this is my opinion. So don't take this for absolute truth.

<sup><a name="it-can-be">3</a></sup> But it absolutely has the potential to be a better systems programming language than C. **This** is why I chose Rust over C.

