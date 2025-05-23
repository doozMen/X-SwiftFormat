import Foundation
import SwiftFormat
import XcodeKit

class SourceEditorCommand: NSObject, XCSourceEditorCommand {

    let supportedUTIs = [
        "public.swift-source",
        "com.apple.dt.playground",
        "com.apple.dt.playgroundpage",
        "com.apple.dt.swiftpm-package-manifest",
    ]

    func perform(
        with invocation: XCSourceEditorCommandInvocation,
        completionHandler: @escaping (Error?) -> Void
    ) {
        let uti = invocation.buffer.contentUTI
        if supportedUTIs.contains(uti) {
            formatBuffer(with: invocation) { error in
                DispatchQueue.main.async {
                    if let swiftFormatError = error as? SwiftFormatError {
                        switch swiftFormatError {
                        case .fileNotReadable:
                            completionHandler(
                                NSError(
                                    domain:
                                        "The requested file was not readable or it did not exist.",
                                    code: -1002, userInfo: nil) as Error)
                        case .isDirectory:
                            completionHandler(
                                NSError(
                                    domain: "The requested file was a directory.", code: -1003,
                                    userInfo: nil) as Error)
                        case .fileContainsInvalidSyntax:
                            completionHandler(
                                NSError(
                                    domain:
                                        "The file contains invalid or unrecognized Swift syntax and cannot be handled safely.",
                                    code: -1004, userInfo: nil) as Error)
                        case .unrecognizedExperimentalFeature(_):
                            completionHandler(
                                NSError(
                                    domain:
                                        "The file contains invalid or unrecognized Swift syntax and cannot be handled safely.",
                                    code: -1004, userInfo: nil) as Error)
                        }
                    } else {
                        completionHandler(error)
                    }
                }
            }
        } else {
            completionHandler(
                NSError(domain: "Not a Swift file", code: -1001, userInfo: nil) as Error)
        }
    }

    private func formatBuffer(
        with invocation: XCSourceEditorCommandInvocation,
        completion: @escaping (_ error: Error?) -> Void
    ) {
        DispatchQueue.global(qos: .background).async {
            let sharedConfiguration = SharedConfiguration.loadConfiguration()
            let configuration = Configuration.buildConfiguration(with: sharedConfiguration.payload)
            let swiftFormatter = SwiftFormatter(configuration: configuration)
            var swiftFormatOutputStream = SwiftFormatOutputStream()

            do {
                try swiftFormatter.format(
					source: invocation.buffer.completeBuffer, assumingFileURL: nil, selection: .infinite,
                    to: &swiftFormatOutputStream)
                if let output = swiftFormatOutputStream.output,
                    invocation.buffer.completeBuffer != output
                {
                    // According to https://github.com/nicklockwood/SwiftFormat/blob/4bf475154c1c98dcdf751037f930f8e5c72597a4/EditorExtension/Extension/FormatFileCommand.swift#L69-L71
                    // Remove all selections to avoid a crash when changing the contents of the buffer.
                    let selections = invocation.buffer.selections.compactMap {
                        $0 as? XCSourceTextRange
                    }
                    invocation.buffer.selections.removeAllObjects()
                    invocation.buffer.completeBuffer = output
                    // Restore selections
                    selections.forEach { selection in
                        invocation.buffer.selections.add(
                            XCSourceTextRange(start: selection.start, end: selection.end))
                    }
                }
                completion(nil)
            } catch {
                completion(error)
            }
        }
    }
}
