import { useEffect, useState } from 'react'
import Navbar from '../components/Navbar'
import { getAuditLogs } from '../api/endpoints'

const ACTION_COLOR = {
  LOGIN:   'bg-blue-100   text-blue-700',
  LOGOUT:  'bg-gray-100   text-gray-600',
  CLEANUP: 'bg-yellow-100 text-yellow-700',
  INSERT:  'bg-green-100  text-green-700',
  UPDATE:  'bg-orange-100 text-orange-700',
  DELETE:  'bg-red-100    text-red-700',
}

const ACTIONS = ['', 'LOGIN', 'LOGOUT', 'INSERT', 'UPDATE', 'DELETE', 'CLEANUP']

export default function AuditLogs() {
  const [logs,    setLogs]    = useState([])
  const [loading, setLoading] = useState(true)
  const [filter,  setFilter]  = useState('')
  const [error,   setError]   = useState(null)

  const load = (action = '') => {
    setLoading(true)
    getAuditLogs(action || undefined)
      .then(setLogs)
      .catch(() => setError('Failed to load audit logs.'))
      .finally(() => setLoading(false))
  }

  useEffect(() => { load() }, [])

  const handleFilter = val => {
    setFilter(val)
    load(val)
  }

  return (
    <div className="min-h-screen bg-gray-50">
      <Navbar />
      <div className="max-w-6xl mx-auto px-6 py-10">
        <div className="flex items-center justify-between mb-6">
          <div>
            <h1 className="text-2xl font-bold text-gray-900">Audit Logs</h1>
            <p className="text-gray-400 text-sm mt-0.5">All system actions — {logs.length} records</p>
          </div>
          <select value={filter} onChange={e => handleFilter(e.target.value)}
            className="border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500">
            {ACTIONS.map(a => <option key={a} value={a}>{a || 'All actions'}</option>)}
          </select>
        </div>

        {error && (
          <div className="bg-red-50 border border-red-200 rounded-lg px-4 py-2 mb-4 flex justify-between items-center">
            <p className="text-red-600 text-sm">{error}</p>
            <button onClick={() => setError(null)} className="text-red-400 hover:text-red-600 text-xs">✕</button>
          </div>
        )}

        {loading ? (
          <div className="text-center py-20 text-gray-400 text-sm">Loading…</div>
        ) : (
          <div className="bg-white rounded-xl border border-gray-200 shadow-sm overflow-hidden">
            <table className="w-full text-sm">
              <thead className="bg-gray-50 border-b border-gray-200">
                <tr>
                  <th className="text-left px-4 py-3 font-medium text-gray-500">ID</th>
                  <th className="text-left px-4 py-3 font-medium text-gray-500">Actor</th>
                  <th className="text-left px-4 py-3 font-medium text-gray-500">Action</th>
                  <th className="text-left px-4 py-3 font-medium text-gray-500">Table</th>
                  <th className="text-left px-4 py-3 font-medium text-gray-500">Record</th>
                  <th className="text-left px-4 py-3 font-medium text-gray-500">IP</th>
                  <th className="text-left px-4 py-3 font-medium text-gray-500">Time</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-100">
                {logs.map(log => (
                  <tr key={log.log_id} className="hover:bg-gray-50">
                    <td className="px-4 py-2.5 font-mono text-gray-400 text-xs">{log.log_id}</td>
                    <td className="px-4 py-2.5 font-medium text-gray-800">{log.actor ?? 'system'}</td>
                    <td className="px-4 py-2.5">
                      <span className={`text-xs px-2 py-0.5 rounded-full font-medium ${
                        ACTION_COLOR[log.action] ?? 'bg-gray-100 text-gray-600'
                      }`}>
                        {log.action}
                      </span>
                    </td>
                    <td className="px-4 py-2.5 font-mono text-gray-500 text-xs">{log.table_affected ?? '—'}</td>
                    <td className="px-4 py-2.5 text-gray-500 text-xs">{log.record_id ?? '—'}</td>
                    <td className="px-4 py-2.5 text-gray-400 text-xs">{log.ip_address ?? '—'}</td>
                    <td className="px-4 py-2.5 text-gray-400 text-xs whitespace-nowrap">
                      {new Date(log.timestamp).toLocaleString()}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </div>
  )
}
