import { useEffect, useState } from 'react'
import { Link, useNavigate } from 'react-router-dom'
import ThemeToggle from '../components/ThemeToggle'
import { placeOrder, shopGetProducts } from '../api/customerEndpoints'
import { useCustomerAuth } from '../auth/CustomerAuthContext'

const CATEGORY_EMOJI = { Electronics: '💻', Beverages: '🥤', Stationery: '📝', Clothing: '👕' }

const FEATURES = [
  { icon: '🛍️', title: 'Curated Selection', desc: 'Every product is handpicked for quality. We partner with trusted suppliers to bring you the best.' },
  { icon: '⚡', title: 'Lightning-Fast Checkout', desc: 'Order in seconds with our streamlined cart. No fuss, no friction — just great shopping.' },
  { icon: '✅', title: 'Quality Guaranteed', desc: 'Not satisfied? We\'ll make it right. Every purchase is backed by our quality promise.' },
]

const TESTIMONIALS = [
  { name: 'Sokha M.', text: 'Love the curated selection! Everything I need in one place with great prices.', role: 'Regular Customer' },
  { name: 'Dara K.', text: 'The checkout is incredibly fast. I placed my order in under a minute!', role: 'New Customer' },
  { name: 'Channa V.', text: 'Best mini mart experience ever. Quality products and friendly service.', role: 'Loyal Member' },
]

export default function Shop() {
  const { customer, logout } = useCustomerAuth()
  const navigate = useNavigate()
  const [products, setProducts] = useState([])
  const [loading, setLoading] = useState(true)
  const [search, setSearch] = useState('')
  const [activecat, setActivecat] = useState('All')
  const [cart, setCart] = useState([])
  const [cartOpen, setCartOpen] = useState(false)
  const [placing, setPlacing] = useState(false)
  const [orderError, setOrderError] = useState(null)
  const [toast, setToast] = useState(null)

  useEffect(() => {
    shopGetProducts().then(setProducts).catch(() => {}).finally(() => setLoading(false))
  }, [])

  const stockFor = (id) => products.find(p => p.product_id === id)?.stock_qty ?? 0
  const qtyInCart = (id) => cart.find(i => i.product_id === id)?.quantity ?? 0
  const cartCount = cart.reduce((s, i) => s + i.quantity, 0)
  const cartTotal = cart.reduce((s, i) => s + Number(i.price) * i.quantity, 0)
  const categories = ['All', ...Array.from(new Set(products.map(p => p.category).filter(Boolean)))]

  const visible = products.filter(p => {
    const matchCat = activecat === 'All' || p.category === activecat
    const matchQ = p.name.toLowerCase().includes(search.toLowerCase())
    return matchCat && matchQ
  })

  const addToCart = (product) => {
    setOrderError(null)
    setCart(prev => {
      const idx = prev.findIndex(i => i.product_id === product.product_id)
      if (idx >= 0) {
        if (prev[idx].quantity >= product.stock_qty) return prev
        const next = [...prev]
        next[idx] = { ...next[idx], quantity: next[idx].quantity + 1 }
        return next
      }
      return [...prev, { product_id: product.product_id, name: product.name, price: Number(product.price), quantity: 1 }]
    })
    setCartOpen(true)
  }

  const changeQty = (productId, delta) => {
    setCart(prev => {
      const stock = stockFor(productId)
      return prev.map(i => {
        if (i.product_id !== productId) return i
        const next = i.quantity + delta
        if (next > stock) return i
        return { ...i, quantity: next }
      }).filter(i => i.quantity > 0)
    })
  }

  const removeFromCart = (id) => setCart(prev => prev.filter(i => i.product_id !== id))

  const handlePlaceOrder = async () => {
    if (!customer || cart.length === 0 || placing) return
    setPlacing(true)
    setOrderError(null)
    try {
      await placeOrder(cart.map(i => ({ product_id: i.product_id, quantity: i.quantity })))
      setCart([])
      setCartOpen(false)
      setToast('Order placed — redirecting to your orders…')
      setTimeout(() => navigate('/orders/mine'), 1200)
    } catch (err) {
      setOrderError(err.response?.data?.detail ?? 'Could not place order. Please try again.')
    } finally { setPlacing(false) }
  }

  return (
    <div className="min-h-screen bg-cream-50 dark:bg-gray-900 font-sans transition-colors">
      {toast && (
        <div className="fixed top-4 left-1/2 -translate-x-1/2 z-50 bg-brand-600 text-white text-sm font-medium px-5 py-2.5 rounded-2xl shadow-lg animate-fade-in">{toast}</div>
      )}

      {/* ── Navbar ── */}
      <nav className="fixed top-0 w-full z-40 bg-cream-50/80 dark:bg-gray-900/80 backdrop-blur-lg border-b border-cream-200/60 dark:border-gray-800">
        <div className="max-w-7xl mx-auto px-6 py-3 flex items-center justify-between">
          <div className="flex items-center gap-2">
            <div className="w-9 h-9 rounded-xl flex items-center justify-center">
              <img src="/logo.svg" alt="67 mini" className="w-9 h-9" />
            </div>
            <span className="font-serif font-bold text-xl text-gray-900 dark:text-white">67 mini mart</span>
          </div>
          <div className="hidden md:flex items-center gap-8">
            <a href="#shop" className="text-sm font-medium text-gray-600 dark:text-gray-300 hover:text-brand-600 transition-colors">Shop</a>
            <a href="#about" className="text-sm font-medium text-gray-600 dark:text-gray-300 hover:text-brand-600 transition-colors">About</a>
            <a href="#features" className="text-sm font-medium text-gray-600 dark:text-gray-300 hover:text-brand-600 transition-colors">Features</a>
          </div>
          <div className="flex items-center gap-3">
            <ThemeToggle />
            <button onClick={() => setCartOpen(true)} className="relative text-sm bg-brand-600 text-white hover:bg-brand-700 px-4 py-2 rounded-xl transition-all duration-300 font-medium hover:shadow-lg hover:shadow-brand-600/20">
              🛒 Cart
              {cartCount > 0 && <span className="absolute -top-1.5 -right-1.5 bg-warm-400 text-gray-900 text-[10px] font-bold w-5 h-5 rounded-full flex items-center justify-center">{cartCount}</span>}
            </button>
            {customer ? (
              <>
                <span className="text-gray-500 text-sm hidden sm:inline">Hi, <span className="font-semibold text-gray-800">{customer.full_name}</span></span>
                <Link to="/orders/mine" className="text-sm font-medium text-brand-600 hover:text-brand-700 transition-colors">My Orders</Link>
                <button onClick={logout} className="text-sm text-gray-400 hover:text-red-500 transition-colors">Sign out</button>
              </>
            ) : (
              <>
                <Link to="/login" className="text-sm font-medium text-gray-600 hover:text-brand-600 transition-colors">Sign in</Link>
                <Link to="/signup" className="text-sm bg-gray-900 text-white hover:bg-gray-800 px-4 py-2 rounded-xl transition-all font-medium">Create account</Link>
              </>
            )}
          </div>
        </div>
      </nav>

      {/* ── Hero ── */}
      <section className="pt-28 pb-20 px-6">
        <div className="max-w-7xl mx-auto flex flex-col lg:flex-row items-center gap-12">
          <div className="flex-1 animate-fade-up">
            <div className="inline-block bg-brand-100 dark:bg-brand-900/30 text-brand-700 dark:text-brand-400 text-xs font-semibold px-3 py-1.5 rounded-full mb-6">🌿 Your Neighborhood Store</div>
            <h1 className="font-serif text-5xl lg:text-6xl font-bold text-gray-900 dark:text-white leading-tight mb-6">
              Fresh Finds,<br /><span className="gradient-text-warm">Every Day</span>
            </h1>
            <p className="text-gray-500 dark:text-gray-400 text-lg leading-relaxed max-w-lg mb-8">
              Quality products curated just for you. From everyday essentials to hidden gems — shop smarter at your local 67 mini mart.
            </p>
            <div className="flex gap-4">
              <a href="#shop" className="btn-primary inline-block">Browse Products</a>
              <a href="#about" className="btn-outline inline-block">Our Story</a>
            </div>
            <div className="flex items-center gap-8 mt-10 text-sm text-gray-400 dark:text-gray-400">
              <div><span className="text-2xl font-bold text-gray-900 dark:text-white block">500+</span>Products</div>
              <div className="w-px h-10 bg-gray-200 dark:bg-gray-700" />
              <div><span className="text-2xl font-bold text-gray-900 dark:text-white block">2K+</span>Customers</div>
              <div className="w-px h-10 bg-gray-200 dark:bg-gray-700" />
              <div><span className="text-2xl font-bold text-gray-900 dark:text-white block">4.9★</span>Rating</div>
            </div>
          </div>
          <div className="flex-1 relative animate-fade-up delay-200">
            <div className="relative w-full aspect-square max-w-md mx-auto">
              <div className="absolute inset-0 bg-gradient-to-br from-brand-200 via-warm-100 to-cream-200 dark:from-brand-900/40 dark:via-warm-900/20 dark:to-gray-800 rounded-[3rem] rotate-3 animate-float" />
              <img src="/home.jpeg" alt="Hero" className="absolute inset-4 rounded-[2.5rem] -rotate-2 object-cover shadow-2xl shadow-brand-600/30 w-[calc(100%-2rem)] h-[calc(100%-2rem)]" />
            </div>
          </div>
        </div>
      </section>

      {/* ── Features ── */}
      <section id="features" className="py-20 px-6 bg-white dark:bg-gray-950 transition-colors">
        <div className="max-w-5xl mx-auto text-center mb-14 animate-fade-up">
          <h2 className="font-serif text-3xl lg:text-4xl font-bold text-gray-900 dark:text-white mb-4">Why Shop With Us?</h2>
          <p className="text-gray-500 dark:text-gray-400 max-w-xl mx-auto">We're not just another store. Every aspect of your experience has been crafted with care.</p>
        </div>
        <div className="max-w-5xl mx-auto grid md:grid-cols-3 gap-6">
          {FEATURES.map((f, i) => (
            <div key={f.title} className={`bg-cream-50 dark:bg-gray-900 rounded-2xl p-8 border border-cream-200 dark:border-gray-800 hover:shadow-xl hover:-translate-y-1 transition-all duration-300 animate-fade-up delay-${(i + 1) * 100}`}>
              <span className="text-4xl mb-4 block">{f.icon}</span>
              <h3 className="font-serif font-bold text-xl text-gray-900 dark:text-white mb-2">{f.title}</h3>
              <p className="text-gray-500 dark:text-gray-400 text-sm leading-relaxed">{f.desc}</p>
            </div>
          ))}
        </div>
      </section>

      {/* ── About ── */}
      <section id="about" className="py-20 px-6 bg-cream-100/50 dark:bg-gray-900/50 transition-colors">
        <div className="max-w-6xl mx-auto flex flex-col lg:flex-row items-center gap-12">
          <div className="flex-1 animate-fade-up">
            <div className="relative aspect-square max-w-sm mx-auto">
               <img src="https://placehold.co/500x500/FDE68A/15803D?text=About+Us" alt="About us" className="rounded-[2.5rem] object-cover w-full h-full shadow-lg" />
            </div>
          </div>
          <div className="flex-1 animate-fade-up delay-200">
            <span className="text-sm font-semibold text-brand-600 uppercase tracking-widest">About Us</span>
            <h2 className="font-serif text-3xl lg:text-4xl font-bold text-gray-900 dark:text-white mt-3 mb-6">Your Neighborhood,<br />Deserves Better</h2>
            <p className="text-gray-500 dark:text-gray-400 leading-relaxed mb-6">
              67 mini mart was born from a simple idea — your neighborhood deserves better. Founded in 2024, we've been on a mission to bring curated, quality products right to your doorstep. From everyday essentials to hidden gems, we handpick every item on our shelves so you don't have to compromise on quality or convenience.
            </p>
            <blockquote className="border-l-4 border-brand-400 pl-5 italic font-serif text-gray-600 dark:text-gray-300 text-lg">
              "Supporting local communities with accessible, quality products is, and will always be, our core mission."
            </blockquote>
          </div>
        </div>
      </section>

      {/* ── Products ── */}
      <section id="shop" className="py-20 px-6 bg-white dark:bg-gray-950 transition-colors">
        <div className="max-w-6xl mx-auto">
          <div className="text-center mb-10 animate-fade-up">
            <h2 className="font-serif text-3xl lg:text-4xl font-bold text-gray-900 dark:text-white mb-3">Our Products</h2>
            <p className="text-gray-500 dark:text-gray-400">Browse our carefully curated selection of quality items</p>
          </div>
          <div className="flex flex-col sm:flex-row gap-3 mb-8">
            <input type="text" placeholder="Search products…" value={search} onChange={e => setSearch(e.target.value)}
              className="input-warm flex-1 dark:bg-gray-900 dark:border-gray-800 dark:text-white" />
            <div className="flex gap-2 flex-wrap">
              {categories.map(cat => (
                <button key={cat} onClick={() => setActivecat(cat)}
                  className={`text-sm px-4 py-2.5 rounded-xl font-medium transition-all duration-300 ${activecat === cat
                    ? 'bg-brand-600 text-white shadow-md shadow-brand-600/20'
                    : 'bg-cream-50 dark:bg-gray-900 border border-cream-200 dark:border-gray-800 text-gray-600 dark:text-gray-300 hover:bg-cream-100 dark:hover:bg-gray-800 hover:border-brand-200'}`}>
                  {CATEGORY_EMOJI[cat] ?? ''} {cat}
                </button>
              ))}
            </div>
          </div>

          {loading ? (
            <div className="text-center py-24 text-gray-400 text-sm animate-pulse-soft">Loading products…</div>
          ) : visible.length === 0 ? (
            <div className="text-center py-24 text-gray-400 text-sm">No products found.</div>
          ) : (
            <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-5">
              {visible.map(p => {
                const inCart = qtyInCart(p.product_id)
                const atMax = inCart >= p.stock_qty
                return (
                  <div key={p.product_id} className="relative bg-cream-50 dark:bg-gray-900 rounded-2xl border border-cream-200 dark:border-gray-800 p-5 hover:shadow-xl hover:-translate-y-1 transition-all duration-300 group">
                    {inCart > 0 && (
                      <span className="absolute top-3 right-3 bg-brand-600 text-white text-xs font-bold w-6 h-6 rounded-full flex items-center justify-center shadow-sm">{inCart}</span>
                    )}
                    <img src={`https://placehold.co/400x300/F0FDF4/16A34A?text=${encodeURIComponent(p.name)}`} alt={p.name} className="w-full h-40 object-cover rounded-xl mb-4 border border-cream-200/50 dark:border-gray-800" />
                    <div className="flex items-center gap-1.5 mb-3">
                      <span className="text-lg">{CATEGORY_EMOJI[p.category] ?? '📦'}</span>
                      <span className="text-xs text-gray-400 font-medium">{p.category ?? 'General'}</span>
                      {p.stock_qty <= 10 && (
                        <span className="ml-auto text-xs bg-warm-100 text-warm-500 px-2 py-0.5 rounded-full font-medium">Low stock</span>
                      )}
                    </div>
                    <h3 className="font-semibold text-gray-900 dark:text-white text-sm leading-snug mb-3 pr-6">{p.name}</h3>
                    <div className="flex items-end justify-between mb-3">
                      <span className="text-2xl font-bold text-brand-600">${Number(p.price).toFixed(2)}</span>
                      <span className="text-xs text-gray-400">{p.stock_qty} left</span>
                    </div>
                    <button disabled={p.stock_qty === 0 || atMax} onClick={() => addToCart(p)}
                      className="w-full bg-brand-600 hover:bg-brand-700 disabled:opacity-40 text-white font-medium text-sm py-2.5 rounded-xl transition-all duration-300 hover:shadow-md hover:shadow-brand-600/20">
                      {p.stock_qty === 0 ? 'Out of stock' : atMax ? 'Max in cart' : 'Add to cart'}
                    </button>
                  </div>
                )
              })}
            </div>
          )}
        </div>
      </section>

      {/* ── Testimonials ── */}
      <section className="py-20 px-6 bg-cream-100/50 dark:bg-gray-900/50 transition-colors">
        <div className="max-w-5xl mx-auto text-center mb-12">
          <h2 className="font-serif text-3xl font-bold text-gray-900 dark:text-white mb-3">What Our Customers Say</h2>
          <p className="text-gray-500 dark:text-gray-400">Join thousands of happy shoppers</p>
        </div>
        <div className="max-w-5xl mx-auto grid md:grid-cols-3 gap-6">
          {TESTIMONIALS.map(t => (
            <div key={t.name} className="bg-white dark:bg-gray-950 rounded-2xl p-6 border border-cream-200 dark:border-gray-800 shadow-sm hover:shadow-lg transition-all duration-300">
              <p className="text-gray-600 dark:text-gray-300 italic mb-4 leading-relaxed">"{t.text}"</p>
              <div className="flex items-center gap-3">
                <div className="w-10 h-10 bg-brand-100 dark:bg-brand-900/30 rounded-full flex items-center justify-center">
                  <span className="text-brand-700 dark:text-brand-400 font-bold text-sm">{t.name[0]}</span>
                </div>
                <div>
                  <p className="font-semibold text-sm text-gray-900 dark:text-white">{t.name}</p>
                  <p className="text-xs text-gray-400">{t.role}</p>
                </div>
              </div>
            </div>
          ))}
        </div>
      </section>

      {/* ── Cart Drawer ── */}
      {cartOpen && (
        <div className="fixed inset-0 z-50 flex">
          <div className="flex-1 bg-black/40 backdrop-blur-sm" onClick={() => setCartOpen(false)} />
          <aside className="w-full max-w-md bg-cream-50 dark:bg-gray-900 shadow-2xl flex flex-col animate-slide-in-r">
            <div className="px-6 py-5 border-b border-cream-200 dark:border-gray-800 flex items-center justify-between">
              <h2 className="font-serif font-bold text-xl text-gray-900 dark:text-white">Your Cart</h2>
              <button onClick={() => setCartOpen(false)} className="text-gray-400 hover:text-gray-600 text-2xl leading-none" aria-label="Close cart">×</button>
            </div>
            <div className="flex-1 overflow-y-auto px-6 py-5">
              {cart.length === 0 ? (
                <div className="text-center text-gray-400 text-sm py-16">
                  <p className="text-5xl mb-4">🛒</p>Your cart is empty. Add a product to get started.
                </div>
              ) : (
                <ul className="space-y-3">
                  {cart.map(item => {
                    const stock = stockFor(item.product_id)
                    return (
                      <li key={item.product_id} className="bg-white dark:bg-gray-950 border border-cream-200 dark:border-gray-800 rounded-xl p-4 flex items-start gap-3">
                        <div className="flex-1 min-w-0">
                          <p className="font-medium text-sm text-gray-900 dark:text-white truncate">{item.name}</p>
                          <p className="text-xs text-gray-400 mt-0.5">${Number(item.price).toFixed(2)} × {item.quantity}</p>
                          <div className="flex items-center gap-2 mt-2">
                            <button onClick={() => changeQty(item.product_id, -1)} className="w-7 h-7 rounded-lg border border-gray-200 dark:border-gray-700 text-gray-600 dark:text-gray-300 hover:bg-gray-100 dark:hover:bg-gray-800 font-medium">−</button>
                            <span className="text-sm font-medium w-6 text-center dark:text-white">{item.quantity}</span>
                            <button onClick={() => changeQty(item.product_id, +1)} disabled={item.quantity >= stock} className="w-7 h-7 rounded-lg border border-gray-200 dark:border-gray-700 text-gray-600 dark:text-gray-300 hover:bg-gray-100 dark:hover:bg-gray-800 disabled:opacity-40 font-medium">+</button>
                            <button onClick={() => removeFromCart(item.product_id)} className="ml-auto text-xs text-red-500 hover:text-red-700">Remove</button>
                          </div>
                        </div>
                        <span className="text-sm font-semibold text-gray-900 dark:text-white whitespace-nowrap">${(Number(item.price) * item.quantity).toFixed(2)}</span>
                      </li>
                    )
                  })}
                </ul>
              )}
            </div>
            <div className="border-t border-cream-200 dark:border-gray-800 px-6 py-5 space-y-3">
              {orderError && <p className="text-sm text-red-600 bg-red-50 border border-red-200 rounded-lg px-3 py-2">{orderError}</p>}
              <div className="flex items-center justify-between">
                <span className="text-sm text-gray-500">Total</span>
                <span className="text-xl font-bold text-gray-900 dark:text-white">${cartTotal.toFixed(2)}</span>
              </div>
              {customer ? (
                <button onClick={handlePlaceOrder} disabled={cart.length === 0 || placing} className="w-full btn-primary">{placing ? 'Placing order…' : 'Place Order'}</button>
              ) : (
                <Link to="/login" className="block text-center w-full btn-primary">Sign in to order</Link>
              )}
            </div>
          </aside>
        </div>
      )}

      {/* ── Footer ── */}
      <footer className="bg-gray-900 text-white pt-16 pb-8 px-6">
        <div className="max-w-6xl mx-auto grid md:grid-cols-4 gap-10 mb-12">
          <div className="md:col-span-2">
            <div className="flex items-center gap-2 mb-4">
              <div className="w-9 h-9 rounded-xl flex items-center justify-center">
                 <img src="/logo.svg" alt="67 mini" className="w-9 h-9" />
              </div>
              <span className="font-serif font-bold text-xl">67 mini mart</span>
            </div>
            <p className="text-gray-400 text-sm leading-relaxed max-w-sm mb-4">
              Your neighborhood store for curated, quality products. We're committed to making your shopping experience delightful, every single day.
            </p>
            <p className="text-gray-500 text-xs italic font-serif">
              "Supporting local communities with accessible, quality products is, and will always be, our core mission."
            </p>
          </div>
          <div>
            <h4 className="font-semibold text-sm mb-4 text-gray-300 uppercase tracking-wider">Quick Links</h4>
            <ul className="space-y-2 text-sm text-gray-400">
              <li><a href="#shop" className="hover:text-brand-400 transition-colors">Shop</a></li>
              <li><a href="#about" className="hover:text-brand-400 transition-colors">About Us</a></li>
              <li><a href="#features" className="hover:text-brand-400 transition-colors">Features</a></li>
              <li><Link to="/login" className="hover:text-brand-400 transition-colors">Customer Login</Link></li>
            </ul>
          </div>
          <div>
            <h4 className="font-semibold text-sm mb-4 text-gray-300 uppercase tracking-wider">Contact</h4>
            <ul className="space-y-2 text-sm text-gray-400">
              <li>📍 Phnom Penh, Cambodia</li>
              <li>📞 +855 12 345 678</li>
              <li>✉️ hello@67minimart.com</li>
              <li>🕐 Open 7am – 10pm Daily</li>
            </ul>
          </div>
        </div>
        <div className="border-t border-gray-800 pt-6 text-center">
          <p className="text-xs text-gray-500">© 2026 67 mini mart — Quality you can trust. Built with ❤️ in Cambodia.</p>
        </div>
      </footer>
    </div>
  )
}
