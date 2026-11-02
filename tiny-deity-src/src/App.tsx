import { useEffect, useRef, useState } from "react";
import { Icon } from "./Icons";
import {
  BUILDINGS,
  RECIPES,
  recipeText,
  POWERS,
  QUESTS,
  UNLOCKS,
  xpForLevel,
} from "./game/data";
import {
  assign,
  cast,
  collect,
  discover,
  expand,
  note,
  offline,
  step,
  upgrade,
} from "./game/simulation";
import {
  RESOURCES,
  materialError,
  gather,
  replant,
  salvage,
  nearby,
} from "./game/economy";
import { message, useGame } from "./game/store";
import { createWorld } from "./game/world";
import type {
  Building,
  BuildingType,
  Follower,
  Power,
  World,
} from "./game/types";
import {
  deserialize,
  load,
  save,
  serialize,
  storedBackup,
} from "./persistence/database";
import { GameView } from "./render/GameView";
import { chime } from "./audio";
const GAME_VERSION = "0.4.4";
const GAME_BUILD = "surface-crossing";
let saveChain = Promise.resolve();
let saveBlocked = false;
let protectedBackup: string | null = null;
async function persist(w: World) {
  if (saveBlocked) {
    useGame.setState({
      saveStatus:
        "Existing save preserved — import a valid save or explicitly start a new world",
    });
    return;
  }
  useGame.setState({ saveStatus: "Saving…" });
  saveChain = saveChain
    .catch(() => {})
    .then(async () => {
      try {
        await save(w);
        useGame.setState({ saveStatus: "Saved on this device" });
      } catch {
        useGame.setState({ saveStatus: "Save unavailable — export a backup" });
      }
    });
  return saveChain;
}
function download(name: string, content: string) {
  const url = URL.createObjectURL(
    new Blob([content], { type: "application/json" }),
  );
  const a = document.createElement("a");
  a.href = url;
  a.download = name;
  a.click();
  setTimeout(() => URL.revokeObjectURL(url), 5000);
}
function action(result: string | null, success?: string) {
  if (result) message(result);
  else if (success) message(success);
  useGame.getState().refresh();
}
function MiniArt({ type }: { type: BuildingType }) {
  return (
    <div className={`mini-art art-${type}`} aria-hidden="true">
      <i className="art-ground" />
      <i className="art-wall" />
      <i className="art-roof" />
      <i className="art-door" />
      <i className="art-window" />
      <i className="art-plant" />
      {["shrine", "temple", "observatory"].includes(type) && (
        <Icon name="spark" size={18} />
      )}
    </div>
  );
}
function Meter({
  label,
  value,
  color = "sage",
}: {
  label: string;
  value: number;
  color?: string;
}) {
  return (
    <div className={`meter ${color}`}>
      <span>
        {label}
        <b>{Math.round(value)}%</b>
      </span>
      <div>
        <i style={{ width: `${Math.max(0, Math.min(100, value))}%` }} />
      </div>
    </div>
  );
}
function IconButton({
  name,
  label,
  onClick,
  active = false,
}: {
  name: string;
  label: string;
  onClick: () => void;
  active?: boolean;
}) {
  return (
    <button
      className={`icon-button ${active ? "active" : ""}`}
      onClick={onClick}
      aria-label={label}
      title={label}
    >
      <Icon name={name} />
    </button>
  );
}
export default function App() {
  const ui = useGame(),
    w = ui.world;
  const host = useRef<HTMLDivElement>(null),
    view = useRef<GameView | null>(null);
  const [tray, setTray] = useState<"terrain" | "weather" | "more" | null>(null);
  const [expanded, setExpanded] = useState(false);
  const [levelUp, setLevelUp] = useState(0);
  const [fatal, setFatal] = useState("");
  const [resetAsk, setResetAsk] = useState(false);
  const [planetName, setPlanetName] = useState(w.name);
  const file = useRef<HTMLInputElement>(null);
  const [ready, setReady] = useState(false);
  useEffect(() => {
    let cancelled = false;
    void (async () => {
      try {
        const restored = await load();
        if (restored) {
          offline(restored, (Date.now() - restored.lastSaved) / 1000);
          if (!cancelled) {
            useGame.setState({
              world: restored,
              saveStatus: "Saved on this device",
            });
            setPlanetName(restored.name);
          }
        } else useGame.setState({ saveStatus: "Autosave ready" });
      } catch {
        saveBlocked = true;
        try {
          protectedBackup = await storedBackup();
        } catch {
          /* Keep inaccessible storage untouched. */
        }
        useGame.setState({
          paused: true,
          saveStatus:
            "Existing save could not be loaded. Autosave stopped to preserve it.",
        });
        message(
          "Your existing save is preserved. Open Settings to export it, import a valid backup, or explicitly start a new world.",
        );
      }
      if (cancelled) return;
      useGame.setState({ ready: true });
      setReady(true);
    })();
    return () => {
      cancelled = true;
    };
  }, []);
  useEffect(() => {
    if (!ready || !host.current) return;
    const game = new GameView(host.current);
    view.current = game;
    void game
      .init()
      .catch(() =>
        setFatal(
          "The planet renderer could not start. Try reloading with WebGL enabled.",
        ),
      );
    let frame = 0,
      last = performance.now(),
      acc = 0,
      refresh = 0,
      saveTime = 0,
      hiddenAt = 0;
    let lastLevel = useGame.getState().world.level,
      lastMiracles = 0,
      lastGold = 0;
    const tick = (now: number) => {
      const state = useGame.getState(),
        world = state.world;
      const delta = Math.min(0.25, (now - last) / 1000);
      last = now;
      if (!state.paused && !document.hidden) {
        acc += delta * world.settings.speed;
        let steps = 0;
        while (acc >= 0.05 && steps < 20) {
          step(world, 0.05);
          acc -= 0.05;
          steps++;
        }
        if (steps === 20) acc = 0;
      }
      refresh += delta;
      saveTime += delta;
      if (refresh >= 0.2) {
        refresh = 0;
        state.refresh();
        if (world.level > lastLevel) {
          setLevelUp(world.level);
          if (world.settings.sound) chime("level");
        }
        lastLevel = world.level;
        if (world.settings.sound && world.stats.miracles > lastMiracles)
          chime();
        if (world.settings.sound && world.stats.collected > lastGold)
          chime("coin");
        lastMiracles = world.stats.miracles;
        lastGold = world.stats.collected;
      }
      if (saveTime > 10) {
        saveTime = 0;
        void persist(world);
      }
      frame = requestAnimationFrame(tick);
    };
    frame = requestAnimationFrame(tick);
    const visibility = () => {
      if (document.hidden) {
        hiddenAt = Date.now();
        void persist(useGame.getState().world);
      } else {
        const current = useGame.getState();
        if (hiddenAt && !current.paused)
          offline(current.world, (Date.now() - hiddenAt) / 1000);
        hiddenAt = 0;
        last = performance.now();
        acc = 0;
      }
    };
    const pagehide = () => {
      void persist(useGame.getState().world);
    };
    document.addEventListener("visibilitychange", visibility);
    window.addEventListener("pagehide", pagehide);
    return () => {
      cancelAnimationFrame(frame);
      game.destroy();
      view.current = null;
      document.removeEventListener("visibilitychange", visibility);
      window.removeEventListener("pagehide", pagehide);
    };
  }, [ready]);
  useEffect(() => {
    if (!ui.toast) return;
    const t = setTimeout(() => useGame.setState({ toast: "" }), 6500);
    return () => clearTimeout(t);
  }, [ui.toast]);
  const panel = (p: typeof ui.panel) => {
    setTray(null);
    setExpanded(false);
    useGame.setState({ panel: ui.panel === p ? null : p, selected: null });
  };
  const selectedFollower =
    ui.selected?.kind === "follower"
      ? w.followers.find((f) => f.id === ui.selected?.id)
      : undefined;
  const selectedBuilding =
    ui.selected?.kind === "building"
      ? w.buildings.find((b) => b.id === ui.selected?.id)
      : undefined;
  const goal = QUESTS.find((q) => !w.completed.includes(q.id));
  const setPower = (power: "hand" | Power) => {
    if (power !== "hand" && w.level < POWERS[power].level) {
      message(`${POWERS[power].name} unlocks at level ${POWERS[power].level}.`);
      return;
    }
    useGame.setState({
      tool: power,
      placing: null,
      moving: null,
      panel: null,
      selected: null,
    });
  };
  const selectBuilding = (type: BuildingType) => {
    if (w.level < BUILDINGS[type].level) return;
    if (w.gold < BUILDINGS[type].cost) {
      message("Earn a little more gold before building this.");
      return;
    }
    const missing = materialError(w, type);
    if (missing) {
      message(missing);
      return;
    }
    useGame.setState({
      placing: type,
      moving: null,
      tool: "hand",
      panel: null,
      selected: null,
    });
    message("Choose a clear patch of grass. Tap to place; drag to explore.");
  };
  const setting = (key: keyof World["settings"], value: boolean | number) => {
    Object.assign(w.settings, { [key]: value });
    ui.refresh();
  };
  const reset = (demo = false) => {
    saveBlocked = false;
    protectedBackup = null;
    const next = createWorld(19207, demo);
    useGame.setState({
      world: next,
      selected: null,
      panel: null,
      tool: "hand",
      placing: null,
      moving: null,
      paused: false,
      toast: demo
        ? "Welcome to the flourishing-world sandbox."
        : "A fresh little beginning.",
    });
    view.current?.home();
    setPlanetName(next.name);
    setResetAsk(false);
    void persist(next);
  };
  const close = () => useGame.setState({ panel: null, selected: null });
  return (
    <main className="app">
      <section className="game-stage" aria-label="Tiny Deity game">
        <div className="sky-haze" />
        <div
          className="game-canvas"
          ref={host}
          onPointerDown={() => {
            if (useGame.getState().tool === "hand") setTray(null);
          }}
        />
        {!ready && <div className="loading">Growing your little world…</div>}
        {fatal && <div className="loading error">{fatal}</div>}
        <header className="compact-hud" aria-label="World resources">
          <button
            onClick={() => panel("resources")}
            aria-label="Open resources"
            className="hud-pill"
          >
            <Icon name="coin" size={20} />
            <b data-testid="gold">{Math.floor(w.gold)}</b>
            <Icon name="rain" size={20} />
            <b data-testid="mana">{w.mana.toFixed(1)}</b>
          </button>
          <button
            className="hud-pill hud-level"
            onClick={() => panel("goals")}
            aria-label={`Level ${w.level}, ${w.xp} XP. Open objectives`}
          >
            <span className="level-badge">{w.level}</span>
            <span>
              <small>
                {w.xp}/{xpForLevel(w.level)} XP
              </small>
              <span className="xp-track">
                <i
                  style={{
                    width: `${Math.min(100, (w.xp / xpForLevel(w.level)) * 100)}%`,
                  }}
                />
              </span>
            </span>
          </button>
          <IconButton
            name="settings"
            label="Settings"
            onClick={() => panel("settings")}
          />
        </header>
        <h1 className="planet-name">
          {w.name}
          <span> · tiny deity</span>
        </h1>
        {goal && (
          <button
            className="objective-chip"
            onClick={() => panel("goals")}
            title={goal.description}
          >
            <Icon name="leaf" size={16} />
            {goal.name}
            <Icon name="chevron" size={12} />
          </button>
        )}
        <div className="view-tools">
          <IconButton
            name="globe"
            label="Full planet overview"
            onClick={() => view.current?.overview()}
          />
          <button
            className="icon-button"
            aria-label="Zoom in"
            title="Zoom in"
            onClick={() => view.current?.zoom(1.2)}
          >
            +
          </button>
          <button
            className="icon-button"
            aria-label="Zoom out"
            title="Zoom out"
            onClick={() => view.current?.zoom(1 / 1.2)}
          >
            −
          </button>
          <IconButton
            name="leaf"
            label="Return to home view"
            onClick={() => view.current?.home()}
          />
          <IconButton
            name="camera"
            label="Save planet snapshot"
            onClick={() => view.current?.snapshot()}
          />
        </div>
        <div className="rotation-controls">
          <button
            aria-label="Rotate planet left"
            onClick={() => view.current?.rotate(0.22)}
          >
            ↶
          </button>
          <span>DRAG TO EXPLORE</span>
          <button
            aria-label="Rotate planet right"
            onClick={() => view.current?.rotate(-0.22)}
          >
            ↷
          </button>
        </div>
        {w.rune && (
          <button
            className="rune-button"
            onClick={() => {
              expand(w);
              message("Your planet has grown. Welcome to new possibilities!");
              ui.refresh();
            }}
          >
            ✧ Awaken the sacred rune
          </button>
        )}
        {["raise", "lower", "smooth"].includes(ui.tool) && w.undo && (
          <button
            className="undo-terrain"
            onClick={() => {
              w.terrain.forEach((t, i) => (t.height = w.undo![i]));
              w.undo = null;
              w.terrainVersion++;
              ui.refresh();
              message("The last terrain change has been restored.");
            }}
          >
            ↶ Undo terrain change
          </button>
        )}
        {ui.paused && (
          <div className="pause-banner">
            <Icon name="pause" />
            Your little world is resting.
            <button onClick={() => useGame.setState({ paused: false })}>
              Resume
            </button>
          </div>
        )}
        {(ui.placing || ui.moving) && (
          <div className="placement-banner">
            <Icon name="build" />
            <span>
              {ui.moving
                ? "Move your building"
                : `Place ${BUILDINGS[ui.placing!].name}`}
              <small>Tap a clear spot along the surface. Drag to rotate.</small>
            </span>
            <button
              onClick={() => useGame.setState({ placing: null, moving: null })}
            >
              Cancel
            </button>
          </div>
        )}
        {ui.toast && (
          <div className="toast" role="status">
            <Icon name="spark" size={18} />
            {ui.toast}
            <button
              aria-label="Dismiss notification"
              onClick={() => useGame.setState({ toast: "" })}
            >
              ×
            </button>
          </div>
        )}
        {(ui.panel || selectedFollower || selectedBuilding) && (
          <aside
            className={`side-panel ${expanded ? "expanded" : ""}`}
            aria-label={
              ui.panel
                ? `${ui.panel} panel`
                : selectedFollower
                  ? "Follower details"
                  : "Building details"
            }
          >
            <div className="panel-heading">
              <button
                aria-label={expanded ? "Collapse panel" : "Expand panel"}
                onClick={() => setExpanded(!expanded)}
              >
                {expanded ? "⌄" : "⌃"}
              </button>
              <span className="overline">
                {ui.panel === "store"
                  ? "A PLACE FOR EVERYTHING"
                  : ui.panel === "goals"
                    ? "ONE LITTLE STEP AT A TIME"
                    : ui.panel === "followers"
                      ? "THE HEART OF YOUR WORLD"
                      : "YOUR LITTLE WORLD"}
              </span>
              <button aria-label="Close panel" onClick={close}>
                <Icon name="close" size={20} />
              </button>
            </div>
            {ui.panel === "resources" && (
              <>
                <span className="overline">GIFTS OF THE LAND</span>
                <h2>A living little economy.</h2>
                <div className="status-line">
                  <span>Awe</span>
                  <b>{w.awe}</b>
                </div>
                <p className="panel-intro">
                  Gather from your landscape, or assign believers to production.
                  Rates show recent actual production and consumption per
                  minute.
                </p>
                {w.waitingFollowers > 0 && (
                  <p className="panel-intro">
                    {w.waitingFollowers} inhabitants await a food surplus. Store
                    3 food to welcome the next visitor.
                  </p>
                )}
                <div className="material-list">
                  {RESOURCES.map((r) => (
                    <div key={r} className="material-row">
                      <Icon name={r} size={30} />
                      <div>
                        <b>{r[0].toUpperCase() + r.slice(1)}</b>
                        <small>
                          +{w.produced[r].toFixed(1)}/min · −
                          {w.consumed[r].toFixed(1)}/min
                        </small>
                        <small>
                          {w.resources[r] < 2
                            ? "Running low"
                            : w.resources[r] >= w.capacity[r]
                              ? "Storage full"
                              : "In settlement storage"}
                        </small>
                      </div>
                      <strong data-testid={`resource-${r}`}>
                        {w.resources[r].toFixed(1)}
                        <small> / {w.capacity[r]}</small>
                      </strong>
                      <button
                        disabled={w.time < w.gatherAt}
                        onClick={() =>
                          action(
                            gather(
                              w,
                              r,
                              r === "wood"
                                ? 0.72
                                : r === "stone"
                                  ? -0.86
                                  : r === "water"
                                    ? 1.18
                                    : 0,
                            ),
                            `Gathered ${r}. +1 gold`,
                          )
                        }
                      >
                        Gather {r}
                      </button>
                    </div>
                  ))}
                </div>
                <p className="panel-intro">
                  Tap trees or rocks on the planet to gather at that location.
                  Gathering takes 6 seconds to recover. Rain into a hollow for
                  pond water; collectors catch rain directly.
                </p>
                <button
                  className="secondary-button"
                  onClick={() =>
                    action(
                      replant(w),
                      "Seedlings planted in the home forest. Add rain to support regrowth.",
                    )
                  }
                >
                  Replant home forest · Free
                </button>
                {w.legacy && (
                  <p className="panel-intro">
                    Legacy world: your original planet size and all inhabitants
                    are preserved.
                  </p>
                )}
              </>
            )}
            {ui.panel === "store" && (
              <>
                <h2>Make room for wonder.</h2>
                <p className="panel-intro">
                  Build a home for a growing world. Believers bring each new
                  place to life.
                </p>
                <div className="store-grid">
                  {(
                    Object.entries(BUILDINGS) as [
                      BuildingType,
                      (typeof BUILDINGS)[BuildingType],
                    ][]
                  )
                    .filter(([, d]) => d.level <= w.level + 1)
                    .map(([type, d]) => (
                      <button
                        key={type}
                        className={`store-item ${w.level < d.level ? "locked" : ""}`}
                        disabled={w.level < d.level}
                        onClick={() => selectBuilding(type)}
                      >
                        <MiniArt type={type} />
                        <b>{d.name}</b>
                        <small>{d.tagline}</small>
                        <span>
                          {w.level < d.level ? (
                            <>
                              <Icon name="lock" size={12} /> Level {d.level}
                            </>
                          ) : (
                            <>
                              <Icon name="coin" size={14} /> {recipeText(type)}
                            </>
                          )}
                        </span>
                      </button>
                    ))}
                </div>
              </>
            )}
            {ui.panel === "goals" && (
              <>
                <h2>
                  Little things,
                  <br />
                  <em>lovely possibilities.</em>
                </h2>
                <p className="panel-intro">
                  Every small act makes your world a little bigger.
                </p>
                <div className="goal-list">
                  {QUESTS.map((q) => {
                    const done = w.completed.includes(q.id);
                    return (
                      <div
                        className={`goal-item ${done ? "done" : ""}`}
                        key={q.id}
                      >
                        <span className="goal-check">
                          <Icon name={done ? "check" : "leaf"} size={18} />
                        </span>
                        <div>
                          <b>{q.name}</b>
                          <p>{q.description}</p>
                          <progress
                            value={Math.min(q.value(w), q.target)}
                            max={q.target}
                          />
                          <small>
                            {done
                              ? "Complete"
                              : `${Math.floor(Math.min(q.value(w), q.target))} / ${q.target}`}
                            <span>
                              +{q.reward} XP · {q.gold} gold
                            </span>
                          </small>
                        </div>
                      </div>
                    );
                  })}
                </div>
                <button
                  className="text-button"
                  onClick={() => panel("discoveries")}
                >
                  Open the discoveries journal →
                </button>
              </>
            )}
            {ui.panel === "followers" && (
              <>
                <h2>Your little people.</h2>
                <p className="panel-intro">
                  Tap a name to meet them. Drag a believer onto a building to
                  give them a purpose.
                </p>
                {w.followers.map((f) => (
                  <button
                    className="follower-row"
                    key={f.id}
                    onClick={() => {
                      useGame.setState({
                        selected: { kind: "follower", id: f.id },
                        panel: null,
                      });
                      view.current?.focus(f.angle);
                    }}
                  >
                    <span className={`portrait small coat-${f.appearance}`}>
                      <i />
                      <b />
                    </span>
                    <span>
                      <b>{f.name}</b>
                      <small>
                        {!f.alive
                          ? "Resting in peace"
                          : f.faith < 50
                            ? "Curious inhabitant"
                            : f.task}
                      </small>
                    </span>
                    <Icon name="chevron" size={17} />
                  </button>
                ))}
              </>
            )}
            {selectedFollower && (
              <FollowerPanel
                f={selectedFollower}
                w={w}
                onFocus={() => view.current?.focus(selectedFollower.angle)}
              />
            )}
            {selectedBuilding && (
              <BuildingPanel
                b={selectedBuilding}
                w={w}
                onFocus={() => view.current?.focus(selectedBuilding.angle)}
              />
            )}
            {ui.panel === "discoveries" && (
              <>
                <h2>A world of discovery.</h2>
                <p className="panel-intro">
                  Your planet remembers the wonders you make.
                </p>
                <div className="discovery-summary">
                  <Icon name="spark" size={32} />
                  <b>{w.discoveries.length}</b>
                  <span>little discoveries</span>
                </div>
                {w.discoveries.map((d) => (
                  <div className="journal-entry" key={d}>
                    <Icon name="leaf" />
                    <b>{d}</b>
                  </div>
                ))}
                {!w.discoveries.length && (
                  <p>
                    Try sunshine after rain. Some wonders take a little
                    experimentation.
                  </p>
                )}
                <h3>From the planet's diary</h3>
                <div className="diary">
                  {w.log.map((line, i) => (
                    <p key={i}>{line}</p>
                  ))}
                </div>
              </>
            )}
            {ui.panel === "help" && (
              <>
                <h2>
                  A gentle guide
                  <br />
                  to playing god.
                </h2>
                <div className="help-copy">
                  <h3>Make a believer</h3>
                  <p>
                    Choose Rain, then tap the grass near Pip. A gentle miracle
                    earns faith. Choose Sunshine after rain to discover a
                    rainbow.
                  </p>
                  <h3>Watch your believers find their purpose</h3>
                  <p>
                    Open Resources to gather wood, then build a logging camp
                    beside the forest. Make a farm with your next logs.
                    Believers automatically find useful work. You can also
                    assign or drag them to a workplace. Once complete, rain
                    charges a farm for three minutes. Its harvest appears above
                    the roof; tap to collect.
                  </p>
                  <h3>A little rest goes a long way</h3>
                  <p>
                    Farms turn stored water into food; a dry farm grows slowly.
                    Rain collectors catch local miracles, and ponds supply
                    water. Hungry followers eat from settlement storage. Working
                    costs energy. Build a tent for recovery. With autonomy
                    enabled, tired workers rest and return to work
                    automatically.
                  </p>
                  <h3>Shape your world</h3>
                  <p>
                    Drag empty space to rotate all 360°. Scroll or pinch to
                    zoom. Use the globe for an overview. From level 1, raise,
                    and lower terrain. Smooth unlocks at level 2. Rain can fill
                    low valleys.
                  </p>
                  <h3>Clouds you can hold</h3>
                  <p>
                    Drag a cloud or the sun toward the grass to cast. In classic
                    mode, hold for half a second before swiping down.
                  </p>
                  <h3>Keyboard</h3>
                  <p>
                    R rain · S sunshine · T raise · F fire
                    <br />
                    1–8 powers · ← → rotate · H home
                    <br />
                    Space pause · Escape cancel
                  </p>
                  <h3>Progress lives here</h3>
                  <p>
                    Your browser saves this world every 10 seconds. Export a
                    backup in Settings to keep it elsewhere. Private browsing
                    may clear saves.
                  </p>
                </div>
              </>
            )}
            {ui.panel === "settings" && (
              <>
                <h2>A moment of calm.</h2>
                <div className="status-line" aria-label="Game build version">
                  <span>Version</span>
                  <b>
                    v{GAME_VERSION} · {GAME_BUILD}
                  </b>
                </div>
                <div className="settings-content">
                  <label className="field-label">
                    Planet name
                    <input
                      value={planetName}
                      maxLength={24}
                      onChange={(e) => setPlanetName(e.target.value)}
                      onBlur={() => {
                        w.name = planetName.trim() || "Clover";
                        setPlanetName(w.name);
                        ui.refresh();
                      }}
                    />
                  </label>
                  <button
                    className="primary-button"
                    onClick={() => useGame.setState({ paused: !ui.paused })}
                  >
                    <Icon name={ui.paused ? "play" : "pause"} size={17} />
                    {ui.paused ? "Resume world" : "Pause world"}
                  </button>
                  {(
                    [
                      ["sound", "Gentle sound effects"],
                      ["classic", "Classic hold-and-swipe gestures"],
                      ["autonomy", "Followers rest and return automatically"],
                      ["seasons", "Changing seasons"],
                      ["events", "Occasional world events"],
                      ["reduced", "Reduce animated effects"],
                      ["debug", "Show simulation details"],
                    ] as const
                  ).map(([key, label]) => (
                    <label className="toggle-row" key={key}>
                      <span>{label}</span>
                      <input
                        type="checkbox"
                        checked={w.settings[key]}
                        onChange={(e) => setting(key, e.target.checked)}
                      />
                    </label>
                  ))}
                  <label className="toggle-row">
                    <span>Simulation speed</span>
                    <select
                      value={w.settings.speed}
                      onChange={(e) => setting("speed", Number(e.target.value))}
                    >
                      <option value={1}>1× · gentle</option>
                      <option value={2}>2× · lively</option>
                      <option value={4}>4× · testing</option>
                    </select>
                  </label>
                  <div className="save-box">
                    <Icon name="leaf" size={19} />
                    <span>{ui.saveStatus}</span>
                  </div>
                  <div className="button-pair">
                    <button onClick={() => void persist(w)}>Save now</button>
                    <button
                      onClick={() =>
                        download(
                          "tiny-deity-save.json",
                          protectedBackup || serialize(w),
                        )
                      }
                    >
                      Export save
                    </button>
                  </div>
                  <button
                    className="text-button"
                    onClick={() => file.current?.click()}
                  >
                    Import a saved world →
                  </button>
                  <input
                    ref={file}
                    type="file"
                    accept=".json,application/json"
                    hidden
                    onChange={async (e) => {
                      const input = e.currentTarget,
                        uploaded = input.files?.[0];
                      if (!uploaded) return;
                      try {
                        if (uploaded.size > 2000000)
                          throw new Error("This file is too large.");
                        const imported = deserialize(await uploaded.text());
                        saveBlocked = false;
                        protectedBackup = null;
                        useGame.setState({
                          world: imported,
                          selected: null,
                          placing: null,
                          moving: null,
                          tool: "hand",
                        });
                        setPlanetName(imported.name);
                        view.current?.home();
                        void persist(imported);
                        message("Your little world has returned.");
                      } catch (err) {
                        message(
                          err instanceof Error
                            ? err.message
                            : "Could not read this save.",
                        );
                      }
                      input.value = "";
                    }}
                  />
                  <div className="settings-divider" />
                  {resetAsk ? (
                    <div className="reset-confirm">
                      <p>
                        This replaces your current world. Export a backup first
                        if you want to keep it.
                      </p>
                      <button onClick={() => reset()}>Start fresh</button>
                      <button onClick={() => reset(true)}>
                        Load developed demo
                      </button>
                      <button onClick={() => setResetAsk(false)}>
                        Keep this world
                      </button>
                    </div>
                  ) : (
                    <button
                      className="text-button"
                      onClick={() => setResetAsk(true)}
                    >
                      New world / developed demo →
                    </button>
                  )}
                  <a
                    href="../"
                    className="text-button"
                    style={{ display: "block", minHeight: 44 }}
                  >
                    ← All projects
                  </a>
                  <p className="version-note">
                    Tiny Deity · World first V3
                    <br />
                    Original procedural art. No accounts. Just a little world.
                  </p>
                </div>
              </>
            )}
          </aside>
        )}
        {w.settings.debug && (
          <div className="debug">
            {Math.round(view.current?.fps || 0)} FPS · tick {w.tick}
            <br />
            {w.followers.length} followers · {w.buildings.length} buildings
            <br />
            Effects {w.effects.length} · ≤{w.effects.length * 55} particles
            <br />
            Rotation {view.current?.camera.rotation.toFixed(2)} · Zoom{" "}
            {view.current?.camera.zoom.toFixed(2)}
            <br />
            Radius {w.radius} · Terrain v{w.terrainVersion}
            <br />~{260 + w.followers.length + w.buildings.length} sprites
          </div>
        )}
        <div className="bottom-ui">
          {tray && (
            <div className="context-tray" aria-label={`${tray} controls`}>
              <button
                className="tray-close"
                aria-label="Close tray"
                onClick={() => setTray(null)}
              >
                ×
              </button>
              {tray !== "more" ? (
                <>
                  <div className="tray-actions">
                    {(
                      Object.entries(POWERS) as [
                        Power,
                        (typeof POWERS)[Power],
                      ][]
                    )
                      .filter(([power]) =>
                        tray === "terrain"
                          ? ["raise", "lower", "smooth"].includes(power)
                          : ["rain", "sun"].includes(power),
                      )
                      .map(([power, d]) => (
                        <button
                          key={power}
                          className={ui.tool === power ? "chosen" : ""}
                          aria-label={`${d.name}${w.level < d.level ? ` (level ${d.level})` : ""}`}
                          aria-pressed={ui.tool === power}
                          onClick={() => setPower(power)}
                        >
                          <Icon name={d.icon} />
                          <span>{d.name.replace(" land", "")}</span>
                          <small>
                            {w.level < d.level
                              ? `Lv ${d.level}`
                              : `${d.cost} mana`}
                          </small>
                        </button>
                      ))}
                  </div>
                  {tray === "terrain" && (
                    <div
                      className="brush-sizes"
                      role="group"
                      aria-label="Brush size"
                    >
                      {[
                        ["Small", 0.09],
                        ["Medium", 0.14],
                        ["Large", 0.22],
                      ].map(([name, size]) => (
                        <button
                          key={name}
                          aria-pressed={ui.brush === size}
                          onClick={() =>
                            useGame.setState({ brush: Number(size) })
                          }
                        >
                          {name}
                        </button>
                      ))}
                    </div>
                  )}
                </>
              ) : (
                <div className="more-grid">
                  <button
                    onClick={() => panel("followers")}
                    aria-label={`${w.followers.length} followers · curious souls`}
                  >
                    <Icon name="people" />
                    Followers
                  </button>
                  <button onClick={() => panel("resources")}>
                    <Icon name="wood" />
                    Resources
                  </button>
                  <button onClick={() => panel("goals")}>
                    <Icon name="book" />
                    Objectives
                  </button>
                  <button onClick={() => panel("discoveries")}>
                    <Icon name="spark" />
                    Journal
                  </button>
                  <button onClick={() => panel("help")}>
                    <Icon name="help" />
                    Help
                  </button>
                  {(Object.entries(POWERS) as [Power, (typeof POWERS)[Power]][])
                    .filter(([power]) =>
                      ["lightning", "fire", "resurrect"].includes(power),
                    )
                    .map(([power, d]) => (
                      <button
                        key={power}
                        onClick={() => {
                          setPower(power);
                          setTray(null);
                        }}
                        aria-label={d.name}
                      >
                        <Icon name={d.icon} />
                        {d.name}
                        <small>
                          {w.level < d.level
                            ? `Lv ${d.level}`
                            : `${d.cost} mana`}
                        </small>
                      </button>
                    ))}
                </div>
              )}
            </div>
          )}
          <nav className="action-bar" aria-label="Primary actions">
            <button
              aria-label="Hand tool"
              aria-pressed={
                ui.tool === "hand" && !ui.placing && !ui.moving && !tray
              }
              onClick={() => {
                setPower("hand");
                setTray(null);
              }}
            >
              <Icon name="hand" />
              <span>Explore</span>
            </button>
            <button
              aria-label="Terrain"
              className={
                ["raise", "lower", "smooth"].includes(ui.tool)
                  ? "active-mode"
                  : ""
              }
              aria-expanded={tray === "terrain"}
              onClick={() => {
                setPower("raise");
                setTray(tray === "terrain" ? null : "terrain");
              }}
            >
              <Icon name="raise" />
              <span>Terrain</span>
            </button>
            <button
              aria-label="Weather"
              className={["rain", "sun"].includes(ui.tool) ? "active-mode" : ""}
              aria-expanded={tray === "weather"}
              onClick={() => {
                setPower("rain");
                setTray(tray === "weather" ? null : "weather");
              }}
            >
              <Icon name="rain" />
              <span>Weather</span>
            </button>
            <button
              aria-label="Build something"
              className={ui.placing || ui.moving ? "active-mode" : ""}
              aria-expanded={ui.panel === "store"}
              onClick={() => panel("store")}
            >
              <Icon name="build" />
              <span>Build</span>
            </button>
            <button
              aria-label="More"
              aria-expanded={tray === "more"}
              onClick={() => {
                close();
                setTray(tray === "more" ? null : "more");
              }}
            >
              <Icon name="book" />
              <span>More</span>
            </button>
          </nav>
        </div>
      </section>
      {levelUp > 0 && (
        <div className="modal-backdrop">
          <div
            className="level-modal"
            role="dialog"
            aria-modal="true"
            aria-label="Level up"
          >
            <Icon name="spark" size={50} />
            <span className="overline">A LITTLE MORE WONDER</span>
            <h2>Level {levelUp}</h2>
            <p>
              {UNLOCKS[levelUp] ||
                "More mana, a new inhabitant, and endless possibilities."}
            </p>
            <div>+2 Awe · Mana restored · A new little soul</div>
            <button className="primary-button" onClick={() => setLevelUp(0)}>
              Keep growing <Icon name="leaf" size={18} />
            </button>
          </div>
        </div>
      )}
    </main>
  );
}
function FollowerPanel({
  f,
  w,
  onFocus,
}: {
  f: Follower;
  w: World;
  onFocus: () => void;
}) {
  const believer = f.faith >= 50;
  return (
    <>
      <div className={`portrait coat-${f.appearance}`}>
        <i />
        <b />
      </div>
      <span className="overline">
        {f.alive
          ? believer
            ? "A DEVOTED LITTLE SOUL"
            : "A CURIOUS LITTLE SOUL"
          : "A LITTLE SOUL TO REMEMBER"}
      </span>
      <h2>
        {f.name}
        <span className="trait-badge">{f.trait}</span>
      </h2>
      <p className="panel-intro">
        {!f.alive
          ? "Their story is not over. A resurrection miracle brings them back."
          : !believer
            ? "“Is someone up there? A little rain would be lovely.”"
            : f.energy < 20
              ? "“I think I need a little lie-down.”"
              : f.task === "worshipping"
                ? "“For you, a little faith.”"
                : "“What shall we make of today?”"}
      </p>
      <Meter label="Energy" value={f.energy} />
      <Meter label="Hunger" value={f.hunger} color="gold" />
      <Meter label="Happiness" value={f.happiness} color="gold" />
      <Meter label="Faith" value={f.faith} color="lavender" />
      <Meter label="Comfort" value={f.comfort} />
      <div className="status-line">
        <span>Right now</span>
        <b>{f.task}</b>
      </div>
      <div className="status-line">
        <span>Proficiency</span>
        <b>{Math.floor(f.proficiency)}</b>
      </div>
      {f.alive && (
        <>
          <h3>A little purpose</h3>
          {!believer && (
            <button
              className="primary-button"
              onClick={() =>
                action(
                  cast(w, "rain", f.angle),
                  "A little rain, a little faith.",
                )
              }
            >
              <Icon name="rain" size={18} /> Rain on {f.name} · 1 mana
            </button>
          )}
          {believer && (
            <>
              <label className="field-label">
                Assign to a place
                <select
                  aria-label="Assign follower to building"
                  value={f.assigned || ""}
                  onChange={(e) =>
                    action(
                      assign(w, f.id, e.target.value || null),
                      "A new little purpose.",
                    )
                  }
                >
                  <option value="">Free to wander</option>
                  {w.buildings.map((b) => (
                    <option key={b.id} value={b.id}>
                      {BUILDINGS[b.type].name}
                      {b.construction < 1 ? " · build" : ""} ·{" "}
                      {
                        w.followers.filter(
                          (f) => f.alive && f.assigned === b.id,
                        ).length
                      }
                      /{BUILDINGS[b.type].capacity + b.upgrade - 1}
                    </option>
                  ))}
                </select>
              </label>
              <button
                className="secondary-button"
                onClick={() => {
                  if (w.awe < 1) {
                    message("You need 1 Awe. Complete goals or level up.");
                    return;
                  }
                  w.awe--;
                  f.energy = 100;
                  f.happiness = Math.min(100, f.happiness + 10);
                  useGame.getState().refresh();
                }}
              >
                Restore energy · 1 Awe
              </button>
            </>
          )}
        </>
      )}
      {!f.alive && (
        <button
          className="primary-button"
          onClick={() =>
            action(cast(w, "resurrect", f.angle), "A second little chance.")
          }
        >
          <Icon name="heart" size={18} /> Resurrect · 4 mana
        </button>
      )}
      <button className="text-button" onClick={onFocus}>
        Find {f.name} on the planet →
      </button>
    </>
  );
}
function BuildingPanel({
  b,
  w,
  onFocus,
}: {
  b: Building;
  w: World;
  onFocus: () => void;
}) {
  const def = BUILDINGS[b.type],
    workers = w.followers.filter((f) => f.alive && f.assigned === b.id);
  return (
    <>
      <div className="building-portrait">
        <MiniArt type={b.type} />
      </div>
      <span className="overline">
        LEVEL {b.upgrade} ·{" "}
        {b.construction < 1
          ? "UNDER CONSTRUCTION"
          : def.role === "produce"
            ? "A LITTLE INDUSTRY"
            : def.role === "rest"
              ? "A LITTLE COMFORT"
              : "A LITTLE WONDER"}
      </span>
      <h2>{def.name}</h2>
      <p className="panel-intro">{def.tagline}</p>
      {["logging", "mine", "collector", "farm", "fishing"].includes(b.type) && (
        <div className="industry-detail">
          <b>
            {b.type === "logging"
              ? "Forest harvest"
              : b.type === "mine"
                ? "Stone extraction"
                : b.type === "collector"
                  ? "Rain & pond collection"
                  : "Food production"}
          </b>
          <p>
            {b.type === "logging"
              ? `${Math.floor(nearby(w, b.angle).reduce((n, t) => n + (t.vegetation > 0.2 ? t.wood : 0), 0))} harvestable wood nearby · 3 wood per cycle`
              : b.type === "mine"
                ? `${Math.floor(nearby(w, b.angle).reduce((n, t) => n + t.stone, 0))} stone remaining nearby · 3 stone per cycle`
                : b.type === "collector"
                  ? "8 water per local rain miracle · 2.4/min from a nearby pond"
                  : b.type === "fishing"
                    ? "5 food per cycle from a nearby lake · No stored water consumed"
                    : `5 food per watered cycle · 1 water used · ${Math.floor(w.resources.water)} water stored`}
          </p>
          <Meter label="Work cycle" value={b.progress * 100} />
        </div>
      )}
      {b.construction < 1 ? (
        <>
          <Meter label="Construction" value={b.construction * 100} />
          <p className="panel-intro">
            Believers will help build here when autonomy is enabled. You can
            also assign a worker.
          </p>
          <button
            className="secondary-button"
            onClick={() => {
              if (w.awe < 2) {
                message("You need 2 Awe.");
                return;
              }
              w.awe -= 2;
              b.construction = 1;
              w.stats.built++;
              useGame.getState().refresh();
            }}
          >
            Finish instantly · 2 Awe
          </button>
        </>
      ) : (
        <>
          {def.output > 0 && (
            <>
              <Meter
                label="Harvest progress"
                value={b.progress * 100}
                color="gold"
              />
              <div className="status-line">
                <span>Per cycle</span>
                <b>
                  {Math.round(def.output * (1 + (b.upgrade - 1) * 0.35))} gold ·{" "}
                  {def.duration}s
                </b>
              </div>
              <button
                className="primary-button"
                disabled={!b.stored}
                onClick={() => {
                  const gold = collect(w, b.id);
                  message(`A golden little harvest. +${gold} gold`);
                  useGame.getState().refresh();
                }}
              >
                <Icon name="coin" size={18} />
                {b.stored ? `Collect ${b.stored} gold` : "A harvest is growing"}
              </button>
            </>
          )}
          {def.need && b.type !== "farm" && (
            <div className="status-line">
              <span>
                {def.need === "water"
                  ? "Needs a nearby lake"
                  : `Powered by ${def.need}`}
              </span>
              <b>
                {def.need === "water"
                  ? "Lakeside"
                  : b.charge > 0
                    ? `${Math.ceil(b.charge)}s left`
                    : "Needs a miracle"}
              </b>
            </div>
          )}
          {(def.need === "rain" || def.need === "sun") && (
            <button
              className="secondary-button"
              onClick={() =>
                action(
                  cast(w, def.need as Power, b.angle),
                  "A little power for your place.",
                )
              }
            >
              <Icon name={def.need} size={17} />
              {def.need === "rain"
                ? "Water this building"
                : "Warm this building"}{" "}
              · 1 mana
            </button>
          )}
        </>
      )}
      <h3>
        Little helping hands{" "}
        <small>
          {workers.length}/{def.capacity + b.upgrade - 1}
        </small>
      </h3>
      {workers.map((f) => (
        <button
          className="assigned-follower"
          key={f.id}
          onClick={() =>
            useGame.setState({ selected: { kind: "follower", id: f.id } })
          }
        >
          <Icon name="people" size={16} />
          {f.name}
          <small>{Math.round(f.energy)}% energy</small>
        </button>
      ))}
      <select
        aria-label="Assign available follower"
        value=""
        onChange={(e) => {
          if (e.target.value)
            action(
              assign(w, e.target.value, b.id),
              "A little helper is on the way.",
            );
        }}
      >
        <option value="">+ Assign a believer…</option>
        {w.followers
          .filter((f) => f.alive && f.faith >= 50 && f.assigned !== b.id)
          .map((f) => (
            <option value={f.id} key={f.id}>
              {f.name} · {f.task}
            </option>
          ))}
      </select>
      <Meter label="Condition" value={b.durability} />
      {b.construction >= 1 && b.upgrade < 4 && (
        <button
          className="secondary-button"
          onClick={() =>
            action(upgrade(w, b.id), "A lovely little improvement.")
          }
        >
          <Icon name="build" size={16} /> Upgrade ·{" "}
          {Math.round(def.cost * 0.65 * b.upgrade)} gold ·{" "}
          {RECIPES[b.type].wood * 0.5 * b.upgrade} wood ·{" "}
          {RECIPES[b.type].stone * 0.5 * b.upgrade} stone
        </button>
      )}
      {b.durability < 100 && (
        <button
          className="secondary-button"
          onClick={() => {
            if (w.gold < 20) {
              message("You need 20 gold.");
              return;
            }
            w.gold -= 20;
            b.durability = 100;
            useGame.getState().refresh();
          }}
        >
          Repair · 20 gold
        </button>
      )}
      <button className="text-button" onClick={onFocus}>
        Find this place →
      </button>
      <div className="button-pair">
        <button
          onClick={() =>
            useGame.setState({
              moving: b.id,
              placing: null,
              selected: null,
              tool: "hand",
            })
          }
        >
          Move
        </button>
        <button
          onClick={() => {
            salvage(w, b);
            w.buildings = w.buildings.filter((v) => v.id !== b.id);
            w.followers.forEach((f) => {
              if (f.assigned === b.id) assign(w, f.id, null);
            });
            note(
              w,
              `${def.name} reclaimed. Gold and half the materials returned.`,
            );
            useGame.setState({ selected: null });
          }}
        >
          Reclaim · 35% gold + 50% materials
        </button>
      </div>
    </>
  );
}
