(function () {
  "use strict";

  const API_ROOT = "https://ddragon.leagueoflegends.com/cdn";
  const cache = new Map();
  let roster = [];
  let activeVersion = "16.16.1";

  const slotNames = ["Q", "W", "E", "R"];
  const ccPattern = /stun|root|snare|knock(?:s|ed|ing)? (?:up|back|aside)|airborne|charm|fear|flee|taunt|suppress|sleep|silenc|pulls? (?:the|all|an|enemy)|immobili/i;
  const slowPattern = /\bslow(?:s|ed|ing)?\b/i;
  const mobilityPattern = /\bdash(?:es|ed|ing)?\b|\bblink\b|\bleap(?:s|ed|ing)?\b|\bjump(?:s|ed|ing)?\b|teleports? (?:to|toward)|lunges? (?:to|toward)|charges? (?:to|toward)/i;
  const sustainPattern = /\bheal(?:s|ed|ing)?\b|restores? (?:his|her|their|health)|health (?:restored|regeneration)|life steal|omnivamp/i;
  const shieldPattern = /\bshield(?:s|ed|ing)?\b/i;
  const stealthPattern = /camouflage|invisible|invisibility|stealth|obscured/i;

  function clean(value) {
    const holder = document.createElement("div");
    holder.innerHTML = String(value || "")
      .replace(/<br\s*\/?>/gi, " ")
      .replace(/\{\{[^}]+\}\}/g, "a scaling value");
    return (holder.textContent || "").replace(/\s+/g, " ").trim();
  }

  function sentence(value, max = 230) {
    const text = clean(value);
    if (text.length <= max) return text;
    const shortened = text.slice(0, max);
    const stop = Math.max(shortened.lastIndexOf("."), shortened.lastIndexOf(";"));
    return `${shortened.slice(0, stop > max * 0.55 ? stop + 1 : max).trim()}…`;
  }

  function shuffle(values) {
    const result = [...values];
    for (let index = result.length - 1; index > 0; index -= 1) {
      const swap = Math.floor(Math.random() * (index + 1));
      [result[index], result[swap]] = [result[swap], result[index]];
    }
    return result;
  }

  function unique(values) {
    return [...new Set(values.filter(Boolean))];
  }

  function spellSummary(spell) {
    return sentence(spell.description || spell.tooltip || "No description available.");
  }

  function fullKitText(champion) {
    return [champion.passive?.description, ...champion.spells.flatMap(spell => [spell.description, spell.tooltip])]
      .map(clean)
      .join(" ");
  }

  function rangeProfile(champion) {
    const range = Number(champion.stats?.attackrange || 0);
    if (range >= 525) return {label:"Ranged", detail:"Expect ranged basic-attack pressure. Use cover, spacing, and last-hit timing to avoid taking free damage."};
    if (range >= 350) return {label:"Short ranged", detail:"They can basic attack from outside normal melee range, but their shorter reach still creates punish windows."};
    return {label:"Melee", detail:"Their basic attacks require close range. Track the spell, dash, or crowd control they use to get access."};
  }

  function damageProfile(champion) {
    const text = [champion.passive?.description, ...champion.spells.map(spell => spell.tooltip || spell.description)].map(clean).join(" ").toLowerCase();
    const count = word => (text.match(new RegExp(`\\b${word} damage\\b`, "g")) || []).length;
    const physical = count("physical");
    const magic = count("magic");
    const trueDamage = count("true");
    const tags = champion.tags || [];

    if (trueDamage > 0 && (physical > 0 || magic > 0)) {
      return {label:"Mixed / true damage", defense:"Prioritize health, the defense matching their other major damage source, and positioning that prevents a full combo. True damage itself is not reduced by armor or magic resistance."};
    }
    if (physical > magic || (tags.includes("Marksman") && magic <= physical)) {
      return {label:tags.includes("Marksman") ? "Mostly physical sustained damage" : "Mostly physical damage", defense:"Armor and health are the default defensive stats, but first check who is actually fed and whether their threat is burst or repeated attacks."};
    }
    if (magic > physical || tags.includes("Mage")) {
      return {label:"Mostly magic damage", defense:"Magic resistance and health are the default defensive stats. A spell shield or stasis can be stronger when one key spell starts the entire sequence."};
    }
    return {label:"Variable damage profile", defense:"Inspect their items and the actual damage recap before committing to one resistance. Health and effect-based defenses are safer against uncertain or mixed profiles."};
  }

  function tacticalProfile(champion) {
    const text = fullKitText(champion);
    const range = rangeProfile(champion);
    const damage = damageProfile(champion);
    const flags = {
      hardCC:ccPattern.test(text),
      slow:slowPattern.test(text),
      mobility:mobilityPattern.test(text),
      sustain:sustainPattern.test(text),
      shield:shieldPattern.test(text),
      stealth:stealthPattern.test(text)
    };
    const threats = [];
    if (flags.hardCC) threats.push("hard crowd control");
    else if (flags.slow) threats.push("slows or zone control");
    if (flags.mobility) threats.push("mobility or gap closing");
    if (flags.sustain) threats.push("healing or fight reset");
    if (flags.shield) threats.push("shielding");
    if (flags.stealth) threats.push("stealth or concealment");
    if (!threats.length) threats.push("damage timing and spacing");

    const tags = champion.tags || [];
    let plan = "Watch their most important cooldown, keep a safe exit, and trade when that cooldown is unavailable.";
    if (tags.includes("Assassin")) plan = "Expect a burst window from fog or a side angle. Preserve peel or a defensive cooldown for their committed access spell.";
    else if (tags.includes("Marksman")) plan = "Expect repeated ranged damage. Do not give them a long, uninterrupted front-to-back fight; use cover, engage timing, or coordinated flanks.";
    else if (tags.includes("Tank")) plan = "Expect them to start or absorb a fight. Space their crowd control and decide whether you can reach a carry instead of spending everything on the tank.";
    else if (tags.includes("Mage")) plan = "Expect spell-based pressure. Track the cooldown or projectile that creates their safest follow-up and move after it misses.";
    else if (tags.includes("Fighter")) plan = "Expect strong close-range or extended fighting. Shorten the trade, kite key cooldowns, and avoid contesting their best fully committed window.";
    else if (tags.includes("Support")) plan = "Expect ally setup or protection. Track whether their strongest spell enables an engage or denies yours.";

    return {range, damage, flags, threats, plan};
  }

  function question(base) {
    return {
      freshness:"live",
      hint:"Use the champion's kit, not their reputation.",
      takeaway:"Recognize the spell, then connect it to the decision it forces.",
      ...base
    };
  }

  function abilityQuestions(champion) {
    const abilities = [
      {slot:"P", name:champion.passive.name, description:spellSummary(champion.passive)},
      ...champion.spells.map((spell, index) => ({slot:slotNames[index], name:spell.name, description:spellSummary(spell), spell}))
    ];
    const names = abilities.map(ability => ability.name);
    const descriptions = abilities.map(ability => ability.description);
    const generated = [];

    abilities.forEach((ability, index) => {
      generated.push(question({
        id:`${champion.id}-identify-${ability.slot}`,
        champion:champion.name,
        category:"abilities",
        level:"easy",
        abilitySlot:ability.slot,
        context:`You are scouting ${champion.name}'s ${ability.slot === "P" ? "passive" : `${ability.slot} ability`} before loading in.`,
        prompt:`Which ${champion.name} ability matches this effect: “${ability.description}”`,
        options:shuffle([ability.name, ...shuffle(names.filter(name => name !== ability.name)).slice(0, 3)]),
        answer:ability.name,
        hint:`It is ${ability.slot === "P" ? "the passive" : `bound to ${ability.slot} by default`}.`,
        explanation:`${ability.slot} — ${ability.name}: ${ability.description}`,
        takeaway:`When ${ability.name} is used, connect its visible cue to the effect it creates.`
      }));

      generated.push(question({
        id:`${champion.id}-slot-${ability.slot}`,
        champion:champion.name,
        category:"abilities",
        level:index === 4 ? "easy" : "hard",
        abilitySlot:ability.slot,
        context:`${champion.name} casts ${ability.name}.`,
        prompt:`What slot is ${ability.name}?`,
        options:shuffle(unique([ability.slot, "P", "Q", "W", "E", "R"]).slice(0, 4)),
        answer:ability.slot,
        hint:"Separate the passive from the four castable abilities.",
        explanation:`${ability.name} is ${champion.name}'s ${ability.slot === "P" ? "passive" : `${ability.slot} ability`}. ${ability.description}`,
        takeaway:`Fast slot recognition makes cooldown tracking and teammate callouts much easier.`
      }));
    });

    champion.spells.forEach((spell, index) => {
      const cooldown = clean(spell.cooldownBurn);
      const resource = clean(spell.resource).replace(/a scaling value/g, clean(spell.costBurn) || "its listed cost");
      if (cooldown) generated.push(question({
        id:`${champion.id}-cooldown-${slotNames[index]}`,
        champion:champion.name,
        category:"counterplay",
        level:"hard",
        abilitySlot:slotNames[index],
        context:`You are tracking ${champion.name}'s ${spell.name} without assuming ability haste.`,
        prompt:"What base cooldown sequence does Riot's current static data list?",
        options:shuffle(unique([cooldown, ...champion.spells.map(other => clean(other.cooldownBurn)).filter(value => value && value !== cooldown)]).slice(0, 4)),
        answer:cooldown,
        hint:`Check ${slotNames[index]}, then remember items can shorten the real in-game cooldown.`,
        explanation:`${spell.name} lists a base cooldown of ${cooldown} seconds by rank in Data Dragon ${activeVersion}. Ability haste and special resets can change the practical window.`,
        takeaway:"Use base cooldown knowledge as a starting estimate, then adjust for rank, haste, and resets."
      }));
      if (resource && resource !== "No Cost") generated.push(question({
        id:`${champion.id}-resource-${slotNames[index]}`,
        champion:champion.name,
        category:"abilities",
        level:"hard",
        abilitySlot:slotNames[index],
        context:`${champion.name} repeatedly uses ${spell.name}.`,
        prompt:"What resource cost does the current static description show?",
        options:shuffle(unique([resource, "No Cost", "Uses only health", "Consumes every ultimate charge"]).slice(0, 4)),
        answer:resource,
        hint:"Resource constraints can create a punish window even before a cooldown does.",
        explanation:`Data Dragon ${activeVersion} lists the resource as: ${resource}.`,
        takeaway:"Watch both cooldowns and resources before deciding an opponent cannot answer your trade."
      }));
    });

    return generated.filter(item => item.options.includes(item.answer) && item.options.length >= 3);
  }

  function tacticalQuestions(champion) {
    const profile = tacticalProfile(champion);
    const crowdAnswer = profile.flags.hardCC
      ? "Yes—expect at least one hard crowd-control effect in the kit"
      : profile.flags.slow
        ? "Expect slows or control, but the static spell text does not identify hard CC"
        : "The static spell text does not identify a hard crowd-control effect";
    const mobilityAnswer = profile.flags.mobility
      ? "Yes—preserve spacing or peel for a dash, leap, blink, or similar access tool"
      : "No obvious dash or blink is identified; spacing and movement speed still matter";

    const result = [
      question({
        id:`${champion.id}-range-profile`, champion:champion.name, category:"threats", level:"easy",
        context:`${champion.name} walks into lane with a base attack range of ${champion.stats.attackrange}.`,
        prompt:"What type of basic-attack interaction should you expect?",
        options:shuffle([profile.range.detail,"They can only attack with abilities","Every basic attack is global","Their basic attacks always stun"]),
        answer:profile.range.detail,
        hint:`The base range points to a ${profile.range.label.toLowerCase()} pattern.`,
        explanation:`${profile.range.label}: ${profile.range.detail}`,
        takeaway:"Range tells you who can touch the wave or the opponent first; spells decide how that spacing changes."
      }),
      question({
        id:`${champion.id}-cc-profile`, champion:champion.name, category:"threats", level:"medium",
        context:`You are deciding whether ${champion.name} can lock you down for a teammate.`,
        prompt:"What should you expect from the current kit text?",
        options:shuffle([crowdAnswer,"Every ability is a guaranteed stun","They permanently ignore crowd control","Their crowd control works globally with no condition"]),
        answer:crowdAnswer,
        hint:"Look for roots, stuns, knockups, charms, fears, taunts, suppression, sleep, or silence.",
        explanation:`The official spell descriptions indicate ${profile.threats.join(", ")}. Conditions still matter: many effects require a hit, setup, channel, or specific target.`,
        takeaway:"Knowing that CC exists is step one; next learn its range, condition, and cooldown."
      }),
      question({
        id:`${champion.id}-mobility-profile`, champion:champion.name, category:"counterplay", level:"medium",
        context:`You are planning your escape before committing onto ${champion.name}.`,
        prompt:"Does the current kit text identify a mobility or gap-closing tool?",
        options:shuffle([mobilityAnswer,"They always have three untargetable dashes","They can teleport to any champion at level one","Movement tools never change a matchup"]),
        answer:mobilityAnswer,
        hint:"Access tools determine whether your current distance is actually safe.",
        explanation:`${mobilityAnswer}. Read the specific ability card after answering to learn its condition.`,
        takeaway:"Measure safety from the opponent's reachable space, not only their current position."
      }),
      question({
        id:`${champion.id}-fight-plan`, champion:champion.name, category:"counterplay", level:"hard",
        context:`The enemy has locked ${champion.name}, tagged by Riot as ${(champion.tags || []).join(" / ")}.`,
        prompt:"Which first-pass fight plan best respects that archetype?",
        options:shuffle([profile.plan,"Use every important cooldown before they enter range","Ignore their cooldowns and repeat the same trade","Stand still and decide only after their full combo lands"]),
        answer:profile.plan,
        hint:"Archetype gives you a starting hypothesis; the five ability cards give you the exact answer.",
        explanation:profile.plan,
        takeaway:"Use class as a first read, then refine the plan from the actual kit and build."
      }),
      question({
        id:`${champion.id}-damage-build`, champion:champion.name, category:"builds", level:"medium",
        context:`${champion.name} is the enemy carrying the fight. You need one defensive direction, not a copied full build.`,
        prompt:`Which adaptation best matches the detected ${profile.damage.label.toLowerCase()} profile?`,
        options:shuffle([profile.damage.defense,"Buy only damage because defensive components never change a duel","Choose resistance based only on your lane, even if another enemy is fed","Complete the same six items every match without checking inventories"]),
        answer:profile.damage.defense,
        hint:"Defend against the damage and sequence that is actually deciding the game.",
        explanation:`Detected profile: ${profile.damage.label}. ${profile.damage.defense}`,
        takeaway:"A defensive purchase is good when you can name the enemy sequence it lets you survive."
      })
    ];

    if (profile.flags.sustain) result.push(question({
      id:`${champion.id}-antiheal`, champion:champion.name, category:"builds", level:"hard",
      context:`${champion.name}'s kit contains a healing or health-restoration effect, and that sustain is repeatedly changing fights.`,
      prompt:"When is anti-heal a sound adaptation?",
      options:shuffle(["When the healing is materially deciding fights and your team can apply Grievous Wounds efficiently","Automatically as the first full item against any healing word","Only after everyone on your team buys the same effect","Never—champion healing cannot be reduced"]),
      answer:"When the healing is materially deciding fights and your team can apply Grievous Wounds efficiently",
      hint:"A detected heal is a reason to evaluate anti-heal, not an automatic shopping command.",
      explanation:"Anti-heal has an opportunity cost. Move it up when the healing is large, repeated, and fight-defining, then coordinate so the team has reliable coverage without needless duplication.",
      takeaway:"Buy utility for a measured problem, not merely because a keyword appeared."
    }));

    if (profile.flags.hardCC) result.push(question({
      id:`${champion.id}-cc-build`, champion:champion.name, category:"builds", level:"hard",
      context:`${champion.name}'s control keeps starting the losing sequence.`,
      prompt:"What is the most accurate defensive shopping rule?",
      options:shuffle(["Consider tenacity for affected effects, or a cleanse, spell shield, or stasis that specifically breaks the key sequence","Tenacity removes every suppression and knockup","Armor always shortens crowd control","Movement speed makes every targeted disable miss"]),
      answer:"Consider tenacity for affected effects, or a cleanse, spell shield, or stasis that specifically breaks the key sequence",
      hint:"Different control types interact with tenacity and cleanses differently.",
      explanation:"Tenacity does not solve every displacement or suppression. Identify the exact effect, then choose between shortening it, cleansing it, blocking its application, surviving its follow-up, or positioning outside it.",
      takeaway:"Counter the exact control sequence; do not treat all CC as interchangeable."
    }));

    return result;
  }

  const spotlights = {
    Akali:[
      question({
        id:"Akali-spotlight-fleet", champion:"Akali", category:"builds", level:"medium", freshness:"patch",
        context:"Akali enters lane with Fleet Footwork instead of a keystone centered on immediate burst.",
        prompt:"What plan is she most likely emphasizing, and what should your response be?",
        options:shuffle(["She is valuing sustain and safer lane access; keep pressure disciplined, deny free farm when safe, and itemize for her actual magic-damage threat—not for the rune itself","She has no damage and can never all-in","Rush anti-heal solely for one Fleet proc regardless of lane state","Stand in melee range because Fleet removes her mobility"]),
        answer:"She is valuing sustain and safer lane access; keep pressure disciplined, deny free farm when safe, and itemize for her actual magic-damage threat—not for the rune itself",
        hint:"Fleet changes how comfortably she reaches later levels; it does not replace the rest of Akali's kit.",
        explanation:"Fleet usually signals that Akali values lane sustain, movement, and access through early pressure. You can still punish cooldowns and wave position. Anti-heal is rarely justified by Fleet alone; MR, health, or a sequence-breaking defensive item answers her damage more directly when needed.",
        takeaway:"Read a rune as evidence of intent, then answer the champion's real win condition."
      })
    ],
    Nasus:[
      question({
        id:"Nasus-spotlight-stacks", champion:"Nasus", category:"threats", level:"easy",
        context:"You are laning against Nasus and the wave is safely reaching him over and over.",
        prompt:"What long-term threat should you expect?",
        options:shuffle(["Siphoning Strike grows as he last-hits with it, so uncontested farming makes his later melee threat stronger","His basic attack range permanently grows with every minion","Every minion lowers his ultimate cooldown to zero","He becomes a ranged marksman after level six"]),
        answer:"Siphoning Strike grows as he last-hits with it, so uncontested farming makes his later melee threat stronger",
        hint:"Watch which ability he uses to last-hit.",
        explanation:"Nasus gains permanent Siphoning Strike damage when it kills a unit. Early wave control, coordinated pressure, and denying safe stacks when your matchup permits are more important than repeatedly taking low-value trades that ruin the wave.",
        takeaway:"Against scaling stacks, judge your lane by denied resources and wave control—not only kills."
      }),
      question({
        id:"Nasus-spotlight-ultimate", champion:"Nasus", category:"counterplay", level:"medium",
        context:"Nasus activates Fury of the Sands and walks at you while Wither is available.",
        prompt:"What should you expect during this window?",
        options:shuffle(["A much stronger extended melee fight; kite the ultimate, preserve an answer to Wither, and re-engage after the power window when possible","A harmless visual effect with no combat impact","A long-range stun that cannot miss","His defenses fall, so every champion should stand and trade"]),
        answer:"A much stronger extended melee fight; kite the ultimate, preserve an answer to Wither, and re-engage after the power window when possible",
        hint:"Do not compare your normal trade to his empowered ultimate window.",
        explanation:"Fury of the Sands improves Nasus's durability and close-range threat while Wither makes disengaging harder. Creating distance and spending the duration safely is often better than proving you can fight him at his strongest.",
        takeaway:"Many matchups are won by refusing one temporary power window."
      })
    ]
  };

  async function fetchJson(url) {
    const response = await fetch(url);
    if (!response.ok) throw new Error(`Riot data request failed (${response.status})`);
    return response.json();
  }

  async function loadRoster(version) {
    activeVersion = version || activeVersion;
    const payload = await fetchJson(`${API_ROOT}/${activeVersion}/data/en_US/champion.json`);
    roster = Object.values(payload.data || {}).sort((a, b) => a.name.localeCompare(b.name));
    return roster;
  }

  async function loadChampion(id, version) {
    activeVersion = version || activeVersion;
    const key = `${activeVersion}:${id}`;
    if (cache.has(key)) return cache.get(key);
    const payload = await fetchJson(`${API_ROOT}/${activeVersion}/data/en_US/champion/${id}.json`);
    const champion = payload.data?.[id] || Object.values(payload.data || {})[0];
    if (!champion) throw new Error(`No champion data returned for ${id}`);
    cache.set(key, champion);
    return champion;
  }

  function makeQuestions(champion) {
    return [
      ...(spotlights[champion.name] || []),
      ...abilityQuestions(champion),
      ...tacticalQuestions(champion)
    ];
  }

  window.MatchupLab = {
    loadRoster,
    loadChampion,
    makeQuestions,
    tacticalProfile,
    clean,
    getRoster:() => roster,
    getVersion:() => activeVersion
  };
}());
