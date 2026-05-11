import Foundation
import SQLite3

enum SQLiteDatabaseError: Error, Equatable, CustomStringConvertible {
    case openFailed(String)
    case prepareFailed(String)
    case executeFailed(String)
    case stepFailed(String)
    case closed

    var description: String {
        switch self {
        case .openFailed(let message):
            return "Open failed: \(message)"
        case .prepareFailed(let message):
            return "Prepare failed: \(message)"
        case .executeFailed(let message):
            return "Execute failed: \(message)"
        case .stepFailed(let message):
            return "Step failed: \(message)"
        case .closed:
            return "Database is closed"
        }
    }
}

final class SQLiteDatabase {
    private var handle: OpaquePointer?

    private init(handle: OpaquePointer) {
        self.handle = handle
    }

    deinit {
        close()
    }

    static func open(path: String) throws -> SQLiteDatabase {
        var rawHandle: OpaquePointer?
        let flags = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX
        let result = sqlite3_open_v2(path, &rawHandle, flags, nil)

        guard result == SQLITE_OK, let handle = rawHandle else {
            let message = rawHandle.map { String(cString: sqlite3_errmsg($0)) } ?? "unknown"
            if let rawHandle {
                sqlite3_close(rawHandle)
            }
            throw SQLiteDatabaseError.openFailed(message)
        }

        return SQLiteDatabase(handle: handle)
    }

    func close() {
        if let handle {
            sqlite3_close(handle)
            self.handle = nil
        }
    }

    func execute(_ sql: String) throws {
        let handle = try requireHandle()
        var errorMessage: UnsafeMutablePointer<CChar>?
        let result = sqlite3_exec(handle, sql, nil, nil, &errorMessage)

        guard result == SQLITE_OK else {
            let message = errorMessage.map { String(cString: $0) } ?? lastErrorMessage()
            sqlite3_free(errorMessage)
            throw SQLiteDatabaseError.executeFailed(message)
        }
    }

    func queryStrings(_ sql: String) throws -> [String] {
        let statement = try prepare(sql)
        defer { sqlite3_finalize(statement) }

        var rows: [String] = []
        while true {
            let result = sqlite3_step(statement)
            if result == SQLITE_ROW {
                if let text = sqlite3_column_text(statement, 0) {
                    rows.append(String(cString: text))
                } else {
                    rows.append("")
                }
            } else if result == SQLITE_DONE {
                return rows
            } else {
                throw SQLiteDatabaseError.stepFailed(lastErrorMessage())
            }
        }
    }

    func queryInt(_ sql: String) throws -> Int {
        let statement = try prepare(sql)
        defer { sqlite3_finalize(statement) }

        let result = sqlite3_step(statement)
        guard result == SQLITE_ROW else {
            if result == SQLITE_DONE {
                throw SQLiteDatabaseError.stepFailed("Query returned no rows")
            }
            throw SQLiteDatabaseError.stepFailed(lastErrorMessage())
        }

        return Int(sqlite3_column_int64(statement, 0))
    }

    private func prepare(_ sql: String) throws -> OpaquePointer? {
        let handle = try requireHandle()
        var statement: OpaquePointer?
        let result = sqlite3_prepare_v2(handle, sql, -1, &statement, nil)

        guard result == SQLITE_OK else {
            throw SQLiteDatabaseError.prepareFailed(lastErrorMessage())
        }

        return statement
    }

    private func requireHandle() throws -> OpaquePointer {
        guard let handle else {
            throw SQLiteDatabaseError.closed
        }
        return handle
    }

    private func lastErrorMessage() -> String {
        guard let handle else {
            return "database is closed"
        }
        return String(cString: sqlite3_errmsg(handle))
    }
}

