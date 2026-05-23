import { useEffect, useState } from 'react'
import Navbar from '../components/Navbar'
import {
  getUsers, createUser, updateUserRole, toggleUserActive, getRoles,
} from '../api/endpoints'

export default function Users() {
  const [users,   setUsers]   = useState([])
  const [roles,   setRoles]   = useState([])
  const [loading, setLoading] = useState(true)
  const [showAdd, setShowAdd] = useState(false)
  const [addForm, setAddForm] = useState({ username: '', password: '', role_name: '' })
  const [error,   setError]   = useState(null)

  const load = () => {
    setLoading(true)
    Promise.all([getUsers(), getRoles()])
      .then(([u, r]) => { setUsers(u); setRoles(r) })
      .catch(() => setError('Failed to load users.'))
      .finally(() => setLoading(false))
  }

  useEffect(() => { load() }, [])

  const handleAdd = async e => {
    e.preventDefault()
    try {
      await createUser(addForm)
      setShowAdd(false)
      setAddForm({ username: '', password: '', role_name: '' })
      load()
    } catch (err) {
      setError(err.response?.data?.detail ?? 'Failed to create user.')
    }
  }

  const handleRole = async (id, role_name) => {
    try { await updateUserRole(id, role_name); load() }
    catch (err) { setError(err.response?.data?.detail ?? 'Role update failed.') }
  }

  const handleToggle = async (id, is_active) => {
    try { await toggleUserActive(id, !is_active); load() }
    catch (err) { setError(err.response?.data?.detail ?? 'Toggle failed.') }
  }

  const ROLE_COLOR = {
    Admin:   'bg-purple-100 text-purple-700',
    Sales:   'bg-blue-100   text-blue-700',
    Cashier: 'bg-green-100  text-green-700',
    User:    'bg-gray-100   text-gray-600',
  }

  return (
    <div className="min-h-screen bg-gray-50">
      <Navbar />
      <div className="max-w-5xl mx-auto px-6 py-10">
        <div className="flex items-center justify-between mb-6">
          <div>
            <h1 className="text-2xl font-bold text-gray-900">Users</h1>
            <p className="text-gray-400 text-sm mt-0.5">Staff account management</p>
          </div>
          <button onClick={() => setShowAdd(true)}
            className="bg-blue-600 hover:bg-blue-700 text-white text-sm px-4 py-2 rounded-lg font-medium transition-colors">
            + Add user
          </button>
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
                  <th className="text-left px-4 py-3 font-medium text-gray-500">Username</th>
                  <th className="text-left px-4 py-3 font-medium text-gray-500">Role</th>
                  <th className="text-left px-4 py-3 font-medium text-gray-500">Status</th>
                  <th className="text-left px-4 py-3 font-medium text-gray-500">Last login</th>
                  <th className="px-4 py-3" />
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-100">
                {users.map(u => (
                  <tr key={u.user_id} className="hover:bg-gray-50">
                    <td className="px-4 py-3 font-medium text-gray-900">{u.username}</td>
                    <td className="px-4 py-3">
                      <select value={u.role_name}
                        onChange={e => handleRole(u.user_id, e.target.value)}
                        className={`text-xs font-medium px-2 py-1 rounded-full border-0 cursor-pointer focus:outline-none focus:ring-2 focus:ring-blue-500
                          ${ROLE_COLOR[u.role_name] ?? 'bg-gray-100 text-gray-600'}`}>
                        {roles.map(r => <option key={r.role_id} value={r.role_name}>{r.role_name}</option>)}
                      </select>
                    </td>
                    <td className="px-4 py-3">
                      <span className={`text-xs px-2 py-0.5 rounded-full font-medium ${
                        u.is_active ? 'bg-green-100 text-green-700' : 'bg-gray-100 text-gray-500'
                      }`}>
                        {u.is_active ? 'Active' : 'Disabled'}
                      </span>
                    </td>
                    <td className="px-4 py-3 text-gray-400 text-xs">
                      {u.last_login ? new Date(u.last_login).toLocaleString() : 'never'}
                    </td>
                    <td className="px-4 py-3 text-right">
                      <button
                        onClick={() => handleToggle(u.user_id, u.is_active)}
                        className={`text-xs hover:underline ${u.is_active ? 'text-red-500' : 'text-green-600'}`}>
                        {u.is_active ? 'Disable' : 'Enable'}
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>

      {/* Add user modal */}
      {showAdd && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 px-4">
          <div className="bg-white rounded-2xl shadow-xl p-6 w-full max-w-sm">
            <h2 className="text-lg font-bold text-gray-900 mb-4">Add staff user</h2>
            <form onSubmit={handleAdd} className="space-y-3">
              <input required placeholder="Username" value={addForm.username}
                onChange={e => setAddForm(f => ({ ...f, username: e.target.value }))}
                className="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500" />
              <input required type="password" placeholder="Password (min 6 chars)" minLength={6}
                value={addForm.password}
                onChange={e => setAddForm(f => ({ ...f, password: e.target.value }))}
                className="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500" />
              <select required value={addForm.role_name}
                onChange={e => setAddForm(f => ({ ...f, role_name: e.target.value }))}
                className="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500">
                <option value="">Select role</option>
                {roles.map(r => <option key={r.role_id} value={r.role_name}>{r.role_name}</option>)}
              </select>
              <div className="flex gap-2 pt-2">
                <button type="button" onClick={() => setShowAdd(false)}
                  className="flex-1 border border-gray-300 rounded-lg py-2 text-sm text-gray-600 hover:bg-gray-50">
                  Cancel
                </button>
                <button type="submit"
                  className="flex-1 bg-blue-600 hover:bg-blue-700 text-white rounded-lg py-2 text-sm font-medium">
                  Create
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  )
}
