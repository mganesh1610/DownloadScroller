import Foundation

enum SampleLibrary {
    static func create() throws -> URL {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("DownloadScroller Samples", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let named: [(String, String)] = [
            ("Weekend reading list.md", "# Weekend reading\n\nA place for ideas, books, and something unexpected.\n"),
            ("Coastal palette.svg", "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"800\" height=\"600\"><rect width=\"800\" height=\"600\" fill=\"#102c37\"/><circle cx=\"400\" cy=\"300\" r=\"180\" fill=\"#8ce5bf\"/><circle cx=\"490\" cy=\"220\" r=\"90\" fill=\"#edf3d0\"/></svg>"),
            ("Project notes.txt", "Little things, beautifully organized.\n\nThese sample files belong to DownloadScroller.\nChoose your Downloads folder to browse your own files.\n"),
            ("November expenses.csv", "Category,Amount\nCoffee,18\nBooks,42\nTravel,125\n"),
            ("Launch checklist.md", "# Launch checklist\n\n- Build something useful\n- Test the details\n- Share the source\n"),
            ("Interface ideas.json", "{\"theme\": \"coastal\", \"layout\": \"fan\", \"scrollable\": true}\n"),
            ("A very long filename that still deserves a place in your Downloads folder.txt", "Long names are truncated in the fan; hover to read the complete name.\n")
        ]
        let now = Date()
        for index in 0..<240 {
            let sample = index < named.count ? named[index] : ("Reading note \(String(format: "%03d", index + 1)).md", "# Reading note \(index + 1)\n\nA sample file for testing a long, scrollable folder.\n")
            let url = folder.appendingPathComponent(sample.0)
            if !FileManager.default.fileExists(atPath: url.path) {
                try Data(sample.1.utf8).write(to: url)
                try FileManager.default.setAttributes([.creationDate: now.addingTimeInterval(Double(-index * 600)),
                                                      .modificationDate: now.addingTimeInterval(Double(-index * 600))], ofItemAtPath: url.path)
            }
        }
        return folder
    }
}
