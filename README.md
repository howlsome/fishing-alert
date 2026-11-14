# Fishing Alert

**Visual fishing cues for World of Warcraft: Forever, made for deaf and hard-of-hearing players.**

Fishing in WoW is built around sound. You cast, wait, and listen for the splash that means a fish has bitten. If you can't hear it, you end up staring at a tiny bobber in moving water, hoping to catch the dip. Fishing Alert makes fishing something you can do with your eyes.

## What it does

### A big marker above your bobber
While your line is out, a large fishing-hook icon with a coloured border and an arrow pulses above the bobber and follows it on screen. You choose its size (24 to 128 pixels) and colour. Optionally, the small "Fishing Bobber" text is hidden so the marker is the only thing above the water.

### Screen-edge flashes for things you'd otherwise only hear
The edges of your screen flash, in colours you choose, when:

- **the fish got away** (red by default)
- **your line ran out** without a bite (yellow)
- **your cast missed the water**, or the water is too shallow (orange)

### One key to fish
While a fishing pole is equipped, **F** (or **Space**, if you prefer) casts, and the same key reels in the bobber. You don't need to find the bobber with your mouse. Unequip the pole and your key goes back to normal.

### Lures without the fuss
- If your pole has no lure on, the fishing key applies your best lure first, then casts on the next press.
- **Shift + your fishing key** opens a lure picker showing every lure in your bags with its bonus. Click one, or use the arrow keys and your fishing key.
- Lures are found by reading their tooltips, so new lures work without an update.

### Gamepad support
If you play with a controller, Fishing Alert can use a pad button as your fishing button and another to open the lure picker. In the picker, the D-pad chooses a lure, your fishing button applies it, and B closes it.

The Gamepad settings only appear when the game's **Enable Gamepad** option is on **and** a controller is connected, so keyboard players never see them. Plug a controller in and they appear straight away.

## What it can't do, and why

**Fishing Alert cannot flash at the exact moment a fish bites.** No addon can. The game doesn't tell addons when a fish bites. The bite is only signalled by the splash sound and the bobber's movement, and Blizzard keeps both out of reach of addon code. We tested this thoroughly: no game event fires at the bite, and the splash sound is never visible to addons.

That's why Fishing Alert focuses on making the bobber impossible to lose sight of, so you can watch it dip, and on telling you visually about everything else that normally comes through sound.

If you'd like a true visual bite cue, please let Blizzard know through the in-game feedback or the official forums. It's something only they can add.

## Settings

Open them with **`/fa`**, or go to **Options > AddOns > Fishing Alert**.

- Fishing key: F or Space
- Gamepad fishing button and lure picker button (when a controller is connected)
- Auto-apply best lure
- Bobber marker: on/off, size, colour, hide the "Fishing Bobber" text
- Optional countdown bar, if you don't already have a cast bar
- Flash colours, with a preview for each

### Chat commands

| Command | What it does |
| --- | --- |
| `/fa` | Open settings |
| `/fa test` | Preview all the flashes |
| `/fa lures` | List the lures found in your bags |
| `/fa status` | Show your current setup |
| `/fa debug` | Toggle a troubleshooting log while fishing |
| `/fa help` | List all commands |

## Game settings Fishing Alert changes

To find the bobber, Fishing Alert switches on some of the game's own soft-targeting settings **only while your fishing pole is equipped**:

- `SoftTargetInteract`
- `SoftTargetIconGameObject`
- `SoftTargetIconInteract`
- `SoftTargetLowPriorityIcons`
- `SoftTargetNameplateInteract`

Your original values are saved and put back as soon as you unequip the pole. If the game closes while you're fishing, they're restored on your next login. You can turn this off in settings.

## Known limitations

- Key bindings can't be changed during combat, which is a game rule. If you're attacked with your pole equipped, your fishing key keeps fishing until combat ends.
- With **Space** as your fishing key, you can't jump while your pole is equipped.

## Feedback

Found a bug or have an idea? Please open an issue on GitHub. Feedback from deaf and hard-of-hearing players is especially welcome.
