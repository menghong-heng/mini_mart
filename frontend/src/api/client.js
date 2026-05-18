import axios from 'axios'

// Vite proxy forwards /api/* → http://localhost:8000/api/*
const client = axios.create({ baseURL: '/api' })

// Attach token from localStorage on every outgoing request
client.interceptors.request.use(config => {
  const token = localStorage.getItem('sentinel_token')
  if (token) config.headers.Authorization = `Bearer ${token}`
  return config
})

// On 401 (invalid/expired session) clear local auth and go to /login
client.interceptors.response.use(
  res => res,
  err => {
    if (err.response?.status === 401) {
      localStorage.removeItem('sentinel_token')
      localStorage.removeItem('sentinel_user')
      localStorage.removeItem('sentinel_perms')
      window.location.href = '/staff/login'
    }
    return Promise.reject(err)
  }
)

export default client
