import AppKit
import SwiftUI

// Explicit alias avoids the SDK's same-named State macro in CLT builds.
typealias ViewState<Value> = SwiftUI.State<Value>

/// Native materials, system typography, and the user's chosen accent color.
struct ShelfView: View {
    @ObservedObject var model: LibraryModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("DownloadScroller").font(.headline)
                Spacer()
                Button { model.onShowDockSettings?() } label: { Image(systemName: "gearshape") }
                    .buttonStyle(.borderless).accessibilityLabel("Dock & Launchers")
                Button { model.onDismiss?() } label: { Image(systemName: "xmark") }
                    .buttonStyle(.borderless).accessibilityLabel("Close window")
            }.padding(26)
            Spacer(minLength: 12)
            Image(nsImage: AppLogo.image(dark: colorScheme == .dark))
                .resizable().scaledToFit().frame(width: 152, height: 152).accessibilityHidden(true)
            Text("Downloads, unfolded.").font(.system(size: 28, weight: .semibold)).padding(.top, 16)
            Text("A familiar fan. Room for every file.")
                .font(.body).foregroundStyle(.secondary).padding(.top, 8)
            Spacer(minLength: 25)
            VStack(alignment: .leading, spacing: 16) {
                Label("Recent files stay closest to your Dock", systemImage: "square.stack.3d.up")
                Label("Scroll up to browse older downloads", systemImage: "arrow.up.and.down")
                Label("Find, preview, and open in a moment", systemImage: "magnifyingglass")
            }.font(.body).foregroundStyle(.secondary).padding(.horizontal, 35)
            Spacer(minLength: 25)
            if let message = model.errorMessage {
                Label(message, systemImage: "exclamationmark.circle")
                    .font(.callout).foregroundStyle(.red).padding(.horizontal, 30).padding(.bottom, 12)
            }
            Button { model.chooseFolder() } label: {
                Label("Choose Downloads folder", systemImage: "folder.badge.plus").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent).controlSize(.large).padding(.horizontal, 30)
            Button("Take a look with sample files") { model.useSamples() }
                .buttonStyle(.borderless).padding(.top, 16)
            Text("On your Mac. Just your files.").font(.caption).foregroundStyle(.secondary)
                .padding(.top, 25).padding(.bottom, 25)
        }
        .foregroundStyle(.primary)
        .background(NativeMaterial(material: .windowBackground, radius: 24))
        .onExitCommand { model.handleEscape() }
    }
}
