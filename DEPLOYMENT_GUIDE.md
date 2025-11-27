# Deploy Support Website (Private Repo)

## Option 1: Netlify (Easiest - Recommended) ⭐

Netlify works perfectly with private GitHub repos and is super easy to set up.

### Steps:

1. **Go to Netlify**: https://app.netlify.com
2. **Sign up/Login** with your GitHub account (free)
3. **Click "Add new site" → "Import an existing project"**
4. **Choose GitHub** and authorize Netlify
5. **Select your repository**: `olivertransf/Claveo`
6. **Configure build settings**:
   - **Base directory**: Leave empty (or `/` if needed)
   - **Build command**: Leave empty (no build needed)
   - **Publish directory**: Leave empty (or `/` if needed)
7. **Click "Deploy site"**

### Your site will be live at:
`https://[random-name].netlify.app`

### Custom Domain (Optional):
- Go to Site settings → Domain management
- Add a custom domain like `claveo.app` or `claveo.support`

### Auto-deploy:
- Every time you push to `main`, Netlify automatically redeploys
- No manual steps needed!

---

## Option 2: Vercel (Alternative)

Similar to Netlify, also very easy:

1. Go to: https://vercel.com
2. Sign up with GitHub
3. Click "Add New Project"
4. Import your `Claveo` repository
5. Deploy (no configuration needed)

---

## Option 3: Cloudflare Pages

1. Go to: https://pages.cloudflare.com
2. Connect GitHub account
3. Select repository
4. Build settings: Leave defaults
5. Deploy

---

## Quick Comparison

| Service | Free Tier | Private Repos | Custom Domain | Ease of Setup |
|---------|-----------|---------------|---------------|---------------|
| Netlify | ✅ Yes | ✅ Yes | ✅ Yes | ⭐⭐⭐⭐⭐ |
| Vercel | ✅ Yes | ✅ Yes | ✅ Yes | ⭐⭐⭐⭐⭐ |
| Cloudflare | ✅ Yes | ✅ Yes | ✅ Yes | ⭐⭐⭐⭐ |
| GitHub Pages | ✅ Yes | ❌ No | ✅ Yes | ⭐⭐⭐ |

**Recommendation**: Use **Netlify** - it's the easiest and most straightforward!

