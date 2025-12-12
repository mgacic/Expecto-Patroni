# Group Variables Organization

This directory contains organized group variables split into logical files for better maintainability.

## File Structure

```
group_vars/all/
├── README.md           # This file
├── versions.yml        # Component versions (PostgreSQL, Patroni, etcd, pgBackRest)
├── postgresql.yml      # PostgreSQL and Patroni configuration
├── pgbackrest.yml      # pgBackRest backup configuration
├── etcd.yml           # etcd configuration
├── repositories.yml    # Package repository URLs and keys
└── packages.yml        # Package lists for all distributions
```

## How It Works

Ansible automatically loads **all** `.yml` files in the `group_vars/all/` directory and merges them together. This allows you to organize variables logically without changing how they're used.

## Benefits

✅ **Easy to Find** - Variables are grouped by component  
✅ **Easy to Edit** - Smaller files are easier to navigate  
✅ **Better Comments** - Each file can have detailed comments  
✅ **Version Control** - Easier to track changes to specific components  
✅ **Team Collaboration** - Multiple people can edit different files without conflicts  

## Quick Reference

### To Change Versions
Edit: `versions.yml`

### To Change Passwords
Edit: `postgresql.yml` (Patroni passwords) or `pgbackrest.yml` (backup passwords)

### To Change Backup Schedule
Edit: `pgbackrest.yml`

### To Add/Remove Packages
Edit: `packages.yml`

### To Change Repository URLs
Edit: `repositories.yml`

## Variable Naming Convention

Variables follow this pattern:
- `{component}_{category}_{name}`

Examples:
- `pg_version` - PostgreSQL version
- `patroni_superuser_password` - Patroni superuser password
- `pgbackrest_stanza` - pgBackRest stanza name
- `etcd_ports` - etcd network ports

## Security Best Practices

⚠️ **Important**: Use Ansible Vault to encrypt sensitive files:

```bash
# Encrypt password files
ansible-vault encrypt group_vars/all/postgresql.yml
ansible-vault encrypt group_vars/all/pgbackrest.yml

# Edit encrypted files
ansible-vault edit group_vars/all/postgresql.yml

# Run playbook with vault
ansible-playbook -i inventory/default/hosts.yml install_vm.yml --ask-vault-pass
```

## Migration from all.yml

If you have an old `all.yml` file, it has been backed up to `all.yml.backup`. The new split structure contains all the same variables, just better organized.

To verify nothing was lost:
```bash
# Compare variable counts
grep -E '^\w+:' all.yml.backup | wc -l
grep -E '^\w+:' all/*.yml | wc -l
```
