import SwiftUI
import WebKit

struct MermaidDiagramView: View {
    let id: String
    let source: String
    let title: String
    @State private var contentHeight: CGFloat = 240
    @State private var zoom = 1.0
    @State private var expandedZoom = 1.0
    @State private var isShowingExpanded = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            MermaidWebView(
                id: id,
                source: source,
                title: title,
                zoom: zoom,
                contentHeight: $contentHeight
            )

            DiagramZoomControls(zoom: $zoom) {
                expandedZoom = zoom
                isShowingExpanded = true
            }
                .padding(8)
        }
        .frame(maxWidth: .infinity)
        .frame(height: min(max(contentHeight, 160), 720))
        .background(.quaternary.opacity(0.18))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay {
            RoundedRectangle(cornerRadius: 6)
                .stroke(.separator.opacity(0.55), lineWidth: 1)
        }
        .sheet(isPresented: $isShowingExpanded) {
            ExpandedMermaidDiagramView(
                id: id,
                source: source,
                title: title,
                zoom: $expandedZoom
            )
        }
    }
}

private enum DiagramZoom {
    static let minimum = 0.5
    static let maximum = 3.0
    static let step = 0.25
}

private struct DiagramZoomControls: View {
    @Binding var zoom: Double
    var onExpand: (() -> Void)?

    var body: some View {
        HStack(spacing: 2) {
            Button {
                zoom = max(DiagramZoom.minimum, zoom - DiagramZoom.step)
            } label: {
                Image(systemName: "minus.magnifyingglass")
            }
            .disabled(zoom <= DiagramZoom.minimum)
            .accessibilityLabel("Zoom out")
            .help("Zoom out")

            Text("\(Int((zoom * 100).rounded()))%")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 38)
                .accessibilityLabel("Diagram zoom \(Int((zoom * 100).rounded())) percent")

            Button {
                zoom = 1
            } label: {
                Image(systemName: "arrow.down.right.and.arrow.up.left")
            }
            .disabled(zoom == 1)
            .accessibilityLabel("Fit diagram")
            .help("Fit diagram")

            Button {
                zoom = min(DiagramZoom.maximum, zoom + DiagramZoom.step)
            } label: {
                Image(systemName: "plus.magnifyingglass")
            }
            .disabled(zoom >= DiagramZoom.maximum)
            .accessibilityLabel("Zoom in")
            .help("Zoom in")

            if let onExpand {
                Divider()
                    .frame(height: 16)
                    .padding(.horizontal, 2)

                Button(action: onExpand) {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                }
                .accessibilityLabel("Open enlarged diagram")
                .help("Open enlarged diagram")
            }
        }
        .buttonStyle(.borderless)
        .controlSize(.small)
        .padding(4)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 5))
    }
}

private struct ExpandedMermaidDiagramView: View {
    let id: String
    let source: String
    let title: String
    @Binding var zoom: Double
    @State private var contentHeight: CGFloat = 600
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Text(title)
                    .font(.headline)
                    .lineLimit(1)

                Spacer(minLength: 16)

                DiagramZoomControls(zoom: $zoom)

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Close diagram")
                .help("Close diagram")
            }
            .padding(12)

            Divider()

            MermaidWebView(
                id: "\(id)-expanded",
                source: source,
                title: title,
                zoom: zoom,
                contentHeight: $contentHeight
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.quaternary.opacity(0.18))
        }
        .frame(
            minWidth: 760,
            idealWidth: 1080,
            maxWidth: .infinity,
            minHeight: 520,
            idealHeight: 760,
            maxHeight: .infinity
        )
    }
}

private struct MermaidWebView: NSViewRepresentable {
    let id: String
    let source: String
    let title: String
    let zoom: Double
    @Binding var contentHeight: CGFloat
    @Environment(\.colorScheme) private var colorScheme

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.userContentController.add(context.coordinator, name: "diagram")

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.setValue(false, forKey: "drawsBackground")
        context.coordinator.observeScrolling(in: webView)

        guard let resourceURL = Bundle.module.url(
            forResource: "index",
            withExtension: "html",
            subdirectory: "Resources/Diagram"
        ) else {
            assertionFailure("The bundled diagram renderer is missing.")
            return webView
        }
        webView.loadFileURL(
            resourceURL,
            allowingReadAccessTo: resourceURL.deletingLastPathComponent()
        )
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.synchronize(webView)
    }

    static func dismantleNSView(_ webView: WKWebView, coordinator: Coordinator) {
        coordinator.stopObservingScrolling()
        webView.configuration.userContentController.removeScriptMessageHandler(
            forName: "diagram"
        )
        webView.navigationDelegate = nil
    }

    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var parent: MermaidWebView
        private var isReady = false
        private var renderedPayload = ""
        private var appliedZoom: Double?
        private weak var webView: WKWebView?
        private var scrollMonitor: Any?

        init(_ parent: MermaidWebView) {
            self.parent = parent
        }

        func observeScrolling(in webView: WKWebView) {
            self.webView = webView
            scrollMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) {
                [weak self, weak webView] event in
                guard let self, let webView else { return event }
                return self.routeScrollEvent(event, over: webView)
            }
        }

        func stopObservingScrolling() {
            if let scrollMonitor {
                NSEvent.removeMonitor(scrollMonitor)
            }
            scrollMonitor = nil
            webView = nil
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation?) {
            synchronize(webView)
        }

        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            guard message.name == "diagram",
                  let body = message.body as? [String: Any],
                  let type = body["type"] as? String
            else { return }

            if type == "ready" {
                isReady = true
                synchronize(message.webView)
            } else if type == "size", let height = body["height"] as? NSNumber {
                parent.contentHeight = CGFloat(truncating: height)
            }
        }

        func synchronize(_ webView: WKWebView?) {
            guard isReady, let webView else { return }
            let payload: [String: Any] = [
                "id": parent.id,
                "source": parent.source,
                "title": parent.title,
                "theme": parent.colorScheme == .dark ? "dark" : "light",
                "zoom": parent.zoom,
            ]
            guard let data = try? JSONSerialization.data(withJSONObject: payload),
                  let json = String(data: data, encoding: .utf8)
            else { return }
            let contentPayload = "\(parent.id)\u{0}\(parent.source)\u{0}\(parent.title)\u{0}\(parent.colorScheme)"
            if contentPayload != renderedPayload {
                renderedPayload = contentPayload
                appliedZoom = parent.zoom
                webView.evaluateJavaScript("window.LeetDiagram.render(\(json))")
            } else if appliedZoom != parent.zoom {
                appliedZoom = parent.zoom
                webView.evaluateJavaScript("window.LeetDiagram.setZoom(\(parent.zoom))")
            }
        }

        private func routeScrollEvent(_ event: NSEvent, over webView: WKWebView) -> NSEvent? {
            guard event.window === webView.window,
                  webView.bounds.contains(webView.convert(event.locationInWindow, from: nil)),
                  abs(event.scrollingDeltaY) > abs(event.scrollingDeltaX),
                  let lessonScrollView = enclosingScrollView(of: webView)
            else { return event }

            lessonScrollView.scrollWheel(with: event)
            return nil
        }

        private func enclosingScrollView(of webView: WKWebView) -> NSScrollView? {
            var ancestor = webView.superview
            while let current = ancestor {
                if let scrollView = current as? NSScrollView {
                    return scrollView
                }
                ancestor = current.superview
            }
            return nil
        }
    }
}