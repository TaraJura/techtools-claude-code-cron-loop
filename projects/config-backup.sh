#!/bin/bash
#
# config-backup.sh - Configuration File Backup Utility
# Backs up important system and application configuration files to timestamped archives
#

# Don't use set -e because arithmetic ((count++)) returns 1 when incrementing from 0

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default settings
BACKUP_DIR="${HOME}/backups/configs"
MAX_BACKUPS=5
DRY_RUN=false
RESTORE_MODE=false
LIST_MODE=false
RESTORE_FILE=""

# Files to backup - grouped by category
declare -a SYSTEM_CONFIGS=(
    "/etc/nginx/nginx.conf"
    "/etc/nginx/sites-available"
    "/etc/ssh/sshd_config"
    "/etc/crontab"
    "/etc/cron.d"
    "/etc/apt/sources.list"
    "/etc/apt/sources.list.d"
    "/etc/fstab"
    "/etc/hosts"
    "/etc/hostname"
)

declare -a USER_CONFIGS=(
    "${HOME}/.bashrc"
    "${HOME}/.bash_profile"
    "${HOME}/.profile"
    "${HOME}/.gitconfig"
    "${HOME}/.ssh/config"
)

declare -a PROJECT_CONFIGS=(
    "${HOME}/CLAUDE.md"
    "${HOME}/README.md"
    "${HOME}/tasks.md"
    "${HOME}/actors/idea-maker/CLAUDE.md"
    "${HOME}/actors/project-manager/CLAUDE.md"
    "${HOME}/actors/developer/CLAUDE.md"
    "${HOME}/actors/tester/CLAUDE.md"
)

usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Configuration File Backup Utility"
    echo ""
    echo "Options:"
    echo "  -l, --list        List files that would be backed up (dry run)"
    echo "  -r, --restore FILE  Restore from a specific backup archive"
    echo "  -d, --dir DIR     Set backup directory (default: ~/backups/configs)"
    echo "  -n, --keep N      Keep last N backups (default: 5)"
    echo "  -s, --show        Show available backup archives"
    echo "  -h, --help        Display this help message"
    echo ""
    echo "Examples:"
    echo "  $0                    Create a new backup"
    echo "  $0 -l                 Show what would be backed up"
    echo "  $0 -s                 List available backups"
    echo "  $0 -r backup.tar.gz   Restore from specific backup"
    echo "  $0 -n 10              Keep last 10 backups"
    echo ""
    echo "Backup includes:"
    echo "  - System configs: nginx, ssh, cron, apt sources, fstab, hosts"
    echo "  - User configs: .bashrc, .profile, .gitconfig, .ssh/config"
    echo "  - Project configs: CLAUDE.md, tasks.md, actor CLAUDE.md files"
}

print_header() {
    echo -e "${BLUE}=======================================${NC}"
    echo -e "${BLUE}  Configuration File Backup Utility${NC}"
    echo -e "${BLUE}=======================================${NC}"
    echo ""
}

# List files that exist and would be backed up
list_backup_files() {
    local count=0

    echo -e "${YELLOW}System Configuration Files:${NC}"
    for file in "${SYSTEM_CONFIGS[@]}"; do
        if [[ -e "$file" ]]; then
            echo -e "  ${GREEN}[EXISTS]${NC} $file"
            ((count++))
        else
            echo -e "  ${RED}[MISSING]${NC} $file"
        fi
    done
    echo ""

    echo -e "${YELLOW}User Configuration Files:${NC}"
    for file in "${USER_CONFIGS[@]}"; do
        if [[ -e "$file" ]]; then
            echo -e "  ${GREEN}[EXISTS]${NC} $file"
            ((count++))
        else
            echo -e "  ${RED}[MISSING]${NC} $file"
        fi
    done
    echo ""

    echo -e "${YELLOW}Project Configuration Files:${NC}"
    for file in "${PROJECT_CONFIGS[@]}"; do
        if [[ -e "$file" ]]; then
            echo -e "  ${GREEN}[EXISTS]${NC} $file"
            ((count++))
        else
            echo -e "  ${RED}[MISSING]${NC} $file"
        fi
    done
    echo ""

    echo -e "${BLUE}Total files to backup: ${count}${NC}"
}

# Show available backups
show_backups() {
    echo -e "${YELLOW}Available Backups in ${BACKUP_DIR}:${NC}"
    echo ""

    if [[ ! -d "$BACKUP_DIR" ]]; then
        echo -e "${RED}Backup directory does not exist.${NC}"
        return 1
    fi

    local backups=($(ls -t "${BACKUP_DIR}"/config-backup-*.tar.gz 2>/dev/null))

    if [[ ${#backups[@]} -eq 0 ]]; then
        echo -e "${YELLOW}No backups found.${NC}"
        return 0
    fi

    local i=1
    for backup in "${backups[@]}"; do
        local filename=$(basename "$backup")
        local size=$(du -h "$backup" | cut -f1)
        local date=$(stat -c %y "$backup" 2>/dev/null | cut -d'.' -f1)
        echo -e "  ${GREEN}${i}.${NC} ${filename}"
        echo -e "     Size: ${size}, Created: ${date}"
        ((i++))
    done
    echo ""
    echo -e "${BLUE}Total backups: ${#backups[@]}${NC}"
}

# Create backup
create_backup() {
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_file="${BACKUP_DIR}/config-backup-${timestamp}.tar.gz"
    local temp_dir=$(mktemp -d)
    local files_backed_up=0

    echo -e "${YELLOW}Creating backup...${NC}"
    echo ""

    # Create backup directory if it doesn't exist
    mkdir -p "$BACKUP_DIR"

    # Create temporary structure
    mkdir -p "${temp_dir}/system"
    mkdir -p "${temp_dir}/user"
    mkdir -p "${temp_dir}/project"

    # Backup system configs (may need sudo for some)
    echo -e "${YELLOW}Backing up system configs...${NC}"
    for file in "${SYSTEM_CONFIGS[@]}"; do
        if [[ -e "$file" ]]; then
            # Create parent directory structure
            local rel_path="${file#/}"
            local parent_dir=$(dirname "$rel_path")
            mkdir -p "${temp_dir}/system/${parent_dir}"

            if cp -rL "$file" "${temp_dir}/system/${rel_path}" 2>/dev/null; then
                echo -e "  ${GREEN}[OK]${NC} $file"
                ((files_backed_up++))
            else
                echo -e "  ${YELLOW}[SKIP]${NC} $file (permission denied)"
            fi
        fi
    done

    # Backup user configs
    echo ""
    echo -e "${YELLOW}Backing up user configs...${NC}"
    for file in "${USER_CONFIGS[@]}"; do
        if [[ -e "$file" ]]; then
            local filename=$(basename "$file")
            if cp -rL "$file" "${temp_dir}/user/${filename}" 2>/dev/null; then
                echo -e "  ${GREEN}[OK]${NC} $file"
                ((files_backed_up++))
            else
                echo -e "  ${YELLOW}[SKIP]${NC} $file (permission denied)"
            fi
        fi
    done

    # Backup project configs
    echo ""
    echo -e "${YELLOW}Backing up project configs...${NC}"
    for file in "${PROJECT_CONFIGS[@]}"; do
        if [[ -e "$file" ]]; then
            local rel_path="${file#${HOME}/}"
            local parent_dir=$(dirname "$rel_path")
            mkdir -p "${temp_dir}/project/${parent_dir}"

            if cp -rL "$file" "${temp_dir}/project/${rel_path}" 2>/dev/null; then
                echo -e "  ${GREEN}[OK]${NC} $file"
                ((files_backed_up++))
            else
                echo -e "  ${YELLOW}[SKIP]${NC} $file (permission denied)"
            fi
        fi
    done

    # Create the archive
    echo ""
    echo -e "${YELLOW}Creating archive...${NC}"
    tar -czf "$backup_file" -C "$temp_dir" .

    # Cleanup temp directory
    rm -rf "$temp_dir"

    # Get backup size
    local backup_size=$(du -h "$backup_file" | cut -f1)

    echo ""
    echo -e "${GREEN}Backup created successfully!${NC}"
    echo -e "  Archive: ${backup_file}"
    echo -e "  Size: ${backup_size}"
    echo -e "  Files backed up: ${files_backed_up}"

    # Rotate old backups
    rotate_backups
}

# Rotate old backups (keep only MAX_BACKUPS)
rotate_backups() {
    local backups=($(ls -t "${BACKUP_DIR}"/config-backup-*.tar.gz 2>/dev/null))
    local count=${#backups[@]}

    if [[ $count -gt $MAX_BACKUPS ]]; then
        echo ""
        echo -e "${YELLOW}Rotating old backups (keeping last ${MAX_BACKUPS})...${NC}"

        local to_remove=$((count - MAX_BACKUPS))
        for ((i = count - to_remove; i < count; i++)); do
            local old_backup="${backups[$i]}"
            rm -f "$old_backup"
            echo -e "  ${RED}[REMOVED]${NC} $(basename "$old_backup")"
        done
    fi
}

# Restore from backup
restore_backup() {
    local backup_file="$1"

    # Check if absolute path or just filename
    if [[ ! -f "$backup_file" ]]; then
        backup_file="${BACKUP_DIR}/${backup_file}"
    fi

    if [[ ! -f "$backup_file" ]]; then
        echo -e "${RED}Error: Backup file not found: ${backup_file}${NC}"
        exit 1
    fi

    echo -e "${YELLOW}Restore from: $(basename "$backup_file")${NC}"
    echo ""

    # Show what's in the backup
    echo -e "${YELLOW}Contents of backup:${NC}"
    tar -tzf "$backup_file" | head -30
    if [[ $(tar -tzf "$backup_file" | wc -l) -gt 30 ]]; then
        echo "  ... and more files"
    fi
    echo ""

    # Confirm restore
    echo -e "${RED}WARNING: This will extract backup contents.${NC}"
    echo -e "${YELLOW}Files will be extracted to: ${HOME}/restore-${timestamp}${NC}"
    echo ""
    read -p "Continue with restore? (y/N): " confirm

    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo -e "${YELLOW}Restore cancelled.${NC}"
        exit 0
    fi

    # Create restore directory
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local restore_dir="${HOME}/restore-${timestamp}"
    mkdir -p "$restore_dir"

    # Extract backup
    echo ""
    echo -e "${YELLOW}Extracting backup...${NC}"
    tar -xzf "$backup_file" -C "$restore_dir"

    echo ""
    echo -e "${GREEN}Backup extracted to: ${restore_dir}${NC}"
    echo ""
    echo -e "${YELLOW}Directory structure:${NC}"
    echo "  ${restore_dir}/system/  - System configuration files"
    echo "  ${restore_dir}/user/    - User configuration files"
    echo "  ${restore_dir}/project/ - Project configuration files"
    echo ""
    echo -e "${YELLOW}To restore files, manually copy them to their original locations.${NC}"
    echo "Example:"
    echo "  cp ${restore_dir}/user/.bashrc ~/.bashrc"
    echo "  sudo cp -r ${restore_dir}/system/etc/nginx/* /etc/nginx/"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -l|--list)
            LIST_MODE=true
            shift
            ;;
        -r|--restore)
            RESTORE_MODE=true
            RESTORE_FILE="$2"
            shift 2
            ;;
        -d|--dir)
            BACKUP_DIR="$2"
            shift 2
            ;;
        -n|--keep)
            MAX_BACKUPS="$2"
            shift 2
            ;;
        -s|--show)
            print_header
            show_backups
            exit 0
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            usage
            exit 1
            ;;
    esac
done

# Main execution
print_header

if [[ "$LIST_MODE" == true ]]; then
    list_backup_files
elif [[ "$RESTORE_MODE" == true ]]; then
    restore_backup "$RESTORE_FILE"
else
    create_backup
fi
