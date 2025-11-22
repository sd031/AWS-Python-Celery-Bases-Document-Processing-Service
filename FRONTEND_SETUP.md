# Frontend Setup Guide

Complete guide to set up and run the Document Processor frontend application.

## 🎯 Overview

The frontend is a modern React application with:
- **Authentication**: Signup/Login with DynamoDB
- **File Upload**: Drag-and-drop with validation
- **Real-time Progress**: Auto-updating job status
- **Results Viewer**: OCR text, metadata, thumbnails, labels

## 📋 Prerequisites

1. **Node.js 18+** and npm
2. **Backend API** deployed and running
3. **Users DynamoDB table** created

## 🚀 Quick Start

### Step 1: Deploy Backend Updates

First, deploy the updated backend with auth endpoints and users table:

```bash
# From project root
cd terraform
AWS_PROFILE=personal_new terraform apply -auto-approve
cd ..

# Rebuild and deploy API with auth endpoints
AWS_PROFILE=personal_new AWS_REGION=us-east-1 make update-images
```

This will:
- Create the `doc-processor-users` DynamoDB table
- Deploy updated API with `/auth/signup` and `/auth/login` endpoints
- Add `/jobs` endpoint for listing documents

### Step 2: Install Frontend Dependencies

```bash
cd frontend
npm install
```

### Step 3: Configure API URL

Create `.env` file:

```bash
cp .env.example .env
```

Edit `.env` and set your API endpoint:

```env
VITE_API_URL=http://doc-processor-alb-XXXXXXXXXX.us-east-1.elb.amazonaws.com
```

Get your API URL from Terraform:

```bash
cd ../terraform
terraform output api_endpoint
```

### Step 4: Start Development Server

```bash
# From frontend directory
npm run dev
```

Or use the startup script:

```bash
./start.sh
```

The frontend will be available at **http://localhost:3000**

## 📱 Using the Application

### 1. Sign Up

1. Navigate to http://localhost:3000
2. Click "create a new account"
3. Enter your name, email, and password
4. Click "Sign up"

### 2. Upload Document

1. After login, you'll see the dashboard
2. Drag and drop a file into the upload zone, or click "browse"
3. Supported formats:
   - **PDF** documents
   - **Images**: PNG, JPG, JPEG, GIF, WebP, TIFF, BMP
   - **Videos**: MP4, MOV, AVI
4. Click "Upload and Process"

### 3. Track Progress

- The job appears in the "Recent Jobs" list
- Progress bar shows current status (0-100%)
- Status updates automatically every 3 seconds
- Status indicators:
  - 🟡 **Pending** - Waiting to start
  - 🔵 **Processing** - Currently processing
  - 🟢 **Completed** - Successfully finished
  - 🔴 **Failed** - Error occurred

### 4. View Results

Click on a completed job to see:
- **Document Info**: File type, size, dates
- **Metadata**: Page count, author, creator, etc.
- **OCR Text**: Full extracted text
- **Thumbnail**: Generated preview image
- **Image Labels**: AI-detected objects and labels (for images)

## 🏗️ Project Structure

```
frontend/
├── src/
│   ├── components/
│   │   ├── Auth/
│   │   │   ├── Login.jsx           # Login page
│   │   │   └── Signup.jsx          # Signup page
│   │   └── Dashboard/
│   │       ├── Dashboard.jsx       # Main dashboard layout
│   │       ├── UploadZone.jsx      # File upload with drag-drop
│   │       ├── JobsList.jsx        # Sidebar with job list
│   │       └── JobDetails.jsx      # Job details and results
│   ├── context/
│   │   └── AuthContext.jsx         # Authentication state management
│   ├── services/
│   │   └── api.js                  # API client (Axios)
│   ├── App.jsx                     # Main app with routing
│   ├── main.jsx                    # Entry point
│   └── index.css                   # Global styles (Tailwind)
├── public/
├── index.html
├── package.json
├── vite.config.js                  # Vite configuration
├── tailwind.config.js              # Tailwind CSS config
├── postcss.config.js               # PostCSS config
└── README.md
```

## 🔧 Configuration

### Environment Variables

Create `.env` file with:

```env
# Backend API URL
VITE_API_URL=http://your-api-endpoint.com

# Optional: Enable development mode features
VITE_DEV_MODE=true
```

### API Proxy (Development)

The Vite dev server is configured to proxy `/api` requests to your backend:

```javascript
// vite.config.js
server: {
  proxy: {
    '/api': {
      target: process.env.VITE_API_URL || 'http://localhost:8000',
      changeOrigin: true,
      rewrite: (path) => path.replace(/^\/api/, '')
    }
  }
}
```

## 🎨 Customization

### Styling

The app uses **Tailwind CSS**. Customize colors and theme in `tailwind.config.js`:

```javascript
theme: {
  extend: {
    colors: {
      primary: '#4F46E5',  // Indigo
      // Add your custom colors
    }
  }
}
```

### API Client

Modify `src/services/api.js` to:
- Add new endpoints
- Change request/response handling
- Add interceptors for logging, etc.

### Components

All components are modular and can be customized:
- **Auth components**: `src/components/Auth/`
- **Dashboard components**: `src/components/Dashboard/`

## 📦 Building for Production

### Build

```bash
npm run build
```

Output will be in `dist/` directory.

### Preview Build

```bash
npm run preview
```

### Deploy to S3 + CloudFront

1. Build the app:
   ```bash
   npm run build
   ```

2. Upload to S3:
   ```bash
   aws s3 sync dist/ s3://your-bucket-name/ --profile personal_new
   ```

3. Invalidate CloudFront cache:
   ```bash
   aws cloudfront create-invalidation \
     --distribution-id YOUR_DIST_ID \
     --paths "/*" \
     --profile personal_new
   ```

## 🐛 Troubleshooting

### Issue: CORS Errors

**Solution**: Ensure backend API has CORS enabled. Check `api/main.py`:

```python
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Or specific frontend URL
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
```

### Issue: "User service unavailable"

**Solution**: Ensure users DynamoDB table exists:

```bash
cd terraform
AWS_PROFILE=personal_new terraform apply
```

### Issue: API connection fails

**Solutions**:
1. Check `.env` has correct `VITE_API_URL`
2. Verify backend is running: `curl http://your-api/health`
3. Check browser console for detailed errors

### Issue: Build fails

**Solutions**:
1. Delete `node_modules` and reinstall:
   ```bash
   rm -rf node_modules package-lock.json
   npm install
   ```

2. Clear Vite cache:
   ```bash
   rm -rf node_modules/.vite
   ```

### Issue: Tailwind styles not working

**Solution**: The `@tailwind` warnings in CSS are normal - they're processed by PostCSS. If styles don't appear:

1. Ensure PostCSS and Tailwind are installed
2. Check `tailwind.config.js` content paths
3. Restart dev server

## 🔐 Security Notes

### Production Considerations

1. **Token Storage**: Currently uses localStorage. For production, consider:
   - HTTP-only cookies
   - Secure token refresh mechanism
   - Token expiration

2. **Password Hashing**: Currently uses SHA-256. For production, use:
   - bcrypt or Argon2
   - Salt + multiple rounds

3. **HTTPS**: Always use HTTPS in production

4. **Environment Variables**: Never commit `.env` files

## 📊 Features Checklist

- ✅ User signup with email/password
- ✅ User login with session management
- ✅ Protected routes (redirect if not authenticated)
- ✅ Drag-and-drop file upload
- ✅ File type and size validation
- ✅ Real-time progress tracking
- ✅ Auto-refresh while processing
- ✅ Job list with status indicators
- ✅ Detailed results viewer
- ✅ OCR text display
- ✅ Metadata display
- ✅ Thumbnail preview
- ✅ Image labels display
- ✅ Responsive design
- ✅ Modern UI with Tailwind CSS
- ✅ Error handling and validation

## 🚀 Next Steps

1. **Deploy Backend Updates**:
   ```bash
   cd terraform
   AWS_PROFILE=personal_new terraform apply
   cd ..
   AWS_PROFILE=personal_new make update-images
   ```

2. **Start Frontend**:
   ```bash
   cd frontend
   npm install
   cp .env.example .env
   # Edit .env with your API URL
   npm run dev
   ```

3. **Test the Application**:
   - Sign up with a new account
   - Upload a test document
   - Watch real-time progress
   - View the results

## 📚 Additional Resources

- [React Documentation](https://react.dev/)
- [Vite Documentation](https://vitejs.dev/)
- [Tailwind CSS](https://tailwindcss.com/)
- [React Router](https://reactrouter.com/)
- [Axios](https://axios-http.com/)

## 🎉 Success!

Your frontend is now ready! The complete document processing system includes:

- ✅ **Backend API** - FastAPI with authentication
- ✅ **Workers** - Celery workers processing documents
- ✅ **Frontend** - React app with modern UI
- ✅ **Infrastructure** - All AWS resources via Terraform

Enjoy your fully functional document processing service! 🚀
