import { BrowserRouter, Navigate, Route, Routes } from 'react-router-dom'

import { AuthProvider }         from './auth/AuthContext'
import { CustomerAuthProvider } from './auth/CustomerAuthContext'
import { ThemeProvider }        from './components/ThemeContext'

// Route guards
import ProtectedRoute         from './auth/ProtectedRoute'
import CustomerProtectedRoute from './auth/CustomerProtectedRoute'

// Customer pages
import Shop     from './pages/Shop'
import Login    from './pages/Login'
import Signup   from './pages/Signup'
import MyOrders from './pages/MyOrders'

// Staff pages
import StaffLogin from './pages/StaffLogin'
import Dashboard  from './pages/Dashboard'
import Forbidden  from './pages/Forbidden'
import Users      from './pages/Users'
import Products   from './pages/Products'
import Orders     from './pages/Orders'
import AuditLogs  from './pages/AuditLogs'

export default function App() {
  return (
    <BrowserRouter>
      {/*
        CustomerAuthProvider wraps everything so Shop/Login/Signup can read
        customer auth state even when nested inside staff routes.
        AuthProvider (staff) wraps only the inner routes — same approach.
      */}
      <CustomerAuthProvider>
        <AuthProvider>
          <ThemeProvider>
          <Routes>
            {/* ── Customer-facing routes ──────────────────────────── */}
            <Route path="/"            element={<Shop />} />
            <Route path="/login"       element={<Login />} />
            <Route path="/signup"      element={<Signup />} />
            <Route path="/orders/mine" element={
              <CustomerProtectedRoute><MyOrders /></CustomerProtectedRoute>
            } />

            {/* ── Staff portal (hidden URL) ────────────────────────── */}
            <Route path="/staff/login"     element={<StaffLogin />} />
            <Route path="/forbidden"       element={<Forbidden />} />

            <Route path="/staff/dashboard" element={
              <ProtectedRoute><Dashboard /></ProtectedRoute>
            } />
            <Route path="/staff/products"  element={
              <ProtectedRoute module="view"><Products /></ProtectedRoute>
            } />
            <Route path="/staff/orders"    element={
              <ProtectedRoute module="view"><Orders /></ProtectedRoute>
            } />
            <Route path="/staff/users"     element={
              <ProtectedRoute module="admin"><Users /></ProtectedRoute>
            } />
            <Route path="/staff/audit"     element={
              <ProtectedRoute module="admin"><AuditLogs /></ProtectedRoute>
            } />

            {/* ── Fallback → customer shop ─────────────────────────── */}
            <Route path="*" element={<Navigate to="/" replace />} />
          </Routes>
          </ThemeProvider>
        </AuthProvider>
      </CustomerAuthProvider>
    </BrowserRouter>
  )
}
