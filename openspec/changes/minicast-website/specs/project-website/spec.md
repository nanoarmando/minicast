## ADDED Requirements

### Requirement: Landing page content
The project SHALL publish one landing page in English that presents Minicast: its name and icon, the
statement "Minicast is Tinycast for every Mac: a small, native launcher that runs from macOS 13 on Intel
and Apple silicon. It started as a personal fork to keep older Macs useful without giving up great
tools.", the main features, the requirements (macOS 13 or later, Intel or Apple silicon), install steps
including clearing the quarantine flag, a link to the source repository, and a credit to Tinycast by Abu
Ammar under AGPL-3.0 with a link to the upstream repository.

#### Scenario: Visitor reads the page
- **WHEN** a visitor opens `https://nanoarmando.github.io/minicast/`
- **THEN** they see what Minicast is, what it needs, how to install it, and that it is based on Tinycast

#### Scenario: No upstream features advertised
- **WHEN** the visitor reads the features list
- **THEN** it lists only features Minicast ships, never removed ones such as Dictation, Notes or Snippets

### Requirement: Download the latest release
The page SHALL offer a download button that always leads to the latest Minicast release on GitHub,
without editing the page for each release.

#### Scenario: New release published
- **WHEN** a new Minicast release is published and a visitor clicks Download
- **THEN** they reach the newest release and its DMG

### Requirement: Static, private-by-default page
The page SHALL be static HTML and CSS, SHALL load no third-party scripts, analytics, trackers or remote
fonts, SHALL adapt to light and dark mode, and SHALL be usable on a phone without horizontal scrolling.

#### Scenario: Dark mode
- **WHEN** the visitor's system uses dark mode
- **THEN** the page uses its dark palette

#### Scenario: Phone width
- **WHEN** the page is opened at 375 points wide
- **THEN** all content is readable without horizontal scrolling

### Requirement: Publishing
Changes to the page on `main` SHALL publish to GitHub Pages automatically; changes to the app alone SHALL
NOT trigger a publish.

#### Scenario: Page edited
- **WHEN** a commit that changes `site/` is pushed to `main`
- **THEN** the published page is updated

#### Scenario: App code edited
- **WHEN** a commit that changes only app code is pushed
- **THEN** no publish runs
