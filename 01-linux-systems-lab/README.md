# Linux Systems Administration Lab

> **Status:** Completed — October 2026

A hands-on Linux administration lab on an Ubuntu AWS EC2 instance, covering identity management, filesystem permissions, command-line file operations, text processing, block storage, and safe infrastructure cleanup.

**Reference:** [DevOps Project 03 — Fun with Linux for Cloud & DevOps Engineers](https://github.com/NotHarshhaa/DevOps-Projects/tree/main/DevOps-Project-03)

## Environment

- AWS EC2 (Ubuntu Linux, `t3.micro`)
- Bash and standard GNU/Linux utilities
- 8 GiB root EBS volume and an additional 5 GiB EBS volume
- ext4 filesystem mounted at `/data`

## What I Implemented

- Created five Linux users and managed primary and supplementary groups (`devops`, `aws`, `app`, and `database`).
- Built a multi-level directory hierarchy and configured ownership and permissions using `chown`, `chmod`, and group membership.
- Created, moved, renamed, searched for, edited, and removed files as different users.
- Practiced `find`, `tail`, `sed`, `vi`, `tee`, `wc`, `getent`, and shell redirection.
- Created and attached a 5 GiB EBS volume, identified its Linux device name, formatted it as ext4, and mounted it at `/data`.
- Verified storage using `lsblk -f` and `df -h`, created `/data/f1`, and safely unmounted the filesystem.
- Removed lab users, groups, home directories, and mount points; detached and deleted the EBS volume and terminated the EC2 instance.

## Selected Verification

```bash
lsblk -f                       # Identify device filesystems and mount points
sudo mkfs.ext4 /dev/nvme1n1    # Format the verified, empty lab volume
sudo mount /dev/nvme1n1 /data  # Make its filesystem accessible at /data
df -h /data                    # Verify the mount and available space
sudo umount /data              # Safely disconnect the filesystem
```

The new EBS volume appeared as `/dev/nvme1n1` (5 GiB) and was mounted successfully at `/data`. The mount reported approximately **4.9 GiB total** and **4.6 GiB available**. The filesystem retained `/data/f1` after unmounting; only its directory-tree access was removed.

> **Safety:** Device names vary by instance and attachment. Always verify the target before running `mkfs`, which destroys existing filesystem data.

## Problems Solved and Lessons Learned

- **Directory permissions govern entry operations.** Moving or deleting a file requires suitable permissions on its parent directory, not just ownership of the file.
- **Lab instructions can omit necessary privileges.** Several exercises asked unprivileged users to create or delete entries directly under `/`, which was `root:root` with mode `755`. I avoided making `/` world-writable and used controlled administrative access where needed.
- **`sed -i` needs directory write access.** It commonly creates a temporary file in the target directory, so it failed when an ordinary user could modify `/f3` but not create entries under `/`.
- **Account deletion and group deletion are separate.** `userdel -r` removes a user's home directory, but unrelated or leftover groups may remain; active user processes can block deletion.
- **Block device, filesystem, and mount point are distinct.** Attaching EBS exposes storage, formatting creates filesystem structures, and mounting connects the filesystem to a path.

## Outcome

Completed the lab and cleaned up its AWS resources. The work strengthened my understanding of Linux identity and access management, filesystem behavior, storage administration, and troubleshooting rather than relying on commands without understanding their effects.

See [notes.md](notes.md) for detailed observations, commands, limitations, and troubleshooting.
