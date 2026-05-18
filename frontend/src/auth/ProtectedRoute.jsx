import { Navigate } from 'react-router-dom'
import { useAuth } from './AuthContext'

/**
 * Wraps a page with two guards:
 *   1. Must be logged in (has a token) — else → /login
 *   2. If `module` is given, role must have that permission — else → /forbidden
 */
export default function ProtectedRoute({ children, module }) {
  const { token, can } = useAuth()

  if (!token) return <Navigate to="/staff/login" replace />
  if (module && !can(module)) return <Navigate to="/forbidden" replace />

  return children
}
