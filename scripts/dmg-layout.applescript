-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright (C) 2026 Dibas Sigdel
--
-- Usage: osascript scripts/dmg-layout.applescript <volume> <app> <background.png> <layout.json>

use framework "Foundation"

on run argv
	set volumeName to item 1 of argv
	set appName to item 2 of argv
	set backgroundPath to item 3 of argv
	set layout to (readLayout(item 4 of argv)) as record

	set windowSize to layout's windowSize
	set iconSize to layout's iconSize
	set appIconCentre to layout's appIconCentre
	set applicationsIconCentre to layout's applicationsIconCentre

	set windowOrigin to {200, 150}
	set windowBounds to {item 1 of windowOrigin, item 2 of windowOrigin, ¬
		(item 1 of windowOrigin) + item 1 of windowSize, ¬
		(item 2 of windowOrigin) + item 2 of windowSize}

	tell application "Finder"
		tell disk volumeName
			open
			set current view of container window to icon view
			set toolbar visible of container window to false
			set statusbar visible of container window to false
			set bounds of container window to windowBounds

			set viewOptions to icon view options of container window
			set arrangement of viewOptions to not arranged
			set icon size of viewOptions to iconSize
			set text size of viewOptions to 12
			set background picture of viewOptions to (POSIX file backgroundPath)

			set position of item (appName & ".app") of container window to appIconCentre
			set position of item "Applications" of container window to applicationsIconCentre

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
	-- `|error|` needs the bars, or the later `error` statement misparses.
	set object_ to current application's NSJSONSerialization's JSONObjectWithData:data_ options:(current application's NSJSONReadingFragmentsAllowed) |error|:(missing value)
	if object_ is missing value then
		error "the layout was not valid JSON: " & json number 1001
	end if
	return object_
end readLayout
