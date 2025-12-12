# GitHub OAuth Setup for CMS

The 404 error occurs because the GitHub backend requires a GitHub OAuth app to be set up. Here's how to fix it:

## Option 1: Use DecapBridge (Easiest - Recommended)

DecapBridge is a service that handles authentication for Decap CMS without requiring Netlify Identity or GitHub OAuth setup.

1. Go to https://decapbridge.com
2. Sign up for free
3. Connect your GitHub repository
4. Get your API endpoint
5. Update `admin/config.yml` to use DecapBridge backend

**This is the simplest solution and works immediately!**

---

## Option 2: Set Up GitHub OAuth App

If you want to use GitHub authentication directly:

### Step 1: Create GitHub OAuth App

1. Go to https://github.com/settings/developers
2. Click **"New OAuth App"**
3. Fill in:
   - **Application name**: `Claveo CMS`
   - **Homepage URL**: `https://your-site-url.netlify.app`
   - **Authorization callback URL**: `https://your-site-url.netlify.app/admin/`
4. Click **"Register application"**
5. **Copy the Client ID** (you'll need this)
6. Click **"Generate a new client secret"** and **copy the secret** (save it now - you won't see it again!)

### Step 2: Deploy an OAuth Proxy

Since GitHub OAuth can't run directly in the browser, you need a serverless function to handle the OAuth flow.

**Option A: Use Netlify Functions (Recommended)**

Create `netlify/functions/github-oauth.js`:

```javascript
exports.handler = async (event, context) => {
  // OAuth proxy implementation
  // This is complex - consider using DecapBridge instead
};
```

**Option B: Use DecapBridge (Much Easier)**

Just use Option 1 above - it's designed for this exact use case!

---

## Option 3: Use GitHub's Web Editor (Simplest Right Now)

While you set up one of the above:

1. Go to https://github.com/olivertransf/Claveo
2. Click on `index.html`
3. Click the pencil icon to edit
4. Make changes and commit
5. Netlify auto-deploys

---

## Recommended Solution

**Use DecapBridge** - it's free, easy to set up, and designed specifically for this use case. It will work immediately without any OAuth complexity.

Would you like me to help set up DecapBridge, or would you prefer to set up GitHub OAuth manually?
