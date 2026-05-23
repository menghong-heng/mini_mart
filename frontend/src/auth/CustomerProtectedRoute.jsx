import { Navigate, useLocation } from 'react-router-dom'
import { useCustomerAuth } from './CustomerAuthContext'

export default function CustomerProtectedRoute({ children }) {
  const { token } = useCustomerAuth()
  const location = useLocation()
  if (!token) return <Navigate to="/login" state={{ from: location.pathname }} replace />
  return children
}
