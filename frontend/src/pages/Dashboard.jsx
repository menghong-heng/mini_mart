import { useEffect, useState } from 'react'
import { Link } from 'react-router-dom'
import Navbar from '../components/Navbar'
import { useAuth } from '../auth/AuthContext'
import { getDashboardActivity, getSummary } from '../api/endpoints'

const ACTIVITY_META = {
  signup:  { icon: '👤', label: 'New customer', tag: 'bg-brand-100 text-brand-700' },
  order:   { icon: '🧾', label: 'New order',    tag: 'bg-blue-100 text-blue-700' },
  invoice: { icon: '💳', label: 'New invoice',  tag: 'bg-purple-100 text-purple-700' },
}

function formatActivityTime(iso) {
  const ts = new Date(iso)
  const diffSec = Math.round((Date.now() - ts.getTime()) / 1000)
  if (diffSec < 60)    return `${diffSec}s ago`
  if (diffSec < 3600)  return `${Math.floor(diffSec / 60)}m ago`
  if (diffSec < 86400) return `${Math.floor(diffSec / 3600)}h ago`
  return ts.toLocaleDateString('en-US', { month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' })
}

const MODULE_INFO = [
  { key: 'admin', label: 'Admin',  desc: 'Users, audit logs, system config', to: '/staff/users',    icon: '🔐', gradient: 'from-purple-500/10 to-purple-600/5', border: 'border-purple-200/60', badge: 'bg-purple-100 text-purple-700', btn: 'text-purple-500' },
  { key: 'sales', label: 'Sales',  desc: 'Orders, invoices, customers',       to: '/staff/orders',   icon: '🧾', gradient: 'from-blue-500/10 to-blue-600/5',   border: 'border-blue-200/60',   badge: 'bg-blue-100 text-blue-700',     btn: 'text-blue-500' },
  { key: 'stock', label: 'Stock',  desc: 'Products, inventory, suppliers',    to: '/staff/products', icon: '📦', gradient: 'from-brand-500/10 to-brand-600/5', border: 'border-brand-200/60', badge: 'bg-brand-100 text-brand-700',   btn: 'text-brand-500' },
  { key: 'view',  label: 'View',   desc: 'Read access across all data',       to: '/staff/products', icon: '👁',  gradient: 'from-gray-500/10 to-gray-600/5',   border: 'border-gray-200/60',   badge: 'bg-gray-100 text-gray-600',     btn: 'text-gray-500' },
]

const ROLE_TAG = {
  Admin:   'bg-purple-500/10 text-purple-400 border border-purple-500/20',
  Sales:   'bg-blue-500/10 text-blue-400 border border-blue-500/20',
  Cashier: 'bg-brand-500/10 text-brand-400 border border-brand-500/20',
  User:    'bg-gray-500/10 text-gray-400 border border-gray-500/20',
}

export default function Dashboard() {
  const { user, permissions, can } = useAuth()
  const [summary, setSummary] = useState(null)
  const [activity, setActivity] = useState([])
  const [activityLoading, setActivityLoading] = useState(true)

  useEffect(() => {
    if (can('admin')) getSummary().then(setSummary).catch(() => {})
  }, [can])

  useEffect(() => {
    let cancelled = false
    const load = () =>
      getDashboardActivity()
        .then(rows => { if (!cancelled) setActivity(rows) })
        .catch(() => {})
        .finally(() => { if (!cancelled) setActivityLoading(false) })
    load()
    const id = setInterval(load, 30_000)
    return () => { cancelled = true; clearInterval(id) }
  }, [])

  return (
    <div className="min-h-screen bg-gray-950 font-sans">
      <Navbar />
      <div className="max-w-5xl mx-auto px-6 py-10">
        {/* Welcome */}
        <div className="flex items-center justify-between mb-10">
          <div>
            <h1 className="text-3xl font-serif font-bold text-white">Welcome back, {user?.username}</h1>
            <p className="text-gray-500 dark:text-gray-400 text-sm mt-2">67 mini mart Staff Portal — here's your access summary</p>
          </div>
          <span className={`text-sm px-4 py-2 rounded-xl font-semibold ${ROLE_TAG[user?.role] ?? 'bg-gray-500/10 text-gray-400'}`}>
            {user?.role}
          </span>
        </div>

        {/* Module Access */}
        <h2 className="text-xs font-semibold text-gray-600 uppercase tracking-widest mb-4">Module Access</h2>
        <div className="grid grid-cols-1 sm:grid-cols-2 gap-4 mb-12">
          {MODULE_INFO.map(({ key, label, desc, to, icon, gradient, border, badge, btn }) => {
            const allowed = permissions[key]
            return (
              <div key={key}
                className={`rounded-2xl border p-5 transition-all duration-300 ${
                  allowed ? `bg-gradient-to-br ${gradient} ${border} hover:scale-[1.02] hover:shadow-lg` : 'border-white/5 bg-white/[0.02] opacity-40'
                }`}>
                <div className="flex items-start justify-between mb-3">
                  <div className="flex items-center gap-2.5">
                    <span className="text-2xl">{icon}</span>
                    <span className="font-semibold text-white">{label}</span>
                  </div>
                  <span className={`text-xs px-2.5 py-1 rounded-full font-medium ${allowed ? badge : 'bg-gray-800 text-gray-600'}`}>
                    {allowed ? 'Allowed' : 'Blocked'}
                  </span>
                </div>
                <p className="text-xs text-gray-500 mb-3">{desc}</p>
                {allowed && (
                  <Link to={to} className={`text-xs font-semibold hover:underline ${btn}`}>Open →</Link>
                )}
              </div>
            )
          })}
        </div>

        {/* Recent Activity */}
        <h2 className="text-xs font-semibold text-gray-600 uppercase tracking-widest mb-4">Recent Activity</h2>
        <div className="glass-dark rounded-2xl mb-12">
          {activityLoading ? (
            <p className="text-center text-gray-600 text-sm py-10 animate-pulse-soft">Loading activity…</p>
          ) : activity.length === 0 ? (
            <p className="text-center text-gray-600 text-sm py-10">No recent activity</p>
          ) : (
            <ul className="divide-y divide-white/5">
              {activity.map(a => {
                const meta = ACTIVITY_META[a.type] ?? { icon: '•', label: a.type, tag: 'bg-gray-800 text-gray-400' }
                return (
                  <li key={`${a.type}-${a.record_id}`} className="flex items-center gap-3 px-5 py-3.5 hover:bg-white/[0.02] transition-colors">
                    <span className="text-xl shrink-0">{meta.icon}</span>
                    <span className={`text-[10px] uppercase tracking-wider px-2 py-0.5 rounded-full font-semibold shrink-0 ${meta.tag}`}>{meta.label}</span>
                    <span className="text-sm text-gray-300 truncate flex-1">{a.label}</span>
                    <span className="text-xs text-gray-600 shrink-0">{formatActivityTime(a.created_at)}</span>
                  </li>
                )
              })}
            </ul>
          )}
        </div>

        {/* Store Snapshot */}
        {can('admin') && summary && (
          <>
            <h2 className="text-xs font-semibold text-gray-600 uppercase tracking-widest mb-4">Store Snapshot</h2>
            <div className="grid grid-cols-2 sm:grid-cols-5 gap-3">
              {summary.map(({ metric, value }) => (
                <div key={metric} className="glass-dark rounded-2xl p-5 text-center hover:scale-105 transition-transform duration-300">
                  <p className="text-3xl font-bold text-white">{value}</p>
                  <p className="text-xs text-gray-500 mt-1.5">{metric}</p>
                </div>
              ))}
            </div>
          </>
        )}
      </div>
    </div>
  )
}
