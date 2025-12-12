# Quick Reference Guide

## Installation Commands

### Full Installation
```bash
ansible-playbook -i inventory/default/hosts.yml install_vm.yml
```

### Install Specific Components
```bash
# Install only etcd
ansible-playbook -i inventory/default/hosts.yml install_vm.yml --tags etcd

# Install only PostgreSQL/Patroni
ansible-playbook -i inventory/default/hosts.yml install_vm.yml --tags postgres

# Install only pgBackRest
ansible-playbook -i inventory/default/hosts.yml install_vm.yml --tags pgbackrest
```

### Install on Specific Hosts
```bash
# Install only on specific host
ansible-playbook -i inventory/default/hosts.yml install_vm.yml --limit 10.0.10.87

# Install only on postgres group
ansible-playbook -i inventory/default/hosts.yml install_vm.yml --limit postgres
```

### Dry Run (Check Mode)
```bash
ansible-playbook -i inventory/default/hosts.yml install_vm.yml --check --diff
```

## Validation

### Run Validation Script
```bash
# Copy to target host
scp validate.sh root@<target-host>:/tmp/

# Run on target host
ssh root@<target-host> "bash /tmp/validate.sh"
```

## Patroni Operations

### Check Cluster Status
```bash
patronictl -c /etc/patroni/patroni.yml list
```

### Switchover (Manual Failover)
```bash
patronictl -c /etc/patroni/patroni.yml switchover
```

### Reinitialize a Replica
```bash
patronictl -c /etc/patroni/patroni.yml reinit postgresql17 <node-name>
```

### Restart PostgreSQL
```bash
patronictl -c /etc/patroni/patroni.yml restart postgresql17 <node-name>
```

### Reload Configuration
```bash
patronictl -c /etc/patroni/patroni.yml reload postgresql17
```

### Show Configuration
```bash
patronictl -c /etc/patroni/patroni.yml show-config
```

## etcd Operations

### Check Health
```bash
etcdctl endpoint health
```

### List Members
```bash
etcdctl member list
```

### Get All Keys
```bash
etcdctl get "" --prefix --keys-only
```

### Get Patroni Configuration from etcd
```bash
etcdctl get /patroni_clusters/postgresql17/config
```

### Watch for Changes
```bash
etcdctl watch "" --prefix
```

## pgBackRest Operations

### Check Stanza Info
```bash
sudo -u postgres pgbackrest --stanza=default info
```

### Manual Full Backup
```bash
sudo -u postgres pgbackrest --stanza=default --type=full backup
```

### Manual Differential Backup
```bash
sudo -u postgres pgbackrest --stanza=default --type=diff backup
```

### Manual Incremental Backup
```bash
sudo -u postgres pgbackrest --stanza=default --type=incr backup
```

### List Backups
```bash
sudo -u postgres pgbackrest --stanza=default info --output=json | jq
```

### Restore Latest Backup
```bash
# Stop Patroni first
systemctl stop patroni

# Restore
sudo -u postgres pgbackrest --stanza=default --delta restore

# Start Patroni
systemctl start patroni
```

### Restore Specific Backup
```bash
sudo -u postgres pgbackrest --stanza=default --set=<backup-id> --delta restore
```

## PostgreSQL Operations

### Connect to Database
```bash
# As postgres user
sudo -u postgres psql

# Connect to specific database
sudo -u postgres psql -d <database-name>
```

### Check Replication Status
```sql
-- On primary
SELECT * FROM pg_stat_replication;

-- On replica
SELECT * FROM pg_stat_wal_receiver;
```

### Check Database Size
```sql
SELECT pg_database.datname, 
       pg_size_pretty(pg_database_size(pg_database.datname)) AS size
FROM pg_database
ORDER BY pg_database_size(pg_database.datname) DESC;
```

## Service Management

### Patroni
```bash
# Status
systemctl status patroni

# Start
systemctl start patroni

# Stop
systemctl stop patroni

# Restart
systemctl restart patroni

# View logs
journalctl -u patroni -f
```

### etcd
```bash
# Status
systemctl status etcd

# Start
systemctl start etcd

# Stop
systemctl stop etcd

# Restart
systemctl restart etcd

# View logs
journalctl -u etcd -f
```

## Firewall Management

### RHEL/CentOS/Rocky (firewalld)
```bash
# Check status
firewall-cmd --state

# List open ports
firewall-cmd --list-ports

# Add port
firewall-cmd --permanent --add-port=5432/tcp
firewall-cmd --reload

# Remove port
firewall-cmd --permanent --remove-port=5432/tcp
firewall-cmd --reload
```

### Debian/Ubuntu (ufw)
```bash
# Check status
ufw status

# Enable UFW
ufw enable

# Allow port
ufw allow 5432/tcp

# Delete rule
ufw delete allow 5432/tcp

# Disable UFW
ufw disable
```

## Troubleshooting

### Check All Services
```bash
systemctl status patroni
systemctl status etcd
systemctl status postgresql  # Should be disabled
```

### Check Logs
```bash
# Patroni logs
journalctl -u patroni -n 100 --no-pager

# etcd logs
journalctl -u etcd -n 100 --no-pager

# PostgreSQL logs (via Patroni)
tail -f /var/log/postgres/postgresql.log
```

### Check Network Connectivity
```bash
# Test PostgreSQL port
nc -zv <host> 5432

# Test Patroni API
curl http://<host>:8008/

# Test etcd
curl http://<host>:2379/health
```

### Check Data Directory
```bash
ls -la /opt/postgresql/17/data/
du -sh /opt/postgresql/17/data/
```

### Check Postgres User
```bash
# Get postgres home directory
getent passwd postgres

# Check SSH keys
ls -la $(getent passwd postgres | cut -d: -f6)/.ssh/
```

## Monitoring

### Patroni REST API
```bash
# Cluster status
curl http://localhost:8008/

# Primary node
curl http://localhost:8008/primary

# Replica nodes
curl http://localhost:8008/replica

# Health check
curl http://localhost:8008/health
```

### etcd Metrics
```bash
curl http://localhost:2379/metrics
```

## Backup Verification

### Check Backup Schedule
```bash
# View cron jobs for postgres user
crontab -u postgres -l
```

### Test Backup Script
```bash
# Run backup script manually
sudo -u postgres /opt/backup.sh -t full -s default
```

### Check Backup Logs
```bash
tail -f /var/log/pgbackrest/*.log
```

## Configuration Files

### Important File Locations
```
/etc/patroni/patroni.yml              # Patroni configuration
/etc/pgbackrest/pgbackrest.conf       # pgBackRest configuration
/etc/systemd/system/patroni.service   # Patroni systemd unit
/etc/systemd/system/etcd.service      # etcd systemd unit
/opt/postgresql/17/data/              # PostgreSQL data directory
/var/log/postgres/                    # PostgreSQL logs
/var/log/pgbackrest/                  # pgBackRest logs
```

### Edit Configuration
```bash
# Edit Patroni config
sudo vim /etc/patroni/patroni.yml

# Edit pgBackRest config
sudo vim /etc/pgbackrest/pgbackrest.conf

# Reload after changes
systemctl restart patroni
```

## Ansible Inventory Management

### Check Inventory
```bash
ansible-inventory -i inventory/default/hosts.yml --list
ansible-inventory -i inventory/default/hosts.yml --graph
```

### Test Connectivity
```bash
ansible -i inventory/default/hosts.yml all -m ping
```

### Run Ad-Hoc Commands
```bash
# Check disk space
ansible -i inventory/default/hosts.yml all -m shell -a "df -h /opt/postgresql"

# Check service status
ansible -i inventory/default/hosts.yml postgres -m shell -a "systemctl status patroni"
```

## Security

### Change Passwords
```bash
# Edit variables
vim inventory/default/group_vars/all.yml

# Use Ansible Vault to encrypt
ansible-vault encrypt inventory/default/group_vars/all.yml

# Edit encrypted file
ansible-vault edit inventory/default/group_vars/all.yml

# Run playbook with vault
ansible-playbook -i inventory/default/hosts.yml install_vm.yml --ask-vault-pass
```

### Generate Strong Passwords
```bash
# Generate random password
openssl rand -base64 32

# Generate cipher pass for pgBackRest
openssl rand -base64 48
```
