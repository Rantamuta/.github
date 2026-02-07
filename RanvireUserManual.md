# Ranvire User Manual

## Initial orientation

### 1) `Ranvire/ranviermud` — the runnable project (entry point)

This is the repository a user clones and runs. It contains:

* the executable wrapper script `./ranvier` (invoked by `npm start` in `package.json`)
* the primary configuration file `ranvier.json` (or optional `ranvier.conf.js`, if present)
* a `bundles/` directory that serves as the bundle root; the provided `util/*` scripts manage bundles as git submodules in this directory
* a `data/` directory used as the on-disk root for runtime data (accounts/players are configured under `data/account` and `data/player` by default)

`ranviermud` depends on external packages via GitHub dependencies in `package.json`, including `ranvier`, `ranvier-datasource-file`, and `ranvier-telnet`.

### 2) `Ranvire/core` — the engine library consumed by `ranviermud`

This repository is the engine implementation published as the `ranvier` package. It is **not** a runnable application by itself; its exported API is built by requiring all modules under `./src/` via `require-dir`. ([GitHub][4])

### 3) `Ranvire/datasource-file` — a pluggable file-backed storage backend

This repository provides the `ranvier-datasource-file` package, exporting datasource classes such as `YamlDataSource`, `YamlAreaDataSource`, `YamlDirectoryDataSource`, and their JSON counterparts. ([GitHub][5])

In the default `ranviermud` configuration (`ranvier.json`), these datasources are registered under short names like `YamlArea`, `Yaml`, `YamlDirectory`, and `JsonDirectory`, and then selected by “entity loader” definitions. ([GitHub][6])

---

## 1. Conceptual overview

### What Ranvire is

Ranvire is a Node.js-based game server composed of:

* a **thin runnable wrapper** (`ranviermud`) that:

  * loads configuration (`ranvier.conf.js` if present, else `ranvier.json`)
  * constructs a global runtime state object (`GameState`) with managers/factories/registries from the `ranvier` dependency
  * wires data sources and entity loaders from `ranvier.json`
  * instantiates a `BundleManager` and calls `loadBundles()`
  * attaches server events and (when not in test mode) calls `GameServer.startup(...)`
  * schedules tick loops for entities and players ([Github][2])

* a **core engine library** (`core`, package `ranvier`) that provides:

  * the object model (managers/factories),
  * configuration access,
  * logging,
  * the bundle loader and script-loading conventions,
  * the entity loader abstraction,
  * and an event-emitting “server” surface that bundles can attach to. ([GitHub][4])
* **storage backends** (e.g., `datasource-file`) that implement CRUD-style access to entity records, and are selected/configured entirely via `ranvier.json`. ([GitHub][6])

### NB

* The process entry point for `ranviermud` is `./ranvier` (not the `ranvier` dependency itself). The wrapper loads the dependency via `require('ranvier')`.
* A datasource is **not** the engine’s persistence layer; it is a pluggable adapter selected by configuration and invoked through `EntityLoader`. ([GitHub][7])

### Architectural separation of concerns

The separation is explicit in how the wrapper builds the process:

* **Configuration**: loaded by the wrapper via `Ranvier.Config.load(...)` and read via `Config.get(...)`.
* **Runtime state (“GameState”)**: constructed as a plain object in `ranvier`, populated with managers/factories/registries from `ranvier`.
* **Content and features**: the wrapper instantiates `Ranvier.BundleManager` and calls `loadBundles()`; bundle loading behavior is defined in the `ranvier` dependency.
* **Persistence wiring**: `ranvier.json` defines `dataSources` and `entityLoaders`, which the wrapper loads via `DataSourceRegistry` and `EntityLoaderRegistry`.

---

## 2. Repository roles and responsibilities

## 2.1 `Ranvire/ranviermud`

### What it owns

* **Process entry and boot**: `./ranvier` performs Node version gating, config selection, logger setup, global state construction, registry initialization, bundle loading, and server startup/ticks.
* **Project-level configuration**: `ranvier.json` defines enabled bundles, datasource registrations, and entity loader wiring (plus other settings like `startingRoom`, name length constraints, etc.).
* **Bundle management tooling**: scripts under `util/` manage bundles as git submodules and update `ranvier.json`.

### What it deliberately does not own

* Engine subsystem implementations live in the external dependency `ranvier`.
* Datasource implementations live in external dependencies such as `ranvier-datasource-file`.

### How it depends on the others

In `package.json`, `ranviermud` depends on:

* `ranvier` (engine)
* `ranvier-datasource-file` (datasources)
* `ranvier-telnet` (telnet transport implementation)

## 2.2 `Ranvire/core`

### What it owns

* **Engine API surface** exported from `index.js` via `require-dir('./src/')`. ([GitHub][4])
* **Minimal Config wrapper**: `Config.load(data)` stores the config object, and `Config.get(key, fallback)` reads from that cache. (No merging, validation, or deep resolution is performed by `Config` itself.) ([GitHub][10])
* **Logging wrapper**: `Logger` wraps Winston and provides `log`, `error`, `warn`, `verbose`, plus optional file logging and pretty errors. ([GitHub][11])
* **Entity loader abstraction**: `EntityLoader` is a thin wrapper around a datasource instance + loader config, providing `setArea`, `setBundle`, and CRUD-ish methods that delegate to the datasource if implemented. ([GitHub][7])
* **Bundle loading convention**: `BundleManager` discovers enabled bundles and loads features from well-known paths within each bundle (commands, behaviors, server-events, etc.), then loads areas and help and “distributes” areas into the `AreaManager`. ([GitHub][8])
* **Server startup surface**: `GameServer` is an `EventEmitter` that (in the core itself) only emits `startup` and `shutdown` events. This is the extension point bundles attach to (via “server events”). ([GitHub][12])

### What it deliberately does not own

* It does not decide *which* bundles to load; it reads the enabled list from `Config`, which is loaded by `ranviermud`. ([GitHub][8])
* It does not bake in a single persistence system; it expects datasources and entity loaders to be configured externally and invoked through registries and `EntityLoader`. ([GitHub][2])

## 2.3 `Ranvire/datasource-file`

### What it owns

* Concrete datasource implementations for file-backed storage:

  * YAML single-file: `YamlDataSource` ([GitHub][13])
  * YAML directory-of-entities: `YamlDirectoryDataSource` ([GitHub][14])
  * YAML areas-by-directory-with-manifest: `YamlAreaDataSource` ([GitHub][15])
  * JSON single-file: `JsonDataSource` ([GitHub][16])
  * JSON directory-of-entities: `JsonDirectoryDataSource` ([GitHub][17])
* A common `FileDataSource` base that implements template resolution (`[BUNDLE]`, `[AREA]`) and root-relative path joining. ([GitHub][18])

### What it deliberately does not own

* It does not know about Ranvier “managers”, “areas”, or “bundles” beyond the string-token substitution it performs. Those higher-level meanings are owned by the engine and bundle loader. ([GitHub][18])

---

## 3. Runtime architecture

This section follows the boot path in `Ranvire/ranvier`.

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

* enumerates directories under the bundles path
* skips non-directories and `.`/`..`
* **only loads bundles whose directory name is present in `Config.get('bundles', [])`**
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

This is one of the most important “architectural contracts” in Ranvire: bundle authors place scripts in these conventional locations to participate in boot.

### 3.8 Server startup

The wrapper attaches server events and starts the server (when not in test mode):

* `GameState.ServerEventManager.attach(GameState.GameServer);`
* `GameState.GameServer.startup(commander);` ([GitHub][2])

In core, `GameServer.startup()` does only one thing: emit `startup` with the commander options. ([GitHub][12])

So “starting the server” in Ranvire is structurally:

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

In Ranvire’s runtime wiring, an “entity” (in the persistence/config sense) is a record or collection of records addressed via an `EntityLoader` that wraps a datasource instance. ([GitHub][7])

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
* `hasData()`, `fetchAll()`, `fetch(id)`, `replace(data)`, `update(id, data)` which delegate to the datasource if it supports the method; otherwise the loader throws a “not supported” error. ([GitHub][7])

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

---

## 5. `datasource-file` in depth

This section is written to be sufficient for implementing a new datasource correctly.

### 5.1 Why datasources exist (in this architecture)

The engine’s persistence surface is configuration-driven:

* The wrapper loads a datasource registry from `ranvier.json:dataSources`. ([GitHub][2])
* Entity categories (accounts, rooms, etc.) are then mapped to datasources + per-entity config via `ranvier.json:entityLoaders`. ([GitHub][6])
* At runtime, code interacts with an `EntityLoader`, not directly with filesystem or YAML/JSON parsing. ([GitHub][7])

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
* joins `root` + `path`
* replaces `[BUNDLE]` and `[AREA]` tokens ([GitHub][18])

#### 5.2.2 The effective datasource interface (duck-typed)

`EntityLoader` calls into the datasource and checks method existence with `'methodName' in this.dataSource`. ([GitHub][7])

In practice, a datasource may implement:

* `hasData(config)` → boolean/promise
* `fetchAll(config)` → object/array/promise
* `fetch(config, id)` → record/promise
* `replace(config, data)` → promise (write entire dataset)
* `update(config, id, data)` → promise (write one record) ([GitHub][7])

A new datasource must implement the subset actually used by the engine/components you wire it to. If you wire it to an entity loader that will call `update`, and you don’t implement `update`, the `EntityLoader` will throw at runtime. ([GitHub][7])

### 5.3 YAML vs JSON sources (actual behavior)

#### 5.3.1 `YamlDataSource` (single YAML file)

* `fetchAll` reads a YAML file and parses it with `js-yaml`’s `yaml.load(contents)`. ([GitHub][13])
* `replace` writes YAML using `yaml.dump(data)`. ([GitHub][13])
* `fetch(id)` expects the parsed object to be keyed by id and throws `ReferenceError` if missing. ([GitHub][13])
* `update(id, data)` loads the whole file, sets `currentData[id] = data`, and rewrites the file; if the YAML content is an array, it throws. ([GitHub][13])

#### 5.3.2 `JsonDataSource` (single JSON file)

* If the file does not exist, `fetchAll` resolves to `{}` (it does not throw). ([GitHub][16])
* It strips a UTF‑8 BOM if present, then `JSON.parse`s the content. ([GitHub][16])
* `replace` writes pretty JSON (`JSON.stringify(data, null, 2)`). ([GitHub][16])
* `update` mirrors the YAML approach (load all, assign by id, rewrite). ([GitHub][16])

### 5.4 Directory-backed vs single-file sources

#### 5.4.1 `YamlDirectoryDataSource` (directory of `*.yml`)

* `fetchAll` reads directory entries, filters to `.yml`, and builds an object keyed by filename stem. ([GitHub][14])
* It uses `YamlDataSource` internally with the directory path as the “root” and then loads `${id}.yml`. ([GitHub][14])

#### 5.4.2 `JsonDirectoryDataSource` (directory of `*.json`)

* `fetchAll` reads directory entries, filters to `.json`, and builds an object keyed by filename stem. ([GitHub][17])
* It uses `JsonDataSource` internally with the directory path as the “root” and then loads `${id}.json`. ([GitHub][17])

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

* Accounts and players are stored under `data/account` and `data/player` and are loaded via `JsonDirectoryDataSource`, which supports `update()` and `replace()` (writes to disk). ([GitHub][6])
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

* `BundleManager` scans the bundles directory.
* It checks whether each directory name is enabled in config.
* It loads known features based on the presence of specific files/directories. ([GitHub][8])

### 6.2 How bundles are installed and enabled in `ranviermud`

Ranvire’s tooling treats bundles as **git submodules**:

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
* **Engine development** happens in `core` (the `ranvier` package), consumed by `ranviermud` as a dependency. ([GitHub][1])

### 7.2 `npm link` workflow

The core repository’s README describes a `npm link` workflow:

* run `npm install` + `npm link` in `core`
* then in the runnable repo run `npm link ranvier` ([GitHub][21])

The `ranvier` wrapper includes  an inline comment describing essentially the same workflow to develop against a local core checkout. ([GitHub][2])

### 7.3 Bundle workflows: prefer the provided submodule scripts

Because bundles are treated as submodules, use the included scripts:

* install: `npm run install-bundle <remote-or-name>` ([GitHub][1])
* remove: `npm run remove-bundle <bundleName>` ([GitHub][1])
* update remote: `npm run update-bundle-remote <bundleName> <remote>` ([GitHub][1])
* initialize example bundles: `npm run init` / `npm run ci:init` (writes enabled list into `ranvier.json`) ([GitHub][1])

### 7.4 CI/smoke-test shape

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
   * scans `bundles/`
   * loads only bundles listed in `ranvier.json.bundles`
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

[1]: https://raw.githubusercontent.com/Ranvire/ranviermud/master/package.json "https://raw.githubusercontent.com/Ranvire/ranviermud/master/package.json"
[2]: https://raw.githubusercontent.com/Ranvire/ranviermud/master/ranvier "https://raw.githubusercontent.com/Ranvire/ranviermud/master/ranvier"
[4]: https://raw.githubusercontent.com/Ranvire/core/master/index.js "https://raw.githubusercontent.com/Ranvire/core/master/index.js"
[5]: https://raw.githubusercontent.com/Ranvire/datasource-file/master/index.js "https://raw.githubusercontent.com/Ranvire/datasource-file/master/index.js"
[6]: https://raw.githubusercontent.com/Ranvire/ranviermud/master/ranvier.json "https://raw.githubusercontent.com/Ranvire/ranviermud/master/ranvier.json"
[7]: https://raw.githubusercontent.com/Ranvire/core/master/src/EntityLoader.js "https://raw.githubusercontent.com/Ranvire/core/master/src/EntityLoader.js"
[8]: https://raw.githubusercontent.com/Ranvire/core/master/src/BundleManager.js "https://raw.githubusercontent.com/Ranvire/core/master/src/BundleManager.js"
[9]: https://raw.githubusercontent.com/Ranvire/ranviermud/master/util/init-bundles.js "https://raw.githubusercontent.com/Ranvire/ranviermud/master/util/init-bundles.js"
[10]: https://raw.githubusercontent.com/Ranvire/core/master/src/Config.js "https://raw.githubusercontent.com/Ranvire/core/master/src/Config.js"
[11]: https://raw.githubusercontent.com/Ranvire/core/master/src/Logger.js "https://raw.githubusercontent.com/Ranvire/core/master/src/Logger.js"
[12]: https://raw.githubusercontent.com/Ranvire/core/master/src/GameServer.js "https://raw.githubusercontent.com/Ranvire/core/master/src/GameServer.js"
[13]: https://raw.githubusercontent.com/Ranvire/datasource-file/master/YamlDataSource.js "https://raw.githubusercontent.com/Ranvire/datasource-file/master/YamlDataSource.js"
[14]: https://raw.githubusercontent.com/Ranvire/datasource-file/master/YamlDirectoryDataSource.js "https://raw.githubusercontent.com/Ranvire/datasource-file/master/YamlDirectoryDataSource.js"
[15]: https://raw.githubusercontent.com/Ranvire/datasource-file/master/YamlAreaDataSource.js "https://raw.githubusercontent.com/Ranvire/datasource-file/master/YamlAreaDataSource.js"
[16]: https://raw.githubusercontent.com/Ranvire/datasource-file/master/JsonDataSource.js "https://raw.githubusercontent.com/Ranvire/datasource-file/master/JsonDataSource.js"
[17]: https://raw.githubusercontent.com/Ranvire/datasource-file/master/JsonDirectoryDataSource.js "https://raw.githubusercontent.com/Ranvire/datasource-file/master/JsonDirectoryDataSource.js"
[18]: https://raw.githubusercontent.com/Ranvire/datasource-file/master/FileDataSource.js "https://raw.githubusercontent.com/Ranvire/datasource-file/master/FileDataSource.js"
[19]: https://raw.githubusercontent.com/Ranvire/ranviermud/master/util/remove-bundle.js "https://raw.githubusercontent.com/Ranvire/ranviermud/master/util/remove-bundle.js"
[20]: https://raw.githubusercontent.com/Ranvire/ranviermud/master/util/update-bundle-url.js "https://raw.githubusercontent.com/Ranvire/ranviermud/master/util/update-bundle-url.js"
[21]: https://github.com/Ranvire/core "https://github.com/Ranvire/core"
[22]: https://raw.githubusercontent.com/Ranvire/ranviermud/master/util/smoke-login.js "https://raw.githubusercontent.com/Ranvire/ranviermud/master/util/smoke-login.js"
:
