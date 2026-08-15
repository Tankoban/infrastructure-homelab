# Linux Workstation Migration

**Lab Date:** August 2026  
**Status:** Complete

## Objective

Convert an older Windows-based workstation into a Linux Mint Cinnamon daily driver while preserving Windows as a dual-boot fallback.

## Environment

- AMD FX-6300
- 16 GB RAM
- NVIDIA GTX 750 Ti
- TP-Link Archer TX20U Plus
- 1 TB SSHD
- 2 TB HDD
- 1 TB game drive

## Work Completed

- Converted Windows boot architecture from Legacy BIOS / MBR to UEFI / GPT.
- Installed Linux Mint Cinnamon alongside Windows.
- Configured GRUB dual boot.
- Installed NVIDIA proprietary drivers.
- Troubleshot wireless support for the TP-Link Archer TX20U Plus.
- Identified kernel-driver compatibility issues.
- Standardized the workstation on Linux kernel 6.8 for stable wireless support.
- Configured automatic NTFS storage mounts.
- Configured Timeshift system snapshots.
- Installed and configured Zsh and Oh My Zsh.
- Restored keyboard backlighting through X11 Scroll Lock LED control.

## Wireless Driver Troubleshooting

### Problem

The TP-Link wireless adapter was detected over USB but did not expose a working wireless interface.

### Investigation

Multiple Realtek driver families were initially tested before the correct hardware ID and driver family were confirmed.

Driver builds failed against newer Linux kernels because of kernel API incompatibilities.

### Resolution

A compatible Realtek DKMS driver successfully built against Linux kernel 6.8.

The system was configured to boot kernel 6.8 by default.

### Meaning

This demonstrated that hardware support depends not only on the device driver but also on compatibility between the driver and running kernel.

## Storage Configuration

Windows-compatible NTFS storage was mounted at:

```
/mnt/storage
```

Configured for persistent mounting and verified for read/write access.

## Keyboard Backlight

The keyboard backlight did not expose a standard Linux backlight interface.

Testing showed the keyboard firmware used the Scroll Lock LED state to control lighting.

The backlight was enabled with:

```
xset led named "Scroll Lock"
```

A delayed startup command was added so lighting initializes automatically after login.

Key Concepts Learned
UEFI vs Legacy BIOS
GPT vs MBR
GRUB dual boot
Linux kernel compatibility
DKMS drivers
Filesystem mounting
/etc/fstab
X11 LED control
System recovery snapshots
Lessons Learned
Newer kernels are not automatically better when third-party drivers are involved.
Hardware identification should happen before choosing a driver.
Linux generally fails safely when a filesystem may be unsafe to mount.
Troubleshooting logs and hardware IDs are often more valuable than guessing.
