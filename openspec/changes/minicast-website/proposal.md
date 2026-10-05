## Why

Minicast needs a public home that explains what it is and where to download it. The `website/` folder is
upstream's Next.js site, built for Cloudflare Workers with paid features (Polar) and upstream media; it
does not describe Minicast and cannot be hosted on GitHub Pages as it is.

## What Changes

- A single static landing page for Minicast, hosted on GitHub Pages at
  `https://nanoarmando.github.io/minicast/`: name and icon, the Minicast statement, main features,
  requirements, a download button for the latest release, install steps, and the credit to Tinycast.
- Plain HTML and CSS in a new `site/` folder, with no build step and no third-party scripts.
- A GitHub Actions workflow that publishes `site/` to Pages when it changes on `main`.
- **BREAKING** Upstream's `website/` folder and `Scripts/upload-website-media.sh` are removed.
- Repository metadata (description and homepage URL) points to the page.

## Capabilities

### New Capabilities

- `project-website`: the Minicast landing page, its content and how it is published.

### Modified Capabilities

- `local-build`: the "No upstream CI" requirement allows the one Pages workflow owned by Minicast.

## Impact

- New `site/` (HTML, CSS, icon), new `.github/workflows/pages.yml`.
- Removed `website/`, `Scripts/upload-website-media.sh`.
- `README.md` and `AGENTS.md` link the site; GitHub repository settings (Pages source: GitHub Actions).
- Depends on `rebrand-to-minicast` (repository name, icon, release asset names).
