#!/bin/zsh
# One-time copy of the official Tinycast's data into Tinycast Fork. The official app is only read.
# Usage: ./Scripts/migrate-from-official.sh [--force]   (see --help)
setopt err_exit no_unset pipe_fail

SCRIPT_NAME=${0:t}

OFFICIAL_ID="com.tinycast.app"
FORK_ID="com.tinycast.app.fork"
FORK_APP="/Applications/Tinycast Fork.app"

SUPPORT="$HOME/Library/Application Support"
CACHES="$HOME/Library/Caches"
OFFICIAL_CONFIG="$HOME/.config/tinycast"
FORK_CONFIG="$HOME/.config/tinycast-fork"

# Official service → fork service. The scopes come from KeychainSecretStore and ExtensionOAuthKeychain.
KEYCHAIN_SERVICES=(
    "$OFFICIAL_ID.ai-api-keys"              "$FORK_ID.ai-api-keys"
    "$OFFICIAL_ID.mcp-secrets"              "$FORK_ID.mcp-secrets"
    "$OFFICIAL_ID.installed-ai-environment" "$FORK_ID.installed-ai-environment"
    "com.tinycast.extensions.oauth"         "$FORK_ID.extensions-oauth"
)

# Every key the fork's settings.json accepts, copied from the raw values in
# Tinycast/Features/Settings/Model/SettingsFileKey.swift. Keys of removed features are dropped so the
# fork does not report them as unknown settings at launch. Regenerate this list when that file changes.
SETTINGS_KEYS=(
    general.showInMenuBar general.popToRootSeconds general.escapeKeyBehavior
    general.autoSwitchInputSource appearance.theme appearance.interfaceSize appearance.compactMode
    appearance.showFavoritesInCompactMode appearance.followCursorAcrossDisplays
    appearance.dragToReposition hyperKey.key hyperKey.includesShift hyperKey.quickPress
    calculator.numberStyle search.showsSuggestions search.sensitivity applications.searchScopes
    commands.enabled commands.showInLauncher appleShortcuts.enabled ai.enabled ai.webSearch
    ai.systemPrompt ai.systemPromptEnabled ai.retentionDays ai.opensTo ai.newChatAfterMinutes
    ai.toolRounds fileSearch.enabled fileSearch.scopes fileSearch.ignorePatterns
    windowManagement.enabled windowManagement.showInLauncher windowManagement.gap
    windowManagement.cycle windowManagement.layoutsShowInLauncher windowManagement.roomsShowInLauncher
    windowManagement.shortcuts windowManagement.customSizes windowManagement.layouts
    windowManagement.rooms clipboard.enabled clipboard.retentionDays clipboard.defaultAction
    clipboard.disabledApps emoji.skinTone emoji.gridColumns calendar.showInLauncher
    calendar.launcherLimit calendar.span calendar.joinWindowMinutes calendar.autoJoinConfirms
    calendar.meetingBrowser calendar.menuBar calendar.menuBarUpcomingEvents
    calendar.menuBarLinkedEventsOnly calendar.menuBarHidesWhenEmpty
    calendar.hideCurrentEventAfterMinutes extensions.showInLauncher
)

usage() {
    cat <<EOF
Copies the official Tinycast ($OFFICIAL_ID) data into Tinycast Fork ($FORK_ID), once.

Usage: $SCRIPT_NAME [--force]

Copied: Application Support, Caches (without the update check), ~/.config/tinycast/ (settings.json
keys of removed features are dropped), preferences, and the Keychain secrets for AI providers, MCP
servers, installed AI tools and extension OAuth. macOS asks to allow each Keychain read; a denied
item is skipped and reported.

Not copied: privacy permissions (Accessibility, Input Monitoring, ...) and the login item.

Both apps must be quit and "$FORK_APP" must be installed. If the fork already has data, the script
stops unless --force is given, which first moves that data to
~/Documents/Backups/Tinycast-Fork-<timestamp>/.

The official app's files, preferences and Keychain items are never modified.
EOF
}

say() { print -r -- "▸ $*"; }
die() { print -r -- "✗ $*" >&2; exit 1; }

is_running() { [[ -n "$(lsappinfo find "bundleid=$1" 2>/dev/null)" ]]; }
# `defaults read` still succeeds on a deleted domain cfprefsd has cached, so count its keys instead.
has_defaults() {
    (( $(defaults export "$1" - 2>/dev/null | plutil -convert xml1 -o - - 2>/dev/null | grep -c "<key>") > 0 ))
}

fork_has_data() {
    [[ -e "$SUPPORT/$FORK_ID" || -e "$CACHES/$FORK_ID" || -e "$FORK_CONFIG" ]] || has_defaults "$FORK_ID"
}

# Moves the fork's data aside, so `--force` never destroys anything.
back_up_fork() {
    local backup="$HOME/Documents/Backups/Tinycast-Fork-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$backup"
    [[ -e "$SUPPORT/$FORK_ID" ]] && mv "$SUPPORT/$FORK_ID" "$backup/Application Support"
    [[ -e "$CACHES/$FORK_ID" ]] && mv "$CACHES/$FORK_ID" "$backup/Caches"
    [[ -e "$FORK_CONFIG" ]] && mv "$FORK_CONFIG" "$backup/config"
    if has_defaults "$FORK_ID"; then
        defaults export "$FORK_ID" "$backup/$FORK_ID.plist"
        defaults delete "$FORK_ID"
    fi
    say "Existing fork data moved to $backup"
}

# Prints settings.json with only the keys the fork knows; sections stay nested as in the file.
filter_settings() {
    osascript -l JavaScript - "$1" "${SETTINGS_KEYS[@]}" <<'JS'
ObjC.import("Foundation");
function run(argv) {
    const [path, ...allowed] = argv;
    const text = $.NSString.stringWithContentsOfFileEncodingError(path, $.NSUTF8StringEncoding, null);
    const settings = JSON.parse(ObjC.unwrap(text));
    const kept = {};
    for (const [section, members] of Object.entries(settings)) {
        if (members === null || typeof members !== "object" || Array.isArray(members)) continue;
        for (const [key, value] of Object.entries(members)) {
            if (!allowed.includes(section + "." + key)) continue;
            (kept[section] ??= {})[key] = value;
        }
    }
    return JSON.stringify(kept, null, 2);
}
JS
}

# The accounts stored under a service, read from attributes only so no secret is printed.
keychain_accounts() {
    security dump-keychain 2>/dev/null | awk -v service="$1" '
        /^keychain: / { if (svce == service && acct != "") print acct; acct = ""; svce = "" }
        /"acct"<blob>="/ { sub(/^[^=]*="/, ""); sub(/"$/, ""); acct = $0 }
        /"svce"<blob>="/ { sub(/^[^=]*="/, ""); sub(/"$/, ""); svce = $0 }
        END { if (svce == service && acct != "") print acct }'
}

# Prints the secret as hex. `-g` quotes a printable secret and hex-encodes any other, unambiguously.
read_secret_hex() {
    local line
    line=$(security find-generic-password -s "$1" -a "$2" -g 2>&1 >/dev/null) || return 1
    line=${line#password: }
    if [[ $line == 0x* ]]; then
        print -r -- "${${line%% *}#0x}"
    elif [[ $line == \"*\" ]]; then
        line=${line#\"}
        printf '%s' "${line%\"}" | xxd -p | tr -d '\n'
    else
        return 1
    fi
}

# Copies every account of one service; prints "<copied> <skipped list>".
copy_keychain_service() {
    local from=$1 to=$2 app=$3 account secret copied=0
    local -a skipped
    for account in "${(@f)$(keychain_accounts "$from")}"; do
        [[ -z $account ]] && continue
        if secret=$(read_secret_hex "$from" "$account") \
            && security add-generic-password -U -s "$to" -a "$account" -X "$secret" -T "$app" 2>/dev/null; then
            copied=$((copied + 1))
        else
            skipped+=("$from/$account")
        fi
        unset secret
    done
    print -r -- "$copied ${skipped[*]}"
}

main() {
    local force=0
    for argument in "$@"; do
        case $argument in
            --force) force=1 ;;
            -h|--help) usage; return 0 ;;
            *) usage >&2; die "Unknown argument: $argument" ;;
        esac
    done

    is_running "$OFFICIAL_ID" && die "Quit Tinycast first."
    is_running "$FORK_ID" && die "Quit Tinycast Fork first."
    [[ -d "$FORK_APP" ]] || die "\"$FORK_APP\" is not installed. Install it (without opening it) and run again."
    [[ -d "$SUPPORT/$OFFICIAL_ID" ]] || has_defaults "$OFFICIAL_ID" \
        || die "No official Tinycast data found ($SUPPORT/$OFFICIAL_ID or the $OFFICIAL_ID preferences)."
    if fork_has_data; then
        (( force )) || die "Tinycast Fork already has data. Run again with --force to move it to ~/Documents/Backups first."
        back_up_fork
    fi

    local -a migrated skipped

    if [[ -d "$SUPPORT/$OFFICIAL_ID" ]]; then
        say "Copying Application Support…"
        cp -Rp "$SUPPORT/$OFFICIAL_ID" "$SUPPORT/$FORK_ID"
        migrated+=("Application Support")
    fi
    if [[ -d "$CACHES/$OFFICIAL_ID" ]]; then
        say "Copying Caches…"
        cp -Rp "$CACHES/$OFFICIAL_ID" "$CACHES/$FORK_ID"
        rm -f "$CACHES/$FORK_ID/update-check.json"
        migrated+=("Caches")
    fi
    if [[ -d "$OFFICIAL_CONFIG" ]]; then
        say "Copying ~/.config/tinycast…"
        cp -Rp "$OFFICIAL_CONFIG" "$FORK_CONFIG"
        if [[ -f "$FORK_CONFIG/settings.json" ]]; then
            local filtered
            if filtered=$(filter_settings "$FORK_CONFIG/settings.json"); then
                print -r -- "$filtered" > "$FORK_CONFIG/settings.json"
            else
                skipped+=("settings.json filtering (copied unchanged; the fork may report unknown settings)")
            fi
        fi
        migrated+=("~/.config/tinycast")
    fi
    if has_defaults "$OFFICIAL_ID"; then
        say "Copying preferences…"
        defaults export "$OFFICIAL_ID" - | defaults import "$FORK_ID" -
        migrated+=("Preferences")
    fi

    say "Copying Keychain secrets (macOS asks to allow each read)…"
    local index result
    for (( index = 1; index < ${#KEYCHAIN_SERVICES}; index += 2 )); do
        result=$(copy_keychain_service "${KEYCHAIN_SERVICES[index]}" "${KEYCHAIN_SERVICES[index + 1]}" "$FORK_APP")
        migrated+=("Keychain ${KEYCHAIN_SERVICES[index]}: ${result%% *} secret(s)")
        [[ $result == *" "?* ]] && skipped+=(${=result#* })
    done

    print
    print "Migrated:"
    printf '  - %s\n' "${migrated[@]}"
    print "Skipped:"
    if (( ${#skipped} )); then printf '  - %s\n' "${skipped[@]}"; else print "  (nothing)"; fi
    print "Manual steps:"
    print "  - Open \"$FORK_APP\" and grant Accessibility, Input Monitoring and any other privacy"
    print "    permission it asks for (permissions are tied to the app's signature and are not copied)."
    print "  - Re-enable \"Launch at login\" in the fork's settings if you used it."
    print "  - Re-enter any skipped secret in the fork's settings."
}

# Sourcing the file (for testing a function) defines everything without running the migration.
if [[ $ZSH_EVAL_CONTEXT == toplevel ]]; then main "$@"; fi
