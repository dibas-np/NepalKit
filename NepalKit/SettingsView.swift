// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import NepalKitCore
import SwiftUI

/// The Settings window: a sidebar of three destinations over the shared
/// models, so no setting is writable from two places.
struct SettingsView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Bindable var settings: DisplaySettingsModel
    @Bindable var loginItem: LoginItemModel
    let updates: UpdateCheckModel
    let menuBar: MenuBarModel
    /// The cache, not its value, because this initialiser runs at launch.
    let metadataCache: DeferredAppMetadata
    let dataset: CalendarDataset

    /// Optional because `List(selection:)` needs `Binding<SelectionValue?>`; a
    /// non-optional binding compiles but leaves the sidebar unresponsive.
    @State private var tab: SettingsTab? = SettingsTab.landingTab

    var body: some View {
        // A system `TabView` sidebar: unlike `NavigationSplitView` it has no collapse
        // affordance to remove.
        VStack(spacing: 0) {
            TabView(selection: $tab) {
                ForEach(SettingsTab.allCases) { destination in
                    Tab(destination.title, systemImage: destination.symbol, value: destination) {
                        content(for: destination)
                    }
                }
            }
            .tabViewStyle(.sidebarAdaptable)
            .toolbar(removing: .sidebarToggle)

            // A layout sibling, not a safe-area inset: an inset on the TabView does not
            // reach the tab contents' scroll views, so rows scrolled under the strip.
            SettingsIdentityStrip(metadata: metadataCache.value)
        }
        // Fits About's Devanagari range line and the General form without scrolling.
        .frame(minWidth: 640, minHeight: 440)
        .task { loginItem.refreshStatus() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                loginItem.refreshStatus()
            }
        }
    }

    // MARK: - Destinations

    @ViewBuilder
    private func content(for destination: SettingsTab) -> some View {
        switch destination {
        case .menuBar:
            MenuBarSettingsView(
                menuBar: menuBar,
                settings: settings.settings,
                timeReference: settings.timeReference,
                updateAvailable: updates.isShowingReminder
            )
        case .general:
            GeneralSettingsView(
                settings: settings,
                loginItem: loginItem,
                dataset: dataset
            )
        case .about:
            AboutSettingsView(
                updates: updates,
                metadata: metadataCache.value,
                dataset: dataset
            )
        }
    }
}

/// The app's icon, name, version and source link along the bottom of the window.
private struct SettingsIdentityStrip: View {
    let metadata: AppMetadata

    var body: some View {
        HStack(spacing: 8) {
            if let icon = metadata.applicationIcon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 24, height: 24)
                    .accessibilityHidden(true)
            }
            Text(metadata.name)
                .font(.callout.weight(.semibold))
                .lineLimit(1)
            Text(Strings.versionLabel(metadata.versionDescription))
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Spacer(minLength: 12)

            if let repository = metadata.repositoryURL {
                SourceLink(repository: repository)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        // Glass on a clear layer inside the strip: Liquid Glass only shows where
        // nothing paints over it, and `.bar` is opaque.
        .background {
            GlassEffectContainer(spacing: 0) {
                Rectangle()
                    .fill(.clear)
                    .glassEffect(.regular, in: .rect)
            }
        }
        // Separates the strip from the selected tab's content.
        .overlay(alignment: .top) { Divider() }
    }
}

/// The repository link: a short visible label, announced in full.
private struct SourceLink: View {
    let repository: URL

    var body: some View {
        Link(destination: repository) {
            // An explicit HStack: `Label` under `.buttonStyle(.glass)` rendered as the
            // bare glyph.
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
        .accessibilityValue(repository.absoluteString)
    }
}

#if DEBUG
#Preview("Settings window") {
    SettingsView(
        settings: .preview,
        loginItem: LoginItemModel(service: PreviewLoginService()),
        updates: UpdateCheckModel(service: PreviewUpdateService()),
        menuBar: MenuBarModel(now: AppData.previewInstant, refreshes: false),
        metadataCache: DeferredAppMetadata(),
        dataset: AppData.dataset
    )
    .frame(width: 700, height: 460)
}
#endif
