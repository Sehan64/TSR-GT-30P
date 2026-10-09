# Touch Sampling Rate for Infinix GT 30 Pro

A KernelSU module that raises the touch sampling rate on the Infinix GT 30 Pro
(`X6873`) from 240 Hz to **360 Hz**.

Tested on XOS / Android 16, MTK mt6897, FocalTech digitizer (IC `0x5672`,
firmware `2e`, driver "FocalTech V4.1 20230424").

## Install

1. Root with [KernelSU](https://github.com/tiann/KernelSU) (required — the touch
   register is root-only).
2. Flash `TSR_GT-30P.zip` from the Releases page, or in KernelSU Manager:
   **Modules → Install from storage**.
3. Reboot.
4. Open the module in KernelSU and press **Action**.

Press Action, then use the volume keys within 12 seconds:

| Key | Result |
|---|---|
| Volume Up | 360 Hz |
| Volume Down | 242 Hz (stock) |

## Usage

The module also ships a WebUI — open it from the module list in KernelSU
Manager. It reads the current rate, offers a button per measured rate, and has a
box for any other value.

## How it works

The FocalTech digitizer exposes a raw register through sysfs:

```
/sys/class/input/input3/device/fts_rw_reg
```

Writing 4 hex digits sets a register: `88` + the two-digit value. So
`echo 8830 > .../fts_rw_reg` writes `0x30` to register `0x88`.

`0x88` is `FT_REG_POINT_RATE` — the report rate register. It is **not a linear
value**. It is a lookup into a firmware rate table, so the number you request is
frequently not the rate you get, and the mapping is not even monotonic:

| Register | Requests | Actually delivers |
|---|---|---|
| `0x10` | 160 Hz | 167 Hz |
| `0x12` | 180 Hz | 182 Hz |
| `0x11`, `0x13` | 170 / 190 Hz | 200 Hz |
| `0x18` | 240 Hz | 242 Hz (stock) |
| `0x14`–`0x17` | 200–230 Hz | 250 Hz |
| `0x1E` | 300 Hz | 296 Hz |
| `0x19`–`0x1D` | 250–290 Hz | 308 Hz |
| `0x24` | 360 Hz | 333 Hz |
| **`0x30`** | **480 Hz** | **360 Hz** |

Note `0x11` → 200 Hz but `0x12` → 182 Hz: raising the value *lowers* the rate.
Always look the value up rather than assuming.

`0x30` is the best setting found. It is the only value above `0x20` that is not
the 333 Hz plateau — every other value in `0x1F`–`0x64` was measured at exactly
333 Hz, including ones requesting 640 or 1000 Hz. Why `0x30` behaves differently
is not known; do not assume the pattern scales. Anything above `0x64` is
untested.

## Reverting

```
su -c 'echo 8818 > /sys/class/input/input3/device/fts_rw_reg'
```

Uninstalling the module restores the stock rate too.

## Known limitations

**The rate reverts every time the screen turns off.** The touch driver rewrites
the register on suspend, so the override is gone after any screen-off cycle —
wake the phone and re-apply. This reproduces with a bare screen off/on and has
nothing to do with game launchers, though launching a game via Infinix XArena
(which suspends the screen) triggers it too, which reads as XArena resetting the
rate.

Measured delivered rate is also capped in practice by the display, which cannot
exceed 120 Hz on this build. Samples above that are measured and discarded.

## Verifying a change

Check the register directly:

```
su -c 'echo 88 > /sys/class/input/input3/device/fts_rw_reg'
su -c 'cat /sys/class/input/input3/device/fts_rw_reg'
```

Expect `Read 88: 30`.

That node is write-and-read on one buffer: a bare `cat` replays the *last
operation*, not the register. You must do the 2-digit write first to select the
register, as above. Three consecutive `cat`s will otherwise all print the same
stale `Write ...` line.

To measure the real rate rather than the requested one, stream `getevent` and
take the mode of the SYN_REPORT gap histogram — with a finger held down for the
whole capture, since the panel only interrupts on contact:

```
su -c 'getevent -lt /dev/input/event3' | grep SYN_REPORT
```

Do **not** trust a max-over-N-seconds IRQ count. It latches onto a single contact
spike and reports wildly different values for the same register on repeat runs.

## Notes

`0x88` is a FocalTech chip-level control, not vendor-specific, so this approach
may carry over to other FocalTech digitizers — though the rate table above is
specific to this controller and will differ. FocalTech documents the register but
never publishes the value-to-rate mapping; their own drivers only read it for a
debug print.

The display's 144 Hz mode is unreachable on this build regardless of touch rate:
AOSP's `RefreshRateSelector.cpp` hardcodes `FrameRateCategory::High → FpsRange{90, 120}`.

## License

MIT