import { useEffect, useState } from 'react'
import Navbar from '../components/Navbar'
import { useAuth } from '../auth/AuthContext'
import {
  getOrders, createOrder, updateOrderStatus,
  getInvoices, createInvoice, payInvoice,
  getCustomers, getProducts,
} from '../api/endpoints'

const STATUS_COLOR = {
  pending:   'bg-yellow-100 text-yellow-700',
  confirmed: 'bg-blue-100   text-blue-700',
  shipped:   'bg-purple-100 text-purple-700',
  completed: 'bg-green-100  text-green-700',
  cancelled: 'bg-red-100    text-red-700',
}

export default function Orders() {
  const { can } = useAuth()
  const [tab,       setTab]       = useState('orders')
  const [orders,    setOrders]    = useState([])
  const [invoices,  setInvoices]  = useState([])
  const [customers, setCustomers] = useState([])
  const [products,  setProducts]  = useState([])
  const [loading,   setLoading]   = useState(true)
  const [showNew,   setShowNew]   = useState(false)
  const [error,     setError]     = useState(null)

  // New order form state
  const [orderForm, setOrderForm] = useState({ customer_id: '', items: [{ product_id: '', quantity: 1 }] })

  const load = () => {
    setLoading(true)
    Promise.all([getOrders(), getInvoices(), getCustomers(), getProducts(true)])
      .then(([o, inv, c, p]) => { setOrders(o); setInvoices(inv); setCustomers(c); setProducts(p) })
      .catch(() => setError('Failed to load data.'))
      .finally(() => setLoading(false))
  }

  useEffect(() => { load() }, [])

  const addItem = () =>
    setOrderForm(f => ({ ...f, items: [...f.items, { product_id: '', quantity: 1 }] }))

  const removeItem = i =>
    setOrderForm(f => ({ ...f, items: f.items.filter((_, idx) => idx !== i) }))

  const setItem = (i, key, val) =>
    setOrderForm(f => ({
      ...f,
      items: f.items.map((it, idx) => idx === i ? { ...it, [key]: val } : it),
    }))

  const handleCreate = async e => {
    e.preventDefault()
    const payload = {
      customer_id: orderForm.customer_id ? Number(orderForm.customer_id) : null,
      items: orderForm.items
        .filter(it => it.product_id)
        .map(it => ({ product_id: Number(it.product_id), quantity: Number(it.quantity) })),
    }
    if (!payload.items.length) { setError('Add at least one item.'); return }
    try {
      await createOrder(payload)
      setShowNew(false)
      setOrderForm({ customer_id: '', items: [{ product_id: '', quantity: 1 }] })
      load()
    } catch (err) {
      setError(err.response?.data?.detail ?? 'Failed to create order.')
    }
  }

  const handleStatus = async (id, status) => {
    try { await updateOrderStatus(id, status); load() }
    catch (err) { setError(err.response?.data?.detail ?? 'Update failed.') }
  }

  const handleInvoice = async order_id => {
    try { await createInvoice({ order_id, due_days: 14 }); setTab('invoices'); load() }
    catch (err) { setError(err.response?.data?.detail ?? 'Invoice creation failed.') }
  }

  const handlePay = async id => {
    try { await payInvoice(id); load() }
    catch (err) { setError(err.response?.data?.detail ?? 'Payment failed.') }
  }

  return (
    <div className="min-h-screen bg-gray-50">
      <Navbar />
      <div className="max-w-6xl mx-auto px-6 py-10">
        <div className="flex items-center justify-between mb-6">
          <div>
            <h1 className="text-2xl font-bold text-gray-900">Sales</h1>
            <p className="text-gray-400 text-sm mt-0.5">Orders &amp; invoices</p>
          </div>
          {can('sales') && (
            <button onClick={() => setShowNew(true)}
              className="bg-blue-600 hover:bg-blue-700 text-white text-sm px-4 py-2 rounded-lg font-medium transition-colors">
              + New order
            </button>
          )}
        </div>

        {error && (
          <div className="bg-red-50 border border-red-200 rounded-lg px-4 py-2 mb-4 flex justify-between items-center">
            <p className="text-red-600 text-sm">{error}</p>
            <button onClick={() => setError(null)} className="text-red-400 hover:text-red-600 text-xs">✕</button>
          </div>
        )}

        {/* Tabs */}
        <div className="flex gap-2 mb-4">
          {['orders', 'invoices'].map(t => (
            <button key={t} onClick={() => setTab(t)}
              className={`text-sm px-3 py-1.5 rounded-lg font-medium capitalize transition-colors ${
                tab === t ? 'bg-blue-600 text-white' : 'bg-white border border-gray-300 text-gray-600 hover:bg-gray-50'
              }`}>
              {t}
            </button>
          ))}
        </div>

        {loading ? (
          <div className="text-center py-20 text-gray-400 text-sm">Loading…</div>
        ) : tab === 'orders' ? (
          <div className="bg-white rounded-xl border border-gray-200 shadow-sm overflow-hidden">
            <table className="w-full text-sm">
              <thead className="bg-gray-50 border-b border-gray-200">
                <tr>
                  <th className="text-left px-4 py-3 font-medium text-gray-500">Order #</th>
                  <th className="text-left px-4 py-3 font-medium text-gray-500">Customer</th>
                  <th className="text-left px-4 py-3 font-medium text-gray-500">By</th>
                  <th className="text-right px-4 py-3 font-medium text-gray-500">Total</th>
                  <th className="text-left px-4 py-3 font-medium text-gray-500">Status</th>
                  <th className="text-left px-4 py-3 font-medium text-gray-500">Date</th>
                  {can('sales') && <th className="px-4 py-3" />}
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-100">
                {orders.map(o => (
                  <tr key={o.order_id} className="hover:bg-gray-50">
                    <td className="px-4 py-3 font-mono text-gray-700">#{o.order_id}</td>
                    <td className="px-4 py-3 text-gray-600">{o.customer ?? '—'}</td>
                    <td className="px-4 py-3 text-gray-500">{o.processed_by}</td>
                    <td className="px-4 py-3 text-right font-semibold">${Number(o.total_amount).toFixed(2)}</td>
                    <td className="px-4 py-3">
                      <span className={`text-xs px-2 py-0.5 rounded-full font-medium ${STATUS_COLOR[o.status] ?? 'bg-gray-100 text-gray-600'}`}>
                        {o.status}
                      </span>
                    </td>
                    <td className="px-4 py-3 text-gray-400 text-xs">
                      {new Date(o.created_at).toLocaleDateString()}
                    </td>
                    {can('sales') && (
                      <td className="px-4 py-3 text-right">
                        <div className="flex justify-end gap-2 flex-wrap">
                          {o.status === 'pending'   && <button onClick={() => handleStatus(o.order_id, 'confirmed')} className="text-xs text-blue-600 hover:underline">Confirm</button>}
                          {o.status === 'confirmed' && <button onClick={() => handleStatus(o.order_id, 'shipped')}   className="text-xs text-blue-600 hover:underline">Ship</button>}
                          {o.status === 'shipped'   && <button onClick={() => handleStatus(o.order_id, 'completed')} className="text-xs text-green-600 hover:underline">Complete</button>}
                          {(o.status === 'pending' || o.status === 'confirmed') && (
                            <button onClick={() => handleStatus(o.order_id, 'cancelled')} className="text-xs text-red-500 hover:underline">Cancel</button>
                          )}
                          {o.status === 'confirmed' && (
                            <button onClick={() => handleInvoice(o.order_id)} className="text-xs text-purple-600 hover:underline">Invoice</button>
                          )}
                        </div>
                      </td>
                    )}
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        ) : (
          <div className="bg-white rounded-xl border border-gray-200 shadow-sm overflow-hidden">
            <table className="w-full text-sm">
              <thead className="bg-gray-50 border-b border-gray-200">
                <tr>
                  <th className="text-left px-4 py-3 font-medium text-gray-500">Invoice #</th>
                  <th className="text-left px-4 py-3 font-medium text-gray-500">Order #</th>
                  <th className="text-left px-4 py-3 font-medium text-gray-500">Customer</th>
                  <th className="text-right px-4 py-3 font-medium text-gray-500">Total</th>
                  <th className="text-left px-4 py-3 font-medium text-gray-500">Status</th>
                  <th className="text-left px-4 py-3 font-medium text-gray-500">Issued</th>
                  {can('sales') && <th className="px-4 py-3" />}
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-100">
                {invoices.map(inv => (
                  <tr key={inv.invoice_id} className="hover:bg-gray-50">
                    <td className="px-4 py-3 font-mono text-gray-700">#{inv.invoice_id}</td>
                    <td className="px-4 py-3 font-mono text-gray-500">#{inv.order_id}</td>
                    <td className="px-4 py-3 text-gray-600">{inv.customer ?? '—'}</td>
                    <td className="px-4 py-3 text-right font-semibold">${Number(inv.total_amount).toFixed(2)}</td>
                    <td className="px-4 py-3">
                      <span className={`text-xs px-2 py-0.5 rounded-full font-medium ${
                        inv.status === 'paid' ? 'bg-green-100 text-green-700' :
                        inv.status === 'overdue' ? 'bg-red-100 text-red-700' :
                        'bg-yellow-100 text-yellow-700'
                      }`}>
                        {inv.status}
                      </span>
                    </td>
                    <td className="px-4 py-3 text-gray-400 text-xs">
                      {new Date(inv.issued_at).toLocaleDateString()}
                    </td>
                    {can('sales') && (
                      <td className="px-4 py-3 text-right">
                        {inv.status === 'unpaid' && (
                          <button onClick={() => handlePay(inv.invoice_id)}
                            className="text-xs text-green-600 hover:underline">Mark paid</button>
                        )}
                      </td>
                    )}
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>

      {/* New order modal */}
      {showNew && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 px-4">
          <div className="bg-white rounded-2xl shadow-xl p-6 w-full max-w-lg max-h-[90vh] overflow-y-auto">
            <h2 className="text-lg font-bold text-gray-900 mb-4">New order</h2>
            <form onSubmit={handleCreate} className="space-y-4">
              <div>
                <label className="block text-xs font-medium text-gray-500 mb-1">Customer (optional)</label>
                <select value={orderForm.customer_id}
                  onChange={e => setOrderForm(f => ({ ...f, customer_id: e.target.value }))}
                  className="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500">
                  <option value="">Walk-in / no customer</option>
                  {customers.map(c => <option key={c.customer_id} value={c.customer_id}>{c.name}</option>)}
                </select>
              </div>

              <div>
                <label className="block text-xs font-medium text-gray-500 mb-2">Items</label>
                {orderForm.items.map((it, i) => (
                  <div key={i} className="flex gap-2 mb-2">
                    <select required value={it.product_id}
                      onChange={e => setItem(i, 'product_id', e.target.value)}
                      className="flex-1 border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500">
                      <option value="">Select product</option>
                      {products.map(p => <option key={p.product_id} value={p.product_id}>{p.name} — ${Number(p.price).toFixed(2)}</option>)}
                    </select>
                    <input type="number" min="1" value={it.quantity}
                      onChange={e => setItem(i, 'quantity', e.target.value)}
                      className="w-20 border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500" />
                    {orderForm.items.length > 1 && (
                      <button type="button" onClick={() => removeItem(i)}
                        className="text-red-400 hover:text-red-600 px-2">✕</button>
                    )}
                  </div>
                ))}
                <button type="button" onClick={addItem}
                  className="text-sm text-blue-600 hover:underline mt-1">+ Add item</button>
              </div>

              <div className="flex gap-2 pt-2">
                <button type="button" onClick={() => setShowNew(false)}
                  className="flex-1 border border-gray-300 rounded-lg py-2 text-sm text-gray-600 hover:bg-gray-50">
                  Cancel
                </button>
                <button type="submit"
                  className="flex-1 bg-blue-600 hover:bg-blue-700 text-white rounded-lg py-2 text-sm font-medium">
                  Create order
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  )
}
