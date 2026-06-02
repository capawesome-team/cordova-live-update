import Foundation
import WebKit

/// Serves files from the active live-update bundle directory in response to
/// WebKit URL scheme tasks. When no bundle is active (or the requested file is
/// not in the active bundle) `handle(task:)` returns `false`, allowing Cordova's
/// default scheme handler to fall back to the app's bundled `www/` folder.
public class LiveUpdateSchemeHandler: NSObject {
    private let activeBundleDirLock = NSLock()
    private var _activeBundleDir: URL?

    private let activeTasksQueue = DispatchQueue(label: "io.capawesome.cordova.liveupdate.schemeHandler")
    private var activeTasks = Set<URLSchemeTaskWrapper>()

    public var activeBundleDir: URL? {
        get {
            activeBundleDirLock.lock()
            defer { activeBundleDirLock.unlock() }
            return _activeBundleDir
        }
        set {
            activeBundleDirLock.lock()
            _activeBundleDir = newValue
            activeBundleDirLock.unlock()
        }
    }

    /// Called from `CDVPlugin.overrideSchemeTask`. Returns `true` if we serve
    /// the resource ourselves, `false` to fall through to the default handler.
    public func handle(task: WKURLSchemeTask) -> Bool {
        guard let baseDir = activeBundleDir else {
            return false
        }
        guard let requestURL = task.request.url else {
            return false
        }

        // Map the request path to a file inside the active bundle directory.
        var relativePath = requestURL.path
        if relativePath.hasPrefix("/") {
            relativePath = String(relativePath.dropFirst())
        }
        if relativePath.isEmpty || relativePath.hasSuffix("/") {
            relativePath += "index.html"
        }

        let fileURL = baseDir.appendingPathComponent(relativePath).standardizedFileURL

        // Defense-in-depth against path traversal.
        let canonicalBase = baseDir.standardizedFileURL.path
        guard fileURL.path == canonicalBase || fileURL.path.hasPrefix(canonicalBase + "/") else {
            return false
        }

        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: fileURL.path, isDirectory: &isDirectory), !isDirectory.boolValue else {
            // File not in the active bundle — let the default handler try.
            return false
        }

        let wrapper = URLSchemeTaskWrapper(task: task)
        activeTasksQueue.sync { _ = activeTasks.insert(wrapper) }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.serve(task: task, wrapper: wrapper, fileURL: fileURL, requestURL: requestURL, request: task.request)
        }
        return true
    }

    public func stop(task: WKURLSchemeTask) {
        activeTasksQueue.sync {
            activeTasks = activeTasks.filter { $0.task !== task }
        }
    }

    private func isActive(_ wrapper: URLSchemeTaskWrapper) -> Bool {
        return activeTasksQueue.sync { activeTasks.contains(wrapper) }
    }

    private func removeActive(_ wrapper: URLSchemeTaskWrapper) {
        activeTasksQueue.sync { _ = activeTasks.remove(wrapper) }
    }

    private func serve(task: WKURLSchemeTask, wrapper: URLSchemeTaskWrapper, fileURL: URL, requestURL: URL, request: URLRequest) {
        let fileHandle: FileHandle
        do {
            fileHandle = try FileHandle(forReadingFrom: fileURL)
        } catch {
            if isActive(wrapper) {
                task.didFailWithError(error)
            }
            removeActive(wrapper)
            return
        }
        defer { try? fileHandle.close() }

        let fileSize: UInt64
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
            fileSize = (attributes[.size] as? NSNumber)?.uint64Value ?? 0
        } catch {
            if isActive(wrapper) {
                task.didFailWithError(error)
            }
            removeActive(wrapper)
            return
        }

        var statusCode = 200
        let mimeType = mimeType(for: fileURL)
        var headers: [String: String] = [
            "Content-Type": mimeType,
            "Cache-Control": "no-cache"
        ]
        var responseSize = fileSize
        var responseSent: UInt64 = 0

        // Range request handling
        if let rangeHeader = request.value(forHTTPHeaderField: "Range"), rangeHeader.hasPrefix("bytes=") {
            let byteRange = rangeHeader.dropFirst("bytes=".count)
            let parts = byteRange.split(separator: "-", maxSplits: 1, omittingEmptySubsequences: false)
            let start: UInt64 = UInt64(parts.first.map(String.init) ?? "") ?? 0
            var end: UInt64
            if parts.count > 1, !parts[1].isEmpty, let parsed = UInt64(parts[1]) {
                end = parsed
            } else {
                end = fileSize > 0 ? fileSize - 1 : 0
            }

            // Clamp the end to the last valid byte so an over-large range does
            // not produce an invalid Content-Length or read past EOF.
            if fileSize > 0 {
                end = min(end, fileSize - 1)
            }

            // An unsatisfiable range (start past EOF, or end before start)
            // must be answered with 416 rather than underflowing `end - start`.
            if start >= fileSize || end < start {
                headers["Content-Range"] = "bytes */\(fileSize)"
                let response = HTTPURLResponse(
                    url: requestURL,
                    statusCode: 416,
                    httpVersion: "HTTP/1.1",
                    headerFields: headers
                )
                if isActive(wrapper), let response = response {
                    task.didReceive(response)
                    task.didFinish()
                }
                removeActive(wrapper)
                return
            }

            do {
                try fileHandle.seek(toOffset: start)
            } catch {
                if isActive(wrapper) {
                    task.didFailWithError(error)
                }
                removeActive(wrapper)
                return
            }
            let length = end - start + 1
            responseSize = length
            statusCode = 206
            headers["Content-Range"] = "bytes \(start)-\(end)/\(fileSize)"
            headers["Content-Length"] = String(length)
        } else {
            headers["Content-Length"] = String(fileSize)
        }

        guard let response = HTTPURLResponse(
            url: requestURL,
            statusCode: statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: headers
        ) else {
            removeActive(wrapper)
            return
        }

        if isActive(wrapper) {
            task.didReceive(response)
        }

        let bufferSize = 64 * 1024
        while isActive(wrapper) && responseSent < responseSize {
            var reachedEOF = false
            autoreleasepool {
                let chunkSize = min(UInt64(bufferSize), responseSize - responseSent)
                let data: Data
                if #available(iOS 13.4, *) {
                    data = (try? fileHandle.read(upToCount: Int(chunkSize))) ?? Data()
                } else {
                    data = fileHandle.readData(ofLength: Int(chunkSize))
                }
                if data.isEmpty {
                    // `return` only exits the autoreleasepool closure; flag EOF
                    // so the enclosing loop terminates instead of spinning.
                    reachedEOF = true
                    return
                }
                if isActive(wrapper) {
                    task.didReceive(data)
                }
                responseSent += UInt64(data.count)
            }
            if reachedEOF {
                break
            }
        }

        if isActive(wrapper) {
            task.didFinish()
        }
        removeActive(wrapper)
    }

    private func mimeType(for url: URL) -> String {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "js", "mjs":
            return "application/javascript"
        case "html", "htm":
            return "text/html"
        case "css":
            return "text/css"
        case "json":
            return "application/json"
        case "wasm":
            return "application/wasm"
        case "svg":
            return "image/svg+xml"
        case "png":
            return "image/png"
        case "jpg", "jpeg":
            return "image/jpeg"
        case "gif":
            return "image/gif"
        case "webp":
            return "image/webp"
        case "ico":
            return "image/x-icon"
        case "woff":
            return "font/woff"
        case "woff2":
            return "font/woff2"
        case "ttf":
            return "font/ttf"
        case "otf":
            return "font/otf"
        case "mp4":
            return "video/mp4"
        case "mp3":
            return "audio/mpeg"
        case "wav":
            return "audio/wav"
        case "txt":
            return "text/plain"
        case "xml":
            return "application/xml"
        case "pdf":
            return "application/pdf"
        default:
            return "application/octet-stream"
        }
    }
}

/// Identity wrapper around `WKURLSchemeTask` so we can store tasks in a `Set`
/// using reference identity (the protocol itself isn't `Hashable`).
private final class URLSchemeTaskWrapper: Hashable {
    let task: WKURLSchemeTask

    init(task: WKURLSchemeTask) {
        self.task = task
    }

    static func == (lhs: URLSchemeTaskWrapper, rhs: URLSchemeTaskWrapper) -> Bool {
        return lhs.task === rhs.task
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(task as AnyObject))
    }
}
