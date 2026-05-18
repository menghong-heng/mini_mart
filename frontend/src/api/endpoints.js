import client from './client'

// ── Auth ────────────────────────────────────────────────────
export const login  = (username, password) =>
  client.post('/auth/login', { username, password }).then(r => r.data)

export const logout = () =>
  client.post('/auth/logout').then(r => r.data)

export const getMe  = () =>
  client.get('/auth/me').then(r => r.data)

// ── Account ─────────────────────────────────────────────────
export const getUsers         = ()                => client.get('/users').then(r => r.data)
export const createUser       = body              => client.post('/users', body).then(r => r.data)
export const updateUserRole   = (id, role_name)   => client.patch(`/users/${id}/role`,   { role_name  }).then(r => r.data)
export const toggleUserActive = (id, is_active)   => client.patch(`/users/${id}/active`, { is_active  }).then(r => r.data)
export const getRoles         = ()                => client.get('/roles').then(r => r.data)
export const getSessions      = ()                => client.get('/sessions').then(r => r.data)

// ── Stock ────────────────────────────────────────────────────
export const getProducts       = (activeOnly = true) =>
  client.get('/products', { params: { active_only: activeOnly } }).then(r => r.data)
export const getLowStock       = (threshold = 100) =>
  client.get('/products/low-stock', { params: { threshold } }).then(r => r.data)
export const createProduct     = body   => client.post('/products', body).then(r => r.data)
export const restockProduct    = (id, add_qty) =>
  client.patch(`/products/${id}/restock`, { add_qty }).then(r => r.data)
export const discontinueProduct = id   => client.patch(`/products/${id}/discontinue`).then(r => r.data)
export const getCategories     = ()    => client.get('/categories').then(r => r.data)
export const getSuppliers      = ()    => client.get('/suppliers').then(r => r.data)

// ── Sales ────────────────────────────────────────────────────
export const getCustomers     = ()     => client.get('/customers').then(r => r.data)
export const getOrders        = ()     => client.get('/orders').then(r => r.data)
export const getOrder         = id     => client.get(`/orders/${id}`).then(r => r.data)
export const createOrder      = body   => client.post('/orders', body).then(r => r.data)
export const updateOrderStatus = (id, status) =>
  client.patch(`/orders/${id}/status`, { status }).then(r => r.data)
export const getInvoices      = ()     => client.get('/invoices').then(r => r.data)
export const createInvoice    = body   => client.post('/invoices', body).then(r => r.data)
export const payInvoice       = id     => client.patch(`/invoices/${id}/pay`).then(r => r.data)

// ── Admin ────────────────────────────────────────────────────
export const getAuditLogs   = (action) =>
  client.get('/audit-logs', { params: action ? { action } : {} }).then(r => r.data)
export const getSystemConfig  = ()              => client.get('/system-config').then(r => r.data)
export const updateConfig     = (key, config_value) =>
  client.patch(`/system-config/${key}`, { config_value }).then(r => r.data)
export const getSummary       = ()              => client.get('/reports/summary').then(r => r.data)
export const getRevenue       = ()              => client.get('/reports/revenue').then(r => r.data)

// ── Dashboard ───────────────────────────────────────────────
export const getDashboardActivity = () => client.get('/dashboard/activity').then(r => r.data)
