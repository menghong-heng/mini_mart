import { createContext, useCallback, useContext, useState } from 'react'
import { customerLogin, customerLogout, customerSignup } from '../api/customerEndpoints'

const CustomerAuthContext = createContext(null)

function load(key, parse = false) {
  try {
    const v = localStorage.getItem(key)
    return v ? (parse ? JSON.parse(v) : v) : null
  } catch {
    return null
  }
}

export function CustomerAuthProvider({ children }) {
  const [token,    setToken]    = useState(() => load('sentinel_customer_token'))
  const [customer, setCustomer] = useState(() => load('sentinel_customer_user', true))

  const _store = (data) => {
    const info = {
      customer_id: data.customer_id,
      full_name:   data.full_name,
      email:       data.email,
      phone:       data.phone ?? null,
    }
    localStorage.setItem('sentinel_customer_token', data.token)
    localStorage.setItem('sentinel_customer_user',  JSON.stringify(info))
    setToken(data.token)
    setCustomer(info)
    return data
  }

  const login = useCallback(async (email, password) => {
    const data = await customerLogin(email, password)
    return _store(data)
  }, [])

  const signup = useCallback(async (email, password, full_name, phone) => {
    const data = await customerSignup(email, password, full_name, phone)
    return _store(data)
  }, [])

  const logout = useCallback(async () => {
    try { await customerLogout() } catch { /* session may already be gone */ }
    localStorage.removeItem('sentinel_customer_token')
    localStorage.removeItem('sentinel_customer_user')
    setToken(null)
    setCustomer(null)
  }, [])

  return (
    <CustomerAuthContext.Provider value={{ token, customer, login, signup, logout }}>
      {children}
    </CustomerAuthContext.Provider>
  )
}

export const useCustomerAuth = () => useContext(CustomerAuthContext)
