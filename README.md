# CombineHits

CombineHits is a World of Warcraft addon designed specifically for Fury Warriors that tracks and displays your most powerful ability hits, with a special focus on abilities that deal damage in multiple hits (like Rampage, Raging Blow, and Execute).

## Overview

This addon is particularly useful for Fury Warriors who want to track their highest hitting abilities and maintain a record of their most powerful hits. It's especially helpful for monitoring abilities that deal damage in multiple hits, combining them into a single total for easier tracking.

## Compatibility

- **Game Version**: World of Warcraft Retail (The War Within)
- **Class**: Warrior
- **Specialization**: Fury only
- **Dependencies**: None

## Features

- **Real-time Damage Tracking**: Combines multiple hits from the same ability cast into a single total
- **Leaderboard System**: Keeps track of your highest damage hits for each ability
- **Location Tracking**: Records where your highest hits occurred
- **Time Tracking**: Records when your highest hits occurred

## Supported Abilities

Currently tracks the following Fury Warrior abilities:
- Rampage (all 4 hits)
- Raging Blow (both hits)
- Execute (including low health execute)
- Bloodthirst
- Thunder Clap
- Thunder Blast

## Commands

- `/ch` or `/combinehits` - Toggle the main display frame
- `/ch reset` - Reset the frame position to center of screen
- `/ch lb` - Toggle the leaderboard display

## Installation

1. Download the addon
2. Extract to your `World of Warcraft/_retail_/Interface/AddOns` folder
3. Restart World of Warcraft if it's running
4. Enable the addon in your addon list

## Configuration

The addon provides a movable frame that can be positioned anywhere on your screen. The main display shows your most recent powerful hits, while the leaderboard keeps track of your highest damage for each ability.