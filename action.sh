#!/system/bin/sh
# FocalTech touch sampling rate.
# VOLUME UP = high (0x30 -> 360 Hz), VOLUME DOWN = stock (0x18 -> 242 Hz).
# Reg 0x88 is a firmware rate-table lookup, not a linear value: the register's
# nominal value is not the delivered rate. 0x30 is the only value above 0x20
# that is not the 333 Hz plateau entry. Labels below are measured, not nominal.

MODE_HIGH=30
MODE_STOCK=18
WINDOW=12
REG=
for f in /sys/class/input/input*/device/fts_rw_reg; do
    [ -e "$f" ] && { REG=$f; break; }
done
[ -n "$REG" ] || { echo "TSR: no FocalTech touch device found"; exit 1; }

get_rate() {
    echo 88 > "$REG" 2>/dev/null
    tail -n1 "$REG" 2>/dev/null | sed -n 's/.*: *\([0-9A-Fa-f][0-9A-Fa-f]\).*/\1/p'
}

# Measured rate per register value; anything else falls back to nominal.
label() {
    case "$1" in
        10) echo "160 Hz" ;;
        11|13) echo "200 Hz" ;;
        12) echo "180 Hz" ;;
        18) echo "240 Hz" ;;
        14|15|16|17) echo "250 Hz" ;;
        1E) echo "290 Hz" ;;
        19|1A|1B|1C|1D) echo "310 Hz" ;;
        30) echo "360 Hz" ;;
        *) [ -n "$1" ] && echo "$((0x$1 * 10)) Hz" || echo "unknown" ;;
    esac
}

if [ "$1" = "--listen" ]; then
    for n in 0 1 2; do
        [ -e "/dev/input/event$n" ] || continue
        getevent -ql "/dev/input/event$n" 2>/dev/null | while read -r line; do
            case "$line" in
                *KEY_VOLUMEUP*DOWN*)   echo "88$MODE_HIGH"  > "$REG" 2>/dev/null ;;
                *KEY_VOLUMEDOWN*DOWN*) echo "88$MODE_STOCK" > "$REG" 2>/dev/null ;;
            esac
        done &
    done
    wait
    exit 0
fi

SELF=$(readlink -f "$0" 2>/dev/null)
[ -r "$SELF" ] || SELF=$0
setsid /system/bin/sh "$SELF" --listen >/dev/null 2>&1 &
LPID=$!
cleanup() { kill -TERM -"$LPID" 2>/dev/null; }
trap 'cleanup; exit 1' INT TERM HUP

start=$(get_rate)
echo "TSR: VOLUME UP = 360 Hz, VOLUME DOWN = 240 Hz (stock)"
echo "TSR: waiting ${WINDOW}s (current: $(label "$start"))"

i=0
while [ "$i" -lt "$WINDOW" ]; do
    sleep 1
    i=$((i + 1))
    [ "$(get_rate)" != "$start" ] && break
done

cleanup
final=$(get_rate)
[ -n "$final" ] || final=$start

if [ "$final" = "$start" ]; then
    echo "TSR: unchanged - $(label "$final")"
else
    echo "TSR: now $(label "$final")"
fi
exit 0
