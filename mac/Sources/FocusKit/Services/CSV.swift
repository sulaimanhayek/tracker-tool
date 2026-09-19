import Foundation

/// Just enough CSV for one writer and one reader: quoted fields, doubled quotes.
public enum CSV {
    public static func escape(_ field: String) -> String {
        guard field.contains(where: { $0 == "," || $0 == "\"" || $0 == "\n" }) else { return field }
        return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    public static func row(_ fields: [String]) -> String {
        fields.map(escape).joined(separator: ",")
    }

    public static func parse(row: String) -> [String] {
        var fields: [String] = []
        var field = ""
        var inQuotes = false
        let characters = Array(row)
        var index = 0

        while index < characters.count {
            let character = characters[index]
            if inQuotes {
                if character == "\"" {
                    // A doubled quote inside a quoted field is a literal quote.
                    if index + 1 < characters.count, characters[index + 1] == "\"" {
                        field.append("\"")
                        index += 1
                    } else {
                        inQuotes = false
                    }
                } else {
                    field.append(character)
                }
            } else if character == "\"" {
                inQuotes = true
            } else if character == "," {
                fields.append(field)
                field = ""
            } else {
                field.append(character)
            }
            index += 1
        }

        fields.append(field)
        return fields
    }
}
