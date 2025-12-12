#!/bin/bash
# Validation script for Expecto-Patroni deployment
# This script checks if all components are properly installed and running

set -e

echo "=================================================="
echo "Expecto-Patroni Deployment Validation"
echo "=================================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print status
print_status() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✓${NC} $2"
    else
        echo -e "${RED}✗${NC} $2"
    fi
}

# Detect OS
echo "=== System Information ==="
echo "OS: $(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)"
echo "Kernel: $(uname -r)"
echo ""

# Check PostgreSQL
echo "=== PostgreSQL Checks ==="
if command -v psql &> /dev/null; then
    PG_VERSION=$(psql --version | awk '{print $3}')
    print_status 0 "PostgreSQL installed (version: $PG_VERSION)"
else
    print_status 1 "PostgreSQL not found"
fi

# Check data directory
if [ -d "/opt/postgresql" ]; then
    print_status 0 "PostgreSQL data directory exists: /opt/postgresql"
    ls -la /opt/postgresql/
else
    print_status 1 "PostgreSQL data directory not found"
fi

echo ""

# Check Patroni
echo "=== Patroni Checks ==="
if command -v patroni &> /dev/null; then
    print_status 0 "Patroni installed"
else
    print_status 1 "Patroni not found"
fi

if systemctl is-active --quiet patroni; then
    print_status 0 "Patroni service is running"
    echo ""
    echo "Patroni cluster status:"
    patronictl -c /etc/patroni/patroni.yml list 2>/dev/null || echo "Could not get cluster status"
else
    print_status 1 "Patroni service is not running"
fi

echo ""

# Check etcd
echo "=== etcd Checks ==="
if command -v etcd &> /dev/null; then
    ETCD_VERSION=$(etcd --version | head -n1 | awk '{print $3}')
    print_status 0 "etcd installed (version: $ETCD_VERSION)"
else
    print_status 1 "etcd not found"
fi

if systemctl is-active --quiet etcd; then
    print_status 0 "etcd service is running"
    echo ""
    echo "etcd health:"
    etcdctl endpoint health 2>/dev/null || echo "Could not check etcd health"
else
    print_status 1 "etcd service is not running"
fi

echo ""

# Check pgBackRest
echo "=== pgBackRest Checks ==="
if command -v pgbackrest &> /dev/null; then
    PGBACKREST_VERSION=$(pgbackrest version | awk '{print $2}')
    print_status 0 "pgBackRest installed (version: $PGBACKREST_VERSION)"
else
    print_status 1 "pgBackRest not found"
fi

if [ -f "/etc/pgbackrest/pgbackrest.conf" ]; then
    print_status 0 "pgBackRest configuration exists"
else
    print_status 1 "pgBackRest configuration not found"
fi

echo ""

# Check network ports
echo "=== Network Port Checks ==="
check_port() {
    if ss -tuln | grep -q ":$1 "; then
        print_status 0 "Port $1 is listening ($2)"
    else
        print_status 1 "Port $1 is not listening ($2)"
    fi
}

check_port 5432 "PostgreSQL"
check_port 8008 "Patroni REST API"
check_port 2379 "etcd client"
check_port 2380 "etcd peer"

echo ""

# Check firewall
echo "=== Firewall Checks ==="
if command -v firewall-cmd &> /dev/null; then
    if systemctl is-active --quiet firewalld; then
        print_status 0 "firewalld is active (RHEL-based system)"
        echo "Open ports:"
        firewall-cmd --list-ports 2>/dev/null || echo "Could not list ports"
    else
        print_status 1 "firewalld is not active"
    fi
elif command -v ufw &> /dev/null; then
    UFW_STATUS=$(ufw status | head -n1)
    if [[ "$UFW_STATUS" == *"active"* ]]; then
        print_status 0 "ufw is active (Debian-based system)"
        echo "UFW status:"
        ufw status numbered 2>/dev/null || echo "Could not get ufw status"
    else
        print_status 0 "ufw is installed but not active"
    fi
else
    print_status 0 "No firewall detected (firewalld/ufw)"
fi

echo ""

# Check SSH keys for pgBackRest
echo "=== SSH Key Checks ==="
POSTGRES_HOME=$(getent passwd postgres | cut -d: -f6)
if [ -f "$POSTGRES_HOME/.ssh/id_rsa" ]; then
    print_status 0 "PostgreSQL user SSH key exists"
else
    print_status 1 "PostgreSQL user SSH key not found"
fi

if [ -f "$POSTGRES_HOME/.ssh/authorized_keys" ]; then
    KEY_COUNT=$(wc -l < "$POSTGRES_HOME/.ssh/authorized_keys")
    print_status 0 "Authorized keys file exists ($KEY_COUNT keys)"
else
    print_status 1 "Authorized keys file not found"
fi

echo ""

# Summary
echo "=================================================="
echo "Validation Complete"
echo "=================================================="
echo ""
echo "Next steps:"
echo "1. Check Patroni cluster: patronictl -c /etc/patroni/patroni.yml list"
echo "2. Check etcd health: etcdctl endpoint health"
echo "3. Check pgBackRest: sudo -u postgres pgbackrest --stanza=default info"
echo "4. View Patroni logs: journalctl -u patroni -f"
echo "5. View etcd logs: journalctl -u etcd -f"
