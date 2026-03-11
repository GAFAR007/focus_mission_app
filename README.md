# focus_mission_app

Flutter frontend for Focus Mission.

## Push To Deploy

Pushes to `main` now deploy the web app to Netlify through GitHub Actions in
`.github/workflows/deploy-web.yml`.

Required GitHub repository secrets:

- `NETLIFY_AUTH_TOKEN`
- `NETLIFY_SITE_ID`

Deployment flow:

1. GitHub Actions runs on every push to `main`.
2. The workflow installs Flutter, runs `flutter analyze` and `flutter test`.
3. It builds the production web bundle with `flutter build web --release`.
4. It deploys `build/web` to Netlify.

The Flutter web app also ships `web/_redirects` so direct route refreshes keep
loading `index.html` instead of returning a Netlify 404.
