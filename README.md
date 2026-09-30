# focus_mission_app

Flutter frontend for Focus Mission.

## Production releases

Tell the coding agent to deploy. It follows [RELEASE.md](RELEASE.md), reviews the
actual changes and runs the guarded command:

```sh
node tool/release.mjs deploy --review .release-work/review.json
```

This prepares the version/history, validates both repositories in clean archives,
creates release commits/tags and deploys through the existing Render and Netlify
services. Local builds do not increment versions.

Required GitHub repository secrets:

- `NETLIFY_AUTH_TOKEN`
- `NETLIFY_SITE_ID`

GitHub Actions checks version/source consistency on pushes to `main`. Manual
workflow dispatch can republish an already validated release after confirming
the paired backend is live. Ordinary unversioned pushes cannot publish.

The Flutter web app also ships `web/_redirects` so direct route refreshes keep
loading `index.html` instead of returning a Netlify 404.
