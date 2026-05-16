# bail. — public site

These three pages are the public website for **bail.** They power the App Store's required URLs:

- `index.html` → marketing URL
- `privacy.html` → privacy policy URL
- `support.html` → support URL

## How to publish (5 minutes)

1. Go to [github.com/new](https://github.com/new) and create a new **public** repo named `bail-app`.
2. From your terminal, in this folder:
   ```bash
   cd /Users/josephsacco/Documents/Bail/docs
   git init
   git add .
   git commit -m "Initial site"
   git branch -M main
   git remote add origin https://github.com/<your-username>/bail-app.git
   git push -u origin main
   ```
3. On GitHub: **Settings → Pages**
4. Under "Build and deployment":
   - **Source**: `Deploy from a branch`
   - **Branch**: `main` / `/ (root)`
5. Save. Wait ~1 minute.

Your site will be live at:
```
https://<your-username>.github.io/bail-app/
https://<your-username>.github.io/bail-app/privacy.html
https://<your-username>.github.io/bail-app/support.html
```

Plug those URLs into App Store Connect → App Information.

## Updating

After any change, just `git add . && git commit -m "update" && git push`. GitHub Pages redeploys in ~30 seconds.
