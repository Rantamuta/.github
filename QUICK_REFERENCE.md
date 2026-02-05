# Quick Reference Guide for Forking

## TL;DR - Fastest Method

```bash
# Install GitHub CLI if you haven't already
# Visit: https://cli.github.com/

# Authenticate
gh auth login

# Run the automated script
./fork-repositories.sh
```

## Manual Forking (Web Interface)

For each repository in the list:

1. Go to: `https://github.com/RanvierMUD/[repository-name]`
2. Click "Fork" button (top-right)
3. Select "Ranvire" organization
4. **IMPORTANT**: Keep "Copy the main branch only" checked (default)
5. Click "Create fork"

**Note**: Only the main/master branch will be forked. Feature branches are not needed for maintenance work.

## Repository List (Copy-Paste Ready)

### Priority 1 - Core (Fork These First)
```
https://github.com/RanvierMUD/ranviermud
https://github.com/RanvierMUD/core
https://github.com/RanvierMUD/ranvier-telnet
https://github.com/RanvierMUD/neuro
https://github.com/RanvierMUD/docs
```

### Priority 2 - Infrastructure
```
https://github.com/RanvierMUD/websocket-networking
https://github.com/RanvierMUD/telnet-networking
https://github.com/RanvierMUD/datasource-file
```

### Priority 3 - Example Bundles
```
https://github.com/RanvierMUD/bundle-example-commands
https://github.com/RanvierMUD/bundle-example-combat
https://github.com/RanvierMUD/bundle-example-player-events
https://github.com/RanvierMUD/bundle-example-effects
https://github.com/RanvierMUD/bundle-example-quests
https://github.com/RanvierMUD/bundle-example-npc-behaviors
https://github.com/RanvierMUD/bundle-example-lib
https://github.com/RanvierMUD/bundle-example-input-events
https://github.com/RanvierMUD/bundle-example-areas
https://github.com/RanvierMUD/bundle-example-debug
https://github.com/RanvierMUD/bundle-example-classes
https://github.com/RanvierMUD/bundle-example-channels
https://github.com/RanvierMUD/bundle-example-bugreport
```

### Priority 4 - Feature Bundles
```
https://github.com/RanvierMUD/lootable-npcs
https://github.com/RanvierMUD/vendor-npcs
https://github.com/RanvierMUD/simple-crafting
https://github.com/RanvierMUD/player-groups
https://github.com/RanvierMUD/dialogflow-npcs
https://github.com/RanvierMUD/simple-waypoints
https://github.com/RanvierMUD/progressive-respawn
```

### Priority 5 - Starter Kits
```
https://github.com/RanvierMUD/trpg-skeleton
https://github.com/RanvierMUD/tiny
```

## One-Liner for GitHub CLI

```bash
for repo in ranviermud core ranvier-telnet neuro docs websocket-networking telnet-networking datasource-file bundle-example-commands bundle-example-combat bundle-example-player-events bundle-example-effects bundle-example-quests bundle-example-npc-behaviors bundle-example-lib bundle-example-input-events bundle-example-areas bundle-example-debug bundle-example-classes bundle-example-channels bundle-example-bugreport lootable-npcs vendor-npcs simple-crafting player-groups dialogflow-npcs simple-waypoints progressive-respawn trpg-skeleton tiny; do gh repo fork "RanvierMUD/$repo" --org Ranvire --clone=false; sleep 2; done
```

## Verification Commands

After forking, verify a repository:

```bash
# Clone the forked repository
git clone https://github.com/Ranvire/[repository-name].git
cd [repository-name]

# Check tags
git tag -l

# Check commit history
git log --oneline | head -20
```

## Troubleshooting

### Fork Already Exists
If you get "repository already exists" error, the fork is complete. Verify by visiting:
`https://github.com/Ranvire/[repository-name]`

### Authentication Issues
```bash
gh auth status
gh auth login
```

## Next Steps After Forking

1. Mark completed repositories in `FORKING_CHECKLIST.md`
2. For each forked repository, consider:
   - Setting branch protection rules
   - Configuring CI/CD workflows
   - Updating documentation to reference Ranvire organization
3. Begin maintenance work on the forked repositories

## Support

- Full Documentation: See `FORKING_INSTRUCTIONS.md`
- Progress Tracking: Use `FORKING_CHECKLIST.md`
- Issues: Create an issue in this repository
