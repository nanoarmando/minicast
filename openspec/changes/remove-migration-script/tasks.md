## 1. Remove the script

- [ ] 1.1 Delete `Scripts/migrate-to-minicast.sh` and confirm nothing else references it
  (`rg migrate-to-minicast`)

## 2. Docs

- [ ] 2.1 Replace README's "Migrating from Tinycast" with "Moving from Tinycast or Raycast", based on the
  `.tinycast` import, the Raycast import, bundles and the settings file
- [ ] 2.2 Update `AGENTS.md` (the posture line about the external migration script),
  `docs/architecture.md` (Scripts folder listing) and `docs/release.md` (second-Mac install)
