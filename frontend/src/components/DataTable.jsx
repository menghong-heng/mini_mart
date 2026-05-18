/**
 * Generic table component.
 *
 * Props:
 *   columns  — [{ key, label, render? }]
 *              `render(value, row)` is optional — defaults to String(value)
 *   data     — array of row objects
 *   emptyMessage — shown when data is empty
 */
export default function DataTable({ columns, data, emptyMessage = 'No records found.' }) {
  if (!data || data.length === 0) {
    return (
      <p className="text-gray-400 text-sm py-6 text-center">{emptyMessage}</p>
    )
  }

  return (
    <div className="overflow-x-auto rounded-lg border border-gray-200">
      <table className="min-w-full text-sm">
        <thead className="bg-gray-100">
          <tr>
            {columns.map(col => (
              <th
                key={col.key}
                className="px-4 py-2 text-left text-xs font-semibold text-gray-600 uppercase tracking-wide"
              >
                {col.label}
              </th>
            ))}
          </tr>
        </thead>
        <tbody className="divide-y divide-gray-100 bg-white">
          {data.map((row, i) => (
            <tr key={i} className="hover:bg-gray-50 transition-colors">
              {columns.map(col => (
                <td key={col.key} className="px-4 py-2 text-gray-700">
                  {col.render
                    ? col.render(row[col.key], row)
                    : row[col.key] != null
                      ? String(row[col.key])
                      : <span className="text-gray-300">—</span>
                  }
                </td>
              ))}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  )
}
