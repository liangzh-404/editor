import Foundation
import Dispatch
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

    func execute(_ sql: String, bindings: [SQLiteValue]) throws {
        let statement = try prepare(sql)
        defer { sqlite3_finalize(statement) }

        try bind(bindings, to: statement)

        let result = sqlite3_step(statement)
        guard result == SQLITE_DONE else {
            throw SQLiteDatabaseError.stepFailed(lastErrorMessage())
        }
    }

    func query(_ sql: String, bindings: [SQLiteValue] = []) throws -> [SQLiteRow] {
        let statement = try prepare(sql)
        defer { sqlite3_finalize(statement) }

        try bind(bindings, to: statement)

        var rows: [SQLiteRow] = []
        while true {
            let result = sqlite3_step(statement)
            if result == SQLITE_ROW {
                rows.append(SQLiteRow(statement: statement))
            } else if result == SQLITE_DONE {
                return rows
            } else {
                throw SQLiteDatabaseError.stepFailed(lastErrorMessage())
            }
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

    @discardableResult
    func withImmediateTransaction<T>(
        _ label: String,
        operation: () throws -> T
    ) throws -> T {
        let startedAt = DispatchTime.now().uptimeNanoseconds
        try execute("BEGIN IMMEDIATE TRANSACTION")
        do {
            let result = try operation()
            try execute("COMMIT")
            EditorLog.store.debug(
                "transaction_committed label=\(label, privacy: .public) duration_ms=\(self.durationMilliseconds(since: startedAt), privacy: .public)"
            )
            return result
        } catch {
            try? execute("ROLLBACK")
            EditorLog.store.error(
                "transaction_rolled_back label=\(label, privacy: .public) duration_ms=\(self.durationMilliseconds(since: startedAt), privacy: .public) error=\(String(describing: error), privacy: .public)"
            )
            throw error
        }
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

    private func bind(_ values: [SQLiteValue], to statement: OpaquePointer?) throws {
        for (offset, value) in values.enumerated() {
            let index = Int32(offset + 1)
            let result: Int32

            switch value {
            case .text(let string):
                result = sqlite3_bind_text(statement, index, string, -1, sqliteTransient)
            case .integer(let integer):
                result = sqlite3_bind_int64(statement, index, Int64(integer))
            case .null:
                result = sqlite3_bind_null(statement, index)
            }

            guard result == SQLITE_OK else {
                throw SQLiteDatabaseError.executeFailed(lastErrorMessage())
            }
        }
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

    private func durationMilliseconds(since startedAt: UInt64) -> Double {
        let elapsedNanoseconds = DispatchTime.now().uptimeNanoseconds - startedAt
        return Double(elapsedNanoseconds) / 1_000_000
    }
}

enum SQLiteValue: Equatable {
    case text(String)
    case integer(Int)
    case null
}

struct SQLiteRow: Equatable {
    private let values: [String: String?]

    init(statement: OpaquePointer?) {
        var rowValues: [String: String?] = [:]
        let columnCount = sqlite3_column_count(statement)

        for columnIndex in 0..<columnCount {
            guard let rawName = sqlite3_column_name(statement, columnIndex) else {
                continue
            }

            let name = String(cString: rawName)
            if sqlite3_column_type(statement, columnIndex) == SQLITE_NULL {
                rowValues[name] = nil
            } else if let rawText = sqlite3_column_text(statement, columnIndex) {
                rowValues[name] = String(cString: rawText)
            } else {
                rowValues[name] = ""
            }
        }

        values = rowValues
    }

    subscript(_ column: String) -> String? {
        values[column] ?? nil
    }
}

private let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
