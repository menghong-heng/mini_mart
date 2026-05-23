import { useEffect, useState } from 'react'
import Navbar from '../components/Navbar'
import { useAuth } from '../auth/AuthContext'
import {
  getProducts, getLowStock, createProduct,
  restockProduct, discontinueProduct, reactivateProduct, getCategories, getSuppliers,
  getProductImages, uploadProductImage, setProductImage,
} from '../api/endpoints'

const EMPTY_ADD_FORM = {
  name: '',
  category_id: '',
  price: '',
  stock_qty: 0,
  supplier_id: '',
  image_url: '',
}

const fallbackImage = () => '/product-images/product-placeholder.png'

export default function Products() {
  const { can } = useAuth()
  const canStock = can('stock')
  const [products, setProducts] = useState([])
  const [lowStock, setLowStock] = useState([])
  const [categories, setCategories] = useState([])
  const [suppliers, setSuppliers] = useState([])
  const [images, setImages] = useState([])
  const [loading, setLoading] = useState(true)
  const [tab, setTab] = useState('all')
  const [showAdd, setShowAdd] = useState(false)
  const [addForm, setAddForm] = useState(EMPTY_ADD_FORM)
  const [addImageFile, setAddImageFile] = useState(null)
  const [restockId, setRestockId] = useState(null)
  const [addQty, setAddQty] = useState(1)
  const [imageProduct, setImageProduct] = useState(null)
  const [selectedImageUrl, setSelectedImageUrl] = useState('')
  const [imageFile, setImageFile] = useState(null)
  const [imageLabel, setImageLabel] = useState('')
  const [savingImage, setSavingImage] = useState(false)
  const [error, setError] = useState(null)
  const [notice, setNotice] = useState(null)

  const load = () => {
    setLoading(true)
    setError(null)

    const stockOnly = canStock
      ? [getLowStock(100), getSuppliers(), getProductImages()]
      : [Promise.resolve([]), Promise.resolve([]), Promise.resolve([])]

    Promise.all([getProducts(false), getCategories(), ...stockOnly])
      .then(([p, cats, ls, sups, imgs]) => {
        setProducts(p)
        setCategories(cats)
        setLowStock(ls)
        setSuppliers(sups)
        setImages(imgs)
        if (!canStock && tab === 'low') setTab('all')
      })
      .catch(() => setError('Failed to load products.'))
      .finally(() => setLoading(false))
  }

  useEffect(() => { load() }, [canStock])

  const imageFor = product => product.image_url || fallbackImage(product.name)

  const resetAdd = () => {
    setShowAdd(false)
    setAddForm(EMPTY_ADD_FORM)
    setAddImageFile(null)
  }

  const handleAdd = async e => {
    e.preventDefault()
    try {
      setError(null)
      setNotice(null)
      let imageUrl = addForm.image_url || null
      if (addImageFile) {
        const uploaded = await uploadProductImage(addForm.name || addImageFile.name, addImageFile)
        imageUrl = uploaded.image_url
      }

      const created = await createProduct({
        name: addForm.name,
        category_id: addForm.category_id ? Number(addForm.category_id) : null,
        price: Number(addForm.price),
        stock_qty: Number(addForm.stock_qty),
        supplier_id: addForm.supplier_id ? Number(addForm.supplier_id) : null,
        image_url: imageUrl,
      })
      setNotice(`${created.name} was added successfully.`)
      resetAdd()
      load()
    } catch (err) {
      setNotice(null)
      setError(err.response?.data?.detail ?? 'Failed to add product.')
    }
  }

  const handleRestock = async e => {
    e.preventDefault()
    try {
      setError(null)
      setNotice(null)
      const updated = await restockProduct(restockId, Number(addQty))
      setNotice(`${updated.name} restocked successfully. New stock: ${updated.stock_qty}.`)
      setRestockId(null)
      setAddQty(1)
      load()
    } catch (err) {
      setNotice(null)
      setError(err.response?.data?.detail ?? 'Restock failed.')
    }
  }

  const openImageManager = product => {
    setImageProduct(product)
    setSelectedImageUrl(product.image_url || '')
    setImageFile(null)
    setImageLabel(product.name)
  }

  const closeImageManager = () => {
    setImageProduct(null)
    setSelectedImageUrl('')
    setImageFile(null)
    setImageLabel('')
    setSavingImage(false)
  }

  const handleImageSave = async e => {
    e.preventDefault()
    if (!imageProduct) return

    setSavingImage(true)
    try {
      setError(null)
      setNotice(null)
      let imageUrl = selectedImageUrl || null
      if (imageFile) {
        const uploaded = await uploadProductImage(imageLabel || imageProduct.name, imageFile)
        imageUrl = uploaded.image_url
      }
      const updated = await setProductImage(imageProduct.product_id, imageUrl)
      setNotice(`Image updated for ${updated.name}.`)
      closeImageManager()
      load()
    } catch (err) {
      setNotice(null)
      setError(err.response?.data?.detail ?? 'Image update failed.')
      setSavingImage(false)
    }
  }

  const handleDiscontinue = async id => {
    if (!window.confirm('Mark this product as discontinued?')) return
    try {
      setError(null)
      setNotice(null)
      const product = products.find(p => p.product_id === id)
      await discontinueProduct(id)
      setNotice(`${product?.name ?? 'Product'} was discontinued successfully.`)
      load()
    } catch (err) {
      setNotice(null)
      setError(err.response?.data?.detail ?? 'Action failed.')
    }
  }

  const handleReactivate = async id => {
    if (!window.confirm('Re-activate this product and make it available again?')) return
    try {
      setError(null)
      setNotice(null)
      const product = products.find(p => p.product_id === id)
      await reactivateProduct(id)
      setNotice(`${product?.name ?? 'Product'} has been re-activated.`)
      load()
    } catch (err) {
      setNotice(null)
      setError(err.response?.data?.detail ?? 'Action failed.')
    }
  }

  const list = tab === 'low' && canStock ? lowStock : products
  const tabs = canStock ? ['all', 'low'] : ['all']

  return (
    <div className="min-h-screen bg-gray-50">
      <Navbar />
      <div className="max-w-6xl mx-auto px-6 py-10">
        <div className="flex items-center justify-between mb-6">
          <div>
            <h1 className="text-2xl font-bold text-gray-900">Products</h1>
            <p className="text-gray-400 text-sm mt-0.5">67 Mini Mart inventory management</p>
          </div>
          {canStock && (
            <button onClick={() => setShowAdd(true)}
              className="bg-blue-600 hover:bg-blue-700 text-white text-sm px-4 py-2 rounded-lg font-medium transition-colors">
              + Add product
            </button>
          )}
        </div>

        {error && (
          <div className="bg-red-50 border border-red-200 rounded-lg px-4 py-2 mb-4 flex justify-between items-center">
            <p className="text-red-600 text-sm">{error}</p>
            <button onClick={() => setError(null)} className="text-red-400 hover:text-red-600 text-xs">x</button>
          </div>
        )}

        {notice && (
          <div className="bg-green-50 border border-green-200 rounded-lg px-4 py-2 mb-4 flex justify-between items-center">
            <p className="text-green-700 text-sm">{notice}</p>
            <button onClick={() => setNotice(null)} className="text-green-500 hover:text-green-700 text-xs">x</button>
          </div>
        )}

        <div className="flex gap-2 mb-4">
          {tabs.map(t => (
            <button key={t} onClick={() => setTab(t)}
              className={`text-sm px-3 py-1.5 rounded-lg font-medium transition-colors ${
                tab === t ? 'bg-blue-600 text-white' : 'bg-white border border-gray-300 text-gray-600 hover:bg-gray-50'
              }`}>
              {t === 'all' ? `All (${products.length})` : `Low stock (${lowStock.length})`}
            </button>
          ))}
        </div>

        {loading ? (
          <div className="text-center py-20 text-gray-400 text-sm">Loading...</div>
        ) : (
          <div className="bg-white rounded-xl border border-gray-200 shadow-sm overflow-hidden">
            <table className="w-full text-sm">
              <thead className="bg-gray-50 border-b border-gray-200">
                <tr>
                  <th className="text-left px-4 py-3 font-medium text-gray-500">Image</th>
                  <th className="text-left px-4 py-3 font-medium text-gray-500">Name</th>
                  <th className="text-left px-4 py-3 font-medium text-gray-500">Category</th>
                  <th className="text-right px-4 py-3 font-medium text-gray-500">Price</th>
                  <th className="text-right px-4 py-3 font-medium text-gray-500">Stock</th>
                  <th className="text-left px-4 py-3 font-medium text-gray-500">Status</th>
                  {canStock && <th className="px-4 py-3" />}
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-100">
                {list.map(p => (
                  <tr key={p.product_id} className="hover:bg-gray-50">
                    <td className="px-4 py-3">
                      <img src={imageFor(p)} alt={p.name}
                        onError={e => { e.currentTarget.src = fallbackImage(p.name) }}
                        className="w-14 h-14 rounded-lg object-cover border border-gray-200 bg-gray-50" />
                    </td>
                    <td className="px-4 py-3 font-medium text-gray-900">{p.name}</td>
                    <td className="px-4 py-3 text-gray-500">{p.category ?? '-'}</td>
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
                    {canStock && (
                      <td className="px-4 py-3 text-right">
                        <div className="flex justify-end gap-2">
                          <button onClick={() => openImageManager(p)}
                            className="text-xs text-blue-600 hover:underline">Image</button>
                          <button onClick={() => { setRestockId(p.product_id); setAddQty(1) }}
                            className="text-xs text-blue-600 hover:underline">Restock</button>
                          {p.is_active ? (
                            <button onClick={() => handleDiscontinue(p.product_id)}
                              className="text-xs text-red-500 hover:underline">Discontinue</button>
                          ) : (
                            <button onClick={() => handleReactivate(p.product_id)}
                              className="text-xs text-green-600 hover:underline">Reactivate</button>
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

      {showAdd && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 px-4">
          <div className="bg-white rounded-2xl shadow-xl p-6 w-full max-w-md max-h-[90vh] overflow-y-auto">
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

              <select value={addForm.image_url}
                onChange={e => setAddForm(f => ({ ...f, image_url: e.target.value }))}
                className="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500">
                <option value="">No stored image</option>
                {images.map(img => <option key={img.image_id} value={img.image_url}>{img.label}</option>)}
              </select>
              {addForm.image_url && (
                <img src={addForm.image_url} alt="Selected product"
                  className="w-full h-36 rounded-lg object-cover border border-gray-200 bg-gray-50" />
              )}
              <input type="file" accept="image/jpeg,image/png,image/webp,image/gif"
                onChange={e => setAddImageFile(e.target.files?.[0] ?? null)}
                className="w-full text-sm text-gray-600 file:mr-3 file:rounded-lg file:border-0 file:bg-gray-100 file:px-3 file:py-2 file:text-sm file:font-medium file:text-gray-700 hover:file:bg-gray-200" />

              <div className="flex gap-2 pt-2">
                <button type="button" onClick={resetAdd}
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

      {imageProduct && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 px-4">
          <div className="bg-white rounded-2xl shadow-xl p-6 w-full max-w-lg max-h-[90vh] overflow-y-auto">
            <h2 className="text-lg font-bold text-gray-900 mb-4">Product image</h2>
            <form onSubmit={handleImageSave} className="space-y-4">
              <div className="flex gap-4">
                <img src={selectedImageUrl || imageProduct.image_url || fallbackImage(imageProduct.name)}
                  alt={imageProduct.name}
                  onError={e => { e.currentTarget.src = fallbackImage(imageProduct.name) }}
                  className="w-28 h-28 rounded-lg object-cover border border-gray-200 bg-gray-50" />
                <div className="min-w-0">
                  <p className="font-semibold text-gray-900 truncate">{imageProduct.name}</p>
                  <p className="text-xs text-gray-400 mt-1">{imageProduct.category ?? 'General'}</p>
                </div>
              </div>

              <select value={selectedImageUrl}
                onChange={e => setSelectedImageUrl(e.target.value)}
                className="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500">
                <option value="">No image</option>
                {images.map(img => <option key={img.image_id} value={img.image_url}>{img.label}</option>)}
              </select>

              <div className="grid grid-cols-5 gap-2 max-h-36 overflow-y-auto">
                {images.map(img => (
                  <button key={img.image_id} type="button" onClick={() => setSelectedImageUrl(img.image_url)}
                    className={`rounded-lg border p-1 ${selectedImageUrl === img.image_url ? 'border-blue-500 ring-2 ring-blue-100' : 'border-gray-200'}`}
                    title={img.label}>
                    <img src={img.image_url} alt={img.label}
                      className="w-full aspect-square rounded-md object-cover bg-gray-50" />
                  </button>
                ))}
              </div>

              <input value={imageLabel}
                onChange={e => setImageLabel(e.target.value)}
                placeholder="Image label"
                className="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500" />
              <input type="file" accept="image/jpeg,image/png,image/webp,image/gif"
                onChange={e => setImageFile(e.target.files?.[0] ?? null)}
                className="w-full text-sm text-gray-600 file:mr-3 file:rounded-lg file:border-0 file:bg-gray-100 file:px-3 file:py-2 file:text-sm file:font-medium file:text-gray-700 hover:file:bg-gray-200" />

              <div className="flex gap-2 pt-2">
                <button type="button" onClick={closeImageManager}
                  className="flex-1 border border-gray-300 rounded-lg py-2 text-sm text-gray-600 hover:bg-gray-50">
                  Cancel
                </button>
                <button type="submit" disabled={savingImage}
                  className="flex-1 bg-blue-600 hover:bg-blue-700 disabled:opacity-50 text-white rounded-lg py-2 text-sm font-medium">
                  {savingImage ? 'Saving...' : 'Save'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

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
