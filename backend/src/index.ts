import express, { Request, Response, NextFunction } from 'express';
import mongoose from 'mongoose';
import cors from 'cors';
import productsRouter from './routes/products';
import { envConfig } from './config/envConfig';
import { connectDB } from './config/db';

const app = express();

// Security middleware: Set security headers
app.use((req: Request, res: Response, next: NextFunction) => {
  // Prevent clickjacking attacks
  res.setHeader('X-Frame-Options', 'DENY');
  // Prevent MIME type sniffing
  res.setHeader('X-Content-Type-Options', 'nosniff');
  // Enable XSS protection
  res.setHeader('X-XSS-Protection', '1; mode=block');
  // Disable referrer information
  res.setHeader('Referrer-Policy', 'no-referrer');
  // Remove powered-by header to avoid fingerprinting
  res.removeHeader('X-Powered-By');
  next();
});

// CORS - only allow gateway in production
const corsOptions =
  process.env.NODE_ENV === 'production'
    ? {
        origin: 'http://gateway:5921',
        credentials: true,
        methods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH', 'OPTIONS'],
        optionsSuccessStatus: 200,
      }
    : {
        origin: '*',
        credentials: false,
        methods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH', 'OPTIONS'],
      };

app.use(cors(corsOptions));

// Request size limits to prevent DoS attacks
app.use(express.json({ limit: '10kb' }));
app.use(express.urlencoded({ limit: '10kb', extended: true }));

// Input sanitization middleware
app.use((req: Request, _res: Response, next: NextFunction) => {
  // Sanitize input to prevent injection attacks
  if (req.body && typeof req.body === 'object') {
    for (const key in req.body) {
      if (typeof req.body[key] === 'string') {
        // Remove potentially dangerous characters
        req.body[key] = req.body[key]
          .trim()
          .replace(/[<>\"']/g, (char: string) => {
            const map: { [key: string]: string } = {
              '<': '&lt;',
              '>': '&gt;',
              '"': '&quot;',
              "'": '&#x27;',
            };
            return map[char] || char;
          });
      }
    }
  }
  next();
});

// Request logger middleware
app.use((req: Request, _res: Response, next: NextFunction) => {
  const timestamp = new Date().toISOString();
  console.log(`[${timestamp}] ${req.method} ${req.path}`);
  next();
});

// MongoDB strict query mode
mongoose.set('strictQuery', false);

async function start(): Promise<void> {
  try {
    // Database connection
    await connectDB();

    // Routes
    app.use('/api/products', productsRouter);

    // Health check endpoint
    app.get('/api/health', (_req: Request, res: Response) => {
      res.json({ ok: true, timestamp: new Date().toISOString() });
    });

    // 404 handler
    app.use((_req: Request, res: Response) => {
      res.status(404).json({ error: 'Not found' });
    });

    // Error handler middleware
    app.use((err: Error, _req: Request, res: Response, _next: NextFunction) => {
      console.error('Unhandled error:', err);
      res.status(500).json({ error: 'Internal server error' });
    });

    const port = envConfig.port;
    app.listen(port, () => {
      console.log(`Backend listening on port ${port}`);
      console.log(`Environment: ${process.env.NODE_ENV || 'development'}`);
    });
  } catch (error) {
    console.error('Failed to start backend:', error);
    process.exit(1);
  }
}

start();

// Handle graceful shutdown
process.on('SIGTERM', () => {
  console.log('SIGTERM received, shutting down gracefully');
  process.exit(0);
});

process.on('SIGINT', () => {
  console.log('SIGINT received, shutting down gracefully');
  process.exit(0);
});

