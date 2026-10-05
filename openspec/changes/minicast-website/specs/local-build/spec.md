## MODIFIED Requirements

### Requirement: No upstream CI
The project SHALL NOT contain GitHub Actions workflows that depend on upstream secrets, release channels,
or website hosting. The only workflow SHALL be the one that publishes `site/` to the project's GitHub
Pages; app builds and releases stay local.

#### Scenario: Push app changes
- **WHEN** the user pushes a branch that does not change `site/`
- **THEN** no workflow is triggered

#### Scenario: Push site changes to main
- **WHEN** the user pushes a change to `site/` on `main`
- **THEN** only the Pages workflow runs, using no secrets beyond the default repository token
