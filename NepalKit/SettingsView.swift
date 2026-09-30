// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import NepalKitCore
import SwiftUI

/// The native Settings surface: a sidebar of three destinations.
///
/// The relocation from the popover added no new setting. The models passed in are
/// the ones the popover already read, so there is exactly one source of truth and
/// no value is writable from two places. Persistence stays in `SettingsStore`
/// keyed by bundle identifier, so settings survive relaunch and updates.
///
/// Control types are carried over unchanged from the popover deliberately: a
/// user who knows the segmented pickers should not have to relearn them.
/// Gregorian month names stay English — the month-name setting governs Bikram
/// Sambat and weekday names only, so a date may carry a Devanagari day and
/// year, an English Gregorian month name, and a weekday in either language at
/// once. That combination is intended (CONTEXT.md).
///
/// The selected destination is ephemeral for the same reason the popover's is:
/// Settings is not where anyone begins a task, so remembering the last one would
/// open a window onto a page the user did not ask for. `SettingsTab.landingTab`
/// is the resting state.
struct SettingsView: View {
    @Bindable var settings: DisplaySettingsModel
    @Bindable var loginItem: LoginItemModel
    /// The updater is constructed and started at launch (NepalKitApp), so the About
    /// tab always has a model to read; its outcome state comes from the same
    /// instance the background check reports into.
    @Bindable var updates: UpdateCheckModel
    /// Read by the Menu Bar preview so that tab cannot disagree with the real
    /// menu-bar label. Deliberately not `@Bindable`: the preview shows the label,
    /// it does not drive it, and a binding would invite writing to it here.
    let menuBar: MenuBarModel
    /// Read once, lazily, and cached — see `DeferredAppMetadata` for why the
    /// bundled LICENSE is not read at launch.
    let metadata: AppMetadata
    /// Injected so the calendar facts are the same dataset the rest of the app
    /// converts with, and so a test can control them.
    let dataset: CalendarDataset

    /// Optional, because `List(selection:)` single-selection takes
    /// `Binding<SelectionValue?>` and nothing else. With a non-optional binding the
    /// sidebar did not wire up at all: it highlighted its own first row instead of
    /// `landingTab`, and clicking a row changed nothing. Two destinations in, the
    /// window was unusable — and it compiled, and every gate passed, because the
    /// binding's type is legal either way. See the commit message.
    @State private var tab: SettingsTab? = SettingsTab.landingTab

    var body: some View {
        // A system `TabView` sidebar, not a split view with a hand-built `List`.
        //
        // Three attempts to remove the collapse button from a
        // `NavigationSplitView` failed, and the third cost the window its traffic
        // lights, so the sidebar this view drew itself is the thing that had to go.
        // A `TabView` sidebar is drawn by the system: there is no toggle to remove
        // because there is no collapse affordance to begin with, and the material,
        // selection highlight and inset behaviour are the platform's own rather
        // than a `List(.sidebar)` imitating them.
        //
        // `sidebarAdaptable` is the only sidebar style on this SDK - there is no
        // `sidebarTabViewStyle` - and "adaptable" means sidebar in a window of this
        // size, switching to a tab bar only when the space is genuinely compact.
        TabView(selection: $tab) {
            ForEach(SettingsTab.allCases) { destination in
                Tab(destination.title, systemImage: destination.symbol, value: destination) {
                    content(for: destination)
                }
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        // The identity strip moves to the bottom of the *window* rather than the
        // bottom of the sidebar. That is the trade for using the system sidebar: it
        // owns its column, so nothing can be placed under the destinations. The
        // strip is the window's identity rather than a destination, and spanning
        // the full width is where a window's status material belongs anyway.
        .safeAreaInset(edge: .bottom, spacing: 0) {
            SettingsIdentityStrip(metadata: metadata)
        }
        // Wide enough for the longest detail (About's Devanagari range line) beside
        // the sidebar without clipping, and tall enough that the General form's two
        // sections do not need to scroll. A minimum, not a fixed size: the window
        // opens at whatever the user last set, and refuses to go below the point
        // where the content stops fitting.
        .frame(minWidth: 640, minHeight: 440)
    }

    // MARK: - Destinations

    @ViewBuilder
    private func content(for destination: SettingsTab) -> some View {
        switch destination {
        case .menuBar:
            MenuBarSettingsView(
                menuBar: menuBar,
                settings: settings.settings,
                updateAvailable: updates.isShowingReminder
            )
        case .general:
            GeneralSettingsView(
                settings: settings,
                loginItem: loginItem
            )
        case .about:
            AboutSettingsView(
                updates: updates,
                metadata: metadata,
                dataset: dataset
            )
        }
    }
}

/// The window's own identity, along the bottom of the window.
///
/// Named for what it is rather than where it used to live: it is no longer a
/// sidebar footer.
///
/// Icon, name, version and a link to the source. This is the answer to "what am I
/// running, and where do I go to tell someone?" — the two questions a person opens
/// Settings with most often, answered without hunting for the About tab.
///
/// It repeats the version the About tab shows on purpose. That tab is where you go
/// to read it deliberately; this is the always-visible strip. A version number
/// that is only findable on one tab is not findable when you are trying to read it
/// off a screenshot.
private struct SettingsIdentityStrip: View {
    let metadata: AppMetadata

    /// One row, not a stack.
    ///
    /// It was a two-row column when it lived under the sidebar's destinations, where
    /// the column was narrow and the width had to be spent. Across the full window
    /// there is room for everything on one line, and a strip that is one row reads
    /// as window furniture rather than as a fourth destination.
    var body: some View {
        HStack(spacing: 8) {
            if let icon = metadata.applicationIcon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 24, height: 24)
                    // Decorative: the name is beside it and is what identifies the
                    // build. Exposed, this is a stop that only says "image" before
                    // the name that carries the meaning.
                    .accessibilityHidden(true)
            }
            Text(metadata.name)
                .font(.callout.weight(.medium))
                .lineLimit(1)
            Text(Strings.versionLabel(metadata.versionDescription))
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Spacer(minLength: 12)

            // A real link, never text styled to look like one. The repository URL
            // comes from the build's metadata, so it cannot drift from the remote
            // the app was published from.
            if let repository = metadata.repositoryURL {
                SourceLink(repository: repository)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        // Glass, on the strip's own content, for the reason the Menu Bar tab's
        // value gives at length: Liquid Glass is only visible where nothing paints
        // over it, and `.bar` is opaque. Applying the material to a transparent
        // layer *inside* the strip and letting the content sit on top of it is
        // what makes it show, rather than putting a `glassEffect` somewhere
        // further out where the strip's own background covers it.
        .background {
            GlassEffectContainer(spacing: 0) {
                Rectangle()
                    .fill(.clear)
                    .glassEffect(.regular, in: .rect)
            }
        }
        // A Divider above, because without it the strip reads as content belonging
        // to whichever tab is selected rather than as part of the window.
        .overlay(alignment: .top) { Divider() }
    }
}

/// The repository link, labelled "Source".
///
/// Text, not a bare glyph. The earlier ghost treatment — a glyph that only
/// appeared on hover — was the wrong call twice over: it hid the only control
/// that takes you out of the app behind a pointer gesture, and a glyph that
/// appears on hover gives a keyboard user nothing to see. Naming it means it is
/// discoverable without a mouse, and it matches the popover footer, which shows
/// its "Quit" text for the same reason.
///
/// `.glass` like the popover footer's buttons, so the two surfaces' controls are
/// the same kind of object. The word is the short one because the row is narrow and
/// "Source repository" wraps; the announcement keeps the full phrase, because
/// "Source" alone does not say what it points at.
private struct SourceLink: View {
    let repository: URL

    var body: some View {
        Link(destination: repository) {
            // An explicit HStack, not a `Label`.
            //
            // `Label("Source", systemImage:)` under `.buttonStyle(.glass)` rendered
            // as the bare glyph: the word was simply not there. Whether the glass
            // style collapses a Label or the sidebar clipped it, `Label` leaves that
            // ambiguous — a Label is *allowed* to show only its icon, so the failure
            // is silent and looks intentional. `Text` beside `Image` has no such
            // mode: if the word is missing now, something is actually broken rather
            // than the label doing its job.
            HStack(spacing: 4) {
                Image(systemName: Symbols.repository)
                    .symbolRenderingMode(.monochrome)
                Text(Strings.sourceLinkTitle)
            }
            .font(.caption)
        }
        .buttonStyle(.glass)
        .lineLimit(1)
        .accessibilityLabel(Strings.repositoryLabel)
        // The label says what the link is; the destination is the part a sighted
        // user reads off the screen and a blind user otherwise never learns, so it
        // becomes the value.
        .accessibilityValue(repository.absoluteString)
    }
}

#if DEBUG
/// Preview stand-ins so the canvas renders without Sparkle, the login-item
/// service, or persistence side effects. Nothing else may use these: the
/// production seams live in NepalKitApp, and a mock that leaked past #if DEBUG
/// would silently replace the real services. `PreviewUpdateService` is
/// MainActor because `UpdateServicing` requires it; `PreviewLoginService` stays
/// nonisolated because `LoginItemServicing` is nonisolated, and a MainActor
/// conformance only satisfies that protocol where default isolation agrees.
@MainActor private final class PreviewUpdateService: UpdateServicing {
    var onOutcome: (@MainActor (UpdateOutcome) -> Void)?
    var onReminder: (@MainActor (Bool) -> Void)?
    var automaticallyChecksForUpdates = true
    func start() {}
    func checkForUpdates() {}
}

private final class PreviewLoginService: LoginItemServicing {
    var isRegistered = true
    func register() throws {}
    func unregister() throws {}
}

#Preview("Settings window") {
    SettingsView(
        settings: .preview,
        loginItem: LoginItemModel(service: PreviewLoginService()),
        updates: UpdateCheckModel(service: PreviewUpdateService()),
        menuBar: MenuBarModel(now: AppData.previewInstant, refreshes: false),
        metadata: .current(),
        dataset: AppData.dataset
    )
    .frame(width: 700, height: 460)
}
#endif
