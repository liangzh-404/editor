import OSLog

enum EditorLog {
    private static let subsystem = "com.liangzhang.editor"

    static let focus = Logger(subsystem: subsystem, category: "editor.focus")
    static let selection = Logger(subsystem: subsystem, category: "editor.selection")
    static let input = Logger(subsystem: subsystem, category: "editor.input")
    static let markdown = Logger(subsystem: subsystem, category: "editor.markdown")
    static let render = Logger(subsystem: subsystem, category: "editor.render")
    static let scroll = Logger(subsystem: subsystem, category: "editor.scroll")
    static let store = Logger(subsystem: subsystem, category: "store.transaction")
    static let sync = Logger(subsystem: subsystem, category: "sync.cloudkit")
    static let attachment = Logger(subsystem: subsystem, category: "attachment.preview")
}

