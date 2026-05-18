import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { useAuth } from '../auth/AuthContext'

const DEMO_ACCOUNTS = [
  { label: 'Admin',   username: 'admin_user', password: 'Admin@1234', icon: '🔐', color: 'from-purple-500/10 to-purple-600/5', border: 'border-purple-200/60', badge: 'bg-purple-100 text-purple-700' },
  { label: 'Sales',   username: 'sales_mgr',  password: 'Sales@1234', icon: '🧾', color: 'from-blue-500/10 to-blue-600/5',   border: 'border-blue-200/60',   badge: 'bg-blue-100 text-blue-700' },
  { label: 'Cashier', username: 'cashier_01', password: 'Cash@1234',  icon: '💳', color: 'from-brand-500/10 to-brand-600/5', border: 'border-brand-200/60', badge: 'bg-brand-100 text-brand-700' },
  { label: 'User',    username: 'user_01',    password: 'User@1234',  icon: '👁',  color: 'from-gray-500/10 to-gray-600/5',   border: 'border-gray-200/60',   badge: 'bg-gray-100 text-gray-600' },
]

export default function StaffLogin() {
  const { login } = useAuth()
  const navigate = useNavigate()
  const [username, setUsername] = useState('')
  const [password, setPassword] = useState('')
  const [error, setError] = useState(null)
  const [loading, setLoading] = useState(false)

  const doLogin = async (u, p) => {
    setError(null)
    setLoading(true)
    try {
      await login(u, p)
      navigate('/staff/dashboard')
    } catch (err) {
      setError(err.response?.data?.detail ?? 'Login failed — check username and password.')
    } finally { setLoading(false) }
  }

  const handleSubmit = e => { e.preventDefault(); doLogin(username, password) }

  return (
    <div className="min-h-screen bg-gradient-to-br from-gray-950 via-gray-900 to-gray-950 flex items-center justify-center px-4 font-sans relative overflow-hidden">
      {/* Ambient blobs */}
      <div className="absolute top-20 left-20 w-96 h-96 bg-brand-600/10 rounded-full blur-3xl" />
      <div className="absolute bottom-20 right-20 w-80 h-80 bg-purple-600/10 rounded-full blur-3xl" />

      <div className="relative z-10 w-full max-w-md animate-fade-up">
        <div className="glass-dark rounded-3xl p-8 shadow-2xl">
          {/* Header */}
          <div className="flex items-center gap-3 mb-8">
            <div className="w-14 h-14 rounded-2xl flex items-center justify-center">
              <img src="/logo.svg" alt="67 mini" className="w-14 h-14" />
            </div>
            <div>
              <h1 className="text-xl font-serif font-bold text-white leading-tight">Staff Portal</h1>
              <p className="text-gray-500 text-xs mt-0.5">Authorized personnel only</p>
            </div>
          </div>

          {/* Login form */}
          <form onSubmit={handleSubmit} className="space-y-4 mb-8">
            <div>
              <label className="block text-sm font-medium text-gray-400 mb-1.5">Username</label>
              <input type="text" value={username} onChange={e => setUsername(e.target.value)}
                placeholder="Enter your username" required
                className="w-full bg-white/5 border border-white/10 rounded-xl px-4 py-3 text-sm text-white placeholder-gray-600 focus:outline-none focus:ring-2 focus:ring-brand-500/40 focus:border-brand-500/40 transition-all" />
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-400 mb-1.5">Password</label>
              <input type="password" value={password} onChange={e => setPassword(e.target.value)}
                placeholder="••••••••" required
                className="w-full bg-white/5 border border-white/10 rounded-xl px-4 py-3 text-sm text-white placeholder-gray-600 focus:outline-none focus:ring-2 focus:ring-brand-500/40 focus:border-brand-500/40 transition-all" />
            </div>
            {error && (
              <div className="bg-red-500/10 border border-red-500/20 rounded-xl px-4 py-3">
                <p className="text-red-400 text-sm">{error}</p>
              </div>
            )}
            <button type="submit" disabled={loading}
              className="w-full bg-gradient-to-r from-brand-600 to-brand-500 hover:from-brand-700 hover:to-brand-600 disabled:opacity-50 text-white py-3 rounded-xl text-sm font-semibold transition-all duration-300 shadow-lg shadow-brand-600/25 hover:shadow-brand-600/40">
              {loading ? 'Signing in…' : 'Sign in'}
            </button>
          </form>

          {/* Quick-login */}
          <div>
            <div className="flex items-center gap-3 mb-4">
              <div className="flex-1 h-px bg-white/10" />
              <span className="text-xs text-gray-600">Quick login for demo</span>
              <div className="flex-1 h-px bg-white/10" />
            </div>
            <div className="grid grid-cols-2 gap-2">
              {DEMO_ACCOUNTS.map(acc => (
                <button key={acc.label} onClick={() => doLogin(acc.username, acc.password)} disabled={loading}
                  className={`bg-gradient-to-br ${acc.color} border ${acc.border} rounded-xl px-3 py-3 text-left disabled:opacity-50 transition-all duration-300 hover:scale-[1.02] hover:shadow-lg`}>
                  <div className="flex items-center justify-between mb-1">
                    <span className="text-lg">{acc.icon}</span>
                    <span className={`text-[10px] px-2 py-0.5 rounded-full font-semibold ${acc.badge}`}>{acc.label}</span>
                  </div>
                  <p className="text-sm font-semibold text-white">{acc.label}</p>
                  <p className="text-xs text-gray-500">{acc.username}</p>
                </button>
              ))}
            </div>
            <p className="text-xs text-gray-600 text-center mt-4">No self-registration — accounts provisioned by admin only</p>
          </div>
        </div>
      </div>
    </div>
  )
}
