import AppKit
import SwiftUI

// Explicit alias avoids the SDK's same-named State macro in CLT builds.
typealias ViewState<Value> = SwiftUI.State<Value>

enum Palette {
    static let mint = Color(red: 0.64, green: 0.94, blue: 0.81)
    static let ink = Color(red: 0.055, green: 0.09, blue: 0.12)
    static let muted = Color(red: 0.62, green: 0.69, blue: 0.72)
}

/// Folder onboarding. Once connected, the app always uses the fan.
struct ShelfView: View {
    @ObservedObject var model: LibraryModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("DownloadScroller").font(.system(size: 12, weight: .medium))
                Spacer()
                Button { model.onDismiss?() } label: { Image(systemName: "xmark") }
                    .buttonStyle(.plain).accessibilityLabel("Close window")
            }.foregroundStyle(Palette.muted).padding(28)
            Text("Downloads, unfolded.").font(.system(size: 29, weight: .semibold, design: .rounded))
                .padding(.horizontal, 30)
            Text("A familiar fan. Room for every file.").font(.system(size: 13))
                .foregroundStyle(Palette.muted).padding(.horizontal, 30).padding(.top, 8)
            welcome
        }
        .background {
            ZStack(alignment: .topLeading) {
                VisualEffect().opacity(0.97)
                Palette.ink.opacity(0.81)
                RadialGradient(colors: [Palette.mint.opacity(0.075), .clear], center: .topLeading,
                               startRadius: 0, endRadius: 380)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(.white.opacity(0.14)))
        .preferredColorScheme(.dark).tint(Palette.mint)
        .onExitCommand { model.onDismiss?() }
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
