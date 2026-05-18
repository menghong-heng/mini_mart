import { useEffect, useState } from 'react'
import { Link } from 'react-router-dom'
import { shopGetMyOrders } from '../api/customerEndpoints'
import { useCustomerAuth } from '../auth/CustomerAuthContext'

const STATUS_COLOR = {
  pending:   'bg-warm-100 text-warm-500',
  confirmed: 'bg-blue-100 text-blue-700',
  shipped:   'bg-purple-100 text-purple-700',
  completed: 'bg-brand-100 text-brand-700',
  cancelled: 'bg-red-100 text-red-700',
}
const STATUS_LABEL = {
  pending: 'Pending', confirmed: 'Confirmed', shipped: 'Shipped', completed: 'Completed', cancelled: 'Cancelled',
}

export default function MyOrders() {
  const { customer, logout } = useCustomerAuth()
  const [orders, setOrders] = useState([])
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    shopGetMyOrders().then(setOrders).catch(() => {}).finally(() => setLoading(false))
  }, [])

  return (
    <div className="min-h-screen bg-cream-50 dark:bg-gray-900 font-sans transition-colors">
      {/* Navbar */}
      <nav className="fixed top-0 w-full z-40 bg-cream-50/80 dark:bg-gray-900/80 backdrop-blur-lg border-b border-cream-200/60 dark:border-gray-800">
        <div className="max-w-7xl mx-auto px-6 py-3 flex items-center justify-between">
          <Link to="/" className="flex items-center gap-2">
            <div className="w-8 h-8 rounded-xl flex items-center justify-center">
              <img src="/logo.svg" alt="67 mini" className="w-8 h-8" />
            </div>
            <span className="font-serif font-bold text-lg text-gray-900 dark:text-white">67 mini mart</span>
          </Link>
          <div className="flex items-center gap-3">
            <span className="text-gray-500 text-sm hidden sm:inline font-medium">{customer?.full_name}</span>
            <button onClick={logout} className="text-sm text-gray-400 hover:text-red-500 transition-colors">Sign out</button>
          </div>
        </div>
      </nav>

      <div className="max-w-4xl mx-auto px-6 pt-24 pb-10">
        {/* Customer profile card */}
        <div className="bg-white rounded-2xl border border-cream-200 shadow-sm p-6 mb-8 flex items-center gap-4 animate-fade-up">
          <div className="w-14 h-14 bg-gradient-to-br from-brand-400 to-brand-600 rounded-2xl flex items-center justify-center shadow-lg shadow-brand-600/20">
            <span className="text-white font-bold text-xl">{customer?.full_name?.[0]?.toUpperCase() ?? '?'}</span>
          </div>
          <div>
            <p className="font-serif font-bold text-lg text-gray-900">{customer?.full_name}</p>
            <p className="text-sm text-gray-500">{customer?.email}</p>
            {customer?.phone && <p className="text-sm text-gray-400">{customer.phone}</p>}
          </div>
        </div>

        <div className="flex items-center justify-between mb-8 animate-fade-up delay-100">
          <div>
            <h1 className="text-2xl font-serif font-bold text-gray-900 dark:text-white">My Orders</h1>
            <p className="text-gray-400 dark:text-gray-500 text-sm mt-1">Your purchase history at 67 mini mart</p>
          </div>
          <Link to="/" className="text-sm btn-primary">Shop more</Link>
        </div>

        {loading ? (
          <div className="text-center py-24 text-gray-400 text-sm animate-pulse-soft">Loading orders…</div>
        ) : orders.length === 0 ? (
          <div className="text-center py-24 animate-fade-up">
            <p className="text-5xl mb-4">🛒</p>
            <p className="text-gray-500 font-medium mb-1">No orders yet</p>
            <p className="text-gray-400 text-sm mb-6">Start shopping and your orders will appear here.</p>
            <Link to="/" className="btn-primary inline-block">Browse products</Link>
          </div>
        ) : (
          <div className="space-y-3">
            {orders.map(o => (
              <div key={o.order_id}
                className="bg-white rounded-2xl border border-cream-200 shadow-sm px-6 py-5 flex items-center justify-between gap-4 hover:shadow-lg hover:-translate-y-0.5 transition-all duration-300">
                <div>
                  <p className="font-semibold text-gray-900">Order #{o.order_id}</p>
                  <p className="text-xs text-gray-400 mt-0.5">{new Date(o.created_at).toLocaleDateString('en-US', { year: 'numeric', month: 'short', day: 'numeric' })}</p>
                </div>
                <div className="flex items-center gap-4">
                  <span className="text-lg font-bold text-gray-900">${Number(o.total_amount).toFixed(2)}</span>
                  <span className={`text-xs px-3 py-1 rounded-full font-medium capitalize ${STATUS_COLOR[o.status] ?? 'bg-gray-100 text-gray-600'}`}>
                    {STATUS_LABEL[o.status] ?? o.status}
                  </span>
                  <span className={`text-xs px-2.5 py-0.5 rounded-full font-medium capitalize ${o.invoice_status === 'paid' ? 'bg-brand-100 text-brand-700' : 'bg-warm-100 text-warm-500'}`}>
                    {o.invoice_status ?? 'No invoice'}
                  </span>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  )
}
