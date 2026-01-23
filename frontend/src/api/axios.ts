import axios from 'axios';
import { BACKEND_URL } from './config';

export const api = axios.create({
  baseURL: BACKEND_URL,
  headers: {
    'Content-Type': 'application/json',
  },
});