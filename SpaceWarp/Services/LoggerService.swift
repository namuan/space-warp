//
//  LoggerService.swift
//  SpaceWarp
//
//  File-based logging system with daily rolling logs.
//

import Foundation

// MARK: - LogLevel Extension

extension LogLevel {
    var prefix: String {
        return "[\(rawValue.uppercased())]"
    }
}

// MARK: - LoggerService

final class LoggerService {
    static let shared = LoggerService()
    
    private let logDirectoryURL: URL
    private let fileManager = FileManager.default
    private let dateFormatter: ISO8601DateFormatter
    private let fileNameFormatter: DateFormatter
    private let queue = DispatchQueue(label: "com.spacewarp.loggerservice", qos: .utility)
    private let lock = NSLock()
    
    private var currentLogFile: URL?
    private var currentDate: String?
    
    private init() {
        let logsPath = (NSHomeDirectory() as NSString).appendingPathComponent("Library/Logs/SpaceWarp")
        logDirectoryURL = URL(fileURLWithPath: logsPath)
        
        dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withYear, .withMonth, .withDay, .withTime, .withSpaceBetweenDateAndTime]
        
        fileNameFormatter = DateFormatter()
        fileNameFormatter.dateFormat = "yyyy-MM-dd"
        
        createLogDirectoryIfNeeded()
        cleanupOldLogs()
    }
    
    private func createLogDirectoryIfNeeded() {
        if !fileManager.fileExists(atPath: logDirectoryURL.path) {
            try? fileManager.createDirectory(at: logDirectoryURL, withIntermediateDirectories: true)
        }
    }
    
    private func cleanupOldLogs() {
        let calendar = Calendar.current
        let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        
        guard let logFiles = try? fileManager.contentsOfDirectory(at: logDirectoryURL, includingPropertiesForKeys: [.creationDateKey]) else {
            return
        }
        
        for logFile in logFiles where logFile.pathExtension == "log" {
            guard let creationDate = try? logFile.resourceValues(forKeys: [.creationDateKey]).creationDate else {
                continue
            }
            
            if creationDate < sevenDaysAgo {
                try? fileManager.removeItem(at: logFile)
            }
        }
    }
    
    private func getCurrentLogFile() -> URL {
        let todayString = fileNameFormatter.string(from: Date())
        
        lock.lock()
        defer { lock.unlock() }
        
        if currentDate != todayString {
            currentDate = todayString
            currentLogFile = logDirectoryURL.appendingPathComponent("spacewarp-\(todayString).log")
            cleanupOldLogs()
        }
        
        return currentLogFile!
    }
    
    private func writeLog(level: LogLevel, message: String, category: String, file: String, function: String, line: UInt, error: Error? = nil) {
        let fileName = (file as NSString).lastPathComponent
        let timestamp = dateFormatter.string(from: Date())
        
        var logMessage = "\(timestamp) \(level.prefix) [\(fileName):\(function)] [\(category)] \(message)"
        
        if let error = error {
            logMessage += " - Error: \(error.localizedDescription)"
        }
        
        logMessage += "\n"
        
        print(logMessage, terminator: "")
        
        queue.async { [weak self] in
            self?.writeToFile(logMessage)
        }
    }
    
    private func writeToFile(_ message: String) {
        autoreleasepool {
            let logFile = getCurrentLogFile()
            
            guard let data = message.data(using: .utf8) else { return }
            
            if fileManager.fileExists(atPath: logFile.path) {
                if let fileHandle = try? FileHandle(forWritingTo: logFile) {
                    fileHandle.seekToEndOfFile()
                    fileHandle.write(data)
                    try? fileHandle.close()
                }
            } else {
                try? data.write(to: logFile)
            }
        }
    }
    
    func debug(_ message: String, category: String, file: String = #file, function: String = #function, line: UInt = #line) {
        writeLog(level: .debug, message: message, category: category, file: file, function: function, line: line)
    }
    
    func info(_ message: String, category: String, file: String = #file, function: String = #function, line: UInt = #line) {
        writeLog(level: .info, message: message, category: category, file: file, function: function, line: line)
    }
    
    func warning(_ message: String, category: String, file: String = #file, function: String = #function, line: UInt = #line) {
        writeLog(level: .warning, message: message, category: category, file: file, function: function, line: line)
    }
    
    func error(_ message: String, category: String, error: Error? = nil, file: String = #file, function: String = #function, line: UInt = #line) {
        writeLog(level: .error, message: message, category: category, file: file, function: function, line: line, error: error)
    }
    
    func getLogFiles() -> [URL] {
        guard let logFiles = try? fileManager.contentsOfDirectory(at: logDirectoryURL, includingPropertiesForKeys: nil) else {
            return []
        }
        return logFiles.filter { $0.pathExtension == "log" }.sorted(by: { $0.lastPathComponent > $1.lastPathComponent })
    }
    
    func getLogContent(for url: URL) -> String? {
        return try? String(contentsOf: url, encoding: .utf8)
    }
    
    func clearAllLogs() {
        guard let logFiles = try? fileManager.contentsOfDirectory(at: logDirectoryURL, includingPropertiesForKeys: nil) else {
            return
        }
        for logFile in logFiles where logFile.pathExtension == "log" {
            try? fileManager.removeItem(at: logFile)
        }
        lock.lock()
        currentLogFile = nil
        currentDate = nil
        lock.unlock()
    }
}
