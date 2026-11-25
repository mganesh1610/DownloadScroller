import AppKit
import SwiftUI
#if SWIFT_PACKAGE
import DownloadScrollerCore
#endif

/// A floating stack of filename capsules and file icons, matching the visual
/// language of the system Dock fan while remaining an independent app window.
struct DockFanView: View {
    @ObservedObject var model: LibraryModel
    @FocusState private var searchFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var alignment: HorizontalAlignment { model.fanIconSide == .left ? .leading : .trailing }
    private var baseEdge: Edge.Set { model.fanIconSide == .left ? .leading : .trailing }

    var body: some View {
        GeometryReader { geometry in fan(width: geometry.size.width) }
    }

    private func fan(width: CGFloat) -> some View {
        VStack(alignment: alignment, spacing: 0) {
            if let message = model.errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.circle")
                    Text(message).font(.system(size: 12))
                    Button("Reconnect…") { model.chooseFolder() }
                }
                .padding(12).systemControlSurface(radius: 15)
                .padding(.horizontal, 30).padding(.top, 12)
            }

            if model.loading && model.entries.isEmpty {
                Spacer()
                ProgressView().padding(20).systemControlSurface().padding(baseEdge, 40)
                Spacer()
            } else if model.visibleEntries.isEmpty {
                Spacer()
                VStack(alignment: alignment, spacing: 10) {
                    Text(model.entries.isEmpty ? "This folder is empty" : "No matching files")
                        .font(.system(size: 14, weight: .medium))
                    if !model.entries.isEmpty {
                        Button("Show all files") { model.search = ""; model.filter = nil }.buttonStyle(.borderless)
                    }
                }
                .padding(20).systemControlSurface(radius: 16)
                .padding(baseEdge, 26)
                Spacer()
            } else {
                NativeFanView(model: model, reduceMotion: reduceMotion)
                    // Preserve window input coverage beneath the visual edge
                    // fade, including otherwise empty pixels near the bounds.
                    .background(Color.black.opacity(1.0 / 255))
            }

            if model.isSearchPresented || !model.search.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                    TextField("Find a file…", text: $model.search).textFieldStyle(.plain)
                        .focused($searchFocused).accessibilityLabel("Search files")
                        .onSubmit { searchFocused = false; model.open() }
                    Button { model.search = ""; model.isSearchPresented = false; searchFocused = false } label: { Image(systemName: "xmark.circle.fill") }
                        .buttonStyle(.borderless).accessibilityLabel("Close search")
                }
                .font(.system(size: 13)).padding(.horizontal, 14).padding(.vertical, 11)
                .systemControlSurface()
                .frame(maxWidth: 330).padding(baseEdge, 27).padding(.bottom, 10)
            }

            controls(maximumFolderLabelWidth: max(44, min(230, width - 155)))
                .padding(baseEdge, 27).padding(.bottom, 9)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: Alignment(horizontal: alignment, vertical: .bottom))
        .foregroundStyle(.primary)
        .background(Color.clear)
        .overlay {
            if model.availableForFanDrop {
                RoundedRectangle(cornerRadius: 16).strokeBorder(Color.accentColor.opacity(0.65),
                    style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                    .padding(3).allowsHitTesting(false).accessibilityHidden(true)
            }
        }
        .onChange(of: model.searchFocusRequest) { _, _ in model.isSearchPresented = true; searchFocused = true }
        .onChange(of: model.isSearchPresented) { _, presented in searchFocused = presented }
        .onExitCommand { model.handleEscape() }
    }

    private func controls(maximumFolderLabelWidth: CGFloat) -> some View {
        VStack(alignment: alignment, spacing: 9) {
            Text(model.dropHint ?? (model.availableForFanDrop ? "Drop here or on a folder" : nil) ?? model.copyNotice ?? "\(model.visibleEntries.count) \(model.visibleEntries.count == 1 ? "item" : "items")\(model.visibleEntries.count > 10 ? (model.sort == .newest ? " · Scroll up for older files" : " · Scroll up to browse") : "")")
                .font(.system(size: 11)).padding(.horizontal, 11).padding(.vertical, 5)
                .systemControlSurface(radius: 12)
                .overlay { if model.dropHint != nil { Capsule().strokeBorder(Color.accentColor, lineWidth: 2) } }
                .padding(baseEdge, 17)
            HStack(spacing: 13) {
                Menu {
                    Button("Open folder in Finder") { model.openFolder() }
                    Button(model.launcherID == nil ? "Choose folder…" : "Change this launcher's folder…") { model.chooseFolder() }
                    if model.launcherID == nil { Button("Disconnect folder") { model.disconnect() } }
                    Button("Dock & Launchers…") { model.onShowDockSettings?() }
                    Divider()
                    Picker("Sort by", selection: $model.sort) {
                        ForEach(FileSort.allCases) { sort in Text(sort.title).tag(sort) }
                    }
                    Menu("Filter by kind") {
                        Button("All files") { model.filter = nil }
                        ForEach(FileKind.allCases) { kind in Button(kind.title) { model.filter = kind } }
                    }
                    Divider()
                    Button(model.pinned ? "Unpin window" : "Keep window open") { model.pinned.toggle() }
                    Button("Refresh") { model.refresh() }
                    Divider()
                    Button("About DownloadScroller") { NSApp.orderFrontStandardAboutPanel(nil) }
                    Button("Quit DownloadScroller") { NSApp.terminate(nil) }
                } label: {
                    Label(model.isSample ? "Sample Downloads" : model.folderName, systemImage: "folder.fill")
                        .font(.system(size: 13, weight: .medium)).lineLimit(1).truncationMode(.middle)
                }
                .menuStyle(.borderlessButton).frame(maxWidth: maximumFolderLabelWidth)
                .accessibilityLabel("Folder options")
                Button { model.isSearchPresented.toggle(); searchFocused = model.isSearchPresented } label: {
                    Image(systemName: "magnifyingglass")
                }
                .buttonStyle(.borderless).help("Search files · ⌘F").accessibilityLabel("Search files")
                Button { model.openFolder() } label: { Image(systemName: "arrow.up.forward.square") }
                    .buttonStyle(.borderless).help("Open in Finder").accessibilityLabel("Open in Finder")
                Button { model.onDismiss?() } label: { Image(systemName: "xmark").font(.system(size: 10, weight: .semibold)) }
                    .buttonStyle(.borderless).help("Close · Esc").accessibilityLabel("Close window")
            }
            .font(.system(size: 13)).padding(.horizontal, 15).frame(height: 37)
            .systemControlSurface()
            .fixedSize(horizontal: true, vertical: false)
        }
    }
}

struct RootView: View {
    @ObservedObject var model: LibraryModel
    var body: some View {
        if model.folder != nil { DockFanView(model: model) }
        else { ShelfView(model: model) }
    }
}
