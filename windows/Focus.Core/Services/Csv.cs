namespace Focus.Core;

/// Just enough CSV for one writer and one reader: quoted fields, doubled quotes.
public static class Csv
{
    public static string Escape(string field) =>
        field.Any(c => c is ',' or '"' or '\n')
            ? "\"" + field.Replace("\"", "\"\"") + "\""
            : field;

    public static string Row(IEnumerable<string> fields) =>
        string.Join(",", fields.Select(Escape));

    public static List<string> Parse(string row)
    {
        var fields = new List<string>();
        var field = new System.Text.StringBuilder();
        var inQuotes = false;

        for (var i = 0; i < row.Length; i++)
        {
            var c = row[i];
            if (inQuotes)
            {
                if (c == '"')
                {
                    // A doubled quote inside a quoted field is a literal quote.
                    if (i + 1 < row.Length && row[i + 1] == '"') { field.Append('"'); i++; }
                    else inQuotes = false;
                }
                else field.Append(c);
            }
            else if (c == '"') inQuotes = true;
            else if (c == ',') { fields.Add(field.ToString()); field.Clear(); }
            else field.Append(c);
        }

        fields.Add(field.ToString());
        return fields;
    }
}
