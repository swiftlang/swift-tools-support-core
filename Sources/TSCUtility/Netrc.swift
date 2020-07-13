import Foundation

@available (OSX 10.13, *)
public struct Netrc {
    
    public struct Machine: Equatable {
        public var isDefault: Bool {
            return name == "default"
        }
        public let name: String
        public let login: String
        public let password: String
        
        init?(for match: NSTextCheckingResult, string: String, variant: String = "") {
            guard let name = Token.machine.capture(in: match, string: string) ?? Token.default.capture(in: match, string: string),
                let login = Token.login.capture(prefix: variant, in: match, string: string),
                let password = Token.password.capture(prefix: variant, in: match, string: string) else {
                    return nil
            }
            self = Machine(name: name, login: login, password: password)
        }
        
        public init(name: String, login: String, password: String) {
            self.name = name
            self.login = login
            self.password = password
        }
    }
    
    public enum Error: Swift.Error {
        case fileNotFound(Foundation.URL)
        case unreadableFile(Foundation.URL)
        case machineNotFound
        case missingToken(String)
        case invalidDefaultMachinePosition
    }
    
    @frozen private enum Token: String, CaseIterable {
        case machine
        case login
        case password
        case macdef
        case `default`
        
        func capture(prefix: String = "", in match: NSTextCheckingResult, string: String) -> String? {
            guard let range = Range(match.range(withName: prefix + rawValue), in: string) else { return nil }
            return String(string[range])
        }
    }
    
    public let machines: [Machine]
    
    init(machines: [Machine]) {
        self.machines = machines
    }
    
    public func authorization(for url: Foundation.URL) -> String? {
        guard let index = machines.firstIndex(where: { $0.name == url.host }) ?? machines.firstIndex(where: { $0.isDefault }) else { return nil }
        let machine = machines[index]
        let authString = "\(machine.login):\(machine.password)"
        guard let authData = authString.data(using: .utf8) else { return nil }
        return "Basic \(authData.base64EncodedString())"
    }
    
    public static func load(from fileURL: Foundation.URL = Foundation.URL(fileURLWithPath: "\(NSHomeDirectory())/.netrc")) -> Result<Netrc, Netrc.Error> {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return .failure(.fileNotFound(fileURL)) }
        guard FileManager.default.isReadableFile(atPath: fileURL.path),
            let fileContents = try? String(contentsOf: fileURL, encoding: .utf8) else { return .failure(.unreadableFile(fileURL)) }
        
        return Netrc.from(fileContents)
    }
    
    public static func from(_ content: String) -> Result<Netrc, Netrc.Error> {
        
        let content = trimComments(from: content)
        let regex = try! NSRegularExpression(pattern: RegexUtil.pattern, options: [])
        let matches = regex.matches(in: content, options: [], range: NSRange(content.startIndex..<content.endIndex, in: content))
        
        let machines: [Machine] = matches.compactMap {
            return Machine(for: $0, string: content, variant: "lp") ??
                Machine(for: $0, string: content, variant: "pl")
        }
        
        if let defIndex = machines.firstIndex(where: { $0.isDefault }) {
            guard defIndex == machines.index(before: machines.endIndex) else { return .failure(.invalidDefaultMachinePosition) }
        }
        guard machines.count > 0 else { return .failure(.machineNotFound) }
        return .success(Netrc(machines: machines))
    }
    
    private static func trimComments(from text: String) -> String {
        let regex = try! NSRegularExpression(pattern: RegexUtil.commentsPattern, options: .anchorsMatchLines)
        let nsString = text as NSString
        let range = NSRange(location: 0, length: nsString.length)
        let matches = regex.matches(in: text, range: range)
        var trimmedCommentsText = text
        matches.forEach {
            trimmedCommentsText = trimmedCommentsText
                .replacingOccurrences(of: nsString.substring(with: $0.range), with: "")
        }
        return trimmedCommentsText
    }
}

fileprivate enum RegexUtil {
    static let loginPassword: [String] = ["login", "password"]
    static let passwordLogin: [String] = ["password", "login"]
    static let pattern: String = #"(?:(?:(\#(namedTrailingCapture("machine"))|\#(namedMatch("default"))))(?:\#(namedTrailingCapture(loginPassword, prefix: "lp"))|\#(namedTrailingCapture(passwordLogin, prefix: "pl"))))"#
    static let commentsPattern: String = "\\#[\\s\\S]*?.*$"
    
    static func namedMatch(_ string: String) -> String {
        return #"(?:\s*(?<\#(string)>\#(string)))"#
    }
    
    static func namedTrailingCapture(_ string: String, prefix: String = "") -> String {
        return #"\s*\#(string)\s+(?<\#(prefix + string)>\S++)"#
    }
    
    static func namedTrailingCapture(_ array: [String], prefix: String = "") -> String {
        return array.map({ namedTrailingCapture($0, prefix: prefix) }).joined()
    }
}
