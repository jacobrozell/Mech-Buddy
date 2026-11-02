import Foundation

public enum AppLinks {
    public static let privacy = makeURL("https://jacobrozell.github.io/Mech-Buddy/privacy.html")
    public static let support = makeURL("https://jacobrozell.github.io/Mech-Buddy/support.html")
    public static let accessibility = makeURL("https://jacobrozell.github.io/Mech-Buddy/accessibility.html")
    public static let tipJar: URL? = nil
    public static let quickStartDownloads = makeURL("https://battletech.com/downloads/")

    private static func makeURL(_ string: String) -> URL {
        guard let url = URL(string: string) else {
            preconditionFailure("Invalid AppLinks URL: \(string)")
        }
        return url
    }
}
