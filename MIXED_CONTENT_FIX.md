# Mixed Content Error Fix

## Problem

The frontend is served over HTTPS (CloudFront), but the backend API uses HTTP (ALB without SSL). Modern browsers block HTTP requests from HTTPS pages for security reasons.

## Solutions

### Option 1: Add HTTPS to ALB (Recommended for Production)

1. **Get a domain name** (e.g., from Route53 or any registrar)

2. **Request SSL certificate** in AWS Certificate Manager:
   ```bash
   aws acm request-certificate \
     --domain-name api.yourdomain.com \
     --validation-method DNS \
     --region us-east-1
   ```

3. **Update ALB** to use HTTPS listener with the certificate

4. **Update frontend** to use HTTPS API URL

### Option 2: Use Local Development (Quick Test)

For testing, run the frontend locally which can access HTTP endpoints:

```bash
cd frontend
npm install
npm run dev
```

Then access at `http://localhost:3000` (HTTP, not HTTPS)

### Option 3: Browser Override (Development Only)

**Chrome/Edge:**
1. Click the shield icon in address bar
2. Click "Load unsafe scripts"
3. This is temporary and resets on page reload

**Firefox:**
1. Click the lock icon
2. Click "Disable protection for now"

**⚠️ Warning**: This is insecure and only for development testing!

### Option 4: Deploy Frontend to HTTP S3 Website (Not Recommended)

Remove CloudFront and use S3 website hosting directly (HTTP):

1. Update `terraform/frontend.tf` to remove CloudFront
2. Use S3 website endpoint instead
3. Both frontend and backend will be HTTP

**⚠️ Warning**: Not recommended for production due to lack of HTTPS and CDN benefits.

## Recommended Approach

For a production system, **Option 1 (HTTPS on ALB)** is the correct solution:

### Step-by-Step: Add HTTPS to Backend

1. **Get a domain** (if you don't have one):
   - Register via Route53 or any registrar
   - Example: `mydocprocessor.com`

2. **Create hosted zone** in Route53 (if using Route53):
   ```bash
   aws route53 create-hosted-zone \
     --name mydocprocessor.com \
     --caller-reference $(date +%s)
   ```

3. **Request certificate**:
   ```bash
   aws acm request-certificate \
     --domain-name api.mydocprocessor.com \
     --validation-method DNS \
     --region us-east-1
   ```

4. **Add DNS validation record** (ACM will provide this)

5. **Update `terraform/alb.tf`** to add HTTPS listener:
   ```hcl
   resource "aws_lb_listener" "https" {
     load_balancer_arn = aws_lb.api.arn
     port              = "443"
     protocol          = "HTTPS"
     ssl_policy        = "ELBSecurityPolicy-2016-08"
     certificate_arn   = "arn:aws:acm:REGION:ACCOUNT:certificate/CERT_ID"

     default_action {
       type             = "forward"
       target_group_arn = aws_lb_target_group.api.arn
     }
   }
   ```

6. **Apply Terraform**:
   ```bash
   cd terraform
   terraform apply
   ```

7. **Update frontend `.env`**:
   ```
   VITE_API_URL=https://api.mydocprocessor.com
   ```

8. **Rebuild and redeploy frontend**:
   ```bash
   cd frontend
   npm run build
   aws s3 sync dist/ s3://YOUR-FRONTEND-BUCKET/
   aws cloudfront create-invalidation --distribution-id YOUR-DIST-ID --paths "/*"
   ```

## Current Workaround

Until you add HTTPS to the backend, you can:

1. **Test locally**:
   ```bash
   cd frontend
   npm run dev
   # Access at http://localhost:3000
   ```

2. **Test API directly** with curl:
   ```bash
   # Signup
   curl -X POST http://doc-processor-alb-XXXXX.elb.amazonaws.com/auth/signup \
     -H 'Content-Type: application/json' \
     -d '{"email":"test@test.com","password":"test123","name":"Test User"}'
   
   # Login
   curl -X POST http://doc-processor-alb-XXXXX.elb.amazonaws.com/auth/login \
     -H 'Content-Type: application/json' \
     -d '{"email":"test@test.com","password":"test123"}'
   
   # Upload
   curl -X POST http://doc-processor-alb-XXXXX.elb.amazonaws.com/upload \
     -F "file=@document.pdf"
   ```

## Summary

- **Problem**: HTTPS frontend + HTTP backend = Mixed content error
- **Quick Fix**: Run frontend locally (`npm run dev`)
- **Production Fix**: Add HTTPS to ALB with SSL certificate
- **Backend APIs**: ✅ All working (signup, login, upload, jobs)
- **Frontend**: ✅ Built and deployed to CloudFront

The system is fully functional - just needs HTTPS on the backend for the CloudFront frontend to work!
