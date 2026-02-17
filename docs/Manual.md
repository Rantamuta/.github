# Rantamuta Maintainer Manual

## Initial orientation

### 1) `Rantamuta/ranviermud` — the runnable project (entry point)

This is the repository a user clones and runs. It contains:

* the executable wrapper script `./ranvier` (invoked by `npm start` in `package.json`)
* the primary configuration file `ranvier.json` (or optional `ranvier.conf.js`, if present)
* a `bundles/` directory that serves as the bundle root; the provided `util/*` scripts manage bundles as git submodules in this directory
* a `data/` directory used as the on-disk root for runtime data (accounts/players are configured under `data/account` and `data/player` by default)

`ranviermud` depends on external repositories via GitHub dependency specs in `package.json`. For backward compatibility, dependency keys still use legacy names such as `ranvier`, `ranvier-datasource-file`, and `ranvier-telnet`.

### 2) `Rantamuta/core` — the engine library consumed by `ranviermud`

This repository is the engine implementation consumed by downstream repos, often under the legacy dependency key `ranvier` for compatibility. In this repository, package metadata is `name: "rantamuta-core"` in `package.json`. It is **not** a runnable application by itself; its exported API is built by requiring all modules under `./src/` via `require-dir`. ([GitHub][4]) ([GitHub][23])

### 3) `Rantamuta/datasource-file` — a pluggable file-backed storage backend

This repository provides the `ranvier-datasource-file` package, exporting datasource classes such as `YamlDataSource`, `YamlAreaDataSource`, `YamlDirectoryDataSource`, and their JSON counterparts. ([GitHub][5])

In the default `ranviermud` configuration (`ranvier.json`), these datasources are registered under short names like `YamlArea`, `Yaml`, `YamlDirectory`, and `JsonDirectory`, and then selected by “entity loader” definitions. ([GitHub][6])

---

## 1. Conceptual overview

### What Rantamuta is

Rantamuta is a Node.js-based game server composed of:

* a **thin runnable wrapper** (`ranviermud`) that:

  * loads configuration (`ranvier.conf.js` if present, else `ranvier.json`)
  * constructs a global runtime state object (`GameState`) with managers/factories/registries from the `ranvier` dependency
  * wires data sources and entity loaders from `ranvier.json`
  * instantiates a `BundleManager` and calls `loadBundles()`
  * attaches server events and (when not in test mode) calls `GameServer.startup(...)`
  * schedules tick loops for entities and players ([Github][2])

* a **core engine library** (`core`, commonly consumed as dependency key `ranvier` for compatibility) that provides:

  * the object model (managers/factories),
  * configuration access,
  * logging,
  * the bundle loader and script-loading conventions,
  * the entity loader abstraction,
  * and an event-emitting “server” surface that bundles can attach to. ([GitHub][4])
* **storage backends** (e.g., `datasource-file`) that implement CRUD-style access to entity records, and are selected/configured entirely via `ranvier.json`. ([GitHub][6])

#### NB

* The process entry point for `ranviermud` is `./ranvier` (not the `ranvier` dependency itself). The wrapper loads the dependency via `require('ranvier')`.
* A datasource is **not** the engine’s persistence layer; it is a pluggable adapter selected by configuration and invoked through `EntityLoader`. ([GitHub][7])

#### Architectural separation of concerns

The separation is explicit in how the wrapper builds the process:

* **Configuration**: loaded by the wrapper via `Ranvier.Config.load(...)` and read via `Config.get(...)`.
* **Runtime state (“GameState”)**: constructed as a plain object in `ranvier`, populated with managers/factories/registries from `ranvier`.
* **Content and features**: the wrapper instantiates `Ranvier.BundleManager` and calls `loadBundles()`; bundle loading behavior is defined in the `ranvier` dependency.
* **Persistence wiring**: `ranvier.json` defines `dataSources` and `entityLoaders`, which the wrapper loads via `DataSourceRegistry` and `EntityLoaderRegistry`.

---

## 2. Repository roles and responsibilities

### 2.1 `Rantamuta/ranviermud`

#### What it owns

* **Process entry and boot**: `./ranvier` performs Node version gating, config selection, logger setup, global state construction, registry initialization, bundle loading, and server startup/ticks.
* **Project-level configuration**: `ranvier.json` defines enabled bundles, datasource registrations, and entity loader wiring (plus other settings like `startingRoom`, name length constraints, etc.).
* **Bundle management tooling**: scripts under `util/` manage bundles as git submodules and update `ranvier.json`.

#### What it deliberately does not own

* Engine subsystem implementations live in the external dependency `ranvier`.
* Datasource implementations live in external dependencies such as `ranvier-datasource-file`.

#### How it depends on the others

In `package.json`, `ranviermud` depends on:

* `ranvier` (engine)
* `ranvier-datasource-file` (datasources)
* `ranvier-telnet` (telnet transport implementation)

### 2.2 `Rantamuta/core`

#### What it owns

* **Engine API surface** exported from `index.js` via `require-dir('./src/')`. ([GitHub][4])
* **Published type declarations**: the package publishes concrete declarations at `types/index.d.ts` and keeps CommonJS consumer compatibility (`export =`) while exposing `Ranvier` as a namespace for tooling. ([GitHub][23]) ([GitHub][24])
* **Minimal Config wrapper**: `Config.load(data)` stores the config object, and `Config.get(key, fallback)` reads from that cache. If `get` is called before `load`, it throws `ConfigNotLoadedError`. (No merging, validation, or deep resolution is performed by `Config` itself.) ([GitHub][10])
* **Logging wrapper**: `Logger` wraps Winston and provides `log`, `error`, `warn`, `verbose`, plus optional file logging and pretty errors. ([GitHub][11])
* **Entity loader abstraction**: `EntityLoader` is a thin wrapper around a datasource instance + loader config, providing `setArea`, `setBundle`, and CRUD-ish methods that delegate to the datasource if implemented. ([GitHub][7])
* **Bundle loading convention**: `BundleManager` iterates configured enabled bundles and loads features from well-known paths within each bundle (commands, behaviors, server-events, etc.), then loads areas and help and “distributes” areas into the `AreaManager`. ([GitHub][8])
* **Server startup surface**: `GameServer` is an `EventEmitter` that (in the core itself) only emits `startup` and `shutdown` events. This is the extension point bundles attach to (via “server events”). ([GitHub][12])
* **Type regression checks**: `npm run typecheck` validates the published declaration surface, including a CommonJS consumer fixture. ([GitHub][23]) ([GitHub][25]) ([GitHub][26])

#### What it deliberately does not own

* It does not decide *which* bundles to load; it reads the enabled list from `Config`, which is loaded by `ranviermud`. ([GitHub][8])
* It does not bake in a single persistence system; it expects datasources and entity loaders to be configured externally and invoked through registries and `EntityLoader`. ([GitHub][2])

### 2.3 `Rantamuta/datasource-file`

#### What it owns

* Concrete datasource implementations for file-backed storage:

  * YAML single-file: `YamlDataSource` ([GitHub][13])
  * YAML directory-of-entities: `YamlDirectoryDataSource` ([GitHub][14])
  * YAML areas-by-directory-with-manifest: `YamlAreaDataSource` ([GitHub][15])
  * JSON single-file: `JsonDataSource` ([GitHub][16])
  * JSON directory-of-entities: `JsonDirectoryDataSource` ([GitHub][17])
* A common `FileDataSource` base that implements template resolution (`[BUNDLE]`, `[AREA]`) and root-relative path joining. ([GitHub][18])

#### What it deliberately does not own

* It does not know about Ranvier “managers”, “areas”, or “bundles” beyond the string-token substitution it performs. Those higher-level meanings are owned by the engine and bundle loader. ([GitHub][18])

---

## 3. Runtime architecture

This section follows the boot path in `Rantamuta/ranvier`.

### 3.1 Process entry and Node version gating

`ranviermud/package.json` defines `npm start` as `node ./ranvier -v`. ([GitHub][1])

At startup, `./ranvier`:

* reads `./package.json`
* checks `process.version` against `pkg.engines.node` via `semver.satisfies`
* throws if the Node runtime does not meet the declared requirement (currently `>=22`). ([GitHub][2])

### 3.2 Configuration loading

The wrapper chooses config in this order:

1. If `./ranvier.conf.js` exists, it loads that.
2. Else if `./ranvier.json` exists, it loads that.
3. Else it prints an error and exits. ([GitHub][2])

In both cases, the wrapper calls `Ranvier.Config.load(require(...))` and later reads values via `Config.get(...)`.

### 3.3 Logging setup

The wrapper configures:

* console logging level (based on commander’s `verbose` option vs environment/config)
* optional file logging if `Config.get('logfile')` is set
* optional “pretty errors” if the `--prettyErrors` CLI flag is set

The engine `Logger` is a Winston wrapper; it configures a Console transport with timestamps, and can add/remove a File transport via `Logger.setFileLogging(path)` / `Logger.deactivateFileLogging()`. ([GitHub][11])

### 3.4 Global runtime state construction (“GameState” as an object)

The wrapper constructs `GameState` as a plain object populated with engine subsystems. The list includes (among others):

* `AccountManager`, `PlayerManager`
* `AreaManager`, `RoomManager`, `MobManager`, `ItemManager`
* factories like `AreaFactory`, `RoomFactory`, `MobFactory`, `ItemFactory`
* `AttributeFactory`, `CommandManager`, `HelpManager`, `ChannelManager`
* behavior managers for areas, rooms, mobs, items
* `QuestFactory`, `QuestGoalManager`, `QuestRewardManager`
* `SkillManager`, `SpellManager`
* `EntityLoaderRegistry`, `DataSourceRegistry`
* `GameServer`, `ServerEventManager`
* `DataLoader` (`Ranvier.Data`)
* `Config`

This object is then passed into `BundleManager` (see below) so bundles can register features against shared runtime subsystems. ([GitHub][2])

### 3.5 Data path

Before loading config, the wrapper sets the engine’s data root:

```js
Ranvier.Data.setDataPath(__dirname + '/data/');
```

This establishes `ranviermud/data/` as the runtime data directory from the perspectives of the engine and the wrapper. ([GitHub][2])

### 3.6 DataSourceRegistry and EntityLoaderRegistry wiring

After `GameState` is constructed, the wrapper:

1. Loads datasources from `Config.get('dataSources')` using `DataSourceRegistry`.
2. Loads entity loaders from `Config.get('entityLoaders')` using `EntityLoaderRegistry`.
3. Sets loaders onto the account and player managers (`accounts` and `players`).
The wrapper is the authoritative “wiring” layer here: it decides which loaders back which subsystems.

### 3.7 BundleManager boot sequence

The wrapper creates a `BundleManager` with the bundles path and `GameState`, then calls `loadBundles()`.

```js
const BundleManager = new Ranvier.BundleManager(__dirname + '/bundles/', GameState);
await BundleManager.loadBundles();
```

`BundleManager.loadBundles()`:

* reads `Config.get('bundles', [])` and iterates bundle names in that exact configured order
* de-duplicates configured names while preserving first-seen order
* skips invalid names (`.` and `..`)
* validates configured bundle paths and skips missing/non-directory entries with warnings
* for each loaded bundle, it loads a fixed set of “features” if their expected path exists, then loads areas and help
* after all bundles load, it validates attributes (`AttributeFactory.validateAttributes()`)
* and then “distributes” loaded area references: it creates each area, hydrates it, and registers it with `AreaManager`. ([GitHub][2])

The feature paths and their load order are hard-coded in `BundleManager.loadBundle()`:

* `quest-goals/` → `loadQuestGoals`
* `quest-rewards/` → `loadQuestRewards`
* `attributes.js` → `loadAttributes`
* `behaviors/` → `loadBehaviors`
* `channels.js` → `loadChannels`
* `commands/` → `loadCommands`
* `effects/` → `loadEffects`
* `input-events/` → `loadInputEvents`
* `server-events/` → `loadServerEvents`
* `player-events.js` → `loadPlayerEvents`
* `skills/` → `loadSkills` ([GitHub][8])

This is one of the most important “architectural contracts” in Rantamuta: bundle authors place scripts in these conventional locations to participate in boot.

#### Conflict Resolution and Override Rules

`BundleManager` has two conflict modes based on `Config.get('strictMode', false)`. ([GitHub][8])

**Non-strict mode (`strictMode: false`, default):**

* Most map-backed registries are overwrite-on-set, so later bundles override earlier bundles for the same key:
  * Commands (`CommandManager`)
  * Channels (`ChannelManager`)
  * Skills/Spells (`SkillManager`, `SpellManager`)
  * Attributes (`AttributeFactory`)
  * Help files (`HelpManager`)
  * Quests (`QuestFactory`)
* Effects are different: `EffectFactory.add` ignores duplicate effect ids, so first registration wins. ([GitHub][8]) ([GitHub][30])
* Event-based registries are additive: multiple listeners for the same event all run in registration order.

**Strict mode (`strictMode: true`):**

* Cross-bundle duplicate registrations in guarded registries throw and fail bundle load.
* The guard applies to command keys/aliases, channel keys/aliases, skill/spell ids, effect ids, attribute names, help names, quest ids, quest-goal names, quest-reward names, and loaded area/entity definition keys.
* Duplicate registration of the same key by the same bundle is allowed by the strict duplicate guard.

**Config-driven behavior:**

* Some “conflicts” are config-defined rather than bundle-defined (e.g., `startingRoom`).

### 3.8 Server startup

The wrapper attaches server events and starts the server (when not in test mode):

* `GameState.ServerEventManager.attach(GameState.GameServer);`
* `GameState.GameServer.startup(commander);` ([GitHub][2])

In core, `GameServer.startup()` does only one thing: emit `startup` with the commander options. ([GitHub][12])

So “starting the server” in Rantamuta is structurally:

* wrapper emits `startup`
* bundles that registered “server-events” are expected to react to this event (e.g., bring up telnet/websocket transports, etc.)
* the core engine itself does not implement a transport in `GameServer`. ([GitHub][2])

### 3.9 Tick scheduling

The wrapper establishes tick loops:

* An entity tick interval (default fallback 100ms) calling:

  * `AreaManager.tickAll(GameState)`
  * `ItemManager.tickAll()` ([GitHub][2])
* A player tick interval (default fallback 100ms) emitting:

  * `PlayerManager.emit('updateTick')` ([GitHub][2])

This is the “heartbeat” that drives time-based mechanics; the wrapper is responsible for setting these intervals, not the core engine.

### 3.10 Wrapper test mode

The wrapper supports a test mode via environment variables:

* `RANVIER_WRAPPER_TEST === '1'` prevents server startup and tick scheduling.
* `RANVIER_WRAPPER_TEST_OUTPUT` writes a JSON payload with fields including `configSource`, `dataPath`, `bundlesPath`, `booted`, `configPort`, and `error`. ([Github][2])

---

## 4. Entity system and data flow

This section distinguishes between:

* **script-loaded features** (commands, server-events, etc.) loaded from bundle filesystem paths by `BundleManager`, and
* **datasource-backed entity records** (areas, rooms, NPCs, items, quests, accounts, players, help entries) loaded through configured entity loaders.

In Rantamuta’s runtime wiring, an “entity” (in the persistence/config sense) is a record or collection of records addressed via an `EntityLoader` that wraps a datasource instance. ([GitHub][7])

### 4.1 Entity loader categories (as configured)

The default `ranvier.json` defines entity loader categories:

* `accounts`
* `players`
* `areas`
* `npcs`
* `items`
* `rooms`
* `quests`
* `help`([GitHub][6])

These names are configuration keys.  The wrapper explicitly wires the `accounts` and `players` loaders into their managers in the wrapper via `EntityLoaderRegistry.get('accounts')` and `get('players')`. ([GitHub][2])

### 4.2 EntityLoader: the executable interface

`EntityLoader` is a thin adapter around:

* a datasource object (`this.dataSource`)
* a config object (`this.config`) ([GitHub][7])

It exposes:

* `setBundle(name)` and `setArea(name)` which set `config.bundle` and `config.area` respectively. ([GitHub][7])
* `hasData()` which delegates directly to the datasource, plus `fetchAll()`, `fetch(id)`, `replace(data)`, `update(id, data)` which delegate only if the method exists; otherwise the loader throws a “not supported” error. ([GitHub][7])

**Practical consequence:** the “datasource interface” is duck-typed. A datasource is usable if it provides the methods the engine attempts to call. ([GitHub][7])

### 4.3 How datasources are registered and selected (as seen from configuration)

In `ranvier.json`:

* `dataSources` is a map of short names → `{ require: "…" }` strings. ([GitHub][6])
* `entityLoaders` is a map of entity category → `{ source: <dataSourceName>, config: { … } }`. ([GitHub][6])

Example (from the default config):

* `areas` uses `YamlArea` with `path: "bundles/[BUNDLE]/areas"`
* `rooms` uses `Yaml` with `path: "bundles/[BUNDLE]/areas/[AREA]/rooms.yml"`
* `accounts` uses `JsonDirectory` with `path: "data/account"` ([GitHub][6])

### 4.4 Token substitution and scope (bundle/area context)

Path templates in config use `[BUNDLE]` and `[AREA]`. The file datasources implement substitution in `FileDataSource.resolvePath()`:

* it throws if `[BUNDLE]` is present but `config.bundle` is unset
* it throws if `[AREA]` is present but `config.area` is unset
* it joins the datasource root + path, then replaces `[BUNDLE]` and `[AREA]`. ([GitHub][18])

Because `EntityLoader.setBundle()` and `setArea()` set these config fields, the **correct usage contract** is:

* any code that uses loaders with `[BUNDLE]` / `[AREA]` templates must call `setBundle()` / `setArea()` before calling `fetchAll()` / `fetch()` on that loader, otherwise the datasource will throw. ([GitHub][18])

### 4.5 Lifecycle overview: world entities vs accounts/players

The default configuration makes a strong separation:

* **World content** (areas, rooms, NPCs, items, quests, help) is stored under `bundles/...` paths and is loaded from YAML files (or directories of YAML) via `Yaml*` datasources. ([GitHub][6]).
* **Accounts** and **players** are stored under `data/account` and `data/player` and are loaded from JSON directories via `JsonDirectoryDataSource`. ([GitHub][6]).

### 4.6 Known runtime semantics and sharp edges

* `AreaFloor` accepts negative coordinates and currently stores coordinates using an array-backed structure indexed as `map[x][y]`. This works because arrays are objects in JavaScript, but negative coordinates are stored as signed keys rather than true array indexes. ([GitHub][27]) ([GitHub][28])
* Room door state is not normalized on load. For a door that exists but omits `locked`, `Room.isDoorLocked(fromRoom)` returns `undefined`; if the door does not exist, it returns `false`. Consumers should treat door lock state as effectively tri-state (`true | false | undefined`). ([GitHub][29])

---

## 5. `datasource-file` in depth

This section is written to be sufficient for implementing a new datasource correctly.

### 5.1 Why datasources exist (in this architecture)

The engine’s persistence surface is configuration-driven:

* The wrapper loads a datasource registry from `ranvier.json:dataSources`. ([GitHub][2])
* Entity categories (accounts, rooms, etc.) are then mapped to datasources + per-entity config via `ranvier.json:entityLoaders`. ([GitHub][6])
* At runtime, most entity access goes through an `EntityLoader`, but core still performs some direct filesystem access via `Data` (e.g., account save and player existence checks). ([GitHub][7])

So a datasource exists to isolate “how do I read/write entity data” from both:

* the wrapper’s boot seeing (which entity categories exist)
* the engine’s higher-level gameplay code (which expects loaders, managers, and factories to be fed data)

### 5.2 The abstractions datasource-file implements

#### 5.2.1 `FileDataSource` as the shared base

All file-backed datasources in this package extend `FileDataSource`, which stores:

* `this.config` (per-datasource config)
* `this.root` (a root filesystem path passed by the registry/loader) ([GitHub][18])

The key function is `resolvePath(config)`:

* expects a `config` containing at least `{ path: string }`
* may also use `{ bundle: string, area: string }` for template expansion
* throws if `this.root` is unset or if `config.path` is missing
* joins `root` + `path`
* replaces the first `[AREA]` and first `[BUNDLE]` token (additional occurrences remain unchanged) in that joined path. ([GitHub][18])

#### 5.2.2 The effective datasource interface (duck-typed)

`EntityLoader` checks method existence with `'methodName' in this.dataSource` for `fetchAll`, `fetch`, `replace`, and `update`; `hasData` is called directly. ([GitHub][7])

In practice, a datasource must implement `hasData(config)` and may implement:

* `fetchAll(config)` → object/array/promise
* `fetch(config, id)` → record/promise
* `replace(config, data)` → promise (write entire dataset)
* `update(config, id, data)` → promise (write one record) ([GitHub][7])

A new datasource must implement the subset actually used by the engine/components you wire it to. If you omit a method and something calls it, `EntityLoader` will throw at runtime. ([GitHub][7])

### 5.3 YAML vs JSON sources (actual behavior)

#### 5.3.1 `YamlDataSource` (single YAML file)

* `fetchAll` reads a YAML file and parses it with `js-yaml`’s `yaml.load(contents)`. ([GitHub][13])
* `replace` writes YAML using `yaml.dump(data)`. ([GitHub][13])
* `fetch(id)` expects the parsed object to be keyed by id and throws `ReferenceError` if missing. ([GitHub][13])
* `update(id, data)` loads the whole file, sets `currentData[id] = data`, and rewrites the file; if the YAML content is an array, it throws. ([GitHub][13])
* Reads are synchronous (`fs.readFileSync(...).toString('utf8')`) even though the method returns a promise. ([GitHub][13])
* The `hasData` check is not awaited in `fetchAll`, so a missing file results in `fs.readFileSync` throwing (e.g., `ENOENT`) rather than a custom “Invalid path” error. ([GitHub][13])
* YAML contents are read as UTF-8 without BOM stripping. ([GitHub][13])

#### 5.3.2 `JsonDataSource` (single JSON file)

* If the file does not exist, `fetchAll` resolves to `{}` (it does not throw). ([GitHub][16])
* It strips a UTF‑8 BOM if present, then `JSON.parse`s the content. ([GitHub][16])
* `replace` writes pretty JSON (`JSON.stringify(data, null, 2)`). ([GitHub][16])
* `update` mirrors the YAML approach (load all, assign by id, rewrite). ([GitHub][16])
* Reads are synchronous (`fs.readFileSync(...).toString('utf8')`) even though the method returns a promise. ([GitHub][16])
* If `update` sees an array, it throws `TypeError('Yaml data stored as array, cannot update by id')` (the message is copied from the YAML implementation). ([GitHub][16])

### 5.4 Directory-backed vs single-file sources

#### 5.4.1 `YamlDirectoryDataSource` (directory of `*.yml`)

* `fetchAll` reads directory entries, filters to `.yml`, and builds an object keyed by filename stem. ([GitHub][14])
* It uses `YamlDataSource` internally with the directory path as the “root” and then loads `${id}.yml`. ([GitHub][14])
* The `hasData` check is not awaited in `fetchAll`, so an invalid directory path is not caught before `fs.readdir` runs; any `fs.readdir` error is ignored and can surface later when iterating `files`. ([GitHub][14])
* `update(id, data)` overwrites or creates `<id>.yml` by calling `YamlDataSource.replace` for that file; there is no `replace` method on the directory datasource itself. ([GitHub][14])

#### 5.4.2 `JsonDirectoryDataSource` (directory of `*.json`)

* `fetchAll` reads directory entries, filters to `.json`, and builds an object keyed by filename stem. ([GitHub][17])
* It uses `JsonDataSource` internally with the directory path as the “root” and then loads `${id}.json`. ([GitHub][17])
* The `hasData` check is not awaited in `fetchAll`, so an invalid directory path is not caught before `fs.readdir` runs; any `fs.readdir` error is ignored and can surface later when iterating `files`. ([GitHub][17])
* `update(id, data)` overwrites or creates `<id>.json` by calling `JsonDataSource.replace` for that file; there is no `replace` method on the directory datasource itself. ([GitHub][17])

### 5.5 `YamlAreaDataSource`: areas as directories with `manifest.yml`

`YamlAreaDataSource` encodes the “area folder” convention:

* It expects a directory containing area directories.
* Each area directory must contain `manifest.yml`. ([GitHub][15])

`fetchAll` iterates directories and loads each area’s `manifest.yml` via a nested `YamlDataSource`. ([GitHub][15])

In the default `ranviermud` config, the areas loader points this datasource at:

* `bundles/[BUNDLE]/areas` ([GitHub][6])

Which concretely implies a content layout like:

```
bundles/<bundle>/areas/
  <area>/
    manifest.yml
```

(And the rest of the area’s entity files are configured separately; see below.) ([GitHub][6])

### 5.6 Token substitution: `[BUNDLE]` and `[AREA]`

`FileDataSource.resolvePath` performs only two substitutions: `[BUNDLE]` and `[AREA]`. ([GitHub][18])

The engine-side bridge to this is `EntityLoader.setBundle(name)` and `setArea(name)`, which set `this.config.bundle` and `this.config.area`. ([GitHub][7])

So the correct way to “scope” an entity loader is:

* set bundle context (if needed)
* set area context (if needed)
* then call `fetchAll` / `fetch` / `update`

### 5.7 Why account/player persistence differs from static world content (as configured)

In the default configuration:

* Accounts and players are stored under `data/account` and `data/player` and are loaded via `JsonDirectoryDataSource`, which supports `update()` (writes per-record JSON files to disk). ([GitHub][6])
* World content (areas, rooms, NPCs, items, quests, help) is stored under `bundles/…` and is loaded via YAML datasources. ([GitHub][6])

Even without inspecting higher-level gameplay code, the config separation plus the fact that JSON directory datasources implement updates makes it clear why these are different categories: the “data/” subtree is positioned as mutable runtime state, while “bundles/” is positioned as authored content. ([GitHub][2])

### 5.8 Implementing a new datasource (minimum correct mental model)

To implement a new datasource compatible with this ecosystem:

1. Decide whether you need `[BUNDLE]` / `[AREA]` token expansion.

   * If yes, extend `FileDataSource` and use `resolvePath(config)` for path resolution. ([GitHub][18])
2. Implement the methods required by the `EntityLoader` call sites you will wire this datasource into (`fetchAll`, `fetch`, `update`, etc.). If you omit a method and something calls it, `EntityLoader` will throw. ([GitHub][7])
3. Ensure your datasource is constructible in the way the registries expect:

   * datasources in `ranvier-datasource-file` accept `(config = {}, rootPath)` in their constructors via `FileDataSource`. ([GitHub][18])
4. Export the class from your datasource package’s `index.js` so that `ranvier.json` can reference it via dotted `package.ExportName` strings (this is how `ranvier-datasource-file` is structured). ([GitHub][5])

---

## 6. Bundles and content layout

### 6.1 What bundles are (in this codebase)

`ranviermud` includes a `bundles/` directory and a `bundles` array in `ranvier.json`. The wrapper passes the bundles path into `Ranvier.BundleManager` and calls `loadBundles()`; bundle discovery and feature loading behavior are defined in the `ranvier` dependency.

Bundle loading is filesystem-driven and convention-driven:

* `BundleManager` iterates configured bundle names from `Config.get('bundles', [])`.
* It validates each configured bundle path and skips invalid entries with warnings.
* It loads known features based on the presence of specific files/directories. ([GitHub][8])

### 6.2 How bundles are installed and enabled in `ranviermud`

Rantamuta’s tooling treats bundles as **git submodules**:

* `util/install-bundle.js` adds a bundle as `git submodule add … bundles/<name>` and runs `npm install --no-audit` inside the bundle if it has a `package.json`. ([GitHub][3])
* `util/remove-bundle.js` deinitializes and removes the submodule and its `.git/modules` entry. ([GitHub][19])
* `util/update-bundle-url.js` rewrites the submodule URL in `.gitmodules` and runs `git submodule sync` and `git submodule update --remote`. ([GitHub][20])

`util/init-bundles.js` is a higher-level helper that:

* optionally prompts the user (unless `--yes/-y`)
* installs a predefined list of example bundles by calling `npm run install-bundle …`
* rewrites `ranvier.json.bundles` to the list of installed bundle directory names
* stages `ranvier.json` for commit. ([GitHub][9])

### 6.3 Bundle feature layout (engine contract)

Within an enabled bundle directory, `BundleManager` conditionally loads features from these locations (if they exist):

* `quest-goals/`
* `quest-rewards/`
* `attributes.js`
* `behaviors/`
* `channels.js`
* `commands/`
* `effects/`
* `input-events/`
* `server-events/`
* `player-events.js`
* `skills/` ([GitHub][8])

This list (and its order) is the authoritative “bundle API surface” for startup contributions.

#### Quest Rewards

Quest rewards are a registry-driven extension mechanism for post-completion quest effects. Core provides the lifecycle hooks, registration plumbing, and dispatch semantics; bundle content provides concrete reward implementations.

At runtime, reward execution sits on the quest completion path in `QuestFactory` and is type-resolved from `QuestRewardManager`. The manager itself is a simple `Map` keyed by reward type name.

##### 1. Core components and contracts

Core classes:

* `QuestReward` (`node_modules/ranvier/src/QuestReward.js`)
  * abstract extension contract with static methods:
    * `reward(GameState, quest, config, player)`
    * `display(GameState, quest, config, player)`
* `QuestRewardManager` (`node_modules/ranvier/src/QuestRewardManager.js`)
  * `class QuestRewardManager extends Map {}`
  * key: reward type string
  * value: reward class/type object used at completion time
* `QuestFactory` (`node_modules/ranvier/src/QuestFactory.js`)
  * consumes quest `rewards` config and invokes reward handlers on completion

Quest data contract (TypeScript surface):

* In `Quest` config, `rewards` is optional and shaped as:
  * `rewards?: Array<{ type: string, config: Record<string, unknown> }>`
* Declared in `node_modules/ranvier/types/Quest.d.ts`.

Interpretation:

* `type` selects a registered reward implementation from `QuestRewardManager`.
* `config` is reward-type-specific payload, passed through untouched by core.

##### 2. Bundle module shape and import semantics

Reward modules are loaded from bundle path `quest-rewards/` by `BundleManager.loadQuestRewards`.

Accepted export forms are intentionally flexible:

* Direct class export (expected to be a `QuestReward` subclass).
* Loader-function export: `module.exports = (srcPath) => RewardClass`.

Resolution logic (from `BundleManager`):

* `const loader = require(rewardPath)`
* `rewardImport = QuestReward.isPrototypeOf(loader) ? loader : loader(srcPath)`
* `QuestRewardManager.set(rewardName, rewardImport)`

Implications:

* `srcPath`-style legacy loaders remain supported.
* Core does not strongly validate that `rewardImport` is a strict `QuestReward` subclass after resolution.
* The runtime assumption is only that resolved import has callable static hooks used by quest flows.

##### 3. Registration and keying rules

Type key derivation:

* Reward type key is filename basename (without extension) in `quest-rewards/`.
* Example: `quest-rewards/xp.js` registers type `xp`.

Script file filter:

* Uses `Data.isScriptFile(path, file)` which checks:
  * filesystem entry is a file
  * filename matches `/js$/`
* Non-JS files in `quest-rewards/` are ignored.

Namespace model:

* Registry is global for booted `GameState`, across all enabled bundles.
* Type collisions therefore cross bundle boundaries unless isolated by naming conventions and/or strict mode.

##### 4. Load order and when rewards become available

Per bundle feature order in `BundleManager.loadBundle` is fixed:

1. `quest-goals/`
2. `quest-rewards/`
3. `attributes.js`
4. `behaviors/`
5. `channels.js`
6. `commands/`
7. `effects/`
8. `input-events/`
9. `server-events/`
10. `player-events.js`
11. `skills/`
12. areas and help load afterward

Why this matters:

* Quest goals/rewards are loaded before area quest definitions are read.
* Quest records loaded from datasource-backed `quests.yml` can safely reference reward types already registered by feature-load phase.

##### 5. Where quest reward config comes from

Quest definitions are not loaded from `quest-rewards/`; they are loaded through entity loaders.

In the default wrapper wiring (`ranvier.json` + `EntityLoaderRegistry`):

* `quests` loader path is `bundles/[BUNDLE]/areas/[AREA]/quests.yml`.
* During area load, `BundleManager.loadQuests(bundle, areaName)` reads quest records and registers them in `QuestFactory`.

So there are two distinct channels:

* `quest-rewards/` provides reward *types* (code modules).
* `areas/*/quests.yml` provides reward *instances/configs* (`type` + `config` per quest).

##### 6. Runtime execution lifecycle

Quest lifecycle path (relevant to rewards):

* `QuestFactory.create(...)` wires event listeners onto quest instances.
* On `complete` event:
  1. `player.emit('questComplete', instance)`
  2. `player.questTracker.complete(instance.entityReference)`
  3. reward loop executes `quest.config.rewards` (if present)
  4. each reward resolves by type from `QuestRewardManager`
  5. `rewardClass.reward(GameState, instance, reward.config, player)` called
  6. `player.emit('questReward', reward)` emitted for each successful reward dispatch
  7. `player.save()` called once after reward loop completes

Additional ordering detail:

* In `Quest.complete()`, quest emits `complete` before calling each goal’s `goal.complete()` cleanup hook.
* Reward side effects therefore occur before goal cleanup methods run.

##### 7. Events and observability

Core events exposed to downstream systems:

* `questComplete(instance)` on player
* `questReward(reward)` on player for each dispatched reward config entry

Important payload notes:

* `questReward` event payload is the reward config object from quest definition (`{ type, config }`), not the return value of reward handler and not a normalized reward result object.
* Reward execution is side-effect driven; no standardized return channel exists in core.

##### 8. Strict mode and duplicate protection

Duplicate registration behavior is controlled by `Config.get('strictMode', false)` as consumed by `BundleManager`.

Non-strict mode (`false`, default):

* `Map.set` semantics apply.
* Later bundle registration for same reward key overwrites earlier entry.

Strict mode (`true`):

* `_registerOrThrow('QuestRewardManager', rewardName, bundle, rewardPath)` rejects cross-bundle duplicate keys.
* Startup fails fast with duplicate-registration error indicating registry, key, and conflicting bundles.

This behavior is covered by strict-mode unit tests in `node_modules/ranvier/test/unit/BundleManagerStrictMode.js`.

##### 9. `display(...)` semantics (and non-semantics)

`QuestReward` defines both:

* static `reward(...)`
* static `display(...)`

Core currently only invokes `reward(...)` in completion flow.

Observations:

* There are no core callsites that invoke `QuestReward.display(...)`.
* `display(...)` is therefore a bundle/UI-layer extension hook and not part of core completion semantics.
* If a quest command/log UI wants human-readable reward previews, that layer must explicitly call `display(...)`.

##### 10. Error handling, fault isolation, and persistence behavior

Within reward loop (`QuestFactory`):

* Invalid reward type (`QuestRewardManager.get(type)` missing) throws an internal error caught by loop.
* Any reward handler exception is caught and logged through `Logger.error`.
* Loop continues to subsequent rewards after an error (best-effort dispatch).
* Player save still executes once after loop completion.

Consequences:

* Partial reward application is possible: earlier rewards may apply, later one fails, quest still marked complete.
* No built-in transactional rollback across multi-reward sets.
* Error handling is log-based; no automatic compensating actions.

##### 11. Concurrency and sync/async assumptions

Reward dispatch callsite does not `await`:

* `rewardClass.reward(...)` is called synchronously.
* If reward implementation returns a Promise, core does not await or handle Promise rejection at callsite.

Practical expectation for reward authors:

* Implement reward handlers as synchronous, deterministic side-effect functions where possible.
* If async behavior is unavoidable, implement explicit internal error handling in reward code and do not rely on core awaiting completion.

##### 12. Boot wiring and availability boundaries

`GameState.QuestRewardManager` is instantiated during wrapper boot before bundle loading:

* wrapper constructs managers (`QuestFactory`, `QuestGoalManager`, `QuestRewardManager`)
* then `BundleManager.loadBundles()` populates reward registry from bundle filesystem

Therefore:

* Reward types are runtime-load-time artifacts, not compile-time constants.
* Missing `quest-rewards/` directory in a bundle is valid (no registration happens).
* Presence of quest reward configs in quests without matching registered reward type causes runtime quest completion errors for those entries.

##### 13. Gotchas and sharp edges

1. `display(...)` is not executed by core.
2. Reward type key is filename-derived; renaming files changes quest config compatibility.
3. Non-strict mode allows silent overwrite of reward type implementations across bundles.
4. Strict mode converts cross-bundle duplicate reward keys into startup failure.
5. Core does not guarantee import type safety beyond callability at use site.
6. Reward loop is best-effort and non-transactional; partial grants can occur.
7. Quest completion is marked before reward dispatch, so failed rewards do not prevent completion status.
8. Reward callsite is synchronous and non-awaited; Promise-returning handlers are not lifecycle-managed by core.
9. `questReward` player event emits authored config entry, not normalized post-grant result.
10. Reward implementations are global in `GameState`; naming discipline is required in multi-bundle deployments.
11. Missing `quest-rewards/` directory is not itself an error and can hide authoring omissions until quest completion path is hit.
12. Since reward behavior is code-driven, behavior changes are compatibility-relevant even when quest YAML is unchanged.

#### Scripts

Scripts are the engine’s extension layer: small bundle-owned JS modules that plug behavior into the runtime without changing core engine code.

High-level, they are intended for:

* Defining gameplay behavior at content boundaries.
* Reacting to lifecycle/game events (`spawn`, `ready`, movement, ticks, combat, save, etc.).
* Wiring server/session entry points (`startup`/`shutdown`, input handlers).
* Implementing player verbs (commands) and temporary mechanics (effects).
* Attaching per-entity policy/planning hooks in content (in your bundle: `canDirect`, `canIndirect`, `planDirect`, `planIndirect`).

How they fit the architecture:

* Data (YAML) declares entities/areas and references script names.
* Boot loader (`BundleManager`) loads script modules and registers listeners/hooks.
* When entities are instantiated/hydrated, listeners are attached.
* Runtime emits events; scripts run in response and customize behavior.

In practice, scripts are meant to keep game-specific logic modular, bundle-local, and event-driven, while the core engine remains a generic host/runtime.

##### 1. Event architecture and where hooks attach

* All major game objects use Node `EventEmitter`.
* Scriptable entities (`Area`, `Room`, `Item`, `Npc`) inherit `Scriptable`, which attaches behavior listeners and squelches events after prune (`__pruned`) (`Scriptable:19`).
* Player events are attached via `PlayerManager.events` (`PlayerManager:21`, `PlayerManager:116`).
* Server events are attached via `ServerEventManager.attach(GameServer)` during boot (`ranvier:145`).
* `EventManager.attach` binds listeners with:
  * `this` = emitter
  * optional first arg = behavior config (`EventManager:40`).
* `BehaviorManager` is just `behaviorName -> EventManager` (`BehaviorManager:9`).
* Entity script listeners are attached per-entity-ref in `EntityFactory.scripts` and attached on instance creation (`EntityFactory:49`, `EntityFactory:70`).

##### 2. Script module contracts (what each script file must export)

* Entity scripts (`areas/<area>/scripts/...`):
  * `module.exports = { listeners: { eventName: state => listenerFn } }`
  * Loaded by `loadEntityScript` (`BundleManager:395`).
* Behavior scripts (`behaviors/{area|room|item|npc}/...`):
  * same `listeners` shape
  * listener gets `(config, ...eventArgs)` because behavior config is bound in attach (`Scriptable:50`, `EventManager:44`).
* Server events (`server-events/*.js`):
  * `listeners` keyed by `GameServer` events (`startup`, `shutdown`) (`BundleManager:684`, `GameServer:16`).
* Player events (`player-events.js`):
  * `listeners` keyed by player event names (`BundleManager:240`).
* Input events (`input-events/*.js`):
  * export `event: state => async (session, inputData) => { ... }` (`BundleManager:549`).
* Effect scripts (`effects/*.js`):
  * export effect definition + optional `listeners`
  * listeners may be object or `state => object` (`EffectFactory:22`).

##### 3. Runtime event flow (important pipelines)

* Boot/load:
  * BundleManager loads features in fixed order (`quest-goals`, `quest-rewards`, `attributes`, `behaviors`, `channels`, `commands`, `effects`, `input-events`, `server-events`, `player-events.js`, `skills`) then areas/help (`BundleManager:112`).
* Tick loop:
  * Wrapper runs intervals:
  * `AreaManager.tickAll(GameState)` and `ItemManager.tickAll()` (`ranvier:154`, `ranvier:155`).
  * `PlayerManager.emit('updateTick')` (`ranvier:160`).
  * Area `updateTick` triggers room/npc `updateTick` (`Area:37`, `Area:160`, `Area:168`).
* Movement:
  * Player/NPC movement emits room leave/enter and self `enterRoom` (`Player:143`, `Player:157`, `Npc:60`, `Npc:74`).
  * Room proxies `playerEnter/playerLeave/npcEnter/npcLeave` to all room npcs/players/items (`Room:72`).
* Combat/damage/heal:
  * `Damage.commit` emits attacker `hit` and target `damaged` (`Damage:66`, `Damage:73`).
  * `Heal.commit` emits attacker `heal` and target `healed` (`Heal:27`, `Heal:34`).
* Character->Effect fanout:
  * Every Character event is forwarded to active effects (`Character:60`, `EffectList:59`).
* Player->Quest fanout:
  * Every Player event forwards to active quests (`Player:62`, `QuestTracker:28`, `Quest:40`).
* Channels:
  * `Channel.send` emits `channelReceive(channel, sender, rawMessage)` on each target (`Channel:101`).

##### 4. Built-in hook catalog (events emitted by core)

**Server lifecycle**

* `startup(commander)` on `GameServer` (`GameServer:16`)
* `shutdown()` on `GameServer` (`GameServer:26`)

**Area**

* `roomAdded(room)` (`Area:82`)
* `roomRemoved(room)` (`Area:96`)
* `updateTick(state)` (`AreaManager:59`)

**Room**

* `spawn()` (`Room:351`)
* `ready()` (`Area:184`)
* `playerEnter(player, prevRoom)` (`Player:157`)
* `playerLeave(player, nextRoom)` (`Player:143`)
* `npcEnter(npc, prevRoom)` (`Npc:74`)
* `npcLeave(npc, nextRoom)` (`Npc:60`)
* `updateTick()` (`Area:160`)

**Item**

* `spawn()` when spawned into room (`Room:318`)
* `updateTick()` (`ItemManager:43`)
* `equip(equipper)` (`Character:380`)
* `unequip(equipper)` (`Character:410`)
* Receives proxied room move events while in room (`Room:75`)

**NPC**

* `spawn()` (`Room:339`)
* `enterRoom(nextRoom)` (`Npc:79`)
* `updateTick()` (`Area:168`)
* Also all Character events below

**Player**

* `enterRoom(nextRoom)` (`Player:162`)
* `commandQueued(index)` (`Player:54`)
* `save(callback)` (`Player:170`)
* `saved` (`PlayerManager:153`)
* `updateTick` (`PlayerManager:173`)
* Quest relay events:
  * `questStart(instance)` (`QuestFactory:88`)
  * `questProgress(instance, progress)` (`QuestFactory:83`)
  * `questTurnInReady(instance)` (`QuestFactory:93`)
  * `questComplete(instance)` (`QuestFactory:97`)
  * `questReward(reward)` (`QuestFactory:114`)

**Character base (Player + NPC)**

* `attributeUpdate(attr, value)` (`Character:148`)
* `combatStart` (`Character:244`)
* `combatantAdded(target)` (`Character:287`)
* `combatantRemoved(target)` (`Character:307`)
* `combatEnd` (`Character:313`)
* `equip(slot, item)` (`Character:386`)
* `unequip(slot, item)` (`Character:416`)
* `followed(target)` (`Character:499`)
* `unfollowed(previousTarget)` (`Character:512`)
* `gainedFollower(follower)` (`Character:527`)
* `lostFollower(follower)` (`Character:541`)
* `hit(damage, target, finalAmount)` (`Damage:66`)
* `damaged(damage, finalAmount)` (`Damage:73`)
* `heal(heal, target, finalAmount)` (`Heal:27`)
* `healed(heal, finalAmount)` (`Heal:34`)
* `effectAdded(effect)` (`EffectList:135`)
* `effectRemoved()` (`EffectList:156`)

**Effect**

* `effectAdded` (`EffectList:131`)
* `effectActivated` (`Effect:152`)
* `effectStackAdded(newEffect)` (`EffectList:106`)
* `effectRefreshed(newEffect)` (`EffectList:115`)
* `effectDeactivated` (`Effect:168`)
* `remove` (`Effect:180`)
* Also receives forwarded character events (except `effectAdded/effectRemoved`) (`EffectList:61`)

**Quest**

* `start` (`QuestTracker:81`)
* `progress(progress)` (`Quest:81`)
* `turn-in-ready` (`Quest:72`)
* `complete` (`Quest:131`)

**Messaging / transport**

* `channelReceive(channel, sender, rawMessage)` (`Channel:101`)
* `close` on `TransportStream` (`TransportStream:71`)
* `metadataUpdated(key, newValue, oldValue)` (`Metadatable:52`)

##### 5. Observed hooks currently used in this workspace bundles

* Server events used:
  * `startup`, `shutdown` in `bundles/bundle-rantamuta/server-events/telnet.js:51`
  * same in minimal bundle `bundles/bundle-minimal/server-events/telnet.js:50`
* Input event used:
  * `main` handler via `event: state => async (...)` in `bundles/bundle-rantamuta/input-events/main.js:10`
* Entity script listeners used in active content:
  * `spawn` on items and rooms (`bundles/bundle-rantamuta/areas/rantamuta/scripts/items/*.js`, `bundles/bundle-rantamuta/areas/rantamuta/scripts/rooms/bellCryptGate.js:333`)
  * `ready` on room (`bundles/bundle-rantamuta/areas/rantamuta/scripts/rooms/bellCryptGate.js:334`)
* No `player-events.js` currently present in bundled content (`find bundles ...` result).

##### 6. Important implementation quirks / gotchas

* `EventManager.detach` is broad: it calls `removeAllListeners(event)` and can remove listeners it did not create (`EventManager:73`).
* `Scriptable.emit` suppresses all events for pruned entities and clears listeners (`Scriptable:22`).
* Entity listeners are synchronous `EventEmitter` dispatch; async handler promises are not awaited by `emit`.
* Area script missing-file path has a warning but still attempts load, so missing file can still throw (`BundleManager:300`, `BundleManager:307`).
* `GameServer.shutdown()` exists but is not called by wrapper boot script by default (startup is called at `ranvier:149`).
* Doc/event naming mismatch: JSDoc says `metadataUpdate`, emitted event is `metadataUpdated` (`Metadatable:47`, `Metadatable:52`).

If you want, I can turn this into a checked-in `docs/` reference with a hook-by-hook signature matrix and a “which script type can listen to which emitter” table.

#### Behaviors

Behaviors are the engine’s reusable event-reaction layer for world entities.

High-level:

* A behavior is a named bundle module that declares listeners for entity events.
* You attach that behavior to areas/rooms/items/NPCs via YAML (`behaviors:`).
* At runtime, the engine binds the behavior’s listeners to each matching entity instance.
* When that entity emits events (`spawn`, `ready`, `updateTick`, movement/combat/etc.), the behavior runs.

What they are intended for:

* Add dynamic game logic without changing core engine code.
* Centralize reusable rules across multiple entities (instead of duplicating per-entity scripts).
* Express “when X happens to this entity, do Y” patterns.
* Power stateful world simulation and reactions over time (ticks, movement, metadata changes, channel receives).
* Let authored content drive behavior through behavior config data in YAML.

In short: behaviors are the content-side mechanism for event-driven world logic, attached declaratively and executed per entity at runtime.
`rantamuta-core` provides **behavior framework and loader contracts**, but not built-in behavior content modules. These are provided by bundles.

NB:

* A `behavior` is an instantiation of an `EventManager`.
* There are no built-in `behaviors/` script files shipped inside `rantamuta-core`.
* `BundleManager` still defines a first-class `behaviors/` feature path and loads `area`, `npc`, `item`, and `room` behavior registries from bundle directories.
* This engine also supports entity-specific `script:` listeners (loaded from area-local `scripts/` paths) alongside behavior registries.
* Player hooks are separate: they are not loaded through `behaviors/`, but through `player-events.js`.

Core behavior architecture:

* `BehaviorManager` stores `Map<behaviorName, EventManager>` and is the central behavior registry (`BehaviorManager`).
* `EventManager` stores `Map<eventName, Set<listener>>`, supports `add`, `attach`, and `detach` (`EventManager`).
* `Scriptable` mixin provides:
  * `hasBehavior(name)`
  * `getBehavior(name)`
  * `setupBehaviors(manager)`
  (`Scriptable`)
* `GameEntity` extends `EventEmitter` through `Scriptable(Metadatable(EventEmitter))`, so area/room/item and other entity classes share the same attach model (`GameEntity`).
* `Npc` is scriptable via `Scriptable(Character)` and therefore receives both scriptable behavior listeners and character/combat events (`Npc`).

Load and bind lifecycle:

* Bundle feature load order is hardcoded. `behaviors/` is loaded early, before channels/commands/effects/input events/skills (`BundleManager`).
* `loadBehaviors` scans:
  * `behaviors/area/`
  * `behaviors/npc/`
  * `behaviors/item/`
  * `behaviors/room/`
  (`BundleManager`)
* For each behavior module:
  * loader is required
  * `.listeners` map is read
  * each listener factory is invoked as `listener(state)`
  * resulting handler is registered under behavior name + event name in the corresponding behavior manager
  (`BundleManager`)
* During entity hydration:
  * area: `this.setupBehaviors(state.AreaBehaviorManager)`
  * room: `this.setupBehaviors(state.RoomBehaviorManager)`
  * npc: `this.setupBehaviors(state.MobBehaviorManager)`
  * item: `this.setupBehaviors(state.ItemBehaviorManager)`
  (`Area`, `Room`, `Npc`, `Item`)

Listener contract and invocation semantics:

* Expected behavior module shape:
  * `module.exports = { listeners: { [eventName]: (state) => handlerFn } }`
* On `attach`, listeners are bound to the emitter as `this`:
  * with config: `listener.bind(emitter, config)`
  * without config: `listener.bind(emitter)`
  (`EventManager`)
* Behavior config rules:
  * behavior map values come from entity definition (`behaviors` map)
  * `behaviorName: true` normalizes to `{}` before attach
  (`Scriptable`)
* Entity-specific scripts (`script:` in area/entity definitions) use a similar `listeners` map but attach through factory script registries (`BundleManager`, `EntityFactory`).
* Back-compat loader behavior:
  * if a module export is a function, `_getLoader` calls it with legacy args and uses the returned object.
  (`BundleManager`)

Behavior hook catalog (engine-emitted events commonly used by scriptable entities):

* Area-oriented hooks:
  * `updateTick(state)`
  * `roomAdded(room)`
  * `roomRemoved(room)`
  * `metadataUpdated(key, value, oldValue)`
  * `channelReceive(channel, sender, rawMessage)` (if area is a channel target)
* Room-oriented hooks:
  * `spawn()`
  * `ready()`
  * `updateTick()`
  * `playerEnter(player, prevRoom)`
  * `playerLeave(player, nextRoom)`
  * `npcEnter(npc, prevRoom)`
  * `npcLeave(npc, nextRoom)`
  * `metadataUpdated(...)`
  * `channelReceive(...)`
* Item-oriented hooks:
  * `spawn()`
  * `updateTick()`
  * `equip(character)`
  * `unequip(character)`
  * proxied room movement hooks: `playerEnter`, `playerLeave`, `npcEnter`, `npcLeave`
  * `metadataUpdated(...)`
* NPC-oriented hooks (via scriptable + character event surface):
  * lifecycle: `spawn`, `updateTick`, `enterRoom`
  * combat/attribute: `attributeUpdate`, `combatStart`, `combatantAdded`, `combatantRemoved`, `combatEnd`, `hit`, `damaged`, `heal`, `healed`
  * equipment/following: `equip`, `unequip`, `followed`, `unfollowed`, `gainedFollower`, `lostFollower`
  * effects on character: `effectAdded(effect)`, `effectRemoved()`
  * proxied room movement hooks and channel hooks as above

Propagation and ordering behavior:

* `Room.emit` emits on room first, then proxies selected movement events to entities in the room (`Room`).
* `Character.emit` emits on character first, then proxies same event to active effects (`Character`).
* Area constructor registers its own internal `updateTick` handler early, so area update logic runs as part of the same event channel used by behavior listeners (`Area`).
* Entity script listeners often attach during factory create paths; behavior listeners attach during hydrate via `setupBehaviors`. This ordering matters if multiple listeners rely on side effects at spawn/hydrate time.

Constraints and sharp edges:

* Player behavior is intentionally separate from `behaviors/`; player listeners are loaded from `player-events.js` into `PlayerManager.events` (`BundleManager`, `PlayerManager`).
* `EventManager.detach` is broad and calls `removeAllListeners(event)` for selected events; this removes listeners beyond those owned by that manager (`EventManager`, `docs/NOTES.md`).
* `loadBehaviors` does not currently perform the same strict export-shape validation that `loadInputEvents` does; malformed behavior modules may fail with less-specific error paths.
* Strict mode duplicate detection (`_registerOrThrow`) covers many registries but does not register-check behavior names loaded via `loadBehaviors` (`BundleManager`).
* In this engine revision, mutation events for `addItem/removeItem` on room/item/character are discussed in proposal docs but are not part of the currently implemented stable behavior hook surface (`docs/proposals/QUERY_HOOK_GUARD_AND_EVENT_DRIVEN_SCRIPTS.md`).

#### Scripts versus Behaviors: Which one do I use?

* `behavior` = reusable listener package by **name**, attached via an entity’s `behaviors` map.
* `script` = listener package by **file reference** (`script:`), attached to a **specific area/entity definition**.

##### **What is actually different**

* Attachment key:
  * Behaviors: keyed by behavior name (`behaviors/<type>/<name>.js`), referenced in YAML `behaviors`.
  * Scripts: keyed by explicit script file (`areas/<area>/scripts/...`), referenced in YAML `script`.
* Reuse model:
  * Behaviors are meant for reuse across many entities.
  * Scripts are usually one-off or tightly content-specific.
* Config model:
  * Behaviors get per-entity config automatically (`behaviorName: true|{...}`), passed as first arg via `EventManager.attach(..., config)`.
  * Scripts don’t get that behavior-config injection; they usually read entity metadata/state directly.
* Lifecycle wiring:
  * Scripts are attached during factory create.
  * Behaviors are attached during `hydrate()` via `setupBehaviors(...)`.
* Governance:
  * Strict duplicate checks cover many registries, but not behavior names the same way; behavior collisions are less guarded.

##### **When to use which**

* Use a **behavior** when:
  * You want one mechanic pattern used by many entities.
  * You need per-entity tuning via YAML config.
  * You want a content-agnostic “capability” (guard, timer, AI pattern).
* Use a **script** when:
  * Logic is bespoke to a specific room/item/npc/area.
  * It depends on unique puzzle/story context.
  * Reuse/configurability is not the main goal.

Practical rule: if you expect copy-paste across entities, make it a behavior; if it is unique authored content, make it a script.

#### Effects

##### 1. What Effects Are

Effects are per-`Character` runtime state objects used for temporary or persistent gameplay modifiers:

* Attribute max modification (`health`, `armor`, etc.) via modifier functions in `src/Effect.js:203`.
* Incoming/outgoing damage modification in `src/Effect.js:220` and `src/Effect.js:230`.
* Time/event-driven behavior via listeners attached to each effect instance in `src/EffectFactory.js:34`.
* Cooldowns and passive skill mechanics via `Skill` integration in `src/Skill.js:143` and `src/Skill.js:174`.

Effects live in `Character.effects` (`EffectList`) in `src/Character.js:44`.

##### 2. Effect Definition Contract

Effect files are loaded from bundle `effects/` directories (if present), keyed by filename:

* Loader path and registration: `src/BundleManager.js:623`.
* Effect id from filename stem: `src/BundleManager.js:633`.
* Script-file detection: `src/Data.js:132`.

Definition shape consumed by `EffectFactory.add`:

* `config`
* `state`
* `modifiers`
* `flags`
* `listeners`
From `types/EffectFactory.d.ts:28`.

`config` defaults (applied by constructor):

* `autoActivate: true`
* `description: ''`
* `duration: Infinity`
* `hidden: false`
* `maxStacks: 0`
* `name: 'Unnamed Effect'`
* `persists: true`
* `refreshes: false`
* `tickInterval: false`
* `type: 'undef'`
* `unique: true`
At `src/Effect.js:41`.

Important units:

* `duration` is milliseconds (`src/Effect.js:22`).
* `tickInterval` is seconds (`src/Effect.js:20` + `EffectList` check in `src/EffectList.js:75`).

##### 3. How Effects Are Loaded

Boot sequence:

* Wrapper creates `GameState.EffectFactory` in `ranvier:107`.
* Bundle load order includes `effects/` before `skills/` in `src/BundleManager.js:124`.
* `loadEffects` requires each effect file and calls `EffectFactory.add` in `src/BundleManager.js:638`.

Compatibility loader behavior:

* If module export is a function, `_getLoader` calls it (legacy pattern) in `src/BundleManager.js:714`.

Duplicate behavior:

* `EffectFactory.add` silently ignores duplicate ids (`if has(id) return`) in `src/EffectFactory.js:23`.
* Strict mode adds cross-bundle duplicate rejection before add (`_registerOrThrow`) in `src/BundleManager.js:637` and `src/BundleManager.js:733`.
* Non-strict mode preserves first-write-wins for effects due duplicate-ignore in factory (validated in test) at `test/unit/BundleManagerStrictMode.js:229`.

##### 4. Runtime Lifecycle

Apply effect:

1. Create instance with `EffectFactory.create(id, configOverride, stateOverride)` at `src/EffectFactory.js:61`.
2. Add to character with `character.addEffect(effect)` at `src/Character.js:218`.
3. `EffectList.add` sets target and emits `effectAdded` in `src/EffectList.js:126`.

Auto-activation:

* If `config.autoActivate`, constructor binds `effectAdded -> activate` in `src/Effect.js:77`.

Expiry:

* No timer object exists per effect.
* Expiry is checked lazily by `validateEffects()` calls in `src/EffectList.js:169`.
* Expired effects are removed when effect list is touched (`entries`, `emit`, `evaluate*`, `serialize`, etc.).

Removal:

* Manual: call `effect.remove()` to emit `remove` in `src/Effect.js:176`.
* `EffectList.add` installs `remove` listener to actually detach in `src/EffectList.js:136`.
* `EffectList.remove` deactivates then emits `Character#effectRemoved` in `src/EffectList.js:151`.

##### 5. Event Model and What Effects Can Listen To

Each effect is an `EventEmitter` instance (`src/Effect.js:35`).

Listeners are attached via `EventManager.attach(effect)` in `src/EffectFactory.js:70`.

Character events are proxied to effects:

* `Character.emit` always forwards to `effects.emit` in `src/Character.js:60`.
* `EffectList.emit` forwards all events except `effectAdded`/`effectRemoved` to avoid ambiguity in `src/EffectList.js:61`.

Effect lifecycle events available:

* `effectAdded`
* `effectActivated`
* `effectStackAdded`
* `effectRefreshed`
* `effectDeactivated`
* `remove`
Emissions are in `src/EffectList.js:106`, `src/EffectList.js:115`, `src/EffectList.js:131`, `src/Effect.js:152`, `src/Effect.js:168`, `src/Effect.js:180`.

Tick delivery:

* Wrapper tick intervals in `ranvier:153` and `ranvier:159`.
* Players get `updateTick` via `PlayerManager` in `src/PlayerManager.js:173`.
* NPCs get `updateTick` via area tick fanout in `src/Area.js:168`.
* `tickInterval` gating is applied only inside `EffectList.emit` for `updateTick` at `src/EffectList.js:73`.

##### 6. Modifier Features

Attribute modifiers:

* Per-attribute map or single function strategy in `src/Effect.js:205`.

Damage modifiers:

* Outgoing modifiers run on attacker first (`Damage.evaluate`) at `src/Damage.js:43`.
* Incoming modifiers run on target next at `src/Damage.js:46`.
* Negative totals are clamped to `0` in `src/EffectList.js:213` and `src/EffectList.js:229`.

Skills integration:

* Passive skills instantiate configured effect id at `src/Skill.js:143`.
* Cooldowns are implemented as effects (`id='cooldown'`) at `src/Skill.js:188`.
* Cooldown state uses `state.cooldownId` for grouping in `src/Skill.js:195`.

##### 7. Stacking / Uniqueness / Refresh Semantics

When adding an effect with same `config.type`:

* If active effect has `maxStacks` and not maxed, increment stacks and emit `effectStackAdded` in `src/EffectList.js:99`.
* Else if active effect has `refreshes`, emit `effectRefreshed` in `src/EffectList.js:110`.
* Else if active effect has `unique`, reject new effect (`false`) in `src/EffectList.js:119`.
* Otherwise duplicates can coexist.

Key detail:

* Stack/refresh behavior does not auto-merge state or auto-reset duration. Listener code must do that explicitly.

##### 8. Persistence and Hydration

Serialize:

* `Effect.serialize()` persists `config`, `state`, elapsed metadata, optional `skill` id in `src/Effect.js:239`.
* Infinite duration is encoded as `"inf"` in `src/Effect.js:241`.
* `lastTick` is stored as time-since-last-tick delta in `src/Effect.js:245`.

Effect-list persistence:

* `EffectList.serialize()` includes only `config.persists === true` at `src/EffectList.js:236`.

Hydration:

* Character hydration calls `effects.hydrate(state)` in `src/Character.js:592`.
* For each serialized effect, factory re-creates by id then calls `effect.hydrate(...)` in `src/EffectList.js:250`.
* If effect id is missing from factory definitions, hydration throws from `src/EffectFactory.js:64`.

#### 9. High-Value Implementation Quirks (Important)

* `EffectFactory.create` override leakage:
  * `config` and `state` overrides mutate stored definition defaults (shallow merge pattern) at `src/EffectFactory.js:66`.
  * Result: one instance override can affect future instances of same effect id.

* `EffectFactory.get` is broken:
  * It recursively calls itself (`return this.get(id)`), causing stack overflow at `src/EffectFactory.js:51`.

* `active` flag is not authoritative:
  * Effects apply modifiers even when not active/deactivated because evaluation paths do not check `effect.active` (`EffectList.evaluateAttribute` and damage evaluators).

* `pause()` is partial:
  * Paused effects are skipped for event forwarding and attribute modifiers (`src/EffectList.js:69`, `src/EffectList.js:190`).
  * Paused effects still modify incoming/outgoing damage because those loops do not check `paused` (`src/EffectList.js:207`, `src/EffectList.js:224`).

* `effectRefreshed` does not reset lifetime by default:
  * Only event is emitted; elapsed/duration must be manually adjusted by listener.

* `effectRemoved` character event has no effect argument:
  * Emitted as `this.target.emit('effectRemoved')` in `src/EffectList.js:156`.

* Script file detection is broad:
  * Regex `/js$/` in `src/Data.js:134` matches `.js`, `.cjs`, `.mjs` suffixes.

### 6.4 Areas and world content layout (as configured by `ranvier.json`)

The default `entityLoaders` define concrete paths for world content:

* `areas`: `bundles/[BUNDLE]/areas` (directory of areas, each with `manifest.yml`) ([GitHub][6])
* `rooms`: `bundles/[BUNDLE]/areas/[AREA]/rooms.yml` ([GitHub][6])
* `items`: `bundles/[BUNDLE]/areas/[AREA]/items.yml` ([GitHub][6])
* `npcs`: `bundles/[BUNDLE]/areas/[AREA]/npcs.yml` ([GitHub][6])
* `quests`: `bundles/[BUNDLE]/areas/[AREA]/quests.yml` ([GitHub][6])
* `help`: `bundles/[BUNDLE]/help` (directory of `.yml` help entries) ([GitHub][6])

**Content-author invariants implied by the code:**

* If a path contains `[BUNDLE]` or `[AREA]`, those values must be set on the `EntityLoader` before use, or the datasource will throw. ([GitHub][18])
* For `YamlAreaDataSource`, each area directory must contain `manifest.yml` to be considered loadable. ([GitHub][15])
* For directory datasources, only files with the configured extension (`.yml` or `.json`) are considered. ([GitHub][14])

### 6.5 Namespacing rules

From the configuration and token placeholders, two namespaces are explicit:

* **bundle namespace**: the bundle directory name (the string inserted into `[BUNDLE]`)
* **area namespace**: the area directory name (the string inserted into `[AREA]`)

Other higher-level “entity reference” strings (e.g. `startingRoom: "limbo:white"`) exist in config, but their parsing/meaning is not defined in the code shown here; treat them as engine- or bundle-interpreted identifiers rather than filesystem paths. ([GitHub][6])

---

## 7. Development and maintenance workflow

### 7.1 Engine development vs game development

`ranviermud` is the runnable wrapper and configuration repo. Engine behavior is provided by the external dependency `ranvier`.

* **Game development** generally happens in `ranviermud` (config, bundles, content data).
* **Engine development** happens in `core` (repository package metadata: `rantamuta-core`), consumed by `ranviermud` as a dependency via GitHub specs. ([GitHub][1]) ([GitHub][23])

### 7.2 Naming and migration steps (core maintainer policy)

Rantamuta currently uses two naming layers intentionally:

* **Canonical repository identity**: `Rantamuta/core`.
* **Core package metadata**: `package.json` name is `rantamuta-core`. ([GitHub][23])
* **Downstream compatibility dependency key**: many consumers still use `ranvier` in their own `package.json` while pointing at `github:Rantamuta/core#...`.
* **Runtime import in legacy consumers**: `require('ranvier')`.

This is intentionally conservative for compatibility and operational stability:

* It avoids forced changes to existing consumer boot code and import paths.
* It keeps migration risk low while consumers pin specific Git tags/SHAs.
* It separates ecosystem-facing compatibility aliases from core repository ownership and maintenance policy.

Migration steps for maintainers:

1. **Recommended now (non-breaking)**: keep downstream dependency key `ranvier` and update only the GitHub ref (`tag`/`SHA`) to the desired `Rantamuta/core` release.
2. **Preparation for optional rename**: remove hardcoded assumptions in downstream tooling/docs that the core dependency key must be `ranvier`; centralize that string where practical.
3. **Breaking rename (coordinated major release only)**: switch downstream dependency key to `rantamuta-core`, update all import sites that currently use `require('ranvier')`, and release with explicit migration notes and rollback plan.

### 7.3 `npm link` workflow

The core repository’s README describes a `npm link` workflow:

* run `npm install` + `npm link` in `core`
* then in the runnable repo run `npm link ranvier` ([GitHub][21])

The `ranvier` wrapper includes  an inline comment describing essentially the same workflow to develop against a local core checkout. ([GitHub][2])

### 7.4 Bundle workflows: prefer the provided submodule scripts

Because bundles are treated as submodules, use the included scripts:

* install: `npm run install-bundle <remote-or-name>` ([GitHub][1])
* remove: `npm run remove-bundle <bundleName>` ([GitHub][1])
* update remote: `npm run update-bundle-remote <bundleName> <remote>` ([GitHub][1])
* initialize example bundles: `npm run init` / `npm run ci:init` (writes enabled list into `ranvier.json`) ([GitHub][1])

### 7.5 CI/smoke-test shape

`ranviermud` includes a smoke-login script that:

* starts `./ranvier` as a child process
* waits for telnet readiness output (using a small set of regexes)
* reads the port from `ranvier.json` (defaults to `4000` if missing)
* opens a TCP connection to `127.0.0.1:<port>`
* waits for a login prompt and sends the username `smokeuser`
* waits for a follow-up prompt
* shuts the server down with `SIGINT` (and `SIGKILL` if it does not exit in time) ([GitHub][22])

This script is a consumer-level integration check that the configured bundles bring up a telnet listener and accept basic interaction.

---

## 8. Mental model summary

### The tight mental model

1. **`ranviermud` boots the process** via `node ./ranvier`:

   * loads config (`ranvier.conf.js` or `ranvier.json`)
   * config is stored in `Ranvier.Config` (a simple static cache) ([GitHub][2])

2. **`ranviermud` constructs `GameState`** as a plain object of engine subsystems, then wires persistence:

   * load datasource definitions (`dataSources`)
   * load entity loader definitions (`entityLoaders`)
   * attach loaders to managers (accounts/players explicitly) ([GitHub][2])

3. **`BundleManager` loads enabled bundles** by name:

   * the wrapper constructs `BundleManager` with `./bundles`
   * `loadBundles()` is called
   * iterates configured bundle names from `ranvier.json.bundles`
   * validates configured bundle paths and skips invalid entries
   * loads feature scripts from conventional paths (`commands/`, `server-events/`, etc.)
   * loads areas and help
   * hydrates and registers areas into the runtime managers ([GitHub][8])

4. **Server startup is invoked** (when not in test mode):

   * wrapper attaches `ServerEventManager` to `GameServer`
   * wrapper calls `GameServer.startup(...)`
   * `GameServer` emits `startup`
   * bundles are expected to respond (via their server-events) and bring up transports ([GitHub][2])

5. **The wrapper schedules ticks** (when not in test mode):

   * entity tick: `AreaManager.tickAll(GameState)` and `ItemManager.tickAll()`
   * player tick: `PlayerManager.emit('updateTick')` ([GitHub][2])

### A single diagram of control flow

```
npm start
  -> node ./ranvier
       -> Config.load(ranvier.conf.js | ranvier.json)
       -> GameState = { ...managers, registries, GameServer... }
       -> DataSourceRegistry.load(...)
       -> EntityLoaderRegistry.load(...)
       -> AccountManager.setLoader(...)
       -> PlayerManager.setLoader(...)
       -> BundleManager.loadBundles()
            -> load features (commands, server-events, ...)
            -> load areas/help
            -> hydrate areas into AreaManager
       -> ServerEventManager.attach(GameServer)
       -> GameServer.startup(...)   (emits 'startup')
       -> setInterval(...) ticks
```

Everything else—gameplay, commands, networking, event reactions—hangs off the bundle conventions and the runtime state object built here. ([GitHub][2])

[1]: https://raw.githubusercontent.com/Rantamuta/ranviermud/master/package.json "https://raw.githubusercontent.com/Rantamuta/ranviermud/master/package.json"
[2]: https://raw.githubusercontent.com/Rantamuta/ranviermud/master/ranvier "https://raw.githubusercontent.com/Rantamuta/ranviermud/master/ranvier"
[3]: https://raw.githubusercontent.com/Rantamuta/ranviermud/master/util/install-bundle.js "https://raw.githubusercontent.com/Rantamuta/ranviermud/master/util/install-bundle.js"
[4]: https://raw.githubusercontent.com/Rantamuta/core/master/index.js "https://raw.githubusercontent.com/Rantamuta/core/master/index.js"
[5]: https://raw.githubusercontent.com/Rantamuta/datasource-file/master/index.js "https://raw.githubusercontent.com/Rantamuta/datasource-file/master/index.js"
[6]: https://raw.githubusercontent.com/Rantamuta/ranviermud/master/ranvier.json "https://raw.githubusercontent.com/Rantamuta/ranviermud/master/ranvier.json"
[7]: https://raw.githubusercontent.com/Rantamuta/core/master/src/EntityLoader.js "https://raw.githubusercontent.com/Rantamuta/core/master/src/EntityLoader.js"
[8]: https://raw.githubusercontent.com/Rantamuta/core/master/src/BundleManager.js "https://raw.githubusercontent.com/Rantamuta/core/master/src/BundleManager.js"
[9]: https://raw.githubusercontent.com/Rantamuta/ranviermud/master/util/init-bundles.js "https://raw.githubusercontent.com/Rantamuta/ranviermud/master/util/init-bundles.js"
[10]: https://raw.githubusercontent.com/Rantamuta/core/master/src/Config.js "https://raw.githubusercontent.com/Rantamuta/core/master/src/Config.js"
[11]: https://raw.githubusercontent.com/Rantamuta/core/master/src/Logger.js "https://raw.githubusercontent.com/Rantamuta/core/master/src/Logger.js"
[12]: https://raw.githubusercontent.com/Rantamuta/core/master/src/GameServer.js "https://raw.githubusercontent.com/Rantamuta/core/master/src/GameServer.js"
[13]: https://raw.githubusercontent.com/Rantamuta/datasource-file/master/YamlDataSource.js "https://raw.githubusercontent.com/Rantamuta/datasource-file/master/YamlDataSource.js"
[14]: https://raw.githubusercontent.com/Rantamuta/datasource-file/master/YamlDirectoryDataSource.js "https://raw.githubusercontent.com/Rantamuta/datasource-file/master/YamlDirectoryDataSource.js"
[15]: https://raw.githubusercontent.com/Rantamuta/datasource-file/master/YamlAreaDataSource.js "https://raw.githubusercontent.com/Rantamuta/datasource-file/master/YamlAreaDataSource.js"
[16]: https://raw.githubusercontent.com/Rantamuta/datasource-file/master/JsonDataSource.js "https://raw.githubusercontent.com/Rantamuta/datasource-file/master/JsonDataSource.js"
[17]: https://raw.githubusercontent.com/Rantamuta/datasource-file/master/JsonDirectoryDataSource.js "https://raw.githubusercontent.com/Rantamuta/datasource-file/master/JsonDirectoryDataSource.js"
[18]: https://raw.githubusercontent.com/Rantamuta/datasource-file/master/FileDataSource.js "https://raw.githubusercontent.com/Rantamuta/datasource-file/master/FileDataSource.js"
[19]: https://raw.githubusercontent.com/Rantamuta/ranviermud/master/util/remove-bundle.js "https://raw.githubusercontent.com/Rantamuta/ranviermud/master/util/remove-bundle.js"
[20]: https://raw.githubusercontent.com/Rantamuta/ranviermud/master/util/update-bundle-url.js "https://raw.githubusercontent.com/Rantamuta/ranviermud/master/util/update-bundle-url.js"
[21]: https://github.com/Rantamuta/core "https://github.com/Rantamuta/core"
[22]: https://raw.githubusercontent.com/Rantamuta/ranviermud/master/util/smoke-login.js "https://raw.githubusercontent.com/Rantamuta/ranviermud/master/util/smoke-login.js"
[23]: https://raw.githubusercontent.com/Rantamuta/core/master/package.json "https://raw.githubusercontent.com/Rantamuta/core/master/package.json"
[24]: https://raw.githubusercontent.com/Rantamuta/core/master/types/index.d.ts "https://raw.githubusercontent.com/Rantamuta/core/master/types/index.d.ts"
[25]: https://raw.githubusercontent.com/Rantamuta/core/master/tsconfig.types.json "https://raw.githubusercontent.com/Rantamuta/core/master/tsconfig.types.json"
[26]: https://raw.githubusercontent.com/Rantamuta/core/master/test/types/cjs-consumer.ts "https://raw.githubusercontent.com/Rantamuta/core/master/test/types/cjs-consumer.ts"
[27]: https://raw.githubusercontent.com/Rantamuta/core/master/src/AreaFloor.js "https://raw.githubusercontent.com/Rantamuta/core/master/src/AreaFloor.js"
[28]: https://raw.githubusercontent.com/Rantamuta/core/master/test/unit/AreaFloor.js "https://raw.githubusercontent.com/Rantamuta/core/master/test/unit/AreaFloor.js"
[29]: https://raw.githubusercontent.com/Rantamuta/core/master/src/Room.js "https://raw.githubusercontent.com/Rantamuta/core/master/src/Room.js"
[30]: https://raw.githubusercontent.com/Rantamuta/core/master/src/EffectFactory.js "https://raw.githubusercontent.com/Rantamuta/core/master/src/EffectFactory.js"
