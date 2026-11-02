import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject private var session: ImageSession
    @EnvironmentObject private var language: LanguageManager

    var body: some View {
        VStack(spacing: 0) {
            ViewerToolbarBar()
            Divider()
            viewerBody
        }
        .frame(minWidth: 480, minHeight: 320)
        .background(WindowConfigurator(title: session.windowTitle, isEdited: session.isDirty, session: session))
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

    private var viewerBody: some View {
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
                    onOpenWithApp: { session.openWithApplication(at: $0) },
                    onRotateLeft: { session.apply(.rotateLeft) },
                    onRotateRight: { session.apply(.rotateRight) },
                    onFlipHorizontal: { session.apply(.flipHorizontal) },
                    onFlipVertical: { session.apply(.flipVertical) },
                    onCopyImage: { session.copyImage() },
                    onSave: { session.saveInPlace() },
                    onSaveAs: { session.saveAs() },
                    onPrint: { session.printCurrent() },
                    onUndoEdit: { session.undoLastEdit() },
                    isDirty: session.isDirty,
                    markupItems: session.markupItems,
                    markupTool: session.markupTool,
                    markupColor: session.markupColor,
                    onAddMarkup: { session.addMarkup($0) },
                    onReplaceMarkup: { session.replaceMarkup($0) },
                    onRemoveMarkup: { session.removeMarkup(id: $0) }
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
        if session.markupTool != .browse {
            session.setMarkupTool(.browse)
            return
        }
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
/// Proxies `windowShouldClose` so unsaved rotate/flip can be saved or discarded.
private struct WindowConfigurator: NSViewRepresentable {
    var title: String
    var isEdited: Bool
    var session: ImageSession

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        view.isHidden = true
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.session = session
        DispatchQueue.main.async {
            guard let window = nsView.window else { return }
            window.title = title
            window.isDocumentEdited = isEdited
            window.setFrameAutosaveName("Flip.Main")
            window.isRestorable = true
            context.coordinator.install(on: window)
            ViewerWindow.fulfillPendingIfNeeded()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator {
        var session: ImageSession?
        private var proxy: FlipWindowDelegateProxy?

        func install(on window: NSWindow) {
            if let existing = window.delegate as? FlipWindowDelegateProxy {
                existing.session = session
                return
            }
            let proxy = FlipWindowDelegateProxy()
            proxy.original = window.delegate
            proxy.session = session
            self.proxy = proxy
            window.delegate = proxy
        }
    }
}

/// Forwards the existing SwiftUI window delegate, intercepting close for unsaved edits.
final class FlipWindowDelegateProxy: NSObject, NSWindowDelegate {
    weak var original: NSWindowDelegate?
    weak var session: ImageSession?

    override func responds(to aSelector: Selector!) -> Bool {
        if aSelector == #selector(NSWindowDelegate.windowShouldClose(_:)) {
            return true
        }
        return (original as AnyObject?)?.responds(to: aSelector) ?? super.responds(to: aSelector)
    }

    override func forwardingTarget(for aSelector: Selector!) -> Any? {
        if (original as AnyObject?)?.responds(to: aSelector) == true {
            return original
        }
        return super.forwardingTarget(for: aSelector)
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        guard session?.confirmDiscardIfNeeded() == true else { return false }
        if (original as AnyObject?)?.responds(to: #selector(NSWindowDelegate.windowShouldClose(_:))) == true {
            return original?.windowShouldClose?(sender) ?? true
        }
        return true
    }
}
