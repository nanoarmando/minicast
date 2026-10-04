#!/bin/zsh
# One-time copy of Tinycast Fork's or the official Tinycast's data into Minicast. The source is only read.
# Usage: ./Scripts/migrate-to-minicast.sh [--from fork|official] [--force]   (see --help)
setopt err_exit no_unset pipe_fail

SCRIPT_NAME=${0:t}

MINICAST_ID="com.minicast.app"
MINICAST_APP="/Applications/Minicast.app"

SUPPORT="$HOME/Library/Application Support"
CACHES="$HOME/Library/Caches"
MINICAST_CONFIG="$HOME/.config/minicast"

# The Keychain scopes Minicast reads; they come from KeychainSecretStore and ExtensionOAuthKeychain.
MINICAST_SERVICES=(
    "$MINICAST_ID.ai-api-keys" "$MINICAST_ID.mcp-secrets"
    "$MINICAST_ID.installed-ai-environment" "$MINICAST_ID.extensions-oauth"
)

# Set by select_source.
SOURCE_NAME="" SOURCE_ID="" SOURCE_CONFIG=""
SOURCE_SERVICES=()

select_source() {
    case $1 in
        fork)
            SOURCE_NAME="Tinycast Fork" SOURCE_ID="com.tinycast.app.fork"
            SOURCE_CONFIG="$HOME/.config/tinycast-fork"
            SOURCE_SERVICES=(
                "$SOURCE_ID.ai-api-keys" "$SOURCE_ID.mcp-secrets"
                "$SOURCE_ID.installed-ai-environment" "$SOURCE_ID.extensions-oauth"
            )
            ;;
        official)
            SOURCE_NAME="Tinycast" SOURCE_ID="com.tinycast.app"
            SOURCE_CONFIG="$HOME/.config/tinycast"
            SOURCE_SERVICES=(
                "$SOURCE_ID.ai-api-keys" "$SOURCE_ID.mcp-secrets"
                "$SOURCE_ID.installed-ai-environment" "com.tinycast.extensions.oauth"
            )
            ;;
        *) return 1 ;;
    esac
}

# Every key Minicast's settings.json accepts, copied from the raw values in
# Tinycast/Features/Settings/Model/SettingsFileKey.swift. Only an official source is filtered: its
# removed features' keys are dropped so Minicast does not report them as unknown settings at launch.
# Regenerate this list when that file changes.
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
    cat <<EOF2
Copies Tinycast Fork's or the official Tinycast's data into Minicast ($MINICAST_ID), once.

Usage: $SCRIPT_NAME [--from fork|official] [--force]

  --from fork       Copy from Tinycast Fork (com.tinycast.app.fork). The default.
  --from official   Copy from the official Tinycast (com.tinycast.app); settings.json keys of
                    features Minicast removed are dropped.
  --force           Move Minicast's existing data to ~/Documents/Backups/Minicast-<timestamp>/ first.

Copied: Application Support, Caches, the ~/.config folder, preferences, and the Keychain secrets for
AI providers, MCP servers, installed AI tools and extension OAuth. macOS asks to allow each Keychain
read; a denied item is skipped and reported.

Not copied: privacy permissions (Accessibility, Input Monitoring, ...) and the login item.

The source app and Minicast must be quit and "$MINICAST_APP" must be installed. If Minicast already
has data, the script stops unless --force is given.

The source app's files, preferences and Keychain items are never modified.
EOF2
}

say() { print -r -- "▸ $*"; }
die() { print -r -- "✗ $*" >&2; exit 1; }

is_running() { [[ -n "$(lsappinfo find "bundleid=$1" 2>/dev/null)" ]]; }
# `defaults read` still succeeds on a deleted domain cfprefsd has cached, so count its keys instead.
has_defaults() {
    (( $(defaults export "$1" - 2>/dev/null | plutil -convert xml1 -o - - 2>/dev/null | grep -c "<key>") > 0 ))
}

minicast_has_data() {
    [[ -e "$SUPPORT/$MINICAST_ID" || -e "$CACHES/$MINICAST_ID" || -e "$MINICAST_CONFIG" ]] \
        || has_defaults "$MINICAST_ID"
}

source_has_data() {
    [[ -e "$SUPPORT/$SOURCE_ID" || -e "$SOURCE_CONFIG" ]] || has_defaults "$SOURCE_ID"
}

# Moves Minicast's data aside, so `--force` never destroys anything.
back_up_minicast() {
    local backup="$HOME/Documents/Backups/Minicast-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$backup"
    [[ -e "$SUPPORT/$MINICAST_ID" ]] && mv "$SUPPORT/$MINICAST_ID" "$backup/Application Support"
    [[ -e "$CACHES/$MINICAST_ID" ]] && mv "$CACHES/$MINICAST_ID" "$backup/Caches"
    [[ -e "$MINICAST_CONFIG" ]] && mv "$MINICAST_CONFIG" "$backup/config"
    if has_defaults "$MINICAST_ID"; then
        defaults export "$MINICAST_ID" "$backup/$MINICAST_ID.plist"
        defaults delete "$MINICAST_ID"
    fi
    say "Existing Minicast data moved to $backup"
}

# Prints settings.json with only the keys Minicast knows; sections stay nested as in the file.
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
    local force=0 source=fork
    while (( $# )); do
        case $1 in
            --force) force=1 ;;
            --from)
                (( $# >= 2 )) || { usage >&2; die "--from needs fork or official." }
                source=$2
                shift
                ;;
            -h|--help) usage; return 0 ;;
            *) usage >&2; die "Unknown argument: $1" ;;
        esac
        shift
    done
    select_source "$source" || { usage >&2; die "Unknown source: $source (use fork or official)." }

    is_running "$SOURCE_ID" && die "Quit $SOURCE_NAME first."
    is_running "$MINICAST_ID" && die "Quit Minicast first."
    [[ -d "$MINICAST_APP" ]] || die "\"$MINICAST_APP\" is not installed. Install it (without opening it) and run again."
    source_has_data || die "No $SOURCE_NAME data found ($SUPPORT/$SOURCE_ID, $SOURCE_CONFIG or the $SOURCE_ID preferences)."
    if minicast_has_data; then
        (( force )) || die "Minicast already has data. Run again with --force to move it to ~/Documents/Backups first."
        back_up_minicast
    fi

    local -a migrated skipped

    if [[ -d "$SUPPORT/$SOURCE_ID" ]]; then
        say "Copying Application Support…"
        cp -Rp "$SUPPORT/$SOURCE_ID" "$SUPPORT/$MINICAST_ID"
        migrated+=("Application Support")
    fi
    if [[ -d "$CACHES/$SOURCE_ID" ]]; then
        say "Copying Caches…"
        cp -Rp "$CACHES/$SOURCE_ID" "$CACHES/$MINICAST_ID"
        rm -f "$CACHES/$MINICAST_ID/update-check.json"
        migrated+=("Caches")
    fi
    if [[ -d "$SOURCE_CONFIG" ]]; then
        say "Copying ${SOURCE_CONFIG/#$HOME/~}…"
        cp -Rp "$SOURCE_CONFIG" "$MINICAST_CONFIG"
        if [[ $source == official && -f "$MINICAST_CONFIG/settings.json" ]]; then
            local filtered
            if filtered=$(filter_settings "$MINICAST_CONFIG/settings.json"); then
                print -r -- "$filtered" > "$MINICAST_CONFIG/settings.json"
            else
                skipped+=("settings.json filtering (copied unchanged; Minicast may report unknown settings)")
            fi
        fi
        migrated+=("${SOURCE_CONFIG/#$HOME/~} → ~/.config/minicast")
    fi
    if has_defaults "$SOURCE_ID"; then
        say "Copying preferences…"
        defaults export "$SOURCE_ID" - | defaults import "$MINICAST_ID" -
        migrated+=("Preferences")
    fi

    say "Copying Keychain secrets (macOS asks to allow each read)…"
    local index result
    for (( index = 1; index <= ${#SOURCE_SERVICES}; index++ )); do
        result=$(copy_keychain_service "${SOURCE_SERVICES[index]}" "${MINICAST_SERVICES[index]}" "$MINICAST_APP")
        migrated+=("Keychain ${SOURCE_SERVICES[index]}: ${result%% *} secret(s)")
        [[ $result == *" "?* ]] && skipped+=(${=result#* })
    done

    print
    print "Migrated from $SOURCE_NAME:"
    printf '  - %s\n' "${migrated[@]}"
    print "Skipped:"
    if (( ${#skipped} )); then printf '  - %s\n' "${skipped[@]}"; else print "  (nothing)"; fi
    print "Manual steps:"
    print "  - Open \"$MINICAST_APP\" and grant Accessibility, Input Monitoring and any other privacy"
    print "    permission it asks for (permissions are tied to the app's signature and are not copied)."
    print "  - Re-enable \"Launch at login\" in Minicast's settings if you used it."
    print "  - Re-enter any skipped secret in Minicast's settings."
    print "  - Once Minicast works, remove $SOURCE_NAME from /Applications if you no longer need it."
}

# Sourcing the file (for testing a function) defines everything without running the migration.
if [[ $ZSH_EVAL_CONTEXT == toplevel ]]; then main "$@"; fi
