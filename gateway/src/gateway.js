const express = require('express');
const axios = require('axios');

const app = express();

// Configuration
const gatewayPort = parseInt(process.env.GATEWAY_PORT, 10) || 5921;
const backendUrl = process.env.BACKEND_URL || 'http://backend:3847';
const nodeEnv = process.env.NODE_ENV || 'development';

// Security middleware: Set security headers
app.use((req, res, next) => {
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
  // Strict transport security for HTTPS only environments
  if (nodeEnv === 'production') {
    res.setHeader('Strict-Transport-Security', 'max-age=31536000; includeSubDomains');
  }
  next();
});

// Request size limits to prevent DoS attacks
app.use(express.json({ limit: '10kb' }));
app.use(express.urlencoded({ limit: '10kb', extended: true }));

// Input sanitization middleware
app.use((req, res, next) => {
  // Sanitize string input to prevent injection attacks
  if (req.body && typeof req.body === 'object') {
    for (const key in req.body) {
      if (typeof req.body[key] === 'string') {
        // Remove potentially dangerous characters
        req.body[key] = req.body[key]
          .trim()
          .replace(/[<>\"']/g, (char) => {
            const map = {
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
app.use((req, res, next) => {
  const timestamp = new Date().toISOString();
  console.log(`[${timestamp}] ${req.method} ${req.url}`);
  next();
});

/**
 * Proxy request handler with error handling and security
 */
async function proxyRequest(req, res, next) {
  const startTime = Date.now();
  const targetPath = req.url;
  const targetUrl = `${backendUrl}${targetPath}`;

  try {
    console.log(`[PROXY] ${req.method} ${req.url} -> ${targetUrl}`);

    // Prepare headers for backend
    const headers = {
      'Content-Type': req.headers['content-type'] || 'application/json',
      'X-Forwarded-For': req.ip || req.connection.remoteAddress || req.socket.remoteAddress,
      'X-Forwarded-Proto': req.protocol,
      'X-Forwarded-Host': req.hostname,
    };

    // Forward request to backend service
    const response = await axios({
      method: req.method,
      url: targetUrl,
      params: req.query,
      data: req.body,
      headers,
      timeout: 30000, // 30 second timeout
      validateStatus: () => true, // Don't throw on any status code
      maxContentLength: 10 * 1024 * 1024, // 10MB max
      maxBodyLength: 10 * 1024 * 1024,
    });

    // Log response metrics
    const duration = Date.now() - startTime;
    console.log(`[PROXY] ${req.method} ${req.url} <- ${response.status} (${duration}ms)`);

    // Set response status and headers
    res.status(response.status);

    // Forward specific headers only (security: don't expose all headers)
    const headersToForward = ['content-type', 'content-length', 'cache-control'];
    headersToForward.forEach((header) => {
      if (response.headers[header]) {
        res.setHeader(header, response.headers[header]);
      }
    });

    // Send response data
    res.json(response.data);
  } catch (error) {
    // Log errors with masked sensitive information
    const errorMessage = error.message || 'Unknown error';
    console.error('[PROXY ERROR]', {
      method: req.method,
      url: req.url,
      message: errorMessage,
      code: error.code,
    });

    // Handle specific error cases
    if (axios.isAxiosError(error)) {
      if (error.code === 'ECONNREFUSED') {
        console.error('[PROXY] Connection refused to backend');
        return res.status(503).json({
          error: 'Backend service unavailable',
          message: 'The backend service is currently unavailable. Please try again later.',
        });
      }

      if (error.code === 'ETIMEDOUT' || error.code === 'ECONNABORTED') {
        console.error('[PROXY] Timeout connecting to backend');
        return res.status(504).json({
          error: 'Backend service timeout',
          message: 'The backend service did not respond in time. Please try again later.',
        });
      }

      if (error.response) {
        // Forward error response from backend
        return res.status(error.response.status).json(error.response.data);
      }
    }

    // Generic error (do not expose stack traces in production)
    if (!res.headersSent) {
      res.status(502).json({ error: 'Bad gateway' });
    }

    next(error);
  }
}

// Proxy all /api requests to backend
app.all('/api/*', proxyRequest);

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({
    ok: true,
    timestamp: new Date().toISOString(),
    environment: nodeEnv,
  });
});

// 404 handler
app.use((req, res) => {
  res.status(404).json({ error: 'Not found' });
});

// Error handler middleware
app.use((err, req, res, next) => {
  console.error('[ERROR]', err.message);
  if (!res.headersSent) {
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Start server
app.listen(gatewayPort, () => {
  console.log(`Gateway listening on port ${gatewayPort}`);
  console.log(`Forwarding to backend: ${backendUrl}`);
  console.log(`Environment: ${nodeEnv}`);
});

// Handle graceful shutdown
process.on('SIGTERM', () => {
  console.log('SIGTERM received, shutting down gracefully');
  process.exit(0);
});

process.on('SIGINT', () => {
  console.log('SIGINT received, shutting down gracefully');
  process.exit(0);
});
