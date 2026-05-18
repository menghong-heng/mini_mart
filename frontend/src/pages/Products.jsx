import { useEffect, useState } from 'react'
import Navbar from '../components/Navbar'
import { useAuth } from '../auth/AuthContext'
import {
  getProducts, getLowStock, createProduct,
  restockProduct, discontinueProduct, getCategories, getSuppliers,
} from '../api/endpoints'

export default function Products() {
  const { can } = useAuth()
  const [products,   setProducts]   = useState([])
  const [lowStock,   setLowStock]   = useState([])
  const [categories, setCategories] = useState([])
  const [suppliers,  setSuppliers]  = useState([])
  const [loading,    setLoading]    = useState(true)
  const [tab,        setTab]        = useState('all')
  const [showAdd,    setShowAdd]    = useState(false)
  const [addForm,    setAddForm]    = useState({ name: '', category_id: '', price: '', stock_qty: 0, supplier_id: '' })
  const [restockId,  setRestockId]  = useState(null)
  const [addQty,     setAddQty]     = useState(1)
  const [error,      setError]      = useState(null)

  const load = () => {
    setLoading(true)
    Promise.all([getProducts(false), getLowStock(100), getCategories(), getSuppliers()])
      .then(([p, ls, cats, sups]) => {
        setProducts(p)
        setLowStock(ls)
        setCategories(cats)
        setSuppliers(sups)
      })
      .catch(() => setError('Failed to load products.'))
      .finally(() => setLoading(false))
  }

  useEffect(() => { load() }, [])

  const handleAdd = async e => {
    e.preventDefault()
    try {
      await createProduct({
        name: addForm.name,
        category_id: addForm.category_id ? Number(addForm.category_id) : null,
        price: Number(addForm.price),
        stock_qty: Number(addForm.stock_qty),
        supplier_id: addForm.supplier_id ? Number(addForm.supplier_id) : null,
      })
      setShowAdd(false)
      setAddForm({ name: '', category_id: '', price: '', stock_qty: 0, supplier_id: '' })
      load()
    } catch (err) {
      setError(err.response?.data?.detail ?? 'Failed to add product.')
    }
  }

  const handleRestock = async e => {
    e.preventDefault()
    try {
      await restockProduct(restockId, Number(addQty))
      setRestockId(null)
      setAddQty(1)
      load()
    } catch (err) {
      setError(err.response?.data?.detail ?? 'Restock failed.')
    }
  }

  const handleDiscontinue = async id => {
    if (!window.confirm('Mark this product as discontinued?')) return
    try {
      await discontinueProduct(id)
      load()
    } catch (err) {
      setError(err.response?.data?.detail ?? 'Action failed.')
    }
  }

  const list = tab === 'low' ? lowStock : products

  return (
    <div className="min-h-screen bg-gray-50">
      <Navbar />
      <div className="max-w-6xl mx-auto px-6 py-10">
        <div className="flex items-center justify-between mb-6">
          <div>
            <h1 className="text-2xl font-bold text-gray-900">Products</h1>
            <p className="text-gray-400 text-sm mt-0.5">67 mini mart inventory management</p>
          </div>
          {can('stock') && (
            <button onClick={() => setShowAdd(true)}
              className="bg-blue-600 hover:bg-blue-700 text-white text-sm px-4 py-2 rounded-lg font-medium transition-colors">
              + Add product
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
          {['all', 'low'].map(t => (
            <button key={t} onClick={() => setTab(t)}
              className={`text-sm px-3 py-1.5 rounded-lg font-medium transition-colors ${
                tab === t ? 'bg-blue-600 text-white' : 'bg-white border border-gray-300 text-gray-600 hover:bg-gray-50'
              }`}>
              {t === 'all' ? `All (${products.length})` : `Low stock (${lowStock.length})`}
            </button>
          ))}
        </div>

        {loading ? (
          <div className="text-center py-20 text-gray-400 text-sm">Loading…</div>
        ) : (
          <div className="bg-white rounded-xl border border-gray-200 shadow-sm overflow-hidden">
            <table className="w-full text-sm">
              <thead className="bg-gray-50 border-b border-gray-200">
                <tr>
                  <th className="text-left px-4 py-3 font-medium text-gray-500">Name</th>
                  <th className="text-left px-4 py-3 font-medium text-gray-500">Category</th>
                  <th className="text-right px-4 py-3 font-medium text-gray-500">Price</th>
                  <th className="text-right px-4 py-3 font-medium text-gray-500">Stock</th>
                  <th className="text-left px-4 py-3 font-medium text-gray-500">Status</th>
                  {can('stock') && <th className="px-4 py-3" />}
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-100">
                {list.map(p => (
                  <tr key={p.product_id} className="hover:bg-gray-50">
                    <td className="px-4 py-3 font-medium text-gray-900">{p.name}</td>
                    <td className="px-4 py-3 text-gray-500">{p.category ?? '—'}</td>
                    <td className="px-4 py-3 text-right font-mono text-gray-700">${Number(p.price).toFixed(2)}</td>
                    <td className="px-4 py-3 text-right">
                      <span className={p.stock_qty <= 10 ? 'text-orange-600 font-semibold' : 'text-gray-700'}>
                        {p.stock_qty}
                      </span>
                    </td>
                    <td className="px-4 py-3">
                      <span className={`text-xs px-2 py-0.5 rounded-full font-medium ${
                        p.is_active ? 'bg-green-100 text-green-700' : 'bg-gray-100 text-gray-500'
                      }`}>
                        {p.is_active ? 'Active' : 'Discontinued'}
                      </span>
                    </td>
                    {can('stock') && (
                      <td className="px-4 py-3 text-right">
                        <div className="flex justify-end gap-2">
                          <button onClick={() => { setRestockId(p.product_id); setAddQty(1) }}
                            className="text-xs text-blue-600 hover:underline">Restock</button>
                          {p.is_active && (
                            <button onClick={() => handleDiscontinue(p.product_id)}
                              className="text-xs text-red-500 hover:underline">Discontinue</button>
                          )}
                        </div>
                      </td>
                    )}
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>

      {/* Add product modal */}
      {showAdd && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 px-4">
          <div className="bg-white rounded-2xl shadow-xl p-6 w-full max-w-md">
            <h2 className="text-lg font-bold text-gray-900 mb-4">Add product</h2>
            <form onSubmit={handleAdd} className="space-y-3">
              <input required placeholder="Product name" value={addForm.name}
                onChange={e => setAddForm(f => ({ ...f, name: e.target.value }))}
                className="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500" />
              <select value={addForm.category_id}
                onChange={e => setAddForm(f => ({ ...f, category_id: e.target.value }))}
                className="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500">
                <option value="">No category</option>
                {categories.map(c => <option key={c.category_id} value={c.category_id}>{c.name}</option>)}
              </select>
              <select value={addForm.supplier_id}
                onChange={e => setAddForm(f => ({ ...f, supplier_id: e.target.value }))}
                className="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500">
                <option value="">No supplier</option>
                {suppliers.map(s => <option key={s.supplier_id} value={s.supplier_id}>{s.name}</option>)}
              </select>
              <div className="flex gap-2">
                <input required type="number" min="0" step="0.01" placeholder="Price"
                  value={addForm.price}
                  onChange={e => setAddForm(f => ({ ...f, price: e.target.value }))}
                  className="w-1/2 border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500" />
                <input type="number" min="0" placeholder="Initial qty"
                  value={addForm.stock_qty}
                  onChange={e => setAddForm(f => ({ ...f, stock_qty: e.target.value }))}
                  className="w-1/2 border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500" />
              </div>
              <div className="flex gap-2 pt-2">
                <button type="button" onClick={() => setShowAdd(false)}
                  className="flex-1 border border-gray-300 rounded-lg py-2 text-sm text-gray-600 hover:bg-gray-50">
                  Cancel
                </button>
                <button type="submit"
                  className="flex-1 bg-blue-600 hover:bg-blue-700 text-white rounded-lg py-2 text-sm font-medium">
                  Add
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Restock modal */}
      {restockId && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 px-4">
          <div className="bg-white rounded-2xl shadow-xl p-6 w-full max-w-xs">
            <h2 className="text-lg font-bold text-gray-900 mb-4">Restock product #{restockId}</h2>
            <form onSubmit={handleRestock} className="space-y-3">
              <input required type="number" min="1" value={addQty}
                onChange={e => setAddQty(e.target.value)}
                placeholder="Units to add"
                className="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500" />
              <div className="flex gap-2">
                <button type="button" onClick={() => setRestockId(null)}
                  className="flex-1 border border-gray-300 rounded-lg py-2 text-sm text-gray-600 hover:bg-gray-50">
                  Cancel
                </button>
                <button type="submit"
                  className="flex-1 bg-blue-600 hover:bg-blue-700 text-white rounded-lg py-2 text-sm font-medium">
                  Restock
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  )
}
