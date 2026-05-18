import { Navigate } from 'react-router-dom'
import { useCustomerAuth } from './CustomerAuthContext'

export default function CustomerProtectedRoute({ children }) {
  const { token } = useCustomerAuth()
  if (!token) return <Navigate to="/login" replace />
  return children
}
