#!/system/bin/sh
# Restore the factory touch sampling rate.
for f in /sys/class/input/input*/device/fts_rw_reg; do
    [ -e "$f" ] && { echo 8818 > "$f" 2>/dev/null; break; }
done
exit 0