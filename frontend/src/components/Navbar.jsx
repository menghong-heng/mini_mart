import { NavLink, useNavigate } from 'react-router-dom'
import { useAuth } from '../auth/AuthContext'

const ROLE_COLOR = {
  Admin:   'text-purple-400',
  Sales:   'text-blue-400',
  Cashier: 'text-brand-400',
  User:    'text-gray-400',
}

const linkClass = ({ isActive }) =>
  `text-sm px-4 py-2 rounded-xl transition-all duration-300 font-medium ${
    isActive
      ? 'bg-brand-600 text-white shadow-md shadow-brand-600/20'
      : 'text-gray-400 hover:text-white hover:bg-white/5'
  }`

export default function Navbar() {
  const { user, can, logout } = useAuth()
  const navigate = useNavigate()

  const handleLogout = async () => {
    await logout()
    navigate('/staff/login')
  }

  return (
    <nav className="bg-gray-950 text-white px-6 py-3.5 flex items-center justify-between border-b border-white/5">
      <div className="flex items-center gap-1.5">
        <div className="flex items-center gap-2.5 mr-6">
          <div className="w-10 h-10 rounded-xl flex items-center justify-center">
            <img src="/logo.svg" alt="67 mini" className="w-10 h-10" />
          </div>
          <span className="font-serif font-bold text-sm tracking-wide text-white hidden sm:inline">
            Staff Portal
          </span>
        </div>
        <NavLink to="/staff/dashboard" className={linkClass}>Dashboard</NavLink>
        {can('view')  && <NavLink to="/staff/products" className={linkClass}>Products</NavLink>}
        {can('view')  && <NavLink to="/staff/orders"   className={linkClass}>Orders</NavLink>}
        {can('admin') && <NavLink to="/staff/users"    className={linkClass}>Users</NavLink>}
        {can('admin') && <NavLink to="/staff/audit"    className={linkClass}>Audit</NavLink>}
      </div>

      <div className="flex items-center gap-4">
        <div className="text-right hidden sm:block">
          <p className="text-sm font-medium leading-none">{user?.username}</p>
          <p className={`text-xs mt-1 ${ROLE_COLOR[user?.role] ?? 'text-gray-400'}`}>{user?.role}</p>
        </div>
        <button onClick={handleLogout}
          className="text-xs bg-white/5 border border-white/10 hover:bg-red-600 hover:border-red-600 px-4 py-2 rounded-xl transition-all duration-300 font-medium">
          Logout
        </button>
      </div>
    </nav>
  )
}
