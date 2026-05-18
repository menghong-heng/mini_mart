import axios from 'axios'

// Separate axios instance for the customer track.
// Uses sentinel_customer_token, not sentinel_token (staff).
const customerClient = axios.create({ baseURL: '/api' })

customerClient.interceptors.request.use(config => {
  const token = localStorage.getItem('sentinel_customer_token')
  if (token) config.headers.Authorization = `Bearer ${token}`
  return config
})

// On 401, clear customer session and redirect to customer login
customerClient.interceptors.response.use(
  res => res,
  err => {
    if (err.response?.status === 401) {
      localStorage.removeItem('sentinel_customer_token')
      localStorage.removeItem('sentinel_customer_user')
      window.location.href = '/login'
    }
    return Promise.reject(err)
  }
)

export default customerClient
