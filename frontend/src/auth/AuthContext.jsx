import { createContext, useCallback, useContext, useState } from 'react'
import { login as apiLogin, logout as apiLogout } from '../api/endpoints'

const AuthContext = createContext(null)

const EMPTY_PERMS = { admin: false, sales: false, stock: false, view: false }

function loadFromStorage(key, parse = false) {
  try {
    const v = localStorage.getItem(key)
    return v ? (parse ? JSON.parse(v) : v) : null
  } catch {
    return null
  }
}

export function AuthProvider({ children }) {
  const [token, setToken]           = useState(() => loadFromStorage('sentinel_token'))
  const [user, setUser]             = useState(() => loadFromStorage('sentinel_user', true))
  const [permissions, setPermissions] = useState(
    () => loadFromStorage('sentinel_perms', true) ?? EMPTY_PERMS
  )

  const login = useCallback(async (username, password) => {
    const data = await apiLogin(username, password)
    const userInfo = { username: data.username ?? username, role: data.role }

    localStorage.setItem('sentinel_token', data.token)
    localStorage.setItem('sentinel_user',  JSON.stringify(userInfo))
    localStorage.setItem('sentinel_perms', JSON.stringify(data.permissions))

    setToken(data.token)
    setUser(userInfo)
    setPermissions(data.permissions)
    return data
  }, [])

  const logout = useCallback(async () => {
    try { await apiLogout() } catch { /* session may already be gone */ }
    localStorage.removeItem('sentinel_token')
    localStorage.removeItem('sentinel_user')
    localStorage.removeItem('sentinel_perms')
    setToken(null)
    setUser(null)
    setPermissions(EMPTY_PERMS)
  }, [])

  // Convenience shortcut: can('admin'), can('sales'), etc.
  const can = useCallback(
    (module) => permissions[module] === true,
    [permissions]
  )

  return (
    <AuthContext.Provider value={{ token, user, permissions, login, logout, can }}>
      {children}
    </AuthContext.Provider>
  )
}

export const useAuth = () => useContext(AuthContext)
