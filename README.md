# Expecto-Patroni

Ansible automation for deploying a **PostgreSQL High Availability cluster** with:
- **Patroni** - PostgreSQL HA orchestration
- **etcd** - Distributed configuration store for Patroni
- **pgBackRest** - Enterprise-grade backup and restore solution

## Supported Distributions

This playbook supports both **RPM-based** and **APT-based** Linux distributions:

### RPM-based (YUM/DNF)
- ✅ Red Hat Enterprise Linux (RHEL) 8, 9
- ✅ CentOS 8, 9
- ✅ Rocky Linux 8, 9
- ✅ AlmaLinux 8, 9

### APT-based
- ✅ Debian 11 (Bullseye), 12 (Bookworm)
- ✅ Ubuntu 20.04 LTS, 22.04 LTS, 24.04 LTS

## Features

- 🔄 **Automatic Distribution Detection** - Automatically installs correct packages for your OS
- 🗄️ **Custom Data Directory** - PostgreSQL data stored in `/opt/postgresql/{{ pg_version }}/data/`
- 🔐 **SSH Key Management** - Automatic SSH key exchange for pgBackRest
- 🔥 **Firewall Configuration** - Supports both `firewalld` (RHEL) and `ufw` (Debian)
- 📦 **Latest PostgreSQL** - Installs from official PostgreSQL repositories
- 🔄 **Automated Backups** - Scheduled full and differential backups via cron

## Prerequisites

- Ansible 2.9 or higher
- Python 3.6 or higher on target hosts
- Root or sudo access on target hosts
- Network connectivity between all nodes

## Quick Start

### 1. Configure Inventory

Edit `inventory/default/hosts.yml` with your server IPs:

```yaml
all:
  children:
    postgres:
      hosts:
        10.0.10.87:
        10.0.10.89:
        10.0.10.90:
    etcd:
      hosts:
        10.0.10.87:
        10.0.10.89:
        10.0.10.90:      
    pgbackrest:
      hosts:
        10.0.10.88:
          pgbackrest_repo_id: 1
```

### 2. Configure Variables

Edit `inventory/default/group_vars/all.yml` to customize:

```yaml
pg_version: 17
patroni_version: "3.3.1"
etcd_version: "v3.5.1"

# Data directory (same for all distributions)
pg_data_dir: "/opt/postgresql/{{ pg_version }}/data/"

# Patroni configuration
patroni_scope: postgresql17
patroni_superuser_username: postgres
patroni_superuser_password: postgres_password
patroni_replication_username: repl
patroni_replication_password: replication_password

# pgBackRest configuration
pgbackrest_stanza: "default"
pgbackrest_backup_username: "postgres"
pgbackrest_backup_password: "test"
```

### 3. Run the Playbook

```bash
# Install everything
ansible-playbook -i inventory/default/hosts.yml install_vm.yml

# Install only specific components
ansible-playbook -i inventory/default/hosts.yml install_vm.yml --tags etcd
ansible-playbook -i inventory/default/hosts.yml install_vm.yml --tags postgres
ansible-playbook -i inventory/default/hosts.yml install_vm.yml --tags pgbackrest
```

## Architecture

### Cluster Components

```
┌─────────────────────────────────────────────────────────┐
│                    etcd Cluster                         │
│  (Distributed Configuration Store)                      │
│  Nodes: 10.0.10.87, 10.0.10.89, 10.0.10.90             │
└─────────────────────────────────────────────────────────┘
                          ▲
                          │
                          ▼
┌─────────────────────────────────────────────────────────┐
│              Patroni + PostgreSQL Cluster               │
│  (High Availability PostgreSQL)                         │
│  Nodes: 10.0.10.87, 10.0.10.89, 10.0.10.90             │
└─────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────┐
│                  pgBackRest Server                      │
│  (Centralized Backup Repository)                        │
│  Node: 10.0.10.88                                       │
└─────────────────────────────────────────────────────────┘
```

### Data Directory Structure

```
/opt/postgresql/
├── 17/
│   └── data/          # PostgreSQL data directory (managed by Patroni)
└── current -> 17/     # Symlink to current version
```

## Configuration Details

### PostgreSQL Ports
- **5432** - PostgreSQL database
- **8008** - Patroni REST API

### etcd Ports
- **2379** - Client communication
- **2380** - Peer communication

### Backup Schedule

Configured in `all.yml`:
- **Full Backups**: Monday, Wednesday, Friday, Sunday at 2 AM
- **Differential Backups**: Tuesday, Thursday, Saturday at 2 AM

## Distribution-Specific Details

### Package Management

**RHEL/CentOS/Rocky:**
- Repository: PostgreSQL official YUM repository
- Package manager: `yum`/`dnf`
- Firewall: `firewalld` (if enabled)

**Debian/Ubuntu:**
- Repository: PostgreSQL official APT repository
- Package manager: `apt`
- Firewall: `ufw` (if enabled)
- Auto-cluster creation: **Disabled** (Patroni manages initialization)

### PostgreSQL User Home Directory

The playbook automatically uses the correct home directory:
- **RHEL**: `/var/lib/pgsql/`
- **Debian**: `/var/lib/postgresql/`

This is handled via the `postgres_home_dir` variable.

## Roles

### `etcd`
Installs and configures etcd cluster for Patroni's distributed consensus.

### `postgresql`
Installs PostgreSQL, Patroni, and configures HA cluster.

### `pgbackrest`
Installs pgBackRest, configures SSH keys, and sets up automated backups.

## Troubleshooting

### Check Patroni Status
```bash
patronictl -c /etc/patroni/patroni.yml list
```

### Check etcd Health
```bash
etcdctl endpoint health
```

### Check pgBackRest
```bash
sudo -u postgres pgbackrest --stanza=default info
```

### View Logs
```bash
# Patroni logs
journalctl -u patroni -f

# etcd logs
journalctl -u etcd -f

# PostgreSQL logs
tail -f /var/log/postgres/postgresql.log
```

## Security Considerations

⚠️ **Important**: This playbook uses default passwords for demonstration. In production:

1. Change all passwords in `all.yml`
2. Use Ansible Vault to encrypt sensitive variables
3. Configure SSL/TLS for PostgreSQL connections
4. Restrict firewall rules to specific IP ranges
5. Use strong SSH keys (4096-bit RSA minimum)

## License

MIT

## Contributing

Contributions welcome! Please open an issue or pull request.
