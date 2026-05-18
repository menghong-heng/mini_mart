import { useAuth } from '../auth/AuthContext'

/**
 * Renders `children` only when the current user's role can access `module`.
 * Optional `fallback` is rendered instead when access is denied.
 *
 * Usage:
 *   <PermissionGate module="admin">
 *     <button>Delete user</button>
 *   </PermissionGate>
 */
export default function PermissionGate({ module, children, fallback = null }) {
  const { can } = useAuth()
  return can(module) ? children : fallback
}
