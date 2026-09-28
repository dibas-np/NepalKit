-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright (C) 2026 Dibas Sigdel
--
-- Check that a mounted DMG's Finder window is the window that was designed.
--
-- The layout is written by Finder into the volume's `.DS_Store`, by a mechanism
-- Apple documents nowhere, into a format Apple documents nowhere. A release
-- that silently ships Finder's default arrangement instead is a release that
-- passed every other gate: the DMG is signed, notarized, stapled and
-- Gatekeeper-clean, and the window a user drags the app out of is a default
-- one. So the window is read back off the finished image and compared against
-- the layout it was supposed to be given.
--
-- Read back rather than diffed: the bytes can match while Finder ignores them,
-- and that is exactly the failure worth catching.
--
-- Usage: osascript scripts/verify-dmg-layout.applescript <volume> <app> <layout.json>
-- Exits 0 if the window matches, 1 with the list of mismatches otherwise.

use framework "Foundation"

on run argv
	set volumeName to item 1 of argv
	set appName to item 2 of argv
	set layout to (readLayout(item 3 of argv)) as record

	set expectedWindowSize to layout's windowSize
	set expectedIconSize to layout's iconSize
	set expectedAppCentre to layout's appIconCentre
	set expectedApplicationsCentre to layout's applicationsIconCentre

	set mismatches to {}

	tell application "Finder"
		tell disk volumeName
			open
			set windowBounds to bounds of container window
			set viewOptions to icon view options of container window
			set actualIconSize to icon size of viewOptions
			set appPosition to position of item (appName & ".app") of container window
			set applicationsPosition to position of item "Applications" of container window
			set toolbarShown to toolbar visible of container window
			set statusBarShown to statusbar visible of container window
			set arrangementMode to arrangement of viewOptions

			-- Bounds are {left, top, right, bottom} on screen. Only the size is
			-- checked: where a window opens is the user's business and Finder's
			-- to remember, and asserting on it would fail on any Mac that had
			-- already opened the volume once.
			set actualWindowSize to {(item 3 of windowBounds) - item 1 of windowBounds, (item 4 of windowBounds) - item 2 of windowBounds}
			if actualWindowSize is not expectedWindowSize then
				set end of mismatches to "window is " & my describe(actualWindowSize) & "pt, expected " & my describe(expectedWindowSize) & "pt"
			end if
			if actualIconSize is not expectedIconSize then
				set end of mismatches to "icon size is " & actualIconSize & ", expected " & expectedIconSize
			end if
			if appPosition is not expectedAppCentre then
				set end of mismatches to appName & ".app sits at " & my describe(appPosition) & ", expected " & my describe(expectedAppCentre)
			end if
			if applicationsPosition is not expectedApplicationsCentre then
				set end of mismatches to "Applications sits at " & my describe(applicationsPosition) & ", expected " & my describe(expectedApplicationsCentre)
			end if
			if toolbarShown then
				set end of mismatches to "the toolbar is showing"
			end if
			if statusBarShown then
				set end of mismatches to "the status bar is showing"
			end if
			if arrangementMode is not not arranged then
				set end of mismatches to "icons are arranged (" & arrangementMode & ") rather than hand-placed"
			end if
		end tell
	end tell

	if mismatches is {} then return "ok"
	error (my join(mismatches, "; ") & " — the DMG would ship with the wrong window") number 1
end run

on describe(pair)
	return "{" & (item 1 of pair) & ", " & (item 2 of pair) & "}"
end describe

on join(itemsToJoin, separatorText)
	set joined to ""
	repeat with i from 1 to count itemsToJoin
		set joined to joined & item i of itemsToJoin
		if i < count itemsToJoin then set joined to joined & separatorText
	end repeat
	return joined
end join

on readLayout(json)
	set text_ to current application's NSString's stringWithString:json
	set data_ to text_'s dataUsingEncoding:(current application's NSUTF8StringEncoding)
	-- `|error|`: the parameter is named after the `error` statement, and
	-- without the vertical bars the `error` below is read as more of the same
	-- expression rather than as a new statement.
	set object_ to current application's NSJSONSerialization's JSONObjectWithData:data_ options:(current application's NSJSONReadingFragmentsAllowed) |error|:(missing value)
	if object_ is missing value then
		error "the layout was not valid JSON: " & json number 1001
	end if
	return object_
end readLayout
