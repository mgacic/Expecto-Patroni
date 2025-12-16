# Migration Guide: Upgrading to Multi-Distribution Support

## Overview

This guide helps you migrate from the old RHEL-only version of Expecto-Patroni to the new multi-distribution version that supports both RPM and APT-based systems.

## What Changed?

### ✅ Backward Compatible Changes
- All existing RHEL/CentOS/Rocky deployments will continue to work without modifications
- No breaking changes to existing configurations
- All variable names remain the same
- Data directory location unchanged (`/opt/postgresql/{{ pg_version }}/data/`)

### 🆕 New Features
- Support for Debian and Ubuntu distributions
- Automatic OS detection and package manager selection
- Flexible postgres home directory handling
- UFW firewall support (in addition to firewalld)
- Improved package name handling

### 📝 New Variables
- `postgres_home_dir` - Automatically set based on OS family
- `postgres_apt_key_url` - PostgreSQL APT repository key
- `postgres_apt_repository` - PostgreSQL APT repository configuration

## Migration Steps

### For Existing RHEL/CentOS/Rocky Deployments

**Good news:** No migration required! Your existing deployment will continue to work.

#### Optional: Update to Latest Version

1. **Backup your current configuration:**
   ```bash
   cd /home/mgacic/SOURCE/Expecto-Patroni
   git stash  # If you have local changes
   ```

2. **Pull the latest changes:**
   ```bash
   git pull origin main
   ```

3. **Review the changes:**
   ```bash
   git diff HEAD~1 inventory/default/group_vars/all.yml
   ```

4. **Test with dry-run:**
   ```bash
   ansible-playbook -i inventory/default/hosts.yml install_vm.yml --check --diff
   ```

5. **Apply updates (if needed):**
   ```bash
   ansible-playbook -i inventory/default/hosts.yml install_vm.yml
   ```

### For New Debian/Ubuntu Deployments

1. **Update inventory** (`inventory/default/hosts.yml`):
   ```yaml
   all:
     children:
       postgres:
         hosts:
           debian-host-1:
           debian-host-2:
           debian-host-3:
       etcd:
         hosts:
           debian-host-1:
           debian-host-2:
           debian-host-3:
       pgbackrest:
         hosts:
           debian-backup-host:
             pgbackrest_repo_id: 1
   ```

2. **Verify variables** (`inventory/default/group_vars/all.yml`):
   - No changes needed! The playbook automatically detects Debian and uses correct packages.

3. **Run the playbook:**
   ```bash
   ansible-playbook -i inventory/default/hosts.yml install_vm.yml
   ```

### For Mixed RHEL + Debian Deployments

You can have both RHEL and Debian nodes in the same cluster!

**Example inventory:**
```yaml
all:
  children:
    postgres:
      hosts:
        rhel-node-1:
        debian-node-1:
        debian-node-2:
    etcd:
      hosts:
        rhel-node-1:
        debian-node-1:
        debian-node-2:
    pgbackrest:
      hosts:
        rhel-backup:
          pgbackrest_repo_id: 1
```

**Important Notes:**
- Patroni and etcd work seamlessly across different OS families
- pgBackRest SSH keys are automatically exchanged between all nodes
- The playbook handles OS-specific differences automatically

## Verification After Migration

### 1. Check Ansible Facts
```bash
ansible -i inventory/default/hosts.yml all -m setup -a "filter=ansible_os_family"
```

Expected output:
```
rhel-node-1 | SUCCESS => {
    "ansible_facts": {
        "ansible_os_family": "RedHat"
    }
}
debian-node-1 | SUCCESS => {
    "ansible_facts": {
        "ansible_os_family": "Debian"
    }
}
```

### 2. Run Validation Script
```bash
# Copy to each host
for host in rhel-node-1 debian-node-1 debian-node-2; do
    scp validate.sh root@$host:/tmp/
    ssh root@$host "bash /tmp/validate.sh"
done
```

### 3. Check Cluster Status
```bash
# On any node
patronictl -c /etc/patroni/patroni.yml list
```

Expected output should show all nodes (both RHEL and Debian) in the cluster.

### 4. Verify Data Directory
```bash
ansible -i inventory/default/hosts.yml postgres -m shell -a "ls -la /opt/postgresql/17/data/"
```

All nodes should have the same data directory structure.

### 5. Check Postgres Home Directory
```bash
ansible -i inventory/default/hosts.yml all -m shell -a "getent passwd postgres"
```

Expected:
- RHEL nodes: `postgres:x:26:26:PostgreSQL Server:/var/lib/pgsql:/bin/bash`
- Debian nodes: `postgres:x:109:117:PostgreSQL administrator:/var/lib/postgresql:/bin/bash`

## Rollback Plan

If you encounter issues, you can rollback:

### Option 1: Git Rollback
```bash
cd /home/mgacic/SOURCE/Expecto-Patroni
git log --oneline  # Find the commit before migration
git checkout <commit-hash>
ansible-playbook -i inventory/default/hosts.yml install_vm.yml
```

### Option 2: Manual Rollback
The new version is backward compatible, so rollback should not be necessary for RHEL systems.

For Debian systems, if you need to remove:
```bash
# On Debian hosts
systemctl stop patroni
systemctl stop etcd
apt remove postgresql-17 postgresql-client-17 pgbackrest
rm -rf /opt/postgresql
rm -rf /etc/patroni
rm -rf /etc/pgbackrest
```

## Common Issues and Solutions

### Issue 1: Package Not Found (Debian)

**Symptom:**
```
E: Unable to locate package postgresql-17
```

**Solution:**
Check that PostgreSQL APT repository was added correctly:
```bash
cat /etc/apt/sources.list.d/pgdg.list
apt update
apt-cache search postgresql-17
```

### Issue 2: Firewall Blocking Connections

**Symptom:**
Cannot connect to PostgreSQL/etcd from other nodes.

**Solution (RHEL):**
```bash
firewall-cmd --permanent --add-port=5432/tcp
firewall-cmd --permanent --add-port=8008/tcp
firewall-cmd --permanent --add-port=2379/tcp
firewall-cmd --permanent --add-port=2380/tcp
firewall-cmd --reload
```

**Solution (Debian):**
```bash
ufw allow 5432/tcp
ufw allow 8008/tcp
ufw allow 2379/tcp
ufw allow 2380/tcp
```

### Issue 3: Debian Auto-Created Cluster

**Symptom:**
Debian created a default cluster in `/var/lib/postgresql/17/main/`

**Solution:**
The playbook now prevents this automatically. If it happened:
```bash
systemctl stop postgresql@17-main
systemctl disable postgresql@17-main
pg_dropcluster 17 main
```

### Issue 4: SSH Key Exchange Failed

**Symptom:**
pgBackRest cannot connect between nodes.

**Solution:**
Manually verify SSH connectivity:
```bash
# On postgres node
sudo -u postgres ssh postgres@<pgbackrest-host>

# If fails, check SSH keys
ls -la $(getent passwd postgres | cut -d: -f6)/.ssh/
```

Re-run the pgbackrest role:
```bash
ansible-playbook -i inventory/default/hosts.yml install_vm.yml --tags pgbackrest
```

### Issue 5: Wrong Postgres Home Directory

**Symptom:**
SSH keys or .pgpass file in wrong location.

**Solution:**
The `postgres_home_dir` variable should handle this automatically. Verify:
```bash
ansible -i inventory/default/hosts.yml all -m debug -a "var=postgres_home_dir"
```

If incorrect, re-run the playbook:
```bash
ansible-playbook -i inventory/default/hosts.yml install_vm.yml
```

## Testing Checklist

Before considering migration complete, verify:

- [ ] All nodes appear in `patronictl list`
- [ ] One node is primary, others are replicas
- [ ] etcd cluster is healthy (`etcdctl endpoint health`)
- [ ] pgBackRest can create backups
- [ ] Firewall allows required ports
- [ ] SSH keys work between all nodes
- [ ] Data directory is `/opt/postgresql/17/data/` on all nodes
- [ ] Patroni can perform switchover
- [ ] Backups are scheduled in cron
- [ ] All services start on boot

## Performance Considerations

### RHEL vs Debian Performance
- No significant performance difference expected
- Both use the same PostgreSQL binaries from official repositories
- Patroni and etcd are distribution-agnostic (Python and Go)

### Mixed Cluster Performance
- Network latency is more important than OS choice
- Ensure all nodes have similar hardware specs
- Monitor replication lag: `SELECT * FROM pg_stat_replication;`

## Support and Troubleshooting

### Getting Help
1. Check logs: `journalctl -u patroni -f`
2. Review `QUICK_REFERENCE.md` for common commands
3. Run `validate.sh` on each node
4. Check GitHub issues

### Reporting Issues
When reporting issues, include:
- OS distribution and version (`cat /etc/os-release`)
- Ansible version (`ansible --version`)
- Error messages from logs
- Output of `validate.sh`
- Inventory configuration (sanitized)

## Next Steps After Migration

1. **Set up monitoring** - Add Prometheus/Grafana
2. **Configure SSL/TLS** - Secure PostgreSQL connections
3. **Implement Ansible Vault** - Encrypt sensitive variables
4. **Test failover** - Verify HA works correctly
5. **Document your setup** - Keep notes on customizations
6. **Schedule maintenance** - Plan for updates and backups

## Conclusion

The migration to multi-distribution support is designed to be seamless for existing RHEL deployments while opening up support for Debian/Ubuntu systems. The playbook handles all OS-specific differences automatically.

If you encounter any issues not covered in this guide, please refer to:
- `README.md` - General documentation
- `QUICK_REFERENCE.md` - Command reference
- `REFACTORING_SUMMARY.md` - Technical changes
