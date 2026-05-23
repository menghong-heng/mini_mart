import { Link } from 'react-router-dom'
import { useAuth } from '../auth/AuthContext'

export default function Forbidden() {
  const { user } = useAuth()
  return (
    <div className="min-h-screen bg-gray-950 flex items-center justify-center px-4 font-sans relative overflow-hidden">
      <div className="absolute top-1/3 left-1/2 -translate-x-1/2 w-96 h-96 bg-red-600/10 rounded-full blur-3xl" />
      <div className="relative z-10 text-center animate-fade-up">
        <p className="text-9xl font-black text-white/5 select-none font-serif">403</p>
        <h1 className="text-2xl font-serif font-bold text-white mt-4 mb-3">Access Denied</h1>
        <p className="text-gray-400 text-sm mb-1">
          Your role{user?.role ? ` (${user.role})` : ''} does not have permission to view this page.
        </p>
        <p className="text-gray-600 text-xs mb-8">
          67 Mini Mart enforces this at the database level — navigating directly won't help.
        </p>
        <Link to="/staff/dashboard"
          className="inline-block bg-gradient-to-r from-brand-600 to-brand-500 hover:from-brand-700 hover:to-brand-600 text-white text-sm px-6 py-3 rounded-xl transition-all duration-300 font-semibold shadow-lg shadow-brand-600/25">
          ← Back to Dashboard
        </Link>
      </div>
    </div>
  )
}
