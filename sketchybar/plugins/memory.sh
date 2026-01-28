#!/bin/bash

# Memory usage plugin
# Shows current memory usage percentage

# Get memory stats
MEMORY=$(memory_pressure 2>/dev/null | grep "System-wide memory free percentage" | awk '{print 100-$5}' | cut -d'%' -f1)

if [ -z "$MEMORY" ]; then
    # Fallback using vm_stat
    PAGES_FREE=$(vm_stat | grep "Pages free" | awk '{print $3}' | tr -d '.')
    PAGES_ACTIVE=$(vm_stat | grep "Pages active" | awk '{print $3}' | tr -d '.')
    PAGES_INACTIVE=$(vm_stat | grep "Pages inactive" | awk '{print $3}' | tr -d '.')
    PAGES_SPECULATIVE=$(vm_stat | grep "Pages speculative" | awk '{print $3}' | tr -d '.')
    PAGES_WIRED=$(vm_stat | grep "Pages wired" | awk '{print $4}' | tr -d '.')

    TOTAL=$((PAGES_FREE + PAGES_ACTIVE + PAGES_INACTIVE + PAGES_SPECULATIVE + PAGES_WIRED))
    USED=$((PAGES_ACTIVE + PAGES_WIRED))

    if [ $TOTAL -gt 0 ]; then
        MEMORY=$((USED * 100 / TOTAL))
    else
        MEMORY="--"
    fi
fi

sketchybar --set "$NAME" label="${MEMORY}%"
