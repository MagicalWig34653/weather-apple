import AppKit
import WebKit

// Usage: snap <w> <h> <scale> <in.html> <out.png> [more triples: in out ...]
// Offscreen WKWebView snapshot, no visible window, app never activated.
let args = CommandLine.arguments
guard args.count >= 6, let w = Double(args[1]), let h = Double(args[2]), let scale = Double(args[3]) else {
    FileHandle.standardError.write("usage: snap w h scale in.html out.png [in out]...\n".data(using: .utf8)!); exit(2)
}
var jobs: [(String, String)] = []
var i = 4
while i + 1 < args.count { jobs.append((args[i], args[i+1])); i += 2 }

let app = NSApplication.shared
app.setActivationPolicy(.prohibited)

final class Runner: NSObject, WKNavigationDelegate {
    let web: WKWebView
    var jobs: [(String, String)]
    let scale: Double
    let size: NSSize
    init(size: NSSize, scale: Double, jobs: [(String, String)]) {
        self.size = size; self.scale = scale; self.jobs = jobs
        let cfg = WKWebViewConfiguration()
        web = WKWebView(frame: NSRect(origin: .zero, size: size), configuration: cfg)
        super.init()
        web.navigationDelegate = self
        web.setValue(false, forKey: "drawsBackground")
    }
    var window: NSWindow!
    func start() {
        window = NSWindow(contentRect: NSRect(origin: NSPoint(x: -20000, y: -20000), size: size), styleMask: [.borderless], backing: .buffered, defer: false)
        window.contentView = web
        next()
    }
    func next() {
        guard let job = jobs.first else { exit(0) }
        web.load(URLRequest(url: URL(fileURLWithPath: job.0)))
    }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        let job = jobs.removeFirst()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            // measure document size
            webView.evaluateJavaScript("(function(){var b=document.querySelector('.board')||document.body;var r=b.getBoundingClientRect();return [Math.ceil(r.width),Math.ceil(r.height)]})()") { res, _ in
                var s = self.size
                if let a = res as? [Double], a.count == 2 { s = NSSize(width: a[0], height: a[1]) }
                else if let a = res as? [Int], a.count == 2 { s = NSSize(width: Double(a[0]), height: Double(a[1])) }
                self.window.setContentSize(s); webView.frame = NSRect(origin: .zero, size: s)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    let cfg = WKSnapshotConfiguration()
                    cfg.rect = NSRect(origin: .zero, size: s)
                    cfg.snapshotWidth = NSNumber(value: s.width * self.scale)
                    webView.takeSnapshot(with: cfg) { image, err in
                        if let image, let tiff = image.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
                           let png = rep.representation(using: .png, properties: [:]) {
                            try? png.write(to: URL(fileURLWithPath: job.1))
                            print("ok \(job.1) \(Int(s.width))x\(Int(s.height))")
                        } else { print("fail \(job.1) \(String(describing: err))") }
                        self.next()
                    }
                }
            }
        }
    }
}
let runner = Runner(size: NSSize(width: w, height: h), scale: scale, jobs: jobs)
runner.start()
app.run()
