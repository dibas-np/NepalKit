// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import NepalKitCore
import SwiftUI

struct SettingsView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Bindable var settings: DisplaySettingsModel
    @Bindable var loginItem: LoginItemModel
    let updates: UpdateCheckModel
    let menuBar: MenuBarModel
    let metadataCache: DeferredAppMetadata
    let dataset: CalendarDataset

    @State private var tab: SettingsTab? = SettingsTab.landingTab

    var body: some View {
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

            SettingsIdentityStrip(metadata: metadataCache.value)
        }
        .frame(minWidth: 640, minHeight: 440)
        .task { loginItem.refreshStatus() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                loginItem.refreshStatus()
            }
        }
    }

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
        .background {
            GlassEffectContainer(spacing: 0) {
                Rectangle()
                    .fill(.clear)
                    .glassEffect(.regular, in: .rect)
            }
        }
        .overlay(alignment: .top) { Divider() }
    }
}

private struct SourceLink: View {
    let repository: URL

    var body: some View {
        Link(destination: repository) {
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
