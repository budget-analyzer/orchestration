#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ORCHESTRATION_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
CERTS_DIR="$ORCHESTRATION_DIR/nginx/certs"
SESSION_GATEWAY_DIR="$ORCHESTRATION_DIR/../session-gateway"

# Track what we did for summary
ACTIONS_TAKEN=()
ACTIONS_SKIPPED=()

# Parse arguments
RESET_MODE=false
FORCE_MODE=false

print_usage() {
    echo "Usage: $(basename "$0") [OPTIONS]"
    echo
    echo "Options:"
    echo "  --reset    Delete all SSL certificates and reset trust stores"
    echo "  --force    Skip confirmation prompts (use with --reset)"
    echo "  --help     Show this help message"
    echo
    echo "Examples:"
    echo "  $(basename "$0")           # Normal setup"
    echo "  $(basename "$0") --reset   # Reset all SSL state, then regenerate"
    echo
}

while [[ "$#" -gt 0 ]]; do
    case $1 in
        --reset) RESET_MODE=true ;;
        --force) FORCE_MODE=true ;;
        --help) print_usage; exit 0 ;;
        *) echo "Unknown parameter: $1"; print_usage; exit 1 ;;
    esac
    shift
done

# Detect OS
case "$OSTYPE" in
    darwin*)  OS="macos" ;;
    linux*)   OS="linux" ;;
    msys*|cygwin*|win32*) OS="windows" ;;
    *)        OS="unknown" ;;
esac

echo "Detected OS: $OS"
echo

# Function to find JAVA_HOME (needed for reset mode too)
find_java_home() {
    if [ -n "$JAVA_HOME" ] && [ -d "$JAVA_HOME" ]; then
        echo "$JAVA_HOME"
        return 0
    fi
    if command -v java &> /dev/null; then
        local java_home_prop
        java_home_prop=$(java -XshowSettings:properties -version 2>&1 | grep 'java.home' | awk -F' = ' '{print $2}')
        if [ -n "$java_home_prop" ] && [ -d "$java_home_prop" ]; then
            if [ -d "$java_home_prop/lib/security" ]; then
                echo "$java_home_prop"
                return 0
            elif [ -d "$(dirname "$java_home_prop")/lib/security" ]; then
                echo "$(dirname "$java_home_prop")"
                return 0
            fi
            echo "$java_home_prop"
            return 0
        fi
    fi
    local common_paths=(
        "$HOME/.sdkman/candidates/java/current"
        "/opt/homebrew/opt/openjdk/libexec/openjdk.jdk/Contents/Home"
        "/opt/homebrew/opt/openjdk"
        "/usr/local/opt/openjdk/libexec/openjdk.jdk/Contents/Home"
        "/usr/local/opt/openjdk"
        "/usr/lib/jvm/default-java"
        "/usr/lib/jvm/java-17-openjdk-amd64"
        "/usr/lib/jvm/java-21-openjdk-amd64"
        "/usr/lib/jvm/java-11-openjdk-amd64"
        "/usr/lib/jvm/java"
        "/usr/lib/jvm/default"
    )
    for path in "${common_paths[@]}"; do
        if [ -d "$path" ]; then
            echo "$path"
            return 0
        fi
    done
    return 1
}

# Function to find cacerts file
find_cacerts() {
    local java_home="$1"
    local standard="$java_home/lib/security/cacerts"
    if [ -f "$standard" ]; then
        if [ "$OS" = "macos" ]; then
            echo "$standard"
        else
            readlink -f "$standard" 2>/dev/null || echo "$standard"
        fi
        return 0
    fi
    local jre_location="$java_home/jre/lib/security/cacerts"
    if [ -f "$jre_location" ]; then
        echo "$jre_location"
        return 0
    fi
    if [ -f "/etc/ssl/certs/java/cacerts" ]; then
        echo "/etc/ssl/certs/java/cacerts"
        return 0
    fi
    return 1
}

# Handle reset mode
if [ "$RESET_MODE" = true ]; then
    echo "=== RESET MODE ==="
    echo
    echo "This will delete all SSL certificates and reset trust stores:"
    echo "  • NGINX certificates in $CERTS_DIR"
    echo "  • mkcert CA from JVM truststore"
    echo "  • mkcert CA from browser trust stores (NSS)"
    echo

    if [ "$FORCE_MODE" != true ]; then
        read -p "Are you sure you want to reset? [y/N] " confirm
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            echo "Aborted."
            exit 0
        fi
    fi

    echo
    echo "Resetting SSL state..."
    echo

    # 1. Delete NGINX certificates
    if [ -f "$CERTS_DIR/_wildcard.budgetanalyzer.localhost.pem" ] || \
       [ -f "$CERTS_DIR/_wildcard.budgetanalyzer.localhost-key.pem" ]; then
        echo "Deleting NGINX certificates..."
        rm -f "$CERTS_DIR/_wildcard.budgetanalyzer.localhost.pem"
        rm -f "$CERTS_DIR/_wildcard.budgetanalyzer.localhost-key.pem"
        echo "[OK] NGINX certificates deleted"
    else
        echo "[SKIP] No NGINX certificates to delete"
    fi

    # 2. Remove from JVM truststore
    DETECTED_JAVA_HOME=$(find_java_home 2>/dev/null) || true
    if [ -n "$DETECTED_JAVA_HOME" ]; then
        CACERTS=$(find_cacerts "$DETECTED_JAVA_HOME" 2>/dev/null) || true
        if [ -n "$CACERTS" ] && [ -f "$CACERTS" ]; then
            if keytool -list -keystore "$CACERTS" -storepass changeit -alias mkcert &>/dev/null; then
                echo "Removing mkcert CA from JVM truststore..."
                if [ -w "$CACERTS" ]; then
                    keytool -delete -alias mkcert -keystore "$CACERTS" -storepass changeit 2>/dev/null && \
                        echo "[OK] Removed from JVM truststore" || \
                        echo "[WARN] Failed to remove from JVM truststore"
                else
                    sudo keytool -delete -alias mkcert -keystore "$CACERTS" -storepass changeit 2>/dev/null && \
                        echo "[OK] Removed from JVM truststore" || \
                        echo "[WARN] Failed to remove from JVM truststore"
                fi
            else
                echo "[SKIP] mkcert CA not in JVM truststore"
            fi
        fi
    fi

    # 3. Remove from browser trust stores (NSS)
    if [ "$OS" = "linux" ] && command -v certutil &> /dev/null; then
        echo "Removing mkcert CA from browser trust stores..."

        # Standard NSS database
        if [ -d "$HOME/.pki/nssdb" ]; then
            certutil -d sql:$HOME/.pki/nssdb -D -n "mkcert" 2>/dev/null && \
                echo "[OK] Removed from ~/.pki/nssdb" || true
        fi

        # Snap Chromium
        if [ -d "$HOME/snap/chromium/current/.pki/nssdb" ]; then
            certutil -d sql:$HOME/snap/chromium/current/.pki/nssdb -D -n "mkcert" 2>/dev/null && \
                echo "[OK] Removed from snap Chromium" || true
        fi

        # Firefox profiles (native and snap)
        for firefox_dir in "$HOME/.mozilla/firefox" "$HOME/snap/firefox/common/.mozilla/firefox"; do
            if [ -d "$firefox_dir" ]; then
                for profile in "$firefox_dir"/*.default* "$firefox_dir"/*.default-release*; do
                    if [ -d "$profile" ]; then
                        certutil -d sql:$profile -D -n "mkcert" 2>/dev/null && \
                            echo "[OK] Removed from Firefox profile $(basename "$profile")" || true
                    fi
                done
            fi
        done
    fi

    # 4. Uninstall mkcert CA (this removes it from system trust)
    if command -v mkcert &> /dev/null; then
        echo "Uninstalling mkcert CA from system trust..."
        mkcert -uninstall 2>/dev/null && \
            echo "[OK] mkcert CA uninstalled" || \
            echo "[WARN] mkcert -uninstall may have partially failed (this is often OK)"
    fi

    echo
    echo "=== Reset Complete ==="
    echo
    echo "All SSL state has been cleared. Now run the script again without --reset"
    echo "to regenerate certificates with your current mkcert CA:"
    echo
    echo "  $0"
    echo
    exit 0
fi

echo "=== Budget Analyzer - Local HTTPS Setup ==="
echo

# Cleanup orphaned certificate files from session-gateway
# (Session Gateway doesn't serve HTTPS - it runs on HTTP behind NGINX)
if [ -d "$SESSION_GATEWAY_DIR/src/main/resources/certs" ]; then
    echo "Cleaning up orphaned certificate directory in session-gateway..."
    rm -rf "$SESSION_GATEWAY_DIR/src/main/resources/certs"
    ACTIONS_TAKEN+=("Removed orphaned session-gateway/src/main/resources/certs/")
    echo "[OK] Removed orphaned certificate directory"
    echo
fi

# Check if mkcert is installed
if ! command -v mkcert &> /dev/null; then
    echo "mkcert is not installed"
    echo
    echo "Install mkcert:"
    echo "  macOS:   brew install mkcert nss"
    echo "  Linux:   sudo apt install libnss3-tools && curl -JLO https://dl.filippo.io/mkcert/latest?for=linux/amd64 && chmod +x mkcert-* && sudo mv mkcert-* /usr/local/bin/mkcert"
    echo "  Windows: choco install mkcert"
    echo
    exit 1
fi

echo "[OK] mkcert is installed"

# Check for certutil on Linux (required for browser trust)
if [ "$OS" = "linux" ]; then
    if ! command -v certutil &> /dev/null; then
        echo "[ERROR] certutil not found - required for browser certificate trust"
        echo
        echo "Install with:"
        echo "  Ubuntu/Debian: sudo apt install libnss3-tools"
        echo "  Fedora/RHEL:   sudo dnf install nss-tools"
        echo "  Arch:          sudo pacman -S nss"
        echo
        exit 1
    fi
    echo "[OK] certutil is installed"
fi

# Install local CA
echo
echo "Installing local CA..."

CA_ROOT="$(mkcert -CAROOT)"
CA_FILE="$CA_ROOT/rootCA.pem"

if [ "$OS" = "linux" ]; then
    # Linux: Install to NSS trust stores (browsers) - no sudo needed
    echo "Installing CA to browser trust stores (NSS)..."
    TRUST_STORES=nss mkcert -install

    # Handle snap-installed Chromium (uses isolated NSS database)
    SNAP_CHROMIUM_NSS="$HOME/snap/chromium/current/.pki/nssdb"
    if [ -d "$SNAP_CHROMIUM_NSS" ]; then
        # Check if already installed
        if ! certutil -d sql:$SNAP_CHROMIUM_NSS -L 2>/dev/null | grep -q "mkcert"; then
            echo "Installing CA to snap Chromium..."
            certutil -d sql:$SNAP_CHROMIUM_NSS -A -t "C,," -n "mkcert" -i "$CA_FILE" && \
                echo "[OK] CA installed to snap Chromium" || \
                echo "[WARN] Failed to install CA to snap Chromium"
        else
            echo "[SKIP] CA already in snap Chromium"
        fi
    fi

    # Handle snap-installed Firefox (uses isolated profile directories)
    SNAP_FIREFOX_DIR="$HOME/snap/firefox/common/.mozilla/firefox"
    if [ -d "$SNAP_FIREFOX_DIR" ]; then
        for profile in "$SNAP_FIREFOX_DIR"/*.default* "$SNAP_FIREFOX_DIR"/*.default-release*; do
            if [ -d "$profile" ]; then
                profile_name=$(basename "$profile")
                if ! certutil -d sql:$profile -L 2>/dev/null | grep -q "mkcert"; then
                    echo "Installing CA to snap Firefox profile ($profile_name)..."
                    certutil -d sql:$profile -A -t "C,," -n "mkcert" -i "$CA_FILE" && \
                        echo "[OK] CA installed to snap Firefox" || \
                        echo "[WARN] Failed to install CA to snap Firefox"
                else
                    echo "[SKIP] CA already in snap Firefox ($profile_name)"
                fi
            fi
        done
    fi

    # Handle native Firefox profiles (non-snap)
    NATIVE_FIREFOX_DIR="$HOME/.mozilla/firefox"
    if [ -d "$NATIVE_FIREFOX_DIR" ]; then
        for profile in "$NATIVE_FIREFOX_DIR"/*.default* "$NATIVE_FIREFOX_DIR"/*.default-release*; do
            if [ -d "$profile" ]; then
                profile_name=$(basename "$profile")
                if ! certutil -d sql:$profile -L 2>/dev/null | grep -q "mkcert"; then
                    echo "Installing CA to native Firefox profile ($profile_name)..."
                    certutil -d sql:$profile -A -t "C,," -n "mkcert" -i "$CA_FILE" 2>/dev/null && \
                        echo "[OK] CA installed to native Firefox" || true
                fi
            fi
        done
    fi

elif [ "$OS" = "macos" ]; then
    # macOS: Install to system keychain
    mkcert -install

elif [ "$OS" = "windows" ]; then
    # Windows: Install to system store
    mkcert -install

else
    echo "[WARN] Unknown OS, attempting default installation..."
    mkcert -install
fi

ACTIONS_TAKEN+=("Installed mkcert CA to browser trust stores")
echo "[OK] Local CA installed ($CA_ROOT)"
echo
echo "[NOTE] Restart your browser for certificate changes to take effect"

# Check if browser trust installation may have failed
if [ "$OS" = "linux" ]; then
    # Check if any browser profile was found
    BROWSER_PROFILES_FOUND=false

    for nss_dir in "$HOME/.pki/nssdb" \
                   "$HOME/snap/chromium/current/.pki/nssdb" \
                   "$HOME/.mozilla/firefox" \
                   "$HOME/snap/firefox/common/.mozilla/firefox"; do
        if [ -d "$nss_dir" ]; then
            BROWSER_PROFILES_FOUND=true
            break
        fi
    done

    if [ "$BROWSER_PROFILES_FOUND" = false ]; then
        echo
        echo "╔════════════════════════════════════════════════════════════════════╗"
        echo "║  BROWSER TRUST: Manual Installation May Be Required                ║"
        echo "╚════════════════════════════════════════════════════════════════════╝"
        echo
        echo "No browser profile directories were found. This can happen if:"
        echo "  • Browser has never been opened (no profile created yet)"
        echo "  • Browser uses a non-standard profile location"
        echo
        echo "To manually install the CA certificate in your browser:"
        echo
        echo "  Firefox:"
        echo "    1. Open about:preferences#privacy"
        echo "    2. Scroll to 'Certificates' → 'View Certificates'"
        echo "    3. Go to 'Authorities' tab → 'Import'"
        echo "    4. Select: $CA_FILE"
        echo "    5. Check 'Trust this CA to identify websites'"
        echo
        echo "  Chrome/Chromium:"
        echo "    1. Open chrome://settings/certificates"
        echo "    2. Go to 'Authorities' tab → 'Import'"
        echo "    3. Select: $CA_FILE"
        echo "    4. Check 'Trust this certificate for identifying websites'"
        echo
        ACTIONS_TAKEN+=("Manual browser trust installation may be needed (see above)")
    fi
fi

# Create certs directory
mkdir -p "$CERTS_DIR"
cd "$CERTS_DIR"

# Generate certificates
echo
echo "Generating wildcard certificate for *.budgetanalyzer.localhost..."

if [ -f "_wildcard.budgetanalyzer.localhost.pem" ]; then
    echo "[SKIP] Certificate already exists"
    echo "       To regenerate: rm $CERTS_DIR/_wildcard.budgetanalyzer.localhost*.pem"
    ACTIONS_SKIPPED+=("NGINX certificate (already exists)")
else
    mkcert "*.budgetanalyzer.localhost"
    echo "[OK] Certificate generated"
    ACTIONS_TAKEN+=("Generated NGINX wildcard certificate")
fi

# Show certificate files
echo
echo "Certificate files:"
ls -lh "$CERTS_DIR"/_wildcard.budgetanalyzer.localhost*.pem 2>/dev/null || echo "  (none found)"

# Validate certificate matches current CA
echo
echo "Validating certificate trust chain..."
CERT_FILE="$CERTS_DIR/_wildcard.budgetanalyzer.localhost.pem"

if [ -f "$CERT_FILE" ] && [ -f "$CA_FILE" ]; then
    # Check if certificate was signed by our CA
    if openssl verify -CAfile "$CA_FILE" "$CERT_FILE" &>/dev/null; then
        echo "[OK] Certificate is signed by current mkcert CA"
    else
        # Get certificate issuer for diagnostic
        CERT_ISSUER=$(openssl x509 -in "$CERT_FILE" -noout -issuer 2>/dev/null | sed 's/issuer=//')
        CA_SUBJECT=$(openssl x509 -in "$CA_FILE" -noout -subject 2>/dev/null | sed 's/subject=//')

        echo
        echo "╔════════════════════════════════════════════════════════════════════╗"
        echo "║  WARNING: Certificate/CA Mismatch Detected                         ║"
        echo "╚════════════════════════════════════════════════════════════════════╝"
        echo
        echo "The NGINX certificate was signed by a different CA than your current one."
        echo "This typically happens when certificates were generated in a different"
        echo "environment (e.g., devcontainer vs host machine)."
        echo
        echo "  Certificate issuer: $CERT_ISSUER"
        echo "  Current CA:         $CA_SUBJECT"
        echo
        echo "To fix this, regenerate the certificate with your current CA:"
        echo
        echo "  rm $CERTS_DIR/_wildcard.budgetanalyzer.localhost*.pem"
        echo "  $0"
        echo
        echo "Or reset everything and start fresh:"
        echo
        echo "  $0 --reset"
        echo "  $0"
        echo

        ACTIONS_TAKEN+=("WARNING: Certificate/CA mismatch detected (see above)")
    fi
else
    echo "[SKIP] Certificate validation skipped (files not found)"
fi

# Add CA to JVM truststore for Session Gateway
echo
echo "=== JVM Truststore Setup ==="
echo
echo "Session Gateway needs to trust the mkcert CA when calling api.budgetanalyzer.localhost"
echo

# Find Java installation (uses functions defined earlier)
DETECTED_JAVA_HOME=$(find_java_home)

if [ -z "$DETECTED_JAVA_HOME" ]; then
    echo "[ERROR] Java installation not found"
    echo
    echo "Please ensure Java is installed and either:"
    echo "  1. Set JAVA_HOME environment variable, or"
    echo "  2. Have 'java' in your PATH"
    echo
    echo "After installing Java, re-run this script or manually add the CA:"
    echo
    echo "  sudo keytool -importcert -file \"$CA_FILE\" \\"
    echo "    -alias mkcert -keystore \$JAVA_HOME/lib/security/cacerts \\"
    echo "    -storepass changeit -noprompt"
    echo
    exit 1
fi

echo "Found Java installation: $DETECTED_JAVA_HOME"

# Find cacerts file
CACERTS=$(find_cacerts "$DETECTED_JAVA_HOME")

if [ -z "$CACERTS" ] || [ ! -f "$CACERTS" ]; then
    echo "[ERROR] Could not find cacerts file"
    echo "  Searched in: $DETECTED_JAVA_HOME/lib/security/cacerts"
    echo
    echo "You may need to manually add the CA to JVM truststore:"
    echo
    echo "  sudo keytool -importcert -file \"$CA_FILE\" \\"
    echo "    -alias mkcert -keystore <path-to-cacerts> \\"
    echo "    -storepass changeit -noprompt"
    echo
    exit 1
fi

echo "Found cacerts: $CACERTS"

if [ ! -f "$CA_FILE" ]; then
    echo "[ERROR] mkcert CA not found at: $CA_FILE"
    echo "  Run 'mkcert -install' first"
    exit 1
fi

# Check if already imported
if keytool -list -keystore "$CACERTS" -storepass changeit -alias mkcert &>/dev/null; then
    echo "[SKIP] mkcert CA already in JVM truststore"
    ACTIONS_SKIPPED+=("JVM truststore (mkcert CA already present)")
else
    echo
    echo "Adding mkcert CA to JVM truststore..."
    echo "  CA file:  $CA_FILE"
    echo "  Keystore: $CACERTS"
    echo

    # Determine if we need sudo (check if we can write to cacerts)
    if [ -w "$CACERTS" ]; then
        KEYTOOL_CMD="keytool"
    else
        echo "  (requires sudo for write access to cacerts)"
        KEYTOOL_CMD="sudo keytool"
    fi

    # Import the certificate
    if $KEYTOOL_CMD -importcert -file "$CA_FILE" \
        -alias mkcert \
        -keystore "$CACERTS" \
        -storepass changeit \
        -noprompt; then
        echo
        echo "[OK] mkcert CA added to JVM truststore"
        ACTIONS_TAKEN+=("Added mkcert CA to JVM truststore ($CACERTS)")
    else
        echo
        echo "[ERROR] Failed to add CA to JVM truststore"
        echo
        echo "Try running manually:"
        echo
        echo "  sudo keytool -importcert -file \"$CA_FILE\" \\"
        echo "    -alias mkcert -keystore \"$CACERTS\" \\"
        echo "    -storepass changeit -noprompt"
        echo
        exit 1
    fi

    # Verify the import
    echo
    echo "Verifying import..."
    if keytool -list -keystore "$CACERTS" -storepass changeit -alias mkcert &>/dev/null; then
        echo "[OK] Certificate verified in truststore"
    else
        echo "[ERROR] Certificate verification failed - import may not have succeeded"
        exit 1
    fi
fi

echo
echo "=== Setup Complete! ==="
echo

# Print summary of actions
if [ ${#ACTIONS_TAKEN[@]} -gt 0 ]; then
    echo "Actions performed:"
    for action in "${ACTIONS_TAKEN[@]}"; do
        echo "  ✓ $action"
    done
    echo
fi

if [ ${#ACTIONS_SKIPPED[@]} -gt 0 ]; then
    echo "Already configured (skipped):"
    for action in "${ACTIONS_SKIPPED[@]}"; do
        echo "  • $action"
    done
    echo
fi

# Final verification
echo "=== Verification ==="
echo
VERIFICATION_PASSED=true

# Check NGINX certificates
if [ -f "$CERTS_DIR/_wildcard.budgetanalyzer.localhost.pem" ] && \
   [ -f "$CERTS_DIR/_wildcard.budgetanalyzer.localhost-key.pem" ]; then
    echo "✓ NGINX certificates present"

    # Also check if certificate matches CA
    if openssl verify -CAfile "$CA_FILE" "$CERTS_DIR/_wildcard.budgetanalyzer.localhost.pem" &>/dev/null; then
        echo "✓ Certificate signed by current CA"
    else
        echo "✗ Certificate NOT signed by current CA (mismatch!)"
        VERIFICATION_PASSED=false
    fi
else
    echo "✗ NGINX certificates MISSING"
    VERIFICATION_PASSED=false
fi

# Check JVM truststore
if keytool -list -keystore "$CACERTS" -storepass changeit -alias mkcert &>/dev/null; then
    echo "✓ mkcert CA in JVM truststore"
else
    echo "✗ mkcert CA NOT in JVM truststore"
    VERIFICATION_PASSED=false
fi

# Check mkcert CA file
if [ -f "$CA_FILE" ]; then
    echo "✓ mkcert CA file exists ($CA_FILE)"
else
    echo "✗ mkcert CA file MISSING"
    VERIFICATION_PASSED=false
fi

echo
if [ "$VERIFICATION_PASSED" = true ]; then
    echo "All verifications passed!"
else
    echo "WARNING: Some verifications failed. SSL may not work correctly."
fi

echo
echo "=== Next Steps ==="
echo
echo "1. Restart your browser (required for certificate changes)"
echo "2. Start NGINX:           docker compose up -d api-gateway"
echo "3. Start Session Gateway: cd ../session-gateway && ./gradlew bootRun"
echo "4. Access application:    https://app.budgetanalyzer.localhost"
echo "5. Test API Gateway:      curl https://api.budgetanalyzer.localhost/health"
echo
echo "Troubleshooting:"
echo "  - If SSL handshake errors occur, ensure Session Gateway was restarted"
echo "  - If browser shows certificate warnings, restart the browser"
echo "  - Run this script again - it's safe and idempotent"
echo
