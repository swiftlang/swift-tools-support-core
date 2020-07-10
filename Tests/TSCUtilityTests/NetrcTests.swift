import XCTest
import TSCUtility

class NetrcTests: XCTestCase {
    func testLoadMachinesInline() {
        //			it("should load machines for a given inline format") {
        let content = "machine example.com login anonymous password qwerty"
        
        let machines = try? Netrc.from(content).get().machines
        XCTAssertEqual(machines?.count, 1)
        
        let machine = machines?.first
        XCTAssertEqual(machine?.name, "example.com")
        XCTAssertEqual(machine?.login, "anonymous")
        XCTAssertEqual(machine?.password, "qwerty")
    }
    
    func testLoadMachinesMultiLine() {
        //			it("should load machines for a given multi-line format") {
        let content = """
                    machine example.com
                    login anonymous
                    password qwerty
                    """
        
        let machines = try? Netrc.from(content).get().machines
        XCTAssertEqual(machines?.count, 1)
        
        let machine = machines?.first
        XCTAssertEqual(machine?.name, "example.com")
        XCTAssertEqual(machine?.login, "anonymous")
        XCTAssertEqual(machine?.password, "qwerty")
    }
    
    func testLoadMachinesMultilineComments() {
        
        //			it("should load machines for a given multi-line format with comments") {
        let content = """
                    ## This is a comment
                    # This is another comment
                    machine example.com # This is an inline comment
                    login anonymous
                    password qwerty # and # another #one
                    """
        
        let machines = try? Netrc.from(content).get().machines
        XCTAssertEqual(machines?.count, 1)
        
        let machine = machines?.first
        XCTAssertEqual(machine?.name, "example.com")
        XCTAssertEqual(machine?.login, "anonymous")
        XCTAssertEqual(machine?.password, "qwerty")
    }
    
    func testLoadMachinesMultilineWhitespaces() {
        //			it("should load machines for a given multi-line + whitespaces format") {
        let content = """
                    machine  example.com login     anonymous
                    password                  qwerty
                    """
        
        let machines = try? Netrc.from(content).get().machines
        XCTAssertEqual(machines?.count, 1)
        
        let machine = machines?.first
        XCTAssertEqual(machine?.name, "example.com")
        XCTAssertEqual(machine?.login, "anonymous")
        XCTAssertEqual(machine?.password, "qwerty")
    }
    
    func testLoadMultipleMachinesInline() {
        //			it("should load multiple machines for a given inline format") {
        let content = "machine example.com login anonymous password qwerty machine example2.com login anonymous2 password qwerty2"
        
        let machines = try? Netrc.from(content).get().machines
        XCTAssertEqual(machines?.count, 2)
        
        var machine = machines?[0]
        XCTAssertEqual(machine?.name, "example.com")
        XCTAssertEqual(machine?.login, "anonymous")
        XCTAssertEqual(machine?.password, "qwerty")
        
        machine = machines?[1]
        XCTAssertEqual(machine?.name, "example2.com")
        XCTAssertEqual(machine?.login, "anonymous2")
        XCTAssertEqual(machine?.password, "qwerty2")
    }
    
    func testLoadMultipleMachinesMultiline() {
        //			it("should load multiple machines for a given multi-line format") {
        let content = """
                    machine  example.com login     anonymous
                    password                  qwerty
                    machine example2.com
                    login anonymous2
                    password qwerty2
                    """
        
        let machines = try? Netrc.from(content).get().machines
        XCTAssertEqual(machines?.count, 2)
        
        var machine = machines?[0]
        XCTAssertEqual(machine?.name, "example.com")
        XCTAssertEqual(machine?.login, "anonymous")
        XCTAssertEqual(machine?.password, "qwerty")
        
        machine = machines?[1]
        XCTAssertEqual(machine?.name, "example2.com")
        XCTAssertEqual(machine?.login, "anonymous2")
        XCTAssertEqual(machine?.password, "qwerty2")
    }
    
    func testErrorMachineParameterMissing() {
        //			it("should throw error when machine parameter is missing") {
        let content = "login anonymous password qwerty"
        
        guard case .failure(.machineNotFound) = Netrc.from(content) else {
            return XCTFail("Expected machineNotFound error")
        }
    }
    
    func testErrorEmptyMachineValue() {
        //			it("should throw error for an empty machine values") {
        let content = "machine"
        
        guard case .failure(.machineNotFound) = Netrc.from(content) else {
            return XCTFail("Expected machineNotFound error")
        }
    }
    
    func testErrorLoginParameterMissing() {
        //			it("should throw error when login parameter is missing") {
        let content = "machine example.com anonymous password qwerty"
        
        guard case .failure(.missingValueForToken(let token)) = Netrc.from(content) else {
            return XCTFail("Expected missingValueForToken error")
        }
        
        XCTAssertEqual(token, "login")
    }
    
    func testErrorPasswordParameterMissing() {
        //			it("should throw error when password parameter is missing") {
        let content = "machine example.com login anonymous"
        
        guard case .failure(.missingValueForToken(let token)) = Netrc.from(content) else {
            return XCTFail("Expected missingValueForToken error")
        }
        
        XCTAssertEqual(token, "password")
    }
    
    func testErrorLoginPasswordParameterMissing() {
        //            it("should throw error when both login and password parameters are missing") {
        let content = "machine example.com"
        
        guard case .failure(.missingValueForToken(let token)) = Netrc.from(content) else {
            return XCTFail("Expected missingValueForToken error")
        }
        
        XCTAssertEqual(token, "login")
    }
    
    func testReturnAuthorizationForMachineMatch() {
        //			it("should return authorization when config contains a given machine") {
        let content = "machine example.com login anonymous password qwerty"
        
        guard let netrc = try? Netrc.from(content).get(),
              let result = netrc.authorization(for: URL(string: "https://example.com")!) else {
            return XCTFail()
        }
        
        let data = "anonymous:qwerty".data(using: .utf8)!.base64EncodedString()
        XCTAssertEqual(result, "Basic \(data)")
    }
    
    func testNoReturnAuthorizationForNoMachineMatch() {
        //			it("should not return authorization when config does not contain a given machine") {
        let content = "machine example.com login anonymous password qwerty"
        
        guard let netrc = try? Netrc.from(content).get() else {
            return XCTFail()
        }
        XCTAssertNil(netrc.authorization(for: URL(string: "https://example99.com")!))
    }
    
    func testIBMDocumentation() {
        // test case: https://www.ibm.com/support/knowledgecenter/en/ssw_aix_72/filesreference/netrc.html
        let content = "machine host1.austin.century.com login fred password bluebonnet"
        
        guard let netrc = try? Netrc.from(content).get() else {
            return XCTFail()
        }
        
        let machine = netrc.machines.first
        XCTAssertEqual(machine?.name, "host1.austin.century.com")
        XCTAssertEqual(machine?.login, "fred")
        XCTAssertEqual(machine?.password, "bluebonnet")
        
    }
    
    func testNoErrorTrailingAccountMacdefDefault() {
        // test case: https://gist.github.com/tpope/4247721
        
        // should not fail on presence of `account`, `macdef`, `default`
        let content = """
            machine api.heroku.com
              login my@email.com
              password 01230123012301230123012301230123

            machine api.github.com password something login somebody

            machine ftp.server login abc password def account ghi macdef somemacro
            cd somehwhere
            continues until end of paragraph

            default login anonymous password my@email.com
            """
        
        guard let netrc = try? Netrc.from(content).get() else {
            return XCTFail()
        }
        
        XCTAssertEqual(netrc.machines.count, 3)
        
        XCTAssertEqual(netrc.machines[0].name, "api.heroku.com")
        XCTAssertEqual(netrc.machines[0].login, "my@email.com")
        XCTAssertEqual(netrc.machines[0].password, "01230123012301230123012301230123")
        
        XCTAssertEqual(netrc.machines[1].name, "api.github.com")
        XCTAssertEqual(netrc.machines[1].login, "somebody")
        XCTAssertEqual(netrc.machines[1].password, "something")
        
        XCTAssertEqual(netrc.machines[2].name, "ftp.server")
        XCTAssertEqual(netrc.machines[2].login, "abc")
        XCTAssertEqual(netrc.machines[2].password, "def")
    }
}
