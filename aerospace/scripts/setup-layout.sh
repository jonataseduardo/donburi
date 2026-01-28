#!/bin/bash
# Setup 30/70 layout for workspace 1 (Slack 30% left, terminal 70% right)

# Switch to workspace 1
aerospace workspace 1
sleep 0.3

# Flatten any nested containers to simplify layout
aerospace flatten-workspace-tree
sleep 0.2

# Ensure horizontal layout
aerospace layout tiles horizontal
sleep 0.2

# Balance all windows to equal sizes first
aerospace balance-sizes
sleep 0.2

# Count windows to determine which is which
# Focus leftmost window (should be Slack after flattening)
aerospace focus left
aerospace focus left
aerospace focus left
sleep 0.1

# Get screen width (approximate calculation for resize)
# In AeroSpace, we resize by pixels. For a typical monitor:
# - If total width is ~2560px, each window at 50/50 would be ~1280px
# - For 30/70 split: Slack needs -512px, terminal needs +512px
# This creates a 30/70 ratio

# Resize left window (Slack) to be smaller
aerospace resize width -512
sleep 0.1

# Move to right window (terminal) and make it larger
aerospace focus right
aerospace resize width +512
