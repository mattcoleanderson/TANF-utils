#!/bin/bash
# Add test users to the local database
# Usage: add_test_user.sh [user_key|--list|--all]
#
# Configure users in test_users.json (same directory as this script)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UTILS_ROOT="${TANF_UTILS_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
CONFIG_FILE="$UTILS_ROOT/personal/scripts/test_users.json"
TANF_WORKTREE_ROOT="${TANF_WORKTREE_ROOT:-$HOME/repos/work/TANF-app}"
BACKEND_DIR="$TANF_WORKTREE_ROOT/00-main/tdrs-backend"

# ============================================================================
# Helper functions
# ============================================================================

check_dependencies() {
    if ! command -v jq &> /dev/null; then
        echo "Error: jq is required but not installed."
        echo "Install with: brew install jq"
        exit 1
    fi

    if [ ! -f "$CONFIG_FILE" ]; then
        echo "Error: Config file not found: $CONFIG_FILE"
        echo "Creating template..."
        create_template
        exit 1
    fi

    if [ ! -d "$BACKEND_DIR" ]; then
        echo "Error: TANF backend not found: $BACKEND_DIR"
        echo "Set TANF_WORKTREE_ROOT to the directory containing 00-main."
        exit 1
    fi
}

create_template() {
    cat > "$CONFIG_FILE" <<'TEMPLATE'
{
  "users": {
    "john": {
      "username": "johndoe",
      "first_name": "John",
      "last_name": "Doe",
      "email": "manderson@teamraft.com",
      "group": "Data Analyst",
      "stt": "Alabama"
    }
  }
}
TEMPLATE
    echo "Created template at: $CONFIG_FILE"
    echo "Edit this file to add more users, then run this script again."
}

show_usage() {
    echo "Usage: $0 [user_key|--list|--all]"
    echo ""
    echo "Options:"
    echo "  user_key  - Create a specific user by key"
    echo "  --list    - List all available test users"
    echo "  --all     - Create all test users"
    echo ""
    echo "Valid groups: OFA Admin, OFA System Admin, Data Analyst, OFA Regional Staff, ACF OCIO, DIGIT Team, Developer"
    echo ""
    echo "Config file: $CONFIG_FILE"
}

list_users() {
    echo "Available test users:"
    echo ""
    jq -r '.users | to_entries[] | "  \(.key): \(.value.first_name) \(.value.last_name) (\(.value.username))\n    Email: \(.value.email)\n    Group: \(.value.group // "none")\n    STT: \(.value.stt // "none")\n"' "$CONFIG_FILE"
}

create_user() {
    local key="$1"

    local username=$(jq -r ".users[\"$key\"].username" "$CONFIG_FILE")
    local first_name=$(jq -r ".users[\"$key\"].first_name" "$CONFIG_FILE")
    local last_name=$(jq -r ".users[\"$key\"].last_name" "$CONFIG_FILE")
    local email=$(jq -r ".users[\"$key\"].email" "$CONFIG_FILE")
    local group=$(jq -r ".users[\"$key\"].group // empty" "$CONFIG_FILE")
    local stt=$(jq -r ".users[\"$key\"].stt // empty" "$CONFIG_FILE")

    if [ "$first_name" == "null" ]; then
        echo "Error: User key '$key' not found in config."
        return 1
    fi

    echo "Creating user: $first_name $last_name ($username)..."
    [ -n "$group" ] && echo "  Group: $group"
    [ -n "$stt" ] && echo "  STT: $stt"

    (cd "$BACKEND_DIR" && docker compose -f docker-compose.yml exec -T web python manage.py shell_plus <<EOF
from tdpservice.users.models import AccountApprovalStatusChoices

# Get or create user
user, created = User.objects.get_or_create(
    username='$username',
    defaults={
        'email': '$email',
        'first_name': '$first_name',
        'last_name': '$last_name',
        'account_approval_status': AccountApprovalStatusChoices.APPROVED,
        'is_active': True,
    }
)

if created:
    print(f'Created new user: {user.first_name} {user.last_name}')
else:
    # Update existing user info
    user.first_name = '$first_name'
    user.last_name = '$last_name'
    user.email = '$email'
    user.account_approval_status = AccountApprovalStatusChoices.APPROVED
    user.is_active = True
    print(f'Updated existing user: {user.first_name} {user.last_name}')

# Set group if specified
group_name = '$group'
if group_name:
    try:
        group = Group.objects.get(name=group_name)
        user.groups.clear()
        user.groups.add(group)
        print(f'  Set group: {group_name}')
    except Group.DoesNotExist:
        print(f'  WARNING: Group "{group_name}" not found!')

# Set STT if specified
stt_name = '$stt'
if stt_name:
    try:
        stt = STT.objects.get(name=stt_name)
        user.stt = stt
        print(f'  Set STT: {stt_name}')
    except STT.DoesNotExist:
        print(f'  WARNING: STT "{stt_name}" not found!')
else:
    user.stt = None

user.save()

print('')
print('User details:')
print(f'  Username: {user.username}')
print(f'  Email: {user.email}')
print(f'  Name: {user.first_name} {user.last_name}')
print(f'  Status: {user.account_approval_status}')
print(f'  Group: {user.groups.first().name if user.groups.exists() else "None"}')
print(f'  STT: {user.stt}')
EOF
    )
}

# ============================================================================
# Main script
# ============================================================================

check_dependencies

case "$1" in
    --list)
        list_users
        ;;
    --all)
        echo "Creating all test users..."
        echo ""
        for key in $(jq -r '.users | keys[]' "$CONFIG_FILE"); do
            create_user "$key"
            echo ""
        done
        ;;
    "")
        show_usage
        echo ""
        list_users
        ;;
    *)
        if jq -e ".users[\"$1\"]" "$CONFIG_FILE" > /dev/null 2>&1; then
            create_user "$1"
        else
            echo "Error: User key '$1' not found."
            echo ""
            list_users
            exit 1
        fi
        ;;
esac
