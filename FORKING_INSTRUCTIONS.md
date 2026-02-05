# Forking RanvierMUD Repositories to Ranvire

## Overview

This document provides instructions for forking all RanvierMUD repositories into the Ranvire organization while preserving commit history of the main/master branch, tags, and repository structure.

## Repositories to Fork

The following repositories from the RanvierMUD organization need to be forked:

### Core Repositories
1. **ranviermud** - A node.js based MUD game engine (Main repository)
   - URL: https://github.com/RanvierMUD/ranviermud
   - License: MIT
   - Primary Language: JavaScript

2. **core** - Core engine code for Ranvier
   - URL: https://github.com/RanvierMUD/core
   - License: MIT
   - Primary Language: JavaScript

3. **ranvier-telnet** - Telnet server and socket with GMCP support
   - URL: https://github.com/RanvierMUD/ranvier-telnet
   - License: MIT
   - Primary Language: JavaScript

4. **neuro** - Websocket MUD client for the Ranvier MUD game engine
   - URL: https://github.com/RanvierMUD/neuro
   - License: MIT
   - Primary Language: HTML

5. **docs** - Documentation
   - URL: https://github.com/RanvierMUD/docs
   - Primary Language: Shell

### Networking
6. **websocket-networking** - Websocket networking implementation
   - URL: https://github.com/RanvierMUD/websocket-networking
   - Primary Language: JavaScript

7. **telnet-networking** - Telnet networking implementation
   - URL: https://github.com/RanvierMUD/telnet-networking
   - Primary Language: JavaScript

### Data Sources
8. **datasource-file** - File based DataSources for Ranvier
   - URL: https://github.com/RanvierMUD/datasource-file
   - Primary Language: JavaScript

### Example Bundles
9. **bundle-example-commands** - Example commands bundle
   - URL: https://github.com/RanvierMUD/bundle-example-commands
   - Primary Language: JavaScript

10. **bundle-example-combat** - Example combat bundle
    - URL: https://github.com/RanvierMUD/bundle-example-combat
    - Primary Language: JavaScript

11. **bundle-example-player-events** - Example player events bundle
    - URL: https://github.com/RanvierMUD/bundle-example-player-events
    - Primary Language: JavaScript

12. **bundle-example-effects** - Example effects bundle
    - URL: https://github.com/RanvierMUD/bundle-example-effects
    - Primary Language: JavaScript

13. **bundle-example-quests** - Example quests bundle
    - URL: https://github.com/RanvierMUD/bundle-example-quests
    - Primary Language: JavaScript

14. **bundle-example-npc-behaviors** - Example NPC behaviors bundle
    - URL: https://github.com/RanvierMUD/bundle-example-npc-behaviors
    - Primary Language: JavaScript

15. **bundle-example-lib** - Example library bundle
    - URL: https://github.com/RanvierMUD/bundle-example-lib
    - Primary Language: JavaScript

16. **bundle-example-input-events** - Example input events bundle
    - URL: https://github.com/RanvierMUD/bundle-example-input-events
    - Primary Language: JavaScript

17. **bundle-example-areas** - Example areas bundle
    - URL: https://github.com/RanvierMUD/bundle-example-areas
    - Primary Language: JavaScript

18. **bundle-example-debug** - Example debug bundle
    - URL: https://github.com/RanvierMUD/bundle-example-debug
    - Primary Language: JavaScript

19. **bundle-example-classes** - Example classes bundle
    - URL: https://github.com/RanvierMUD/bundle-example-classes
    - Primary Language: JavaScript

20. **bundle-example-channels** - Example channels bundle
    - URL: https://github.com/RanvierMUD/bundle-example-channels
    - Primary Language: JavaScript

21. **bundle-example-bugreport** - Example bug report bundle
    - URL: https://github.com/RanvierMUD/bundle-example-bugreport
    - Primary Language: JavaScript

### Feature Bundles
22. **lootable-npcs** - Ranvier bundle for having NPCs drop loot
    - URL: https://github.com/RanvierMUD/lootable-npcs
    - Primary Language: JavaScript

23. **vendor-npcs** - Vendor NPCs bundle
    - URL: https://github.com/RanvierMUD/vendor-npcs
    - Primary Language: JavaScript

24. **simple-crafting** - Simple crafting system bundle
    - URL: https://github.com/RanvierMUD/simple-crafting
    - Primary Language: JavaScript

25. **player-groups** - Ranvier bundle for a player party system
    - URL: https://github.com/RanvierMUD/player-groups
    - Primary Language: JavaScript

26. **dialogflow-npcs** - NPC behavior bundle for interactable npcs via Dialogflow
    - URL: https://github.com/RanvierMUD/dialogflow-npcs
    - Primary Language: JavaScript

27. **simple-waypoints** - Bundle for a simple player fast-travel system
    - URL: https://github.com/RanvierMUD/simple-waypoints
    - Primary Language: JavaScript

28. **progressive-respawn** - Progressive respawn bundle
    - URL: https://github.com/RanvierMUD/progressive-respawn
    - Primary Language: JavaScript

### Starter Kits
29. **trpg-skeleton** - Tactical turn based RPG style MUD skeleton
    - URL: https://github.com/RanvierMUD/trpg-skeleton
    - License: MIT
    - Primary Language: JavaScript

30. **tiny** - Absolutely barebones starter kit for advanced users only
    - URL: https://github.com/RanvierMUD/tiny
    - License: MIT
    - Primary Language: JavaScript

## Forking Instructions

### Method 1: Using GitHub Web Interface (Recommended for Individual Repositories)

For each repository listed above:

1. Navigate to the repository URL
2. Click the "Fork" button in the top-right corner
3. Select "Ranvire" as the destination organization
4. Keep the same repository name
5. Ensure "Copy the main branch only" is **CHECKED** (default)
6. Click "Create fork"

**Important**: This method automatically preserves:
- Complete commit history of the default branch
- All tags
- Repository settings (where applicable)

**Note**: Feature branches are not copied - only the main/master branch is forked for maintenance purposes.

### Method 2: Using GitHub CLI (Recommended for Batch Forking)

Prerequisites:
```bash
# Install GitHub CLI if not already installed
# See: https://cli.github.com/

# Authenticate
gh auth login
```

Fork all repositories using a script:

```bash
#!/bin/bash

# List of repositories to fork
repos=(
  "ranviermud"
  "core"
  "ranvier-telnet"
  "neuro"
  "docs"
  "websocket-networking"
  "telnet-networking"
  "datasource-file"
  "bundle-example-commands"
  "bundle-example-combat"
  "bundle-example-player-events"
  "bundle-example-effects"
  "bundle-example-quests"
  "bundle-example-npc-behaviors"
  "bundle-example-lib"
  "bundle-example-input-events"
  "bundle-example-areas"
  "bundle-example-debug"
  "bundle-example-classes"
  "bundle-example-channels"
  "bundle-example-bugreport"
  "lootable-npcs"
  "vendor-npcs"
  "simple-crafting"
  "player-groups"
  "dialogflow-npcs"
  "simple-waypoints"
  "progressive-respawn"
  "trpg-skeleton"
  "tiny"
)

# Fork each repository (copies main branch only by default)
for repo in "${repos[@]}"; do
  echo "Forking RanvierMUD/$repo to Ranvire/$repo..."
  gh repo fork "RanvierMUD/$repo" --org Ranvire --clone=false
  sleep 2  # Rate limiting consideration
done

echo "All repositories forked successfully!"
```

**Note**: The `gh repo fork` command automatically copies only the default branch (main/master), which is the desired behavior for Ranvire.

### Method 3: Using Git (Manual Method - Not Recommended)

If you need to manually clone and push:

```bash
# For each repository
git clone --mirror https://github.com/RanvierMUD/[repo-name].git
cd [repo-name].git
git push --mirror https://github.com/Ranvire/[repo-name].git
cd ..
rm -rf [repo-name].git
```

**Note**: This method requires the destination repository to be created first and is more error-prone. Use Method 1 or 2 instead.

## Verification Steps

After forking each repository, verify:

1. **Commit History**: Check that all commits are present on the main branch
   ```bash
   git log --oneline
   ```

2. **Tags**: Ensure all tags are present
   ```bash
   git tag -l
   ```

3. **License Files**: Confirm MIT license files are preserved where applicable

## Post-Fork Checklist

- [ ] All 30 repositories have been forked to the Ranvire organization
- [ ] Repository descriptions are preserved
- [ ] Main/master branch is present in each forked repository
- [ ] All tags are present in each forked repository
- [ ] Commit history is complete and unchanged
- [ ] License files (MIT) are intact
- [ ] Repository topics/labels are preserved (if needed)

## Additional Notes

- **No Code Changes**: These are exact forks with no modifications to code
- **Main Branch Only**: Only the default branch (main/master) is forked; feature branches are not maintained
- **Maintenance Work**: After forking, maintenance work can begin on the Ranvire versions
- **Upstream Tracking**: Consider setting up upstream remotes to track the original RanvierMUD repositories if updates need to be pulled in the future

## Setting Up Upstream Tracking (Optional)

After forking, you may want to track the original repositories:

```bash
cd /path/to/local/clone
git remote add upstream https://github.com/RanvierMUD/[repo-name].git
git fetch upstream
```

This allows pulling future updates from the original repository if needed.

## Priority Order

If forking must be done incrementally, prioritize in this order:

1. **ranviermud** (Main game engine)
2. **core** (Core engine code)
3. **ranvier-telnet** (Telnet server)
4. **neuro** (Web client)
5. **docs** (Documentation)
6. All networking and data source repositories
7. Example bundles
8. Feature bundles
9. Starter kits

## Support

For questions or issues during the forking process, refer to:
- GitHub's forking documentation: https://docs.github.com/en/get-started/quickstart/fork-a-repo
- GitHub CLI documentation: https://cli.github.com/manual/gh_repo_fork
