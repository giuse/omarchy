# Updates

Omarchy and your packages are kept up to date via _Update > Omarchy_ in the Omarchy menu (`Super + Space`).

Omarchy itself is installed as regular pacman packages from the [Omarchy Package Repository](https://github.com/omacom-io/omarchy-pkgs), so an update installs [the latest Omarchy release](https://github.com/omacom/omarchy/releases), runs any pending migrations to get your system in sync with the latest, and updates all system packages from the [Omarchy Arch Mirror](https://github.com/omacom-io/omarchy-mirror) and [AUR](https://aur.archlinux.org/) (if you have installed any AUR packages).

When new releases are made, a circle arrow icon will appear to the right of your clock. Click it and the update process will start.

### Menu changes

After an update, Omarchy can notify you when its menu changes. Open **Update → Menu changes** to see additions, removals, renames, and modifications by the date they were observed. You can also open this window at any time with `omarchy launch menu-changes`.

When a hidden command changes, or its command name appears in release notes, the update explains the old and new command or shows the matching release text. Confirm that you want to keep it hidden; this is selected by default. Choose **Show entry** to make it visible. If hidden-command reviews are turned off, pending reviews remain available in the change history.

Notification and hidden-command review settings are under **Setup → Menu entries**. Both are on by default. The review setting controls interaction; notifications control the separate update summary.

If you hide the Menu entries manager or Setup, reopen it from a terminal with `omarchy launch menu-settings`. Its visibility settings live at `~/.config/omarchy/menu-visibility.json`.

![update-available](images/update-available.webp)

### Four channels

Omarchy is updated along four channels: stable, RC, edge, and dev. New installations start on the stable channel, which tracks the [official releases](https://github.com/omacom/omarchy/releases/), as well as the [stable Omarchy Arch mirror](https://github.com/omacom-io/omarchy-mirror) that's running one month behind the latest, so we can catch any new incompatibilities that require config changes before they cause problems for people.

But if you'd like to help spot those potential issues, you can run on the edge channel. That'll keep your Omarchy packages tracking the latest development builds, and lets you update to the latest Arch packages as soon as they're available. You should only do this if you're experienced with Linux, and know how to recover a system that has problems.

Before any new major release, we'll be doing final validation using the RC channel. If you're interested in helping with final polishing, come hang out in #omarchy-release-candidates on the Discord.

Finally, there's the dev channel, which links Omarchy directly to a git checkout of the source code in `~/omarchy`, combined with the edge packages. You should only use this channel if you're an experienced Linux user, working directly on Omarchy, and willing to tolerate breakage.

You can switch between channels using _Update > Channel_ from the Omarchy menu (or `omarchy-channel-set` in the terminal).

### Firmware updates

Your packages aren't the only thing that goes stale. Many laptops and peripherals ship BIOS, SSD, and dock firmware through the Linux Vendor Firmware Service, and _Update > Firmware_ in the Omarchy menu will fetch and install whatever your hardware has waiting. It installs `fwupd` the first time you run it. Plenty of firmware can only be written during a reboot, so don't be surprised to be asked for one.

### Warning about direct pacman/yay updates

If you're already familiar with Arch, you might be tempted to just run `pacman -Syu` or `yay -Syu` yourself, but if you do that, you'll miss the snapshot, migrations, and configuration updates that Omarchy runs together with new packages. That's why Omarchy will actually stop a direct system upgrade and point you to `omarchy update` instead. (If you really know what you're doing, the guard will tell you how to bypass it for a single transaction.)

### Rolling back bad updates

If you ever have a problem after doing an update, you can rollback your system to the snapshot taken before the update. Just restart and pick the snapshot in the boot loading menu from before you started the update.

![bootloader](images/bootloader.webp)

If somehow your configuration files have been corrupted, you can also perform an Omarchy reinstall using `omarchy reinstall` in the terminal. This will reinstall all the default Omarchy packages, put you on stable and downgrade any packages that are too new, and reset all the configuration files. Note that all your user config changes to the Omarchy defaults will be overwritten doing this!
