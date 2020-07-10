import Foundation


public struct Netrc {
    
    public struct Machine {
        public let name: String
        public let login: String
        public let password: String
    }
	
    public enum Error: Swift.Error {
        case fileNotFound(Foundation.URL)
        case unreadableFile(Foundation.URL)
		case machineNotFound
		case missingToken(String)
		case missingValueForToken(String)
	}
	
	public let machines: [Machine]
	
	init(machines: [Machine]) {
		self.machines = machines
	}
	
    public func authorization(for url: Foundation.URL) -> String? {
		guard let index = machines.firstIndex(where: { $0.name == url.host }) else { return nil }
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
		let trimmedCommentsContent = trimComments(from: content)
		let tokens = trimmedCommentsContent
			.trimmingCharacters(in: .whitespacesAndNewlines)
			.components(separatedBy: .whitespacesAndNewlines)
			.filter({ $0 != "" })
		
		var machines: [Machine] = []
		
		let machineTokens = tokens.split { $0 == "machine" }
		guard tokens.contains("machine"), machineTokens.count > 0 else { return .failure(.machineNotFound) }
		
		for machine in machineTokens {
			let values = Array(machine)
			guard let name = values.first else { continue }
			guard let login = values["login"] else { return .failure(.missingValueForToken("login")) }
			guard let password = values["password"] else { return .failure(.missingValueForToken("password")) }
			machines.append(Machine(name: name, login: login, password: password))
		}
		
		guard machines.count > 0 else { return .failure(Error.machineNotFound) }
		return .success(Netrc(machines: machines))
	}
	
	private static func trimComments(from text: String) -> String {
		let regex = try! NSRegularExpression(pattern: "\\#[\\s\\S]*?.*$", options: .anchorsMatchLines)
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

fileprivate extension Array where Element == String {
	subscript(_ token: String) -> String? {
		guard let tokenIndex = firstIndex(of: token),
			count > tokenIndex,
			!["machine", "login", "password"].contains(self[tokenIndex + 1]) else {
				return nil
		}
		return self[tokenIndex + 1]
	}
}
