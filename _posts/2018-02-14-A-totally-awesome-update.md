---
layout: post
title: A (totally Awesome) update
date: 2018-02-14
category: blog
---
Hey all! It's been a bit quiet for a while, so I'd thought I'd give an update on both Way Cooler and [wlroots-rs](https://github.com/swaywm/wlroots-rs), the wrapper I'm building for the new compositor framework [wlroots](https://github.com/swaywm/wlroots) which I explained briefly in my [Way Cooler: 2018 blog post](/blog/2017/12/24/way-cooler-2017.html).

# Way Cooler
Development on Way Cooler has slowed considerably for me these past several months, mostly because I have focused on wlroots-rs. However, thanks to the wonderful work of [psychon](https://github.com/psychon) there has been non-trivial progress!

The fruit of his efforts can probably best be described by this image:

![](/assets/awesome_bar_in_way_cooler.png)

If you look closely at the top... yep that's the Awesome status bar rendering in Way Cooler.

This isn't representative of what's available on master at the moment, because we will be redoing the rendering pipeline for Way Cooler when wlroots-rs is complete. However we already have enough of the API surface laid out that Awesome can load up a cairo surface and draw the status bar which is really cool!

# wlroots-rs
This is where the majority of my work has been so far. It has taken a _lot_ of effort to design wlroots-rs so that it's 100% safe for Rust users.

The API is mostly trait based, and tries to keep the modular design of wlroots while at the same time making it much easier to write several parts. Here's a minimal compositor using the library:


```rust
extern crate wlroots;

fn main() {
    wlroots::utils::init_logging(wlroots::utils::L_DEBUG, None);
    wlroots::CompositorBuilder::new().build_auto((), None, None, None)
                                     .run()
}
```

This works today, though I highly suggest you don't run that in a TTY directly...this really is a minimal example. wlroots gives us **much** more control, so because we didn't define any way to get any user input once you start this program you can't break out of it...short of turning off your machine.

Here's a more complete example you can run either in a TTY or in an X11 or Wayland instance:

```rust
#[macro_use]
extern crate wlroots;

use wlroots::{Compositor, CompositorBuilder, CursorBuilder, InputManagerHandler, Keyboard,
              KeyboardHandler, Output, OutputBuilder, OutputBuilderResult, OutputHandler,
              OutputLayout, OutputManagerHandler, Pointer, PointerHandler, XCursorTheme};
use wlroots::key_events::KeyEvent;
use wlroots::pointer_events::{AxisEvent, ButtonEvent, MotionEvent};
use wlroots::utils::{init_logging, L_DEBUG};
use wlroots::wlroots_sys::gl;
use wlroots::wlroots_sys::wlr_button_state::WLR_BUTTON_RELEASED;
use wlroots::xkbcommon::xkb::keysyms::KEY_Escape;

struct State {
    color: [f32; 4],
    default_color: [f32; 4],
    xcursor_theme: XCursorTheme,
    layout: OutputLayout
}

impl State {
    fn new(xcursor_theme: XCursorTheme, layout: OutputLayout) -> Self {
        State { color: [0.25, 0.25, 0.25, 1.0],
                default_color: [0.25, 0.25, 0.25, 1.0],
                xcursor_theme,
                layout }
    }
}

compositor_data!(State);

struct OutputManager;

struct ExOutput;

struct InputManager;

struct ExPointer;

struct ExKeyboardHandler;

impl OutputManagerHandler for OutputManager {
    fn output_added<'output>(&mut self,
                             compositor: &mut Compositor,
                             builder: OutputBuilder<'output>)
                             -> Option<OutputBuilderResult<'output>> {
        let result = builder.build_best_mode(ExOutput);
        let state: &mut State = compositor.into();
        let xcursor = state.xcursor_theme
                           .get_cursor("left_ptr".into())
                           .expect("Could not load left_ptr cursor");
        let image = &xcursor.images()[0];
        // TODO use output config if present instead of auto
        state.layout.add_auto(result.output);
        let cursor = &mut state.layout.cursors()[0];
        cursor.set_cursor_image(image);
        let (x, y) = cursor.coords();
        // https://en.wikipedia.org/wiki/Mouse_warping
        cursor.warp(None, x, y);
        Some(result)
    }
}

impl KeyboardHandler for ExKeyboardHandler {
    fn on_key(&mut self, compositor: &mut Compositor, _: &mut Keyboard, key_event: &mut KeyEvent) {
        for key in key_event.pressed_keys() {
            if key == KEY_Escape {
                compositor.terminate()
            }
        }
    }
}

impl PointerHandler for ExPointer {
    fn on_motion(&mut self, compositor: &mut Compositor, _: &mut Pointer, event: &MotionEvent) {
        let state: &mut State = compositor.into();
        let (delta_x, delta_y) = event.delta();
        state.layout.cursors()[0].move_to(event.device(), delta_x, delta_y);
    }

    fn on_button(&mut self, compositor: &mut Compositor, _: &mut Pointer, event: &ButtonEvent) {
        let state: &mut State = compositor.into();
        if event.state() == WLR_BUTTON_RELEASED {
            state.color = state.default_color;
        } else {
            state.color = [0.25, 0.25, 0.25, 1.0];
            state.color[event.button() as usize % 3] = 1.0;
        }
    }

    fn on_axis(&mut self, compositor: &mut Compositor, _: &mut Pointer, event: &AxisEvent) {
        let state: &mut State = compositor.into();
        for color_byte in &mut state.default_color[..3] {
            *color_byte += if event.delta() > 0.0 { -0.05 } else { 0.05 };
            if *color_byte > 1.0 {
                *color_byte = 1.0
            }
            if *color_byte < 0.0 {
                *color_byte = 0.0
            }
        }
        state.color = state.default_color.clone()
    }
}

impl OutputHandler for ExOutput {
    fn on_frame(&mut self, compositor: &mut Compositor, output: &mut Output) {
        let state: &mut State = compositor.into();
        // NOTE gl functions will probably always be unsafe.
        unsafe {
            output.make_current();
            gl::ClearColor(state.color[0], state.color[1], state.color[2], 1.0);
            gl::Clear(gl::COLOR_BUFFER_BIT);
            output.swap_buffers();
        }
    }
}

impl InputManagerHandler for InputManager {
    fn pointer_added(&mut self,
                     _: &mut Compositor,
                     _: &mut Pointer)
                     -> Option<Box<PointerHandler>> {
        Some(Box::new(ExPointer))
    }

    fn keyboard_added(&mut self,
                      _: &mut Compositor,
                      _: &mut Keyboard)
                      -> Option<Box<KeyboardHandler>> {
        Some(Box::new(ExKeyboardHandler))
    }
}

fn main() {
    init_logging(L_DEBUG, None);
    let cursor = CursorBuilder::new().expect("Could not create cursor");
    let xcursor_theme = XCursorTheme::load_theme(None, 16).expect("Could not load theme");
    let mut layout = OutputLayout::new().expect("Could not construct an output layout");

    layout.attach_cursor(cursor);
    let compositor = CompositorBuilder::new().build_auto(State::new(xcursor_theme, layout),
                                                         Some(Box::new(InputManager)),
                                                         Some(Box::new(OutputManager)),
                                                         None);
    compositor.run();
}
```

This gives you an idea of the API surface. As you can see, the only lines of unsafe that aren't wrapped are for talking to opengl directly. This and other examples can be found in the project repo.

I'm fairly sure my API design means there's no way to break the holy mutability / aliasing tenants of Rust, but if anyone wants to look and point out any mistakes I made I certainly won't complain.

And finally, here's what I've been working on in the past week on wlroots-rs. This is the [example wayland-rs client](https://github.com/Smithay/wayland-rs/blob/master/wayland-client/examples/simple_window.rs) being drawn in wlroots-rs:

![](/assets/proto_wlroots-rs_rendering.png)


# Conclusion
So lots of exciting rendering milestones have been reached just this week. There's still a lot to do, as you can see from the [wlroots-rs issue list](https://github.com/swaywm/wlroots-rs/issues) and the [Way Cooler issue list](https://github.com/way-cooler/way-cooler/issues?q=is%3Aissue+is%3Aopen+label%3AAwesome). If you want to help out, feel free to ask a question [on our gitter channel](https://gitter.im/way-cooler/way-cooler)
