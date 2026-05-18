import { useEffect, useState } from 'react'
import { Link, useNavigate } from 'react-router-dom'
import ThemeToggle from '../components/ThemeToggle'
import { useCustomerAuth } from '../auth/CustomerAuthContext'

export default function Signup() {
  const { customer, signup } = useCustomerAuth()
  const navigate = useNavigate()
  const [form, setForm] = useState({ email: '', password: '', full_name: '', phone: '' })
  const [error, setError] = useState(null)
  const [loading, setLoading] = useState(false)
  const [alreadyExists, setAlreadyExists] = useState(false)

  useEffect(() => {
    if (customer) navigate('/orders/mine', { replace: true })
  }, [customer, navigate])

  const set = key => e => setForm(f => ({ ...f, [key]: e.target.value }))

  const handleSubmit = async e => {
    e.preventDefault()
    setError(null)
    setAlreadyExists(false)
    setLoading(true)
    try {
      await signup(form.email, form.password, form.full_name, form.phone || null)
      navigate('/orders/mine')
    } catch (err) {
      const msg = err.response?.data?.detail ?? 'Sign-up failed — please try again.'
      if (msg.toLowerCase().includes('already exists')) setAlreadyExists(true)
      else setError(msg)
    } finally { setLoading(false) }
  }

  return (
    <div className="min-h-screen flex font-sans transition-colors relative">
      <div className="absolute top-4 right-4 z-50">
        <ThemeToggle />
      </div>
      {/* Left — Brand Panel */}
      <div className="hidden lg:flex flex-1 bg-gradient-to-br from-gray-900 via-gray-800 to-brand-900 relative overflow-hidden items-center justify-center p-12">
        <div className="absolute inset-0 opacity-10">
          <div className="absolute top-20 right-10 w-72 h-72 bg-brand-400 rounded-full blur-3xl" />
          <div className="absolute bottom-20 left-10 w-96 h-96 bg-warm-400 rounded-full blur-3xl" />
        </div>
        <div className="relative z-10 text-center text-white max-w-md">
          <div className="w-20 h-20 rounded-2xl flex items-center justify-center mx-auto mb-8">
            <img src="/logo.svg" alt="67 mini" className="w-20 h-20 drop-shadow-xl" />
          </div>
          <h2 className="font-serif text-4xl font-bold mb-4">Join Our<br />Community</h2>
          <p className="text-gray-300 leading-relaxed mb-8">
            Create your free account and start shopping. Track orders, save favorites, and enjoy exclusive member perks.
          </p>
          <div className="grid grid-cols-3 gap-4 text-sm text-gray-400">
            <div className="bg-white/5 rounded-2xl p-4 border border-white/10">
              <span className="text-2xl block mb-1">🛍️</span>
              <span className="text-white font-semibold block">Shop</span>
              Browse curated items
            </div>
            <div className="bg-white/5 rounded-2xl p-4 border border-white/10">
              <span className="text-2xl block mb-1">📦</span>
              <span className="text-white font-semibold block">Track</span>
              Real-time orders
            </div>
            <div className="bg-white/5 rounded-2xl p-4 border border-white/10">
              <span className="text-2xl block mb-1">⭐</span>
              <span className="text-white font-semibold block">Save</span>
              Member perks
            </div>
          </div>
        </div>
      </div>

      {/* Right — Form */}
      <div className="flex-1 bg-cream-50 dark:bg-gray-900 flex flex-col items-center justify-center px-6 py-12 transition-colors">
        <Link to="/" className="flex items-center gap-2 mb-10 lg:hidden">
          <div className="w-12 h-12 rounded-xl flex items-center justify-center">
            <img src="/logo.svg" alt="67 mini" className="w-12 h-12" />
          </div>
          <span className="text-xl font-serif font-bold text-gray-900 dark:text-white">67 mini mart</span>
        </Link>

        <div className="bg-white dark:bg-gray-950 rounded-3xl shadow-sm border border-cream-200 dark:border-gray-800 p-8 w-full max-w-sm animate-fade-up">
          <div className="mb-8 text-center">
            <h1 className="font-serif text-3xl font-bold text-gray-900 dark:text-white">Create account</h1>
            <p className="text-gray-400 text-sm mt-2">Join 67 mini mart and track your orders</p>
          </div>

          {alreadyExists ? (
            <div className="text-center py-4 animate-fade-in">
              <p className="text-4xl mb-3">👋</p>
              <p className="font-semibold text-gray-900 dark:text-white mb-1">You already have an account</p>
              <p className="text-gray-500 dark:text-gray-400 text-sm mb-5">
                An account with <span className="font-medium text-gray-800 dark:text-gray-200">{form.email}</span> already exists.
              </p>
              <Link to="/login" className="block w-full btn-primary text-center">Sign in instead</Link>
              <button onClick={() => setAlreadyExists(false)} className="mt-3 text-sm text-gray-400 hover:text-gray-600 dark:hover:text-gray-200 transition-colors">
                Use a different email
              </button>
            </div>
          ) : (
            <form onSubmit={handleSubmit} className="space-y-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1.5">Full name</label>
                <input type="text" value={form.full_name} onChange={set('full_name')} placeholder="Your full name" required className="input-warm dark:bg-gray-900 dark:border-gray-800 dark:text-white" />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1.5">Email</label>
                <input type="email" value={form.email} onChange={set('email')} placeholder="you@example.com" required className="input-warm dark:bg-gray-900 dark:border-gray-800 dark:text-white" />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1.5">Phone <span className="text-gray-400 font-normal">(optional)</span></label>
                <input type="tel" value={form.phone} onChange={set('phone')} placeholder="012 345 6789" className="input-warm dark:bg-gray-900 dark:border-gray-800 dark:text-white" />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1.5">Password</label>
                <input type="password" value={form.password} onChange={set('password')} placeholder="Min 6 characters" required minLength={6} className="input-warm dark:bg-gray-900 dark:border-gray-800 dark:text-white" />
              </div>
              {error && (
                <div className="bg-red-50 border border-red-200 rounded-xl px-4 py-3">
                  <p className="text-red-600 text-sm">{error}</p>
                </div>
              )}
              <button type="submit" disabled={loading} className="w-full btn-primary disabled:opacity-50">
                {loading ? 'Creating account…' : 'Create account'}
              </button>
            </form>
          )}

          {!alreadyExists && (
            <p className="text-center text-sm text-gray-500 mt-8">
              Already a member?{' '}
              <Link to="/login" className="text-brand-600 hover:underline font-semibold">Sign in</Link>
            </p>
          )}
        </div>

        <Link to="/" className="mt-6 text-sm text-gray-400 hover:text-brand-600 transition-colors">← Back to shop</Link>
      </div>
    </div>
  )
}
