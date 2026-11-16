import AppKit
import SwiftUI
#if SWIFT_PACKAGE
import DownloadScrollerCore
#endif

/// A floating stack of filename capsules and file icons, matching the visual
/// language of the system Dock fan while remaining an independent app window.
struct DockFanView: View {
    @ObservedObject var model: LibraryModel
    @ViewState private var searching = false
    @FocusState private var searchFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .trailing, spacing: 0) {

            if let message = model.errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.circle")
                    Text(message).font(.system(size: 12))
                    Button("Reconnect…") { model.chooseFolder() }
                }
                .padding(12).background(.black.opacity(0.75), in: RoundedRectangle(cornerRadius: 15))
                .padding(.horizontal, 30).padding(.top, 12)
            }

            if model.loading && model.entries.isEmpty {
                Spacer()
                ProgressView().padding(20).background(.black.opacity(0.6), in: Capsule()).padding(.trailing, 40)
                Spacer()
            } else if model.visibleEntries.isEmpty {
                Spacer()
                VStack(alignment: .trailing, spacing: 10) {
                    Text(model.entries.isEmpty ? "This folder is empty" : "No matching files")
                        .font(.system(size: 14, weight: .medium))
                    if !model.entries.isEmpty {
                        Button("Show all files") { model.search = ""; model.filter = nil }.buttonStyle(.plain)
                    }
                }
                .padding(20).background(.black.opacity(0.65), in: RoundedRectangle(cornerRadius: 16))
                .padding(.trailing, 26)
                Spacer()
            } else {
                NativeFanView(model: model, reduceMotion: reduceMotion)
            }

            if searching || !model.search.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                    TextField("Find a file…", text: $model.search).textFieldStyle(.plain)
                        .focused($searchFocused).accessibilityLabel("Search files")
                        .onSubmit { searchFocused = false; model.open() }
                    Button { model.search = ""; searching = false; searchFocused = false } label: { Image(systemName: "xmark.circle.fill") }
                        .buttonStyle(.plain).accessibilityLabel("Close search")
                }
                .font(.system(size: 13)).padding(.horizontal, 14).padding(.vertical, 11)
                .background(Color(white: 0.20).opacity(0.96), in: Capsule())
                .overlay(Capsule().strokeBorder(.white.opacity(0.15)))
                .frame(width: 350).padding(.trailing, 39).padding(.bottom, 10)
            }

            controls.padding(.trailing, 39).padding(.bottom, 9)
        }
        .foregroundStyle(.white.opacity(0.96))
        .background(Color.clear)
        .preferredColorScheme(.dark)
        .onChange(of: model.searchFocusRequest) { _, _ in searching = true; searchFocused = true }
        .onExitCommand {
            if !model.search.isEmpty { model.search = "" }
            else if searching { searching = false; searchFocused = false }
            else { model.onDismiss?() }
        }
    }

    private var controls: some View {
        VStack(alignment: .trailing, spacing: 9) {
            Text("\(model.visibleEntries.count) \(model.visibleEntries.count == 1 ? "item" : "items")\(model.visibleEntries.count > 10 ? " · Scroll to browse" : "")")
                .font(.system(size: 11)).padding(.horizontal, 11).padding(.vertical, 5)
                .background(Color(white: 0.23).opacity(0.92), in: Capsule())
                .padding(.trailing, 17)
            HStack(spacing: 13) {
                Menu {
                    Button("Open folder in Finder") { model.openFolder() }
                    Button("Choose folder…") { model.chooseFolder() }
                    Button("Disconnect folder") { model.disconnect() }
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
                .menuStyle(.borderlessButton).fixedSize().frame(maxWidth: 230)
                .accessibilityLabel("Folder options")
                Button { searching.toggle(); searchFocused = searching } label: {
                    Image(systemName: "magnifyingglass")
                }
                .buttonStyle(.plain).help("Search files · ⌘F").accessibilityLabel("Search files")
                Button { model.openFolder() } label: { Image(systemName: "arrow.up.forward.square") }
                    .buttonStyle(.plain).help("Open in Finder").accessibilityLabel("Open in Finder")
                Button { model.onDismiss?() } label: { Image(systemName: "xmark").font(.system(size: 10, weight: .semibold)) }
                    .buttonStyle(.plain).help("Close · Esc").accessibilityLabel("Close window")
            }
            .font(.system(size: 13)).padding(.horizontal, 15).frame(height: 37)
            .background(Color(white: 0.20).opacity(0.96), in: Capsule())
            .overlay(Capsule().strokeBorder(.white.opacity(0.12)))
            .fixedSize(horizontal: true, vertical: false)
        }
        .shadow(color: .black.opacity(0.25), radius: 5, y: 2)
    }
}

struct RootView: View {
    @ObservedObject var model: LibraryModel
    var body: some View {
        if model.folder != nil { DockFanView(model: model) }
        else { ShelfView(model: model) }
    }
}
