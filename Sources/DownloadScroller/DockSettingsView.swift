import SwiftUI

struct DockSettingsView: View {
    private static let privacyPolicyURL = URL(string: "https://github.com/mganesh1610/DownloadScroller/blob/main/PRIVACY.md")!

    @ObservedObject var model: DockSettingsModel
    @ObservedObject var visibility: DockVisibility
    @ObservedObject var fanPositions: FanPositionPreferences

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Toggle("Show app in Dock", isOn: Binding(get: { visibility.isVisible }, set: { model.setDockVisible($0) }))
                    .toggleStyle(.switch)
                Text("The menu-bar button stays available. A shortcut you pinned manually may remain until you remove it from the Dock.")
                    .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            Divider()
            VStack(alignment: .leading, spacing: 10) {
                Text("Create a launcher").font(.headline)
                HStack {
                    TextField("Launcher name", text: $model.draftName).textFieldStyle(.roundedBorder)
                        .accessibilityLabel("Launcher name")
                    Button("Create launcher") { model.create() }
                        .disabled(model.draftFolder == nil || !model.storageAvailable)
                }
                HStack {
                    Label(model.draftFolder?.name ?? "Choose a folder", systemImage: "folder")
                        .lineLimit(1).truncationMode(.middle)
                    Spacer()
                    Button("Choose folder…") { model.chooseDraftFolder() }
                        .accessibilityLabel("Choose launcher folder")
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("Your launchers").font(.headline)
                List(selection: $model.selectedID) {
                    ForEach(model.profiles) { profile in
                        HStack(spacing: 10) {
                            Image(systemName: "square.stack.3d.up").foregroundStyle(.secondary)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(profile.name).fontWeight(.medium)
                                Text(profile.folder.name).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Toggle("Enabled", isOn: Binding(get: { profile.isEnabled }, set: { model.setEnabled($0, id: profile.id) }))
                                .toggleStyle(.switch).controlSize(.small)
                                .accessibilityLabel("Enable \(profile.name)")
                        }
                        .padding(.vertical, 4)
                        .tag(profile.id)
                    }
                }
                .listStyle(.bordered).frame(minHeight: 130)
                .overlay {
                    if model.profiles.isEmpty {
                        Text(model.storageAvailable ? "Create a launcher to get started." : "Saved launchers are unavailable.")
                            .foregroundStyle(.secondary).allowsHitTesting(false)
                    }
                }
                HStack {
                    Button("Open fan") { model.openSelected() }.disabled(model.selected?.isEnabled != true)
                    Button("Duplicate") { model.duplicateSelected() }.disabled(model.selected == nil)
                    Button("Change folder…") { model.changeSelectedFolder() }.disabled(model.selected == nil)
                    Button(model.selectedID != nil && fanPositions.rightLauncherID == model.selectedID ? "Fixed on right" : "Fix on right") {
                        if let id = model.selectedID { fanPositions.fixOnRight(id) }
                    }.disabled(model.selectedID == nil || fanPositions.rightLauncherID == model.selectedID)
                    Spacer()
                    Button("Show in Finder") { model.revealSelected() }.disabled(model.selected == nil)
                }
            }
            Text("Drag the original from Show in Finder to the Dock beside Trash. Leave the file in place to keep its recent-file icon up to date. Each launcher opens its own fan.")
                .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            if let message = model.message {
                Text(message).font(.callout).textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel(message)
            }
            HStack {
                Link("Privacy Policy", destination: Self.privacyPolicyURL)
                Spacer()
                Button("Quit DownloadScroller") { NSApp.terminate(nil) }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
