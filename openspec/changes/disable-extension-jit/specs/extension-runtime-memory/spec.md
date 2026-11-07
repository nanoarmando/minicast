## Purpose

Keep Minicast's memory bounded while Raycast extensions run repeatedly, so a long-running process
stays within the resident memory budget no matter how long extensions keep refreshing.

## ADDED Requirements

### Requirement: Repeated extension runs do not grow memory

Minicast SHALL keep its memory footprint bounded while extension commands run repeatedly. Extension
runs MUST NOT leave memory regions allocated after the run ends.

#### Scenario: Menu-bar and background refreshes over time

- **GIVEN** a Release build with four extension commands refreshing every minute
- **WHEN** Minicast runs for 30 minutes
- **THEN** `vmmap` reports no growing set of untagged 512 KB regions
- **AND** the memory footprint stays within the 100 MB resident budget of `docs/standards.md`

#### Scenario: Interactive command opened many times

- **GIVEN** an installed extension with a view command
- **WHEN** the user opens and closes that command repeatedly
- **THEN** memory returns to a stable level instead of growing with each launch

### Requirement: Extensions keep working without the JIT

Every extension command that works today SHALL keep working, with the same results, when JavaScript
runs without the JIT compiler.

#### Scenario: Heavy interactive extension

- **GIVEN** an extension that lists and filters thousands of items (Iconify, Kill Process)
- **WHEN** the user opens it, types to filter and scrolls
- **THEN** results appear and update without a noticeable delay compared with the JIT build

#### Scenario: Extension test harnesses

- **WHEN** the extension harnesses run
- **THEN** they pass unchanged
