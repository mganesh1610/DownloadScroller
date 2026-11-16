import AppKit
import SwiftUI
#if SWIFT_PACKAGE
import DownloadScrollerCore
#endif

// Explicit alias keeps the property wrapper available with SDKs that also define
// a same-named State macro, including Command Line Tools without SwiftUIMacros.
typealias ViewState<Value> = SwiftUI.State<Value>

enum Palette {
    static let mint = Color(red: 0.64, green: 0.94, blue: 0.81)
    static let ink = Color(red: 0.055, green: 0.09, blue: 0.12)
    static let muted = Color(red: 0.62, green: 0.69, blue: 0.72)
}

struct ShelfView: View {
    @ObservedObject var model: LibraryModel
    @FocusState private var searchFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            header
            if model.folder == nil { welcome }
            else {
                searchField
                filters.padding(.top, 13).padding(.bottom, 12)
                if let message = model.errorMessage { errorBanner(message) }
                fileArea
                footer
            }
        }
        .background {
            ZStack(alignment: .topLeading) {
                VisualEffect().opacity(0.97)
                Palette.ink.opacity(0.81)
                RadialGradient(colors: [Palette.mint.opacity(0.075), .clear], center: .topLeading,
                               startRadius: 0, endRadius: 380)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(.white.opacity(0.14), lineWidth: 1))
        .preferredColorScheme(.dark)
        .tint(Palette.mint)
        .onChange(of: model.searchFocusRequest) { _, _ in searchFocused = true }
        .onExitCommand {
            if !model.search.isEmpty { model.search = "" }
            else { model.onDismiss?() }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 7) {
                Image(systemName: "square.stack.3d.up").font(.system(size: 12, weight: .semibold))
                Text("DOWNLOADSCROLLER").font(.system(size: 10, weight: .semibold, design: .rounded)).tracking(2.0)
                Spacer()
                Button { model.pinned.toggle() } label: {
                    Image(systemName: model.pinned ? "pin.fill" : "pin").frame(width: 24, height: 24)
                }
                .buttonStyle(.plain).foregroundStyle(model.pinned ? Palette.mint : Palette.muted)
                .help(model.pinned ? "Unpin window" : "Keep window open")
                .accessibilityLabel(model.pinned ? "Unpin window" : "Keep window open")
                Menu {
                    Button("Choose folder…") { model.chooseFolder() }
                    if model.folder != nil {
                        Button("Open folder in Finder") { model.openFolder() }
                        Button("Refresh") { model.refresh() }
                        Button("Disconnect folder") { model.disconnect() }
                    }
                    Divider()
                    Button("About DownloadScroller") { NSApp.orderFrontStandardAboutPanel(nil) }
                    Button("Quit DownloadScroller") { NSApp.terminate(nil) }
                } label: { Image(systemName: "ellipsis").frame(width: 24, height: 24) }
                .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize().help("More options")
                .accessibilityLabel("More options")
                Button { model.onDismiss?() } label: {
                    Image(systemName: "xmark").font(.system(size: 10, weight: .semibold)).frame(width: 24, height: 24)
                        .background(.white.opacity(0.07), in: Circle())
                }
                .buttonStyle(.plain).help("Close window · Esc").accessibilityLabel("Close window")
            }
            .foregroundStyle(Palette.muted)

            HStack(alignment: .center, spacing: 13) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14).fill(Palette.mint.opacity(0.1)).frame(width: 50, height: 50)
                    Image(systemName: "arrow.down.to.line.compact").font(.system(size: 25, weight: .medium)).foregroundStyle(Palette.mint)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(model.isSample ? "A little room to explore." : model.folderName)
                        .font(.system(size: model.folder == nil ? 25 : 23, weight: .semibold, design: .rounded))
                        .lineLimit(1).truncationMode(.middle)
                    Text(model.folder == nil ? "A familiar fan. Room for every file." : model.isSample ? "240 sample files. One continuous scroll." : "Your files. A scroll away.")
                        .font(.system(size: 12)).foregroundStyle(Palette.muted)
                }
                Spacer(minLength: 0)
                if model.folder != nil {
                    HStack(spacing: 2) {
                        layoutButton(symbol: "square.stack.3d.up", fan: true)
                        layoutButton(symbol: "list.bullet", fan: false)
                    }
                    .padding(3).background(.black.opacity(0.2), in: RoundedRectangle(cornerRadius: 9))
                }
            }
        }
        .padding(.horizontal, 25).padding(.top, 20).padding(.bottom, 22)
    }

    private func layoutButton(symbol: String, fan: Bool) -> some View {
        Button { model.fanLayout = fan } label: {
            Image(systemName: symbol).font(.system(size: 13)).frame(width: 29, height: 28)
                .background(model.fanLayout == fan ? .white.opacity(0.12) : .clear, in: RoundedRectangle(cornerRadius: 6))
                .foregroundStyle(model.fanLayout == fan ? Palette.mint : Palette.muted)
        }
        .buttonStyle(.plain).help(fan ? "Fan view" : "List view")
        .accessibilityLabel(fan ? "Fan view" : "List view")
        .accessibilityAddTraits(model.fanLayout == fan ? .isSelected : [])
    }

    private var searchField: some View {
        HStack(spacing: 9) {
            Image(systemName: "magnifyingglass").font(.system(size: 14)).foregroundStyle(Palette.muted)
            TextField("Find a file…", text: $model.search)
                .textFieldStyle(.plain).font(.system(size: 13)).focused($searchFocused)
                .onSubmit { searchFocused = false; model.open() }
                .accessibilityLabel("Search files")
            if model.search.isEmpty {
                Text("⌘ F").font(.system(size: 10, design: .monospaced)).foregroundStyle(Palette.muted.opacity(0.7))
            } else {
                Button { model.search = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(Palette.muted) }
                    .buttonStyle(.plain).accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 13).frame(height: 39)
        .background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.white.opacity(searchFocused ? 0.22 : 0.09)))
        .padding(.horizontal, 25)
    }

    private var filters: some View {
        HStack(spacing: 5) {
            filterChip("All files", kind: nil)
            filterChip("Documents", kind: .documents)
            filterChip("Images", kind: .images)
            Menu {
                ForEach(FileKind.allCases.filter { ![.documents, .images].contains($0) }) { kind in
                    Button(kind.title, systemImage: kind.symbol) { model.filter = kind }
                }
            } label: {
                Text(model.filter.map { [.documents, .images].contains($0) ? "More" : $0.title } ?? "More")
                    .font(.system(size: 11, weight: .medium))
            }
            .menuStyle(.borderlessButton).fixedSize().padding(.leading, 5).foregroundStyle(Palette.muted)
            .accessibilityLabel("More file types")
            Spacer(minLength: 4)
            Menu {
                Picker("Sort files", selection: $model.sort) {
                    ForEach(FileSort.allCases) { sort in Text(sort.title).tag(sort) }
                }
            } label: { Image(systemName: "arrow.up.arrow.down").font(.system(size: 12)) }
            .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize().foregroundStyle(Palette.muted)
            .help("Sort: \(model.sort.title)").accessibilityLabel("Sort files: \(model.sort.title)")
        }
        .padding(.horizontal, 25)
    }

    private func filterChip(_ title: String, kind: FileKind?) -> some View {
        Button { model.filter = kind } label: {
            Text(title).font(.system(size: 11, weight: .medium)).padding(.horizontal, 10).padding(.vertical, 6)
                .foregroundStyle(model.filter == kind ? Palette.mint : Palette.muted)
                .background(model.filter == kind ? Palette.mint.opacity(0.11) : .clear, in: Capsule())
        }
        .buttonStyle(.plain).accessibilityAddTraits(model.filter == kind ? .isSelected : [])
    }

    @ViewBuilder private var fileArea: some View {
        if model.loading && model.entries.isEmpty {
            Spacer()
            ProgressView("Opening your folder…").font(.system(size: 12)).tint(Palette.mint)
            Spacer()
        } else if model.visibleEntries.isEmpty {
            Spacer()
            VStack(spacing: 12) {
                Image(systemName: model.entries.isEmpty ? "tray" : "magnifyingglass").font(.system(size: 30, weight: .light)).foregroundStyle(Palette.mint)
                Text(model.entries.isEmpty ? "A little breathing room." : "No matching files.").font(.system(size: 18, weight: .medium, design: .rounded))
                Text(model.entries.isEmpty ? "New files will appear here automatically." : "Try another name or choose All files.")
                    .font(.system(size: 12)).foregroundStyle(Palette.muted)
                if !model.entries.isEmpty {
                    Button("Clear filters") { model.search = ""; model.filter = nil }.buttonStyle(.bordered)
                }
            }
            Spacer()
        } else {
            GeometryReader { viewport in
                ScrollViewReader { reader in
                    ScrollView(.vertical) {
                        LazyVStack(spacing: model.fanLayout ? 10 : 5) {
                            ForEach(model.visibleEntries) { entry in
                                GeometryReader { row in
                                    let fraction = min(max(row.frame(in: .named("fan")).midY / max(viewport.size.height, 1), 0), 1)
                                    let fan = model.fanLayout && !reduceMotion
                                    let angle = fan ? (fraction - 0.52) * 8 : 0
                                    let inset = fan ? 20 * pow(1 - fraction, 1.6) : 0
                                    FileRow(entry: entry, selected: model.selectedID == entry.id, fan: model.fanLayout,
                                            open: { searchFocused = false; model.selectedID = entry.id; model.open(entry) },
                                            preview: { searchFocused = false; model.preview(entry) }, reveal: { model.reveal(entry) })
                                        .padding(.leading, inset)
                                        .rotationEffect(.degrees(angle), anchor: .trailing)
                                }
                                .frame(height: 58).id(entry.id)
                            }
                        }
                        .padding(.horizontal, 25).padding(.top, 18).padding(.bottom, 22)
                    }
                    .coordinateSpace(name: "fan")
                    .scrollIndicators(.visible)
                    .onChange(of: model.selectedID) { _, id in
                        guard let id else { return }
                        reader.scrollTo(id)
                    }
                    .onChange(of: model.search) { _, _ in
                        if let first = model.visibleEntries.first { reader.scrollTo(first.id, anchor: .top) }
                    }
                    .onChange(of: model.sort) { _, _ in
                        if let first = model.visibleEntries.first { reader.scrollTo(first.id, anchor: .top) }
                    }
                }
            }
            .overlay(alignment: .top) { LinearGradient(colors: [Palette.ink.opacity(0.7), .clear], startPoint: .top, endPoint: .bottom).frame(height: 13).allowsHitTesting(false) }
        }
    }

    private var footer: some View {
        VStack(spacing: 13) {
            Rectangle().fill(.white.opacity(0.08)).frame(height: 1)
            HStack {
                HStack(spacing: 6) {
                    Circle().fill(model.loading ? Palette.muted : Palette.mint).frame(width: 5, height: 5)
                    Text("\(model.visibleEntries.count) \(model.visibleEntries.count == 1 ? "item" : "items")")
                    if model.search.isEmpty && model.filter == nil { Text("·").foregroundStyle(Palette.muted.opacity(0.5)); Text("\(model.isSample ? "Sample folder" : "Live")") }
                }
                .font(.system(size: 11)).foregroundStyle(Palette.muted)
                Spacer()
                Button { model.isSample ? model.chooseFolder() : model.openFolder() } label: {
                    HStack(spacing: 5) { Text(model.isSample ? "Choose your folder" : "Open in Finder"); Image(systemName: "arrow.up.right").font(.system(size: 9, weight: .semibold)) }
                }
                .font(.system(size: 11, weight: .medium)).buttonStyle(.plain).foregroundStyle(Palette.mint)
            }
            HStack(spacing: 18) {
                shortcut("↑ ↓", "Browse")
                shortcut("space", "Preview")
                shortcut("↵", "Open")
                Spacer()
                Text(model.fanLayout ? "FAN VIEW" : "LIST VIEW").font(.system(size: 8, weight: .medium)).tracking(1.2).foregroundStyle(Palette.muted.opacity(0.5))
            }
        }
        .padding(.horizontal, 25).padding(.bottom, 18)
    }

    private func shortcut(_ key: String, _ title: String) -> some View {
        HStack(spacing: 5) {
            Text(key).font(.system(size: 9, design: .monospaced)).foregroundStyle(Palette.muted)
            Text(title).font(.system(size: 10)).foregroundStyle(Palette.muted.opacity(0.65))
        }
    }

    private var welcome: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 10)
            VStack(spacing: 14) {
                welcomeCard("Weekend reading.pdf", symbol: "doc.text", rotation: -9, offset: 22)
                welcomeCard("A little inspiration.png", symbol: "photo", rotation: -3, offset: 7)
                welcomeCard("Something worth keeping.zip", symbol: "archivebox", rotation: 4, offset: 0)
            }
            .padding(.horizontal, 37).accessibilityHidden(true)
            Spacer(minLength: 25)
            VStack(alignment: .leading, spacing: 13) {
                feature("cursorarrow.and.square.on.square.dashed", "Open from your Dock or menu bar")
                feature("arrow.up.and.down", "Scroll past every file, without a cutoff")
                feature("magnifyingglass", "Find, preview, and open in a moment")
            }
            .padding(.horizontal, 35)
            Spacer(minLength: 22)
            if let message = model.errorMessage { errorBanner(message).padding(.bottom, 12) }
            Button { model.chooseFolder() } label: {
                HStack { Image(systemName: "folder.badge.plus"); Text("Choose Downloads folder"); Spacer(); Image(systemName: "arrow.right") }
                    .font(.system(size: 13, weight: .semibold)).padding(.horizontal, 18).frame(height: 46)
                    .foregroundStyle(Palette.ink).background(Palette.mint, in: RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain).padding(.horizontal, 30)
            Button("Take a look with sample files") { model.useSamples() }
                .buttonStyle(.plain).font(.system(size: 11)).foregroundStyle(Palette.muted).padding(.top, 15)
            Text("On your Mac. Just your files.").font(.system(size: 10)).foregroundStyle(Palette.muted.opacity(0.65)).padding(.top, 28).padding(.bottom, 24)
        }
    }

    private func welcomeCard(_ title: String, symbol: String, rotation: Double, offset: CGFloat) -> some View {
        HStack {
            Text(title).font(.system(size: 12, weight: .medium)).foregroundStyle(.white.opacity(0.85))
            Spacer()
            Image(systemName: symbol).font(.system(size: 24, weight: .light)).foregroundStyle(Palette.mint)
        }
        .padding(.horizontal, 17).frame(height: 54)
        .background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 15))
        .overlay(RoundedRectangle(cornerRadius: 15).strokeBorder(.white.opacity(0.08)))
        .rotationEffect(.degrees(reduceMotion ? 0 : rotation), anchor: .trailing).offset(x: -offset)
    }

    private func feature(_ symbol: String, _ title: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol).font(.system(size: 14)).foregroundStyle(Palette.mint).frame(width: 20)
            Text(title).font(.system(size: 12)).foregroundStyle(Palette.muted)
        }
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.circle").foregroundStyle(.orange)
            Text(message).font(.system(size: 11)).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Button("Choose…") { model.chooseFolder() }.buttonStyle(.plain).foregroundStyle(Palette.mint)
        }
        .padding(12).background(.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 10)).padding(.horizontal, 25)
    }
}

private struct FileRow: View {
    let entry: FileEntry
    let selected: Bool
    let fan: Bool
    let open: () -> Void
    let preview: () -> Void
    let reveal: () -> Void
    @ViewState private var hovering = false

    var body: some View {
        Button(action: open) {
            HStack(spacing: 13) {
                if !fan { FileThumbnail(entry: entry) }
                VStack(alignment: .leading, spacing: 5) {
                    Text(entry.name).font(.system(size: 12, weight: .medium)).lineLimit(1).truncationMode(.middle)
                        .foregroundStyle(selected || hovering ? .white : .white.opacity(0.85))
                    HStack(spacing: 6) {
                        Text(entry.kind == .folders ? "Folder" : ByteCountFormatter.string(fromByteCount: entry.size, countStyle: .file))
                        Text("·").foregroundStyle(Palette.muted.opacity(0.5))
                        Text(entry.addedAt.formatted(.relative(presentation: .named))).lineLimit(1)
                    }
                    .font(.system(size: 10)).foregroundStyle(Palette.muted)
                }
                Spacer(minLength: 0)
                if fan { FileThumbnail(entry: entry) }
            }
            .padding(.horizontal, 13).frame(height: 58)
            .background(selected || hovering ? Palette.mint.opacity(0.10) : .white.opacity(fan ? 0.04 : 0.025), in: RoundedRectangle(cornerRadius: fan ? 16 : 10))
            .overlay(RoundedRectangle(cornerRadius: fan ? 16 : 10).strokeBorder(selected || hovering ? Palette.mint.opacity(0.24) : .white.opacity(0.045)))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain).onHover { hovering = $0 }
        .help(entry.name)
        .accessibilityLabel(entry.name)
        .accessibilityValue("\(entry.kind.title), \(ByteCountFormatter.string(fromByteCount: entry.size, countStyle: .file))")
        .accessibilityHint("Open file. Use the context menu to preview or reveal in Finder.")
        .accessibilityAddTraits(selected ? .isSelected : [])
        .contextMenu {
            Button("Open", systemImage: "arrow.up.right.square", action: open)
            Button("Quick Look", systemImage: "eye", action: preview)
            Button("Show in Finder", systemImage: "folder", action: reveal)
        }
    }
}

private struct VisualEffect: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }
    func updateNSView(_ view: NSVisualEffectView, context: Context) {}
}
