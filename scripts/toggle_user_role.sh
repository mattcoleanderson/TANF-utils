#!/bin/bash
# Toggle user role between different TDP groups
# Usage: toggle_user_role.sh [role] [--stt NAME] [--region NAME] [--env APP_NAME]
#
# Groups and their requirements:
#   - OFA System Admin: Full admin access, no STT/regions (federal staff)
#   - OFA Admin: Limited admin access, no STT/regions (federal staff)
#   - Data Analyst: Upload data files, REQUIRES STT (state/territory users)
#   - OFA Regional Staff: View files by region, REQUIRES region(s) (federal regional staff)
#   - DIGIT Team: Data analysis and feedback reports, no STT/regions (federal team)
#   - ACF OCIO: Security scan viewing only, no STT/regions (security team)
#   - Developer: All permissions, optional STT (DEV ONLY)

EMAIL="manderson@teamraft.com"
DEFAULT_STT="Alabama"
DEFAULT_REGION="Boston"
CF_APP=""
TANF_WORKTREE_ROOT="${TANF_WORKTREE_ROOT:-$HOME/repos/work/TANF-app}"
BACKEND_DIR="$TANF_WORKTREE_ROOT/00-main/tdrs-backend"

# Common Django model imports prepended to all shell commands.
# Redundant when using shell_plus locally, but required for remote (manage.py shell).
DJANGO_IMPORTS='from django.contrib.auth.models import Group
from tdpservice.users.models import User
from tdpservice.stts.models import STT, Region
'

# ============================================================================
# Execution wrapper
# ============================================================================

run_django() {
    local code
    code=$(cat)
    local full_code="${DJANGO_IMPORTS}${code}"

    if [ -n "$CF_APP" ]; then
        printf '%s\n' "$full_code" | cf ssh "$CF_APP" -c "cd /home/vcap/app && /home/vcap/deps/1/python/bin/python manage.py shell"
    else
        printf '%s\n' "$full_code" | (cd "$BACKEND_DIR" && docker compose -f docker-compose.yml exec -T web python manage.py shell_plus)
    fi
}

# ============================================================================
# Helper functions
# ============================================================================

show_usage() {
    echo "Usage: $0 [role] [OPTIONS]"
    echo ""
    echo "Roles:"
    echo "  sysadmin  - OFA System Admin (full admin, no location)"
    echo "  admin     - OFA Admin (limited admin, no location)"
    echo "  analyst   - Data Analyst (requires STT, default: $DEFAULT_STT)"
    echo "  regional  - OFA Regional Staff (requires region, default: $DEFAULT_REGION)"
    echo "             Regions: Boston, New York, Philadelphia, Atlanta, Chicago,"
    echo "                      Dallas, Kansas City, Denver, San Francisco, Seattle"
    echo "  digit     - DIGIT Team (federal reporting team, no location)"
    echo "  ocio      - ACF OCIO (security scan viewing, no location)"
    echo "  developer - Developer (DEV ONLY, all permissions)"
    echo ""
    echo "Options:"
    echo "  --stt NAME     Set STT (for analyst role, e.g., 'Alabama', 'California')"
    echo "  --region NAME  Set region (for regional role, e.g., 'Boston', 'Atlanta')"
    echo "  --env APP      Run against a Cloud Foundry app (e.g., 'tanf-dev')"
    echo ""
    echo "Examples:"
    echo "  $0 analyst                          # Local: Data Analyst with Alabama STT"
    echo "  $0 analyst --stt California         # Local: Data Analyst with California STT"
    echo "  $0 regional                         # Local: Regional Staff with Boston region"
    echo "  $0 regional --region Atlanta        # Local: Regional Staff with Atlanta region"
    echo "  $0 admin                            # Local: OFA Admin (no STT)"
    echo "  $0 analyst --env tanf-dev           # Remote: Data Analyst on tanf-dev"
    echo "  $0 admin --env tanf-staging         # Remote: OFA Admin on tanf-staging"
    exit 1
}

print_user_status() {
    run_django <<EOF
user = User.objects.get(username='$EMAIL')
print('')
print('=' * 50)
print('User Status:')
print('=' * 50)
print(f'  Username: {user.username}')
print(f'  Name: {user.first_name} {user.last_name}')
print(f'  Group: {user.groups.first().name if user.groups.exists() else "None"}')
print(f'  STT: {user.stt.name if user.stt else "None"}')
regions = list(user.regions.values_list('name', flat=True))
print(f'  Regions: {", ".join(regions) if regions else "None"}')
print(f'  Status: {user.account_approval_status}')
print('=' * 50)
EOF
}

set_role_no_location() {
    local group_name="$1"
    local display_name="$2"

    echo "Switching $EMAIL to $display_name (no STT/regions)..."
    run_django <<EOF
user = User.objects.get(username='$EMAIL')
group = Group.objects.get(name='$group_name')
user.groups.clear()
user.groups.add(group)
user.stt = None
user.regions.clear()
user.save()
EOF
    print_user_status
}

set_role_with_stt() {
    local group_name="$1"
    local display_name="$2"
    local stt_name="$3"

    echo "Switching $EMAIL to $display_name (STT: $stt_name)..."
    run_django <<EOF
user = User.objects.get(username='$EMAIL')
group = Group.objects.get(name='$group_name')
matches = STT.objects.filter(name__icontains='$stt_name'.strip())
if matches.count() == 1:
    stt = matches.first()
elif matches.filter(name__iexact='$stt_name'.strip()).exists():
    stt = matches.filter(name__iexact='$stt_name'.strip()).first()
elif matches.count() > 1:
    print(f'ERROR: Multiple STTs match "$stt_name":')
    for s in matches:
        print(f'  - {s.name}')
    exit(1)
else:
    print(f'ERROR: STT "$stt_name" not found!')
    print('Available STTs:')
    for s in STT.objects.all()[:20]:
        print(f'  - {s.name}')
    exit(1)

user.groups.clear()
user.groups.add(group)
user.stt = stt
user.regions.clear()
user.save()
EOF
    print_user_status
}

set_role_with_region() {
    local group_name="$1"
    local display_name="$2"
    local region_name="$3"

    echo "Switching $EMAIL to $display_name (Region: $region_name)..."
    run_django <<EOF
user = User.objects.get(username='$EMAIL')
group = Group.objects.get(name='$group_name')
try:
    region = Region.objects.get(name='$region_name')
except Region.DoesNotExist:
    print(f'ERROR: Region "$region_name" not found!')
    print('Available regions:')
    for r in Region.objects.all():
        print(f'  - {r.name}')
    exit(1)

user.groups.clear()
user.groups.add(group)
user.stt = None
user.regions.clear()
user.regions.add(region)
user.save()
EOF
    print_user_status
}

# ============================================================================
# Parse arguments
# ============================================================================

ROLE=""
STT_NAME="$DEFAULT_STT"
REGION_NAME="$DEFAULT_REGION"

while [[ $# -gt 0 ]]; do
    case $1 in
        --stt)
            STT_NAME="$2"
            shift 2
            ;;
        --region)
            REGION_NAME="$2"
            shift 2
            ;;
        --env)
            CF_APP="$2"
            shift 2
            ;;
        -h|--help)
            show_usage
            ;;
        *)
            if [ -z "$ROLE" ]; then
                ROLE="$1"
            else
                echo "Unknown argument: $1"
                show_usage
            fi
            shift
            ;;
    esac
done

# ============================================================================
# Validate CF connection if targeting remote env
# ============================================================================

if [ -n "$CF_APP" ]; then
    if ! cf target &>/dev/null; then
        echo "ERROR: Not logged into Cloud Foundry. Run 'cf login' first."
        exit 1
    fi
    echo "Targeting remote app: $CF_APP"
elif [ ! -d "$BACKEND_DIR" ]; then
    echo "ERROR: TANF backend not found: $BACKEND_DIR"
    echo "Set TANF_WORKTREE_ROOT to the directory containing 00-main."
    exit 1
fi

# ============================================================================
# Execute role switch
# ============================================================================

case "$ROLE" in
    sysadmin)
        set_role_no_location "OFA System Admin" "OFA System Admin"
        ;;
    admin)
        set_role_no_location "OFA Admin" "OFA Admin"
        ;;
    analyst)
        set_role_with_stt "Data Analyst" "Data Analyst" "$STT_NAME"
        ;;
    regional)
        set_role_with_region "OFA Regional Staff" "OFA Regional Staff" "$REGION_NAME"
        ;;
    digit)
        set_role_no_location "DIGIT Team" "DIGIT Team"
        ;;
    ocio)
        set_role_no_location "ACF OCIO" "ACF OCIO"
        ;;
    developer)
        # Developer can optionally have STT for testing
        echo "Switching $EMAIL to Developer (optional STT: $STT_NAME)..."
        run_django <<EOF
user = User.objects.get(username='$EMAIL')
try:
    group = Group.objects.get(name='Developer')
except Group.DoesNotExist:
    print('ERROR: Developer group not found!')
    print('The Developer group is only available in development environments.')
    print('Check that ENABLE_DEVELOPER_GROUP=True in your settings.')
    exit(1)

# Developer can have optional STT for testing
stt_name = '$STT_NAME'
try:
    stt = STT.objects.get(name=stt_name)
except STT.DoesNotExist:
    stt = None
    print(f'Note: STT "{stt_name}" not found, setting to None')

user.groups.clear()
user.groups.add(group)
user.stt = stt
user.regions.clear()
user.save()
EOF
        print_user_status
        ;;
    "")
        show_usage
        ;;
    *)
        echo "Unknown role: $ROLE"
        echo ""
        show_usage
        ;;
esac
