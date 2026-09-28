# The DMG window is designed, laid out by Finder, and read back before release

**Governs the DMG half of `scripts/package-release.sh`. The window is a shipped
surface, not packaging debris.**

The double-clicked DMG is the first thing a user sees of NepalKit — it arrives
before the menu-bar date, and for a menu-bar-only app it is the only window the
app will ever show on its own. Finder will not lay one out: unscripted it is a
default-sized window with the app and the Applications shortcut stacked in the
top-left corner and the disk image's filename as a caption.

**Decision: the window is a designed surface.** A background image with an
arrow and a caption, generated at build time from one description of the layout
that both the artwork and Finder are driven from, written onto the image by
Finder, and read back off the finished DMG as a hard gate.

## Where a Finder window's layout actually lives

In `.DS_Store` at the root of the volume: a `bwsp` blob carrying the window
bounds and the background's alias record, and an `icvp` blob carrying the icon
view options — arrangement, icon size, text size, and the alias to the
background picture. Apple documents neither the file nor the mechanism, and
there is no API for writing one.

The consequence that shaped everything else: **a `.DS_Store` cannot be shipped
by copying it into a folder.** `diskutil image create from` deliberately drops
it — other dotfiles in the same directory are copied, `.DS_Store` alone is
skipped — so a DMG built the obvious way is a default Finder window no matter
what the staging directory contains. This was measured, not inferred, and it is
the reason the old pipeline could not have shipped a layout even if someone had
written one.

So the layout has to be written by Finder onto a mounted, writable volume, and
the shipped image has to be made from that volume afterwards. That is the whole
reason the release script now builds two images instead of one.

## The image is a read-write HFS+ image, converted, and hdiutil is used twice

Both `hdiutil` calls are deprecated and both are deliberate.

`diskutil image create blank` is the supported way to make a read-write image,
and every filesystem it offers is unusable here: ExFAT and MS-DOS cannot hold
the `/Applications` symlink, and its APFS option produces a container that
**cannot be converted to a compressed UDZO image at all** — `diskutil image
create from` and `hdiutil convert` both fail with `EBUSY` on it, verified. A
single-volume HFS+ image converts cleanly, and `hdiutil convert` is the only
thing that performs that conversion: the deprecation notice on it points at
`diskutil image create from`, which fails with `EBUSY` on a disk-image source.

The warnings are filtered out of the release log. A log that always carries a
deprecation notice trains people to stop reading it, which is a worse outcome
than a documented, deliberate use of two deprecated calls whose replacements
cannot do the job. Anything hdiutil says that is not that one line is passed
through, and a non-zero exit still fails the release.

Two more details that are not obvious and cost the most to find:

- **Ejecting is not unmounting.** An image that is merely unmounted is still
  attached, and converting an attached image fails with `EBUSY` and a message
  that never mentions attachments. The whole disk has to be ejected, and
  `diskutil image attach --plist` is the only non-deprecated way to learn which
  device that is — the volume's identifier is the only thing printed without it.
  The cleanup trap covers this too, so a failed release does not leave an image
  attached to break the next one.
- **`hdiutil create` with a size, not `diskutil image create blank`.** The
  layout volume's *own* name must be `NepalKit`, because the background's alias
  is recorded against it, but it must be *mounted* somewhere unique. Finder
  identifies a mounted disk by the last component of its mount point, so if
  another `NepalKit` is mounted on the release machine, `tell disk "NepalKit"`
  scripts that one instead. The failure is completely silent: the layout is
  written to a volume nobody ships, and the DMG comes out default. Hence
  `/Volumes/NepalKit-layout`.

## The composition, and why it is defined in one place

Finder positions an item at a point in the window's **content area**
coordinates, and that point is the **centre of the item's cell**, not its
corner. Finder draws the background picture at the image's *logical* size,
centred in the same content area, without scaling it — and a file named `@2x`
counts as half its pixel size, which is what keeps 2x artwork from being drawn
twice as large.

Three facts, and the layout follows from them:

1. The image is authored one-to-one in content coordinates, so `position` and
   drawing coordinates are the same numbers.
2. The arrow sits on the icons' shared centre line, which is also the image's
   centre, and therefore the content area's centre.
3. The icons are centred on that same line.

So `scripts/make-dmg-artwork.swift` owns the whole layout and prints it as JSON;
`scripts/dmg-layout.applescript` is handed that JSON rather than a set of
numbers of its own. A layout that drifts is a layout nobody can reason about,
because its halves would be edited in two files. The caption text, the arrow,
the icon positions and the window size all come from one place, and the artwork
cannot disagree with the icon positions it was drawn between.

The artwork is 2x, named `dmg-background@2x.png`, in a `.background` folder
inside the volume — the convention a shipping commercial DMG uses, and the
reason the image stays sharp on a Retina display.

## The read-back is a hard gate, and the background is checked in the file

Every other gate in the release script passes just as happily on a DMG whose
window is Finder's default. The image is signed, notarized, stapled and
Gatekeeper-clean either way; the layout lives in an undocumented file that Apple
is free to stop reading. So the window is read back **off the finished image**
and compared against the layout it was supposed to be given — read back rather
than diffed, because the bytes can match while Finder ignores them, which is
precisely the failure worth catching. Window size, both icon positions, icon
size, arrangement, and the toolbar and status bar are all asserted, and every
mismatch is reported at once rather than one per run.

One property cannot be read: `background picture` is declared as a `file` in
Finder's dictionary, and every way of asking for it fails with `-10000` whether
or not one is set. It is checked where it is actually stored instead — the
icon view options inside `.DS_Store` must name the artwork, and the artwork
must be in the image. Attempting the AppleScript read again is a dead end, and
the reason is recorded next to the gate so nobody spends the time again.

The check runs on a mount that is **not** `nobrowse`, unlike every other mount in
the script, because Finder cannot describe a window for a volume it has been
told not to show. A Finder window opens on screen during a release. That is the
price of checking the window.

## The numbers that belong to macOS, not to NepalKit

The window is the content area plus the furniture Finder draws around it, and
that furniture is measured rather than assumed: a 4pt border down each side, a
32pt title bar above, a 32pt path bar below, on macOS 26/27. Only the packager
needs those numbers — the artwork is authored against the content area alone and
centred in it, so an OS change moves the window rather than breaking the
alignment.

**The residual risk is the path bar, and it is not closed.** Its visibility is a
Finder-wide user setting with no key in `.DS_Store` and no AppleScript property,
so the packager cannot pin it. A user who has turned the path bar off gets a
content area 32pt taller, the image stays centred in it, and the icons — placed
at the centre of the content area the packager measured — sit about 16pt above
the arrow. The arrow is between the icons either way and the window still works;
it is a composition that no longer lines up.

## Still needs human eyes

Recorded rather than claimed as verified, for the same reason the boundary-state
layout and the ⌘Q shortcut are recorded in the README:

- **The finished composition, on the real icon, on macOS 26.** It was built and
  measured on macOS 27. The window is verified by gate, but "verified" means the
  geometry read back matches what was asked for — not that the result looks
  right, which is a judgement no assertion makes.
- **A Mac whose Finder has the path bar off**, which is the one configuration
  where the composition is known to drift. The fresh-Mac install procedure is
  where that gets caught, so the arrow is on its checklist.
- **A second mounted volume called `NepalKit`.** Handled by mounting the layout
  volume at a unique path, and worth knowing is handled rather than assumed.

## Considered options

**Ship a plain window and let users work it out.** Rejected. The drag-install
window is the app's first impression and the only window a menu-bar-only app
shows unprompted; leaving it as Finder's default is a design decision taken by
not deciding.

**Hand-write `.DS_Store` from the build script.** Rejected. It would remove
Finder scripting and the writable image, but the format is undocumented and
reverse-engineered, `bwsp` needs a valid alias record, and a format Apple may
change at any time would then be load-bearing for every release. Finder writing
its own state is at least self-consistent, and the gate catches the day it stops
being so.

**Add a README or install script to the DMG instead.** Rejected. A file in the
window is a third thing for the eye to read, and it competes with the two icons
the user has to act on.

**A SwiftUI onboarding window on first launch instead.** Not this decision, and
not rejected by it — a different surface, at a different moment, answering a
different question. The DMG window is what a user sees before the app has ever
run; it cannot wait for the app to have an opinion.
