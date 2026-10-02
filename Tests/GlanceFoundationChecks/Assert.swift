import Foundation

enum CheckRun {
    private(set) static var failed = 0
    private(set) static var passed = 0

    static func expect(_ condition: Bool, _ message: String, file: String = #fileID, line: Int = #line) {
        if condition {
            passed += 1
        } else {
            failed += 1
            fputs("FAIL \(file):\(line) \(message)\n", stderr)
        }
    }

    static func equal<T: Equatable>(_ lhs: T, _ rhs: T, _ message: String, file: String = #fileID, line: Int = #line) {
        expect(lhs == rhs, "\(message) (\(lhs) != \(rhs))", file: file, line: line)
    }
}
