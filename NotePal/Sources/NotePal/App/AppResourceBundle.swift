import Foundation

enum AppResourceBundle {
    private static let resourceBundleName = "NotePal_NotePal.bundle"

    static func url(forResource name: String, withExtension fileExtension: String) -> URL? {
        for bundle in candidateBundles() {
            if let url = bundle.url(forResource: name, withExtension: fileExtension) {
                return url
            }
        }

        return nil
    }

    private static func candidateBundles() -> [Bundle] {
        candidateBundleURLs().compactMap(Bundle.init(url:))
    }

    private static func candidateBundleURLs() -> [URL] {
        var urls: [URL] = []

        if let resourceURL = Bundle.main.resourceURL {
            urls.append(resourceURL.appendingPathComponent(resourceBundleName, isDirectory: true))
        }

        urls.append(
            Bundle.main.bundleURL
                .appendingPathComponent("Contents", isDirectory: true)
                .appendingPathComponent("Resources", isDirectory: true)
                .appendingPathComponent(resourceBundleName, isDirectory: true)
        )

        urls.append(Bundle.main.bundleURL.appendingPathComponent(resourceBundleName, isDirectory: true))

        return urls
    }
}
