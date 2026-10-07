# Linux Systems Administration Lab

Hands-on Linux administration project covering user management,
permissions, filesystem operations, and storage on an Ubuntu EC2
instance.

> **Status:** In Progress

## Environment

-   AWS EC2
-   Ubuntu Linux
-   Bash

## Tasks Completed

-   Created and managed Linux users and groups.
-   Configured primary and supplementary group memberships.
-   Built the required multi-level filesystem hierarchy.
-   Managed file and directory ownership with `chown`.
-   Configured permissions using symbolic and numeric `chmod`.
-   Configured shared directory access using Linux groups.
-   Troubleshot user home directory and login shell configuration.
-   Diagnosed permission failures when creating, moving, and renaming
    files.
-   Applied source and destination directory permissions to allow
    controlled file movement.

## Key Lessons

-   Directory `r`, `w`, and `x` permissions behave differently from file
    permissions.
-   `x` controls directory traversal, while `w` controls creating,
    deleting, and renaming entries.
-   Moving or deleting a file depends heavily on the permissions of its
    parent directory.
-   Supplementary groups provide controlled shared access without
    granting unnecessary privileges.
-   `sudo` elevates individual commands rather than permanently making a
    user root.
-   Permission and ownership changes should be verified instead of
    assuming a silent command succeeded.

## Issues Encountered

-   `user4` was created without a home directory and initially used
    `/bin/sh`; both were corrected.
-   Several operations in the original lab required permissions that
    were not explicitly configured.
-   Rather than making system directories globally writable, permissions
    were adjusted using ownership and group membership where
    appropriate.

## Progress

Completed through the `user4` filesystem and permissions exercises.

Remaining work includes additional user exercises, file manipulation,
filesystem searches, and EBS volume creation and mounting.
