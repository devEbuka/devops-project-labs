# Linux Systems Administration Lab — Learning Notes

> **Status:** Completed — October 2026  
> Detailed working notes for [Project 03](https://github.com/NotHarshhaa/DevOps-Projects/tree/main/DevOps-Project-03). These notes preserve the reasoning, mistakes, and troubleshooting behind the concise portfolio README.

## Environment

- Ubuntu Linux on AWS EC2 (`t3.micro`)
- Root volume: 8 GiB; additional EBS volume: 5 GiB
- Bash, GNU/Linux utilities, ext4
- The instance and temporary EBS volume were deleted after the lab.

## 1. Users, Groups, and Identity

Created `user1`, `user2`, and `user3`; configured `devops` and `aws` groups and primary/supplementary memberships. Later, `user1` created `user4`, `user5`, `app`, and `database` with elevated privileges.

Useful commands:

```bash
id user1
getent passwd user4
getent group devops
usermod -aG app user4
```

**Lessons:** A user has one primary group and may have multiple supplementary groups. Group changes may require a fresh login session. `getent` consults the system's configured name-service databases, which can include sources beyond local `/etc/passwd` and `/etc/group`.

### User setup problems

- `user4` initially lacked an actual home directory despite having a home path in its account record; created the directory and corrected ownership.
- `user4` initially had `/bin/sh` rather than Bash; inspected and changed the configured login shell.
- `user1` could not run privileged account-management commands until given authorized `sudo` access. Membership in `sudo` does not elevate ordinary commands automatically.

## 2. Filesystem Hierarchy, Ownership, and Permissions

Built the required nested `/dir1`–`/dir8` and `/opt/dir14` hierarchy and test files. Used `mkdir`, `touch`, `chown`, `chmod`, `ls -ld`, `mv`, and `rm` to manage them.

Required ownership examples included:

```text
/dir1        user1:devops
/dir7/dir10 user1:devops
/f2          user1:devops (later renamed to /f4)
```

### Why operations failed

- `user4` initially could not create `/dir6/dir4`: `/dir6` lacked group write permission. Configured an appropriate shared group and group permissions.
- Moving `/dir1/f1` to `/dir2/dir1/dir2/` required appropriate permissions on **both parent directories**. The file's own write bit did not grant the ability to move its directory entry.
- Creating `/f3` and renaming `/f2` to `/f4` as an ordinary user failed because `/` was `root:root` with mode `755`.
- Later, `user2` and `user5` could not remove root-level directory entries for the same reason. Used root or explicitly elevated commands for those operations rather than making `/` globally writable.

**Key rule:** For ordinary directory entry creation, deletion, and renaming, the parent directory generally needs `w+x`. Recursive deletion also depends on permissions within subdirectories. Sticky directories such as `/tmp` add further restrictions.

## 3. user1: Paths and File Manipulation

Completed the user1 exercises involving `/home/user2/dir1`, moving a test file to the user1 home directory, removing `/dir4`, clearing `/opt/dir14` contents, and writing the required text to `/f3`.

The relative-path task was originally completed using an absolute path rather than the requested relative path. From `/dir2/dir1/dir2/dir10`, the correct relative path to `/opt/dir14/dir10/f1` is:

```text
../../../../opt/dir14/dir10/f1
```

This was identified afterward but not rerun. It remains a useful reminder to distinguish absolute paths (`/opt/...`) from paths resolved relative to the current working directory.

The requested text contained `!!`:

```text
Linux assessment for an DevOps Engineer!! Learn with Fun!!
```

Bash history expansion interfered with the initial attempt. Using single quotes protected the literal exclamation marks.

## 4. user2: Editing Text and Removing Files

Created `/dir1/f2`, worked through removal of `/dir6` and `/dir8` with the necessary privilege boundary, and edited `/f3`:

- Replaced `DevOps` with `devops` without a text editor.
- Used `vi` to duplicate the first line ten times, producing 11 lines total (`wc -l /f3`).
- Replaced `Engineer` with `engineer` using a shell command.
- Removed `/f3` with root privileges because its parent was `/`.

### Why `sed -i` failed

`/f3` was writable by the user through group permissions, but `/` was not. GNU `sed -i` commonly creates a temporary file alongside its target and then renames it, requiring permission to create entries in `/`.

A non-in-place alternative used a temporary file in a writable directory:

```bash
sed 's/Engineer/engineer/g' /f3 > /tmp/f3.tmp
cat /tmp/f3.tmp > /f3
rm /tmp/f3.tmp
```

This works when the user can write the target file, even if they cannot replace its directory entry. It is **not atomic**; for production workflows, use a carefully permissioned temporary location and an appropriate replacement strategy.

An earlier `sed ... /f3 | tee /f3` attempt succeeded in the lab but is unsafe because `tee` may truncate the input file before `sed` has finished reading it. Avoid reading and overwriting the same file in a pipeline.

## 5. root: Searching and Inspecting

Searched for all files named `f3`:

```bash
find / -type f -name 'f3' 2>/dev/null
```

Found, among others:

```text
/dir7/f3
/dir2/dir1/dir2/f3
```

Counted regular files directly under `/`:

```bash
find / -maxdepth 1 -type f 2>/dev/null | wc -l
```

The result was `1` at that stage of the lab. Printed the last passwd entry using:

```bash
tail -n 1 /etc/passwd
```

**Lesson:** `find /` can be expensive because it traverses much of the filesystem. Narrow the search root where possible; `-xdev` can restrict traversal to one filesystem.

## 6. EBS: Attach, Format, and Mount

Created a **5 GiB EBS volume** in the same Availability Zone as the running EC2 instance and attached it. Although the AWS attachment name was `/dev/sdf`, Linux exposed it as an NVMe device:

```text
/dev/nvme0n1  8G  root disk — do not format
/dev/nvme1n1  5G  new EBS lab disk
```

Checked the device before formatting:

```bash
lsblk
lsblk -f
```

The new device initially had no filesystem. Created ext4 on the **verified lab device**:

```bash
mkfs.ext4 /dev/nvme1n1
```

The filesystem received UUID:

```text
4a31efbe-af4a-4d09-8d87-ddcba62d579e
```

Created a mount point, mounted the device, and verified it:

```bash
mkdir -p /data
mount /dev/nvme1n1 /data
df -h /data
lsblk
touch /data/f1
ls /data
```

Observed:

```text
Filesystem      Size  Used Avail Use% Mounted on
/dev/nvme1n1    4.9G  1.3M  4.6G   1% /data
```

`/data` contained `f1` and the ext4-created `lost+found` directory.

### Storage model

1. **Attach a block device:** the OS sees addressable storage.
2. **Create a filesystem:** ext4 supplies metadata, inodes, directories, and free-space management.
3. **Mount:** the filesystem becomes accessible through a path in the Linux directory tree.

Partitioning is optional for this simple single-filesystem lab. Mounting with `mount` alone does not configure persistence across reboots; production systems often use filesystem UUIDs in `/etc/fstab`.

## 7. Cleanup: Users, Groups, and Storage

Deleted the requested root-level lab directories and files. Because `/` was not writable by `user5`, temporary sudo access was used in this disposable environment; this was a deliberate lab shortcut, **not a recommended production privilege model**.

Removed users and their home directories:

```bash
userdel -r user2
```

Encountered several messages:

- `mail spool ... not found`: harmless when no spool existed.
- `group user2 not removed`: deleting a user does not necessarily remove a same-named group, particularly when it is not the user's primary group.
- `user5 is currently used by process 60308`: an active `-bash` shell was keeping the account in use. Inspected it with `ps -fp 60308` and closed the session before account deletion.

Verified and removed leftover groups using `getent group` and `groupdel`. Final lookup for lab groups returned no entries.

### Unmount and AWS cleanup

```bash
umount /data
lsblk
ls -la /data
rmdir /data
```

`lsblk` showed the 5 GiB device with no mount point, and `/data` was empty before removal. **Unmounting did not delete `f1` from the EBS filesystem**; it only removed access through `/data`.

Finally detached and deleted the temporary 5 GiB EBS volume and terminated the EC2 instance through AWS.

## 8. Main Takeaways

- Filesystem ownership and parent-directory permissions answer different questions.
- Broad `sudo` privileges are a shortcut, not a substitute for designing least-privilege access.
- Shell quoting matters, particularly with history-expansion characters such as `!`.
- Text-replacement tools can require different permissions depending on whether they edit bytes or replace directory entries.
- A block device is not automatically a mounted filesystem.
- Verify the device before formatting; verify the mount before writing; unmount before detaching.
- Inspect active processes before deleting users, and verify leftover groups after account removal.
- Document deviations from instructions rather than implying a task was performed exactly as written.

**Final status:** Project completed; temporary AWS resources cleaned up.
