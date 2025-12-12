# Website CMS Setup Guide

Since Netlify Identity is deprecated, here are the best options for editing your website:

## Option 1: GitHub OAuth with Decap CMS (Recommended)

Use Decap CMS with GitHub OAuth directly (no Netlify Identity needed).

### Setup Steps:

1. **Create a GitHub OAuth App**:
   - Go to https://github.com/settings/developers
   - Click **New OAuth App**
   - Set **Application name**: `Claveo CMS`
   - Set **Homepage URL**: `https://your-site-url.netlify.app`
   - Set **Authorization callback URL**: `https://your-site-url.netlify.app/admin/`
   - Click **Register application**
   - Copy the **Client ID** and create a **Client Secret**

2. **Update the config**:
   - Open `admin/config.yml`
   - Update the `repo` field with your GitHub username/repo (e.g., `olivertran/Claveo`)
   - You'll need to add the Client ID to the config

3. **Access the CMS**:
   - Go to `https://your-site-url.netlify.app/admin/`
   - You'll authenticate with GitHub directly

**Note**: This requires setting up an OAuth proxy or using a serverless function. For simpler setup, see Option 2.

---

## Option 2: Use GitHub's Built-in Editor (Simplest)

Edit files directly in GitHub's web interface - no additional setup needed!

1. Go to your GitHub repository
2. Navigate to `index.html` or `privacy-policy.html`
3. Click the **pencil icon** to edit
4. Make your changes and commit
5. Netlify will automatically deploy your changes

**Pros**: Zero setup, works immediately
**Cons**: Less user-friendly than a CMS interface

---

## Option 3: Use CloudCannon (Paid, Easiest)

CloudCannon provides a visual editor for static sites.

1. Sign up at https://cloudcannon.com
2. Connect your GitHub repository
3. Edit your site visually
4. Changes sync to GitHub and deploy automatically

**Cost**: ~$15/month for basic plan
**Pros**: Visual editor, very user-friendly
**Cons**: Paid service

---

## Option 4: Use Tina CMS (Free, Modern Alternative)

Tina CMS is a modern, open-source CMS for static sites.

1. Install Tina CMS: `npm install -g @tinacms/cli`
2. Set up Tina configuration
3. Get a visual editing interface

**Pros**: Modern, actively maintained
**Cons**: Requires Node.js setup

---

## Quick Recommendation

**For immediate use**: Use **Option 2** (GitHub's web editor) - it works right now with zero setup.

**For long-term**: Consider **Option 3** (CloudCannon) if you want a visual editor and don't mind paying, or set up **Option 1** if you want free and can handle the OAuth setup.

---

## Current Setup (Deprecated)

⚠️ **Note**: The current config uses `git-gateway` which relies on Netlify Identity (deprecated). 
The config has been updated to use `github` backend instead, but requires OAuth app setup as described in Option 1.
