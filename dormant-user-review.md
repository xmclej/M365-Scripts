# 👤 User Cleanup Script

## ✅ Purpose

Identify and safely disable **inactive user accounts**.

---

## 🔍 Key Logic

| Signal | Source |
|------|--------|
| Last Sign-In | Entra signInActivity |
| Account Status | Entra |
| User Type | Member/Guest |

---

## 📊 Classification

- `ACTIVE`
- `DORMANT`
- `ALREADY_DISABLED`
- `GUEST`

---

## 📁 Output Files

| File | Description |
|-----|------------|
| `FULL` | All users |
| `MEMBERS` | Internal users |
| `MEMBERS_TOP50` | Safe disable candidates |
| `GUESTS` | All guest users |
| `GUESTS_TOP50` | Oldest guest accounts |
| `PRIVILEGED` | Users with admin roles |
| `Log` | Execution log |

---

## 🔐 Automatic Protections

Users are automatically excluded if:

- In exclusion CSV ✅  
- In emergency accounts CSV ✅  
- Hold privileged roles ✅  

---

## 🛡️ Safe Disable Criteria

A user is marked safe if:

- Dormant ✅  
- Member account ✅  
- Enabled ✅  
- NOT excluded/emergency/privileged ✅  

---

# 📄 Required CSV Files

## ✅ 1. Exclusion List

**File:** `ExcludedAccounts.csv`

```csv
UserPrincipalName
admin@contoso.com
serviceaccount@contoso.com
vip.user@contoso.com