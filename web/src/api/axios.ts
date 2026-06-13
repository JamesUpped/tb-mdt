import axios, { type AxiosInstance } from 'axios'

const api: AxiosInstance = axios.create({
  baseURL: 'https://tb-mdt/',
})

export default api
