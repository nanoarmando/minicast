## Context

`website/` is upstream's Next.js + Fumadocs site deployed to Cloudflare Workers (`wrangler`), with Polar
payments and media in an R2 bucket (`Scripts/upload-website-media.sh`). Minicast has no workflows today
(`local-build` spec: no upstream CI). The repository becomes `nanoarmando/minicast` in
`rebrand-to-minicast`, so the Pages URL is `https://nanoarmando.github.io/minicast/`.

## Goals / Non-Goals

**Goals:** one fast static page; zero build tooling; automatic publishing; light and dark.

**Non-Goals:** documentation site, blog, changelog page, custom domain, analytics, localization.

## Decisions

### 1. Plain static files in `site/`
`site/index.html`, `site/style.css`, `site/icon.png` (rendered from the M monogram) and a favicon. System
font stack, CSS custom properties for colors with a `prefers-color-scheme` dark palette, a centered
single column. `docs/` is not used because it holds the Markdown documentation.
- Alternative: export the Next.js site statically. Rejected: heavy toolchain and content that describes
  upstream.

### 2. Download link
The button links to `https://github.com/nanoarmando/minicast/releases/latest`, which GitHub redirects to
the newest release, so the page never needs a version edit. No API call from the page.

### 3. Publishing workflow
`.github/workflows/pages.yml` runs on `push` to `main` with `paths: [site/**]` and on manual dispatch,
using `actions/configure-pages`, `actions/upload-pages-artifact` (path `site`) and `actions/deploy-pages`
with `pages: write` and `id-token: write` permissions only. Action versions are checked against their
latest releases when the workflow is written. The repository's Pages source is set to "GitHub Actions"
(`gh api`), and its description and homepage point to the page.

### 4. Remove upstream site
Delete `website/` and `Scripts/upload-website-media.sh`; drop their mentions from `README.md`,
`AGENTS.md` and `docs/` (any left after `rebrand-to-minicast`).

## Risks / Trade-offs

- [Feature list drifts from the app] → The list is short and reviewed with each feature change.
- [Pages URL changes if the repository is renamed again] → GitHub redirects repository URLs, not Pages
  URLs; update links if that happens.

## Migration Plan

Implement after `rebrand-to-minicast` is merged and the repository is renamed. Rollback: disable Pages
and revert the commit.
