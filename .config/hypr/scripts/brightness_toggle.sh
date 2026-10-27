#!/usr/bin/env bash
CURRENT=$(brightnessctl g)

if [ "$CURRENT" -eq 0 ]; then
    # save current, then set 0
    brightnessctl -r         
else
    # restore the saved value
    brightnessctl -s set 0   
fi