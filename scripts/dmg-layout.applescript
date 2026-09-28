-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright (C) 2026 Dibas Sigdel
--
-- Lay out the drag-install Finder window on a mounted DMG.
--
-- Finder does not arrange a DMG window for you: unscripted it is a
-- default-sized window with the app and the Applications shortcut stacked in
-- the top-left corner, which is the first thing a user sees of NepalKit. The
-- geometry is not passed in as numbers by this script — it arrives as the JSON
-- that `make-dmg-artwork.swift` prints, which is the same description the
-- artwork was drawn from. Passing the numbers in separately would allow the
-- two to disagree, and a caption that misses its arrow is worse than no
-- caption.
--
-- Usage: osascript scripts/dmg-layout.applescript <volume> <background.png> <layout.json>

use framework "Foundation"

on run argv
	set volumeName to item 1 of argv
	set backgroundPath to item 2 of argv
	set layout to (readLayout(item 3 of argv)) as record

	set windowSize to layout's windowSize
	set iconSize to layout's iconSize
	set appIconOrigin to layout's appIconOrigin
	set applicationsIconOrigin to layout's applicationsIconOrigin

	-- Where the window opens on screen is not part of the layout: Finder
	-- restores that per user, and a DMG that remembers a position is an
	-- annoyance rather than a design. Only the size is fixed, because the
	-- artwork is drawn to fill it.
	set windowOrigin to {200, 150}
	set windowBounds to {item 1 of windowOrigin, item 2 of windowOrigin, ¬
		(item 1 of windowOrigin) + item 1 of windowSize, ¬
		(item 2 of windowOrigin) + item 2 of windowSize}

	tell application "Finder"
		tell disk volumeName
			open
			set current view of container window to icon view
			-- The chrome is what makes this window look like a poster rather
			-- than a folder of files. It also costs the drag target room.
			set toolbar visible of container window to false
			set statusbar visible of container window to false
			set bounds of container window to windowBounds

			set viewOptions to icon view options of container window
			set arrangement of viewOptions to not arranged
			set icon size of viewOptions to iconSize
			set text size of viewOptions to 12
			set background picture of viewOptions to (POSIX file backgroundPath)

			set position of item (volumeName & ".app") of container window to appIconOrigin
			set position of item "Applications" of container window to applicationsIconOrigin

			-- The layout reaches the volume only when the window closes, and
			-- the .DS_Store only reaches the image when Finder is told to write
			-- it. Skip either step and the window comes back in Finder's
			-- default arrangement on the next mount, which is exactly the
			-- failure this script exists to prevent.
			close
			open
			update without registering applications
			delay 2
		end tell
	end tell
end run

on readLayout(json)
	set text_ to current application's NSString's stringWithString:json
	set data_ to text_'s dataUsingEncoding:(current application's NSUTF8StringEncoding)
	-- `|error|`: the parameter is named after the `error` statement, and
	-- without the vertical bars the next `error` in this handler is read as
	-- more of the same expression rather than as a new statement.
	set object_ to current application's NSJSONSerialization's JSONObjectWithData:data_ options:(current application's NSJSONReadingFragmentsAllowed) |error|:(missing value)
	if object_ is missing value then
		error "the layout was not valid JSON: " & json number 1001
	end if
	return object_
end readLayout
