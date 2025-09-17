#!/bin/bash
# Ensure that Paperless consume and export directories are created with the correct permissions
set -euo pipefail

# Configuration
readonly UMBREL_DATA_DIR="${UMBREL_ROOT}/data"
readonly UMBREL_DATA_STORAGE_DIR="${UMBREL_DATA_DIR}/storage"
readonly UMBREL_DATA_STORAGE_PAPERLESS_DIR="${UMBREL_DATA_STORAGE_DIR}/paperless"
readonly UMBREL_DATA_STORAGE_PAPERLESS_MEDIA_DIR="${UMBREL_DATA_STORAGE_PAPERLESS_DIR}/media"
readonly UMBREL_DATA_STORAGE_PAPERLESS_CONSUME_DIR="${UMBREL_DATA_STORAGE_PAPERLESS_DIR}/consume"
readonly UMBREL_DATA_STORAGE_PAPERLESS_EXPORT_DIR="${UMBREL_DATA_STORAGE_PAPERLESS_DIR}/export"
readonly DESIRED_OWNER="1000:1000"
readonly DESIRED_PERMISSIONS="755"

# Logging function
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" >&2
}

# Create directories if they don't exist
create_directory() {
    local -r dir_path="${1}"
    
    if [[ ! -d "${dir_path}" ]]; then
        log "Creating directory: ${dir_path}"
        if ! mkdir -p "${dir_path}"; then
            log "ERROR: Failed to create directory: ${dir_path}"
            return 1
        fi
    fi
}

# Create required directories
create_directory "${UMBREL_DATA_STORAGE_PAPERLESS_MEDIA_DIR}"
create_directory "${UMBREL_DATA_STORAGE_PAPERLESS_CONSUME_DIR}"
create_directory "${UMBREL_DATA_STORAGE_PAPERLESS_EXPORT_DIR}"

set_paperless_correct_permissions() {
    local -r path="${1}"
    
    if [[ ! -d "${path}" ]]; then
        log "WARNING: Directory does not exist: ${path}"
        return 1
    fi
    
    # Get current ownership (Linux vs macOS compatible)
    if command -v stat >/dev/null 2>&1; then
        if stat -c "%u:%g" "${path}" >/dev/null 2>&1; then
            # Linux
            owner=$(stat -c "%u:%g" "${path}")
        else
            # macOS
            owner=$(stat -f "%u:%g" "${path}")
        fi
    else
        log "ERROR: stat command not available"
        return 1
    fi
    
    # Set ownership if incorrect
    if [[ "${owner}" != "${DESIRED_OWNER}" ]]; then
        log "Setting ownership ${DESIRED_OWNER} on: ${path}"
        if ! chown "${DESIRED_OWNER}" "${path}"; then
            log "ERROR: Failed to set ownership on: ${path}"
            return 1
        fi
    fi
    
    # Set permissions
    current_perms=$(stat -c "%a" "${path}" 2>/dev/null || stat -f "%A" "${path}" 2>/dev/null || echo "000")
    if [[ "${current_perms}" != "${DESIRED_PERMISSIONS}" ]]; then
        log "Setting permissions ${DESIRED_PERMISSIONS} on: ${path}"
        if ! chmod "${DESIRED_PERMISSIONS}" "${path}"; then
            log "ERROR: Failed to set permissions on: ${path}"
            return 1
        fi
    fi
    
    log "Permissions verified for: ${path}"
}

# Apply correct permissions to all directories
log "Starting permission check and correction..."

directories=(
    "${UMBREL_DATA_STORAGE_DIR}"
    "${UMBREL_DATA_STORAGE_PAPERLESS_DIR}"
    "${UMBREL_DATA_STORAGE_PAPERLESS_MEDIA_DIR}"
    "${UMBREL_DATA_STORAGE_PAPERLESS_CONSUME_DIR}"
    "${UMBREL_DATA_STORAGE_PAPERLESS_EXPORT_DIR}"
)

failed_count=0
for dir in "${directories[@]}"; do
    if ! set_paperless_correct_permissions "${dir}"; then
        ((failed_count++))
    fi
done

if [[ ${failed_count} -eq 0 ]]; then
    log "All directory permissions set successfully"
    exit 0
else
    log "ERROR: ${failed_count} directories failed permission setup"
    exit 1
fi
