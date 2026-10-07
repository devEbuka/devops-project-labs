# Linux Systems Administration Lab --- Learning Notes

> Detailed working notes for Project 03. These notes capture
> troubleshooting, reasoning, mistakes, and lessons that are
> intentionally omitted from the portfolio README.

## Environment

-   AWS EC2
-   Ubuntu Linux
-   Bash / POSIX shell

## 1. Initial Users and Groups

Created `user1`, `user2`, and `user3`.

Created the groups:

-   `devops`
-   `aws`

Configured:

-   `user2` → primary group `devops`
-   `user3` → primary group `devops`
-   `user1` → supplementary group `aws`

Verified membership using `id`.

### Lesson

A Linux user has one primary group but can belong to multiple
supplementary groups. `id <user>` is a quick way to verify both.

## 2. Filesystem Structure

Built the required hierarchy:

``` text
/dir1
└── f1
/dir2
└── dir1
    └── dir2
        ├── dir10
        └── f3
/dir3
└── dir11
/dir4
└── dir12
    ├── f4
    └── f5
/dir5
└── dir13
/dir6
/dir7
├── dir10
└── f3
/dir8
└── dir9
/opt/dir14
├── dir10
└── f3
/f1
/f2
```

One early mistake was treating some required files as directories. This
reinforced the basic distinction:

``` bash
mkdir   # creates a directory
touch   # creates an empty regular file
```

## 3. Ownership Configuration

The project required `/dir1`, `/dir7/dir10`, and `/f2` to be owned by
`user1` and grouped under `devops`.

Configured and verified them as:

``` text
/dir1        → user1:devops
/dir7/dir10 → user1:devops
/f2          → user1:devops
```

### Lesson

Commands such as `chown` normally produce no output when successful.
Always verify the resulting state with commands such as:

``` bash
ls -ld <path>
```

## 4. Creating user4 and user5

The project required `user1` to create `user4`, `user5`, and the `app`
and `database` groups.

Running `useradd` directly as `user1` failed because modifying system
account information requires elevated privileges.

`sudo` also initially failed because `user1` was not authorized to use
it. `user1` was added to the Ubuntu `sudo` group, a new login session
was started, and the administrative commands could then be executed with
`sudo`.

### Lesson

Membership in the `sudo` group does not make every command privileged.
`sudo` elevates the specific command being executed.

## 5. Missing Home Directory

`user4` was created with `useradd`, but `/home/user4` did not exist.

`getent passwd user4` showed `/home/user4` as the configured home path
even though the directory itself had not been created.

The home directory was created manually and ownership corrected to:

``` text
user4:user4
```

### Lesson

The account database can specify a home directory without that directory
actually existing. Account configuration and filesystem state are
separate things.

## 6. Login Shell

`user4` initially used `/bin/sh`, which resulted in the minimal `$`
shell prompt.

The account configuration was inspected with:

``` bash
getent passwd user4
```

and the login shell was changed to Bash.

### Lesson

The final field of a user's `/etc/passwd` entry identifies the
configured login shell.

## 7. Creating /dir6/dir4 as user4

`/dir6` initially belonged to `root:root` with mode `755`.

As `user4`, creating `/dir6/dir4` failed with `Permission denied`.

Because `user4` fell under the `others` permission set, they had `r-x`
but no write permission.

Rather than granting broad access:

-   `user4` was added to the `app` group.
-   `/dir6` was assigned to the `app` group.
-   Group write permission was added.

`user4` could then create `/dir6/dir4`.

### Directory Permission Lesson

For directories:

  Permission   Meaning
  ------------ --------------------------------------------------
  `r`          List directory entries
  `w`          Create, delete, or rename entries
  `x`          Traverse/search the directory and access entries

A particularly important correction was that **directory traversal
requires `x`, not `r`**.

## 8. Symbolic chmod

At one point `/dir6` was changed using a numeric mode. A more targeted
operation was:

``` bash
chmod g+w /dir6
```

### Lesson

Numeric modes are useful when setting the complete permission state
deliberately. Symbolic modes are often safer when only one specific
permission needs to change.

## 9. Creating /f3

The project required `user4` to create `/f3`.

This exposed a gap in the lab instructions. `/` was correctly owned by
`root:root` with mode `755`, meaning `user4` had no write permission on
the root directory.

Giving all users write permission on `/` would be unsafe.

For the lab, `/f3` was created by root and ownership transferred to
`user4`.

Final state:

``` text
/f3 → user4:root
```

### Lesson

Do not weaken an important system directory simply to make a lab command
work. First understand which permission is actually missing and why.

## 10. Moving /dir1/f1

The required operation was:

``` text
/dir1/f1 → /dir2/dir1/dir2/f1
```

Initially, `user4` could not perform the move.

The source `/dir1` was required to remain associated with the `devops`
group, so instead of replacing that group:

-   `user4` was added to `devops`.
-   Group write permission was added to `/dir1`.

For the destination:

-   `/dir2/dir1/dir2` was assigned to the `app` group.
-   Group write permission was added.

The move then succeeded.

### Major Lesson

Moving a file is largely a **directory permission operation**.

To move a file between directories, the user needs appropriate
permissions on the source and destination parent directories. The write
permission on the file itself is not what determines whether its
directory entry can be moved.

## 11. Renaming /f2 to /f4

`/f2` was:

``` text
user1:devops
```

and `user4` was already a member of `devops`.

However:

``` bash
mv /f2 /f4
```

failed with:

``` text
mv: cannot move '/f2' to '/f4': Permission denied
```

The important object was not `/f2` itself but its parent directory `/`.

`/` was:

``` text
root:root
rwxr-xr-x
```

`user4` therefore had no write permission on `/`.

Renaming `/f2` to `/f4` requires removing one directory entry and
creating another inside `/`, so write permission on `/` is required.

The lab does not explicitly provide a safe permission arrangement for
`user4` to perform this operation. The root directory was deliberately
**not** made globally writable.

### Major Lesson

A user can potentially rename or delete a file they do not own if they
have the necessary permissions on the parent directory.

Likewise, owning or being able to read a file does not automatically
grant permission to rename or delete it.

## Commands and Concepts Practiced

``` text
useradd
usermod
id
getent
su
sudo
chown
chmod
mkdir
touch
mv
ls
```

Concepts covered so far:

-   User and group management
-   Primary vs supplementary groups
-   File ownership
-   Directory ownership
-   Numeric and symbolic permissions
-   Privilege escalation
-   Home directories
-   Login shells
-   Directory traversal
-   Parent-directory permissions
-   Permission troubleshooting

## Current Checkpoint

Paused after the `user4` portion of the project.

Next session will continue with the remaining `user1`, `user2`, root,
filesystem search, and EBS/storage tasks.
