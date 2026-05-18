import { useEffect, useState } from 'react'
import { Link, useNavigate } from 'react-router-dom'
import ThemeToggle from '../components/ThemeToggle'
import { useCustomerAuth } from '../auth/CustomerAuthContext'

export default function Login() {
  const { customer, login } = useCustomerAuth()
  const navigate = useNavigate()
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [error, setError] = useState(null)
  const [loading, setLoading] = useState(false)

  useEffect(() => {
    if (customer) navigate('/orders/mine', { replace: true })
  }, [customer, navigate])

  const handleSubmit = async e => {
    e.preventDefault()
    setError(null)
    setLoading(true)
    try {
      await login(email, password)
      navigate('/orders/mine')
    } catch (err) {
      setError(err.response?.data?.detail ?? 'Sign-in failed — check your email and password.')
    } finally { setLoading(false) }
  }

  return (
    <div className="min-h-screen flex font-sans transition-colors relative">
      <div className="absolute top-4 right-4 z-50">
        <ThemeToggle />
      </div>
      {/* Left — Brand Panel */}
      <div className="hidden lg:flex flex-1 bg-gradient-to-br from-brand-600 via-brand-700 to-brand-800 relative overflow-hidden items-center justify-center p-12">
        <div className="absolute inset-0 opacity-10">
          <div className="absolute top-20 left-10 w-72 h-72 bg-white rounded-full blur-3xl" />
          <div className="absolute bottom-10 right-10 w-96 h-96 bg-warm-400 rounded-full blur-3xl" />
        </div>
        <div className="relative z-10 text-center text-white max-w-md">
          <div className="w-20 h-20 rounded-2xl flex items-center justify-center mx-auto mb-8">
            <img src="/logo.svg" alt="67 mini" className="w-20 h-20 drop-shadow-xl" />
          </div>
          <h2 className="font-serif text-4xl font-bold mb-4">Welcome Back to<br />67 mini mart</h2>
          <p className="text-brand-100 leading-relaxed mb-8">
            Sign in to track your orders, manage your account, and enjoy a seamless shopping experience.
          </p>
          <div className="flex justify-center gap-6 text-sm text-brand-200">
            <div><span className="text-2xl font-bold text-white block">500+</span>Products</div>
            <div className="w-px h-12 bg-white/20" />
            <div><span className="text-2xl font-bold text-white block">2K+</span>Customers</div>
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
            <h1 className="font-serif text-3xl font-bold text-gray-900 dark:text-white">Welcome back</h1>
            <p className="text-gray-400 text-sm mt-2">Sign in to view your orders</p>
          </div>

          <form onSubmit={handleSubmit} className="space-y-5">
            <div>
              <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1.5">Email</label>
              <input type="email" value={email} onChange={e => setEmail(e.target.value)}
                placeholder="you@example.com" required className="input-warm dark:bg-gray-900 dark:border-gray-800 dark:text-white" />
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1.5">Password</label>
              <input type="password" value={password} onChange={e => setPassword(e.target.value)}
                placeholder="••••••••" required className="input-warm dark:bg-gray-900 dark:border-gray-800 dark:text-white" />
            </div>

            {error && (
              <div className="bg-red-50 border border-red-200 rounded-xl px-4 py-3">
                <p className="text-red-600 text-sm">{error}</p>
              </div>
            )}

            <button type="submit" disabled={loading} className="w-full btn-primary disabled:opacity-50">
              {loading ? 'Signing in…' : 'Sign in'}
            </button>
          </form>

          <p className="text-center text-sm text-gray-500 mt-8">
            New to 67 mini mart?{' '}
            <Link to="/signup" className="text-brand-600 hover:underline font-semibold">Create account</Link>
          </p>
        </div>

        <Link to="/" className="mt-6 text-sm text-gray-400 hover:text-brand-600 transition-colors">← Back to shop</Link>
      </div>
    </div>
  )
}
