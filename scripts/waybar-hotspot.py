#!/usr/bin/env python3
"""
~/.config/hyprland/scripts/waybar-hotspot.py

A near-zero-cost layer-shell surface that reveals Waybar when the mouse
touches the top edge, and hides it again after an idle timeout.

Purely event-driven: relies on GDK's enter-notify-event / leave-notify-event,
which are only ever dispatched by the compositor when the pointer actually
crosses the surface boundary. No polling loop, no timers running unless a
hide is actually pending.

Requires: python-gobject, gtk-layer-shell, gtk3
"""

import gi
gi.require_version("Gtk", "3.0")
gi.require_version("GtkLayerShell", "0.1")
from gi.repository import Gtk, Gdk, GLib, GtkLayerShell

import subprocess

# ---- tunables ----------------------------------------------------------
HOTSPOT_HEIGHT_PX = 4
HIDE_DELAY_MS = 5000
WAYBAR_PROC_NAME = "waybar"
# -------------------------------------------------------------------------

_hide_source_id = None


def _send_signal(sig: str):
    subprocess.run(["killall", f"-{sig}", WAYBAR_PROC_NAME], check=False)


def _cancel_pending_hide():
    global _hide_source_id
    if _hide_source_id is not None:
        GLib.source_remove(_hide_source_id)
        _hide_source_id = None


def _do_hide():
    global _hide_source_id
    _send_signal("SIGUSR2")  # hide
    _hide_source_id = None
    return False  # one-shot, don't repeat


def on_enter(widget, event):
    _cancel_pending_hide()
    _send_signal("SIGUSR1")  # show
    return False


def on_leave(widget, event):
    global _hide_source_id
    _cancel_pending_hide()
    _hide_source_id = GLib.timeout_add(HIDE_DELAY_MS, _do_hide)
    return False


def build_window():
    print("building window", flush=True)
    win = Gtk.Window(type=Gtk.WindowType.TOPLEVEL)
    win.set_decorated(False)
    win.set_default_size(1, HOTSPOT_HEIGHT_PX)

    GtkLayerShell.init_for_window(win)
    GtkLayerShell.set_layer(win, GtkLayerShell.Layer.OVERLAY)
    GtkLayerShell.set_namespace(win, "waybar-hotspot")

    # Stretch across the full width, pinned to the top edge.
    for edge in (GtkLayerShell.Edge.TOP, GtkLayerShell.Edge.LEFT, GtkLayerShell.Edge.RIGHT):
        GtkLayerShell.set_anchor(win, edge, True)

    # Don't reserve screen space and don't take keyboard focus.
    GtkLayerShell.set_exclusive_zone(win, -1)
    GtkLayerShell.set_keyboard_mode(win, GtkLayerShell.KeyboardMode.NONE)

    win.set_app_paintable(True)
    screen = win.get_screen()
    visual = screen.get_rgba_visual()
    if visual is not None:
        win.set_visual(visual)

    # IMPORTANT: a bare toplevel Gtk.Window doesn't reliably deliver
    # enter/leave crossing events on Wayland. An EventBox owns its own
    # input window, so it does. Put the events on the EventBox, not win.
    eventbox = Gtk.EventBox()
    eventbox.set_size_request(-1, HOTSPOT_HEIGHT_PX)  # prevent GTK collapsing empty content to 0px
    eventbox.add_events(Gdk.EventMask.ENTER_NOTIFY_MASK | Gdk.EventMask.LEAVE_NOTIFY_MASK)
    eventbox.connect("enter-notify-event", on_enter)
    eventbox.connect("leave-notify-event", on_leave)

    # DEBUG ONLY: paint it visibly red so you can literally see the strip
    # and confirm it's placed/sized where you expect. Remove once confirmed.
    #eventbox.override_background_color(Gtk.StateFlags.NORMAL, Gdk.RGBA(1, 0, 0, 0.6))

    win.add(eventbox)

    win.connect("realize", lambda w: print("realized", flush=True))
    win.connect("map-event", lambda w, e: print("mapped", flush=True))

    win.show_all()
    return win


if __name__ == "__main__":
    build_window()
    Gtk.main()
