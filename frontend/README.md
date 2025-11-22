# Document Processor Frontend

Modern React frontend for the AWS Document Processing Service with authentication, file upload, and real-time progress tracking.

## Features

- 🔐 **User Authentication** - Signup/Login with DynamoDB storage
- 📤 **Drag & Drop Upload** - Easy file upload with validation
- 📊 **Real-time Progress** - Live updates on document processing
- 📄 **Results Viewer** - View OCR text, metadata, thumbnails, and image labels
- 🎨 **Modern UI** - Built with React, Tailwind CSS, and Lucide icons

## Tech Stack

- **React 18** - UI framework
- **Vite** - Build tool and dev server
- **Tailwind CSS** - Styling
- **React Router** - Navigation
- **Axios** - HTTP client
- **Lucide React** - Icons

## Prerequisites

- Node.js 18+ and npm
- Backend API running (see main README)

## Quick Start

### 1. Install Dependencies

```bash
cd frontend
npm install
```

### 2. Configure Environment

Create `.env` file:

```bash
cp .env.example .env
```

Edit `.env` and set your API URL:

```
VITE_API_URL=http://your-api-endpoint.com
```

### 3. Run Development Server

```bash
npm run dev
```

The app will be available at `http://localhost:3000`

### 4. Build for Production

```bash
npm run build
```

The built files will be in the `dist/` directory.

## Project Structure

```
frontend/
├── src/
│   ├── components/
│   │   ├── Auth/
│   │   │   ├── Login.jsx          # Login page
│   │   │   └── Signup.jsx         # Signup page
│   │   └── Dashboard/
│   │       ├── Dashboard.jsx      # Main dashboard
│   │       ├── UploadZone.jsx     # File upload component
│   │       ├── JobsList.jsx       # Jobs list sidebar
│   │       └── JobDetails.jsx     # Job details with results
│   ├── context/
│   │   └── AuthContext.jsx        # Authentication context
│   ├── services/
│   │   └── api.js                 # API client
│   ├── App.jsx                    # Main app component
│   ├── main.jsx                   # Entry point
│   └── index.css                  # Global styles
├── package.json
├── vite.config.js
└── tailwind.config.js
```

## Features Overview

### Authentication

- **Signup**: Create new account with email, password, and name
- **Login**: Sign in with email and password
- **Session Management**: Token-based authentication with localStorage
- **Protected Routes**: Automatic redirect for unauthenticated users

### Document Upload

- **Drag & Drop**: Drag files directly into the upload zone
- **File Validation**: Checks file type and size (max 100MB)
- **Supported Formats**:
  - Documents: PDF
  - Images: PNG, JPG, JPEG, GIF, WebP, TIFF, BMP
  - Videos: MP4, MOV, AVI

### Progress Tracking

- **Real-time Updates**: Auto-refresh every 3 seconds while processing
- **Progress Bar**: Visual indication of processing progress
- **Status Messages**: Detailed status messages at each stage
- **Status Icons**: Visual indicators for pending, processing, completed, failed

### Results Viewer

- **Document Info**: File type, size, creation date
- **Metadata**: Extracted metadata (page count, author, dates, etc.)
- **OCR Text**: Full extracted text with scrollable view
- **Thumbnails**: Generated thumbnail preview
- **Image Labels**: AI-detected labels with confidence scores

## API Integration

The frontend communicates with the backend API through these endpoints:

- `POST /auth/signup` - User registration
- `POST /auth/login` - User login
- `POST /upload` - Upload document
- `GET /status/{job_id}` - Get job status
- `GET /results/{job_id}` - Get job results
- `GET /jobs` - List all jobs
- `GET /health` - Health check

## Development

### Available Scripts

- `npm run dev` - Start development server
- `npm run build` - Build for production
- `npm run preview` - Preview production build

### Environment Variables

- `VITE_API_URL` - Backend API URL (default: `/api` for proxy)

## Deployment

### Option 1: Static Hosting (S3 + CloudFront)

1. Build the app:
   ```bash
   npm run build
   ```

2. Upload `dist/` to S3 bucket

3. Configure CloudFront distribution

### Option 2: Docker

Create `Dockerfile`:

```dockerfile
FROM node:18-alpine as build
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

FROM nginx:alpine
COPY --from=build /app/dist /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
```

Build and run:

```bash
docker build -t doc-processor-frontend .
docker run -p 3000:80 doc-processor-frontend
```

## Customization

### Styling

Edit `tailwind.config.js` to customize colors, fonts, and other design tokens.

### API Client

Modify `src/services/api.js` to add new endpoints or change request/response handling.

### Components

All components are in `src/components/` and can be customized or extended.

## Troubleshooting

### CORS Errors

If you see CORS errors, ensure your backend API has CORS enabled for your frontend domain.

### API Connection Issues

1. Check that `VITE_API_URL` is set correctly in `.env`
2. Verify the backend API is running
3. Check browser console for detailed error messages

### Build Errors

1. Delete `node_modules` and `package-lock.json`
2. Run `npm install` again
3. Clear Vite cache: `rm -rf node_modules/.vite`

## License

MIT
