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
                .background(.black.opacity(0.65), in: Capsule())
                .overlay(Capsule().strokeBorder(.white.opacity(0.15)))
                .frame(width: 350).padding(.trailing, 22).padding(.top, 12)
            }

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
                GeometryReader { viewport in
                    let viewportHeight = max(viewport.size.height, 1)
                    let fanAmount = min(1, CGFloat(max(model.visibleEntries.count - 1, 0)) / 8)
                    let motionReduced = reduceMotion
                    ScrollViewReader { reader in
                        ScrollView(.vertical, showsIndicators: false) {
                            LazyVStack(spacing: 8) {
                                Color.clear.frame(height: topPadding).id("fanStart")
                                ForEach(model.visibleEntries) { entry in
                                    DockFanRow(entry: entry, selected: model.selectedID == entry.id,
                                               open: { searchFocused = false; model.selectedID = entry.id; model.open(entry) },
                                               preview: { searchFocused = false; model.preview(entry) },
                                               reveal: { model.reveal(entry) })
                                        .frame(height: 62)
                                        .padding(.trailing, 71)
                                        // Keep row sizes constant. These compositor effects
                                        // follow scrolling without triggering row layout.
                                        .visualEffect { content, geometry in
                                            let position = geometry.frame(in: .named("dockFan")).midY
                                            let rawProgress = min(max(position / viewportHeight, 0), 1)
                                            let progress = 1 - (1 - rawProgress) * fanAmount
                                            let angle = motionReduced ? 0 : 19 * pow(1 - progress, 1.15)
                                            return content
                                                .rotationEffect(.degrees(angle), anchor: .trailing)
                                                .offset(x: 57 * (1 - pow(progress, 1.7)))
                                        }
                                        .id(entry.id)
                                }
                            }
                            // Rotation lifts the left edge of long labels. This
                            // space keeps the first label fully inside the window.
                            .padding(.leading, 16).padding(.bottom, 18)
                            .frame(maxWidth: .infinity)
                            .contentShape(Rectangle())
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Rectangle())
                        // Fully clear pixels in a borderless macOS window can pass
                        // input to the app behind it. One alpha step keeps the whole
                        // viewport interactive without a visible panel background.
                        .background(Color.black.opacity(1.0 / 255.0))
                        .coordinateSpace(name: "dockFan")
                        .scrollIndicators(.never)
                        .scrollContentBackground(.hidden)
                        .onChange(of: model.selectedID) { _, id in
                            if let id { reader.scrollTo(id) }
                        }
                        .onChange(of: model.search) { _, _ in scrollToStart(reader) }
                        .onChange(of: model.filter) { _, _ in scrollToStart(reader) }
                        .onChange(of: model.sort) { _, _ in scrollToStart(reader) }
                    }
                }
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

    private func scrollToStart(_ reader: ScrollViewProxy) {
        reader.scrollTo("fanStart", anchor: .top)
    }

    private var topPadding: CGFloat {
        reduceMotion ? 16 : min(125, max(16, CGFloat(model.visibleEntries.count - 1) * 14))
    }

    private var controls: some View {
        VStack(alignment: .trailing, spacing: 9) {
            Text("\(model.visibleEntries.count) \(model.visibleEntries.count == 1 ? "item" : "items")\(model.visibleEntries.count > 10 ? " · Scroll to browse" : "")")
                .font(.system(size: 11)).padding(.horizontal, 11).padding(.vertical, 5)
                .background(.black.opacity(0.55), in: Capsule())
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
                    Button("Switch to list view") { model.fanLayout = false }
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
            .background(.black.opacity(0.65), in: Capsule())
            .overlay(Capsule().strokeBorder(.white.opacity(0.12)))
            .fixedSize(horizontal: true, vertical: false)
        }
        .shadow(color: .black.opacity(0.25), radius: 5, y: 2)
    }
}

private struct DockFanRow: View {
    let entry: FileEntry
    let selected: Bool
    let open: () -> Void
    let preview: () -> Void
    let reveal: () -> Void
    @ViewState private var hovering = false

    var body: some View {
        HStack(spacing: 0) {
            Spacer(minLength: 0)
            // Only the label and icon open a file. The surrounding space belongs
            // to the scroll viewport, including the gaps between angled rows.
            Button(action: open) {
                HStack(spacing: 11) {
                    Text(entry.name)
                        .font(.system(size: 13)).lineLimit(1).truncationMode(.middle)
                        .padding(.horizontal, 12).padding(.vertical, 5)
                        .background(hovering ? Color.accentColor.opacity(0.9) : .black.opacity(selected ? 0.68 : 0.52), in: Capsule())
                        .overlay(Capsule().strokeBorder(.white.opacity(selected || hovering ? 0.26 : 0.12), lineWidth: 0.5))
                        .shadow(color: .black.opacity(0.35), radius: 2, y: 1)
                        .fixedSize(horizontal: false, vertical: true)
                    FileThumbnail(entry: entry, size: 54)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain).onHover { hovering = $0 }.help(entry.name)
            .accessibilityLabel(entry.name)
            .accessibilityValue(entry.kind.title)
            .accessibilityHint("Open file. Use the context menu to preview or reveal in Finder.")
            .accessibilityAddTraits(selected ? .isSelected : [])
            .contextMenu {
                Button("Open", systemImage: "arrow.up.right.square", action: open)
                Button("Quick Look", systemImage: "eye", action: preview)
                Button("Show in Finder", systemImage: "folder", action: reveal)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
    }
}

struct RootView: View {
    @ObservedObject var model: LibraryModel
    var body: some View {
        if model.folder != nil && model.fanLayout { DockFanView(model: model) }
        else { ShelfView(model: model) }
    }
}
