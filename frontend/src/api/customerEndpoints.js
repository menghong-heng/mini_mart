import customerClient from './customerClient'

// ── Customer auth ─────────────────────────────────────────────────
export const customerSignup = (email, password, full_name, phone) =>
  customerClient.post('/customer/signup', { email, password, full_name, phone }).then(r => r.data)

export const customerLogin = (email, password) =>
  customerClient.post('/customer/login', { email, password }).then(r => r.data)

export const customerLogout = () =>
  customerClient.post('/customer/logout').then(r => r.data)

export const getMyProfile = () =>
  customerClient.get('/customer/me').then(r => r.data)

// ── Shop ──────────────────────────────────────────────────────────
export const shopGetProducts = () =>
  customerClient.get('/shop/products').then(r => r.data)

export const shopGetMyOrders = () =>
  customerClient.get('/shop/orders/mine').then(r => r.data)

export const shopGetOrder = id =>
  customerClient.get(`/shop/orders/${id}`).then(r => r.data)

export const placeOrder = items =>
  customerClient.post('/shop/orders', { items }).then(r => r.data)

export const payOrder = id =>
  customerClient.post(`/shop/orders/${id}/pay`).then(r => r.data)

