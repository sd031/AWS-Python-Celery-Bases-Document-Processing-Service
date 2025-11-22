import axios from 'axios';

const API_URL = import.meta.env.VITE_API_URL || '/api';

const api = axios.create({
  baseURL: API_URL,
  headers: {
    'Content-Type': 'application/json',
  },
});

// Add auth token to requests
api.interceptors.request.use((config) => {
  const token = localStorage.getItem('token');
  if (token) {
    config.headers.Authorization = `Bearer ${token}`;
  }
  return config;
});

// Auth API
export const authAPI = {
  signup: async (email, password, name) => {
    const response = await api.post('/auth/signup', { email, password, name });
    return response.data;
  },
  
  login: async (email, password) => {
    const response = await api.post('/auth/login', { email, password });
    return response.data;
  },
  
  logout: () => {
    localStorage.removeItem('token');
    localStorage.removeItem('user');
  },
  
  getCurrentUser: () => {
    const user = localStorage.getItem('user');
    return user ? JSON.parse(user) : null;
  },
};

// Documents API
export const documentsAPI = {
  upload: async (file, notificationEmail) => {
    const formData = new FormData();
    formData.append('file', file);
    if (notificationEmail) {
      formData.append('notification_email', notificationEmail);
    }
    
    const response = await api.post('/upload', formData, {
      headers: {
        'Content-Type': 'multipart/form-data',
      },
    });
    return response.data;
  },
  
  getStatus: async (jobId) => {
    const response = await api.get(`/status/${jobId}`);
    return response.data;
  },
  
  getResults: async (jobId) => {
    const response = await api.get(`/results/${jobId}`);
    return response.data;
  },
  
  listJobs: async () => {
    const response = await api.get('/jobs');
    return response.data;
  },
};

// Health check
export const healthCheck = async () => {
  const response = await api.get('/health');
  return response.data;
};

export default api;
