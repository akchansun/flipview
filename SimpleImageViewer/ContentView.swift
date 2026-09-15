import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject private var session: ImageSession
    @EnvironmentObject private var language: LanguageManager

    var body: some View {
        ZStack {
            if session.currentImage != nil {
                Color.black
            } else {
                Color(nsColor: .windowBackgroundColor)
            }

            if let image = session.currentImage {
                ZoomableImageView(
                    image: image,
                    imageURL: session.currentURL,
                    zoomRequest: session.zoomRequest,
                    onNavigate: { session.navigate($0) },
                    onDelete: { session.requestDelete() },
                    onEscape: handleEscape,
                    onOpenImage: { session.openPanelForImage() },
                    onOpenFolder: { session.openPanelForFolder() },
                    onRevealInFinder: { session.revealInFinder() },
                    onCopyPath: { session.copyCurrentPath() },
                    onOpenWithApp: { session.openWithApplication(at: $0) }
                )
            } else {
                EmptyStateView()
            }

            if session.isLoading && session.currentImage == nil {
                ProgressView()
                    .scaleEffect(1.2)
                    .tint(.white)
            }


            if session.isSlideshow {
                VStack {
                    Text(language.t(.slideshowHint))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.black.opacity(0.55), in: Capsule())
                        .padding(.top, 10)
                    Spacer()
                }
                .allowsHitTesting(false)
            }

            VStack(spacing: 0) {
                if session.needsFolderPermission {
                    folderAccessBanner
                }
                Spacer()
                if let error = session.errorMessage, session.currentImage == nil {
                    Text(error)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .padding()
                }
            }
        }
        .frame(minWidth: 480, minHeight: 320)
        .background(WindowConfigurator(title: session.windowTitle))
        .onOpenURL { url in
            session.open(url)
        }
        .onDrop(of: [.fileURL], isTargeted: $session.isDropTargeted, perform: handleDrop)
        .alert(language.t(.moveToTrashQuestion), isPresented: $session.showDeleteConfirm) {
            Button(language.t(.moveToTrash), role: .destructive) {
                session.deleteCurrent()
            }
            Button(language.t(.cancel), role: .cancel) {}
        } message: {
            if let name = session.currentURL?.lastPathComponent {
                Text(language.format(.moveToTrashMessageNamed, name))
            } else {
                Text(language.t(.moveToTrashMessage))
            }
        }
        .alert(
            language.t(.couldNotOpenImage),
            isPresented: Binding(
                get: { session.errorMessage != nil && session.currentImage != nil },
                set: { if !$0 { session.errorMessage = nil } }
            )
        ) {
            Button(language.t(.ok), role: .cancel) { session.errorMessage = nil }
        } message: {
            Text(session.errorMessage ?? "")
        }
    }

    private var folderAccessBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "folder.badge.questionmark")
            Text(language.t(.allowFolderTitle))
                .lineLimit(2)
            Spacer(minLength: 8)
            Button(language.t(.allowFolderBody)) {
                session.requestFolderAccess()
            }
        }
        .font(.callout)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.bar)
    }

    private func handleEscape() {
        if session.isSlideshow {
            session.stopSlideshow()
        } else {
            session.requestZoom(.fit)
        }
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }) else {
            return false
        }
        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
            let url: URL?
            if let existing = item as? URL {
                url = existing
            } else if let data = item as? Data {
                url = URL(dataRepresentation: data, relativeTo: nil)
            } else if let nsurl = item as? NSURL {
                url = nsurl as URL
            } else {
                url = nil
            }
            guard let url else { return }
            Task { @MainActor in
                session.open(url)
            }
        }
        return true
    }
}

private struct EmptyStateView: View {
    @EnvironmentObject private var session: ImageSession
    @EnvironmentObject private var language: LanguageManager

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(.secondary)

            Text(language.t(.openImageToStart))
                .font(.title2.weight(.medium))

            Text(language.t(.openImageHint))
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)

            HStack(spacing: 12) {
                Button(language.t(.openImage)) {
                    session.openPanelForImage()
                }
                .keyboardShortcut("o", modifiers: .command)

                Button(language.t(.openFolder)) {
                    session.openPanelForFolder()
                }
            }
            .padding(.top, 4)

            Text(language.t(.shortcutsHint))
                .font(.caption)
                .foregroundStyle(.tertiary)
                .padding(.top, 8)
        }
        .padding(32)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(session.isDropTargeted ? 0.9 : 0.0))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(session.isDropTargeted ? Color.accentColor : Color.clear, lineWidth: 2)
                )
        )
        .animation(.easeInOut(duration: 0.15), value: session.isDropTargeted)
    }
}

/// Sets the window title (`filename — 3 / 42`) and remembers size/position.
private struct WindowConfigurator: NSViewRepresentable {
    var title: String

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        view.isHidden = true
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            guard let window = nsView.window else { return }
            window.title = title
            window.setFrameAutosaveName("Flip.Main")
            window.isRestorable = true
        }
    }
}
