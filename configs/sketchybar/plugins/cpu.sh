#!/bin/bash

CPU_INFO=$(top -l 1 -n 0 2>/dev/null | grep -E "^CPU" | tail -1)
USER=$(echo "$CPU_INFO" | awk '{print $3}' | tr -d '%')
SYS=$(echo "$CPU_INFO" | awk '{print $5}' | tr -d '%')

if [ -n "$USER" ] && [ -n "$SYS" ]; then
  TOTAL=$(echo "$USER + $SYS" | bc 2>/dev/null | cut -d. -f1)
  sketchybar --set $NAME label="${TOTAL:-0}%"
else
  sketchybar --set $NAME label="0%"
fi
