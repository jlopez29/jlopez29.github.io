// Riot Data Dragon static assets.
// 16.16.1 was the current Data Dragon release when this prototype was generated.
const DDRAGON_VERSION = "16.16.1";
const DDRAGON_BASE = `https://ddragon.leagueoflegends.com/cdn/${DDRAGON_VERSION}/img/champion/`;

const idOverrides = {
  "Jarvan IV":"JarvanIV",
  "Kai'Sa":"Kaisa",
  "LeBlanc":"Leblanc",
  "Lee Sin":"LeeSin",
  "Master Yi":"MasterYi",
  "Dr. Mundo":"DrMundo"
};

function champId(name) {
  return idOverrides[name] || name.replace(/[^A-Za-z0-9]/g, "");
}
function portrait(name) {
  return `${DDRAGON_BASE}${champId(name)}.png`;
}

const champions = [
  // TOP
  {name:"Ornn",role:"TOP",damage:"AP",tags:["frontline","engage","scaling","teamfight"],desc:"Tank engage and strong front-to-back teamfighting."},
  {name:"Malphite",role:"TOP",damage:"AP",tags:["frontline","engage","antiAD","teamfight"],desc:"Reliable hard engage, especially into physical-heavy teams."},
  {name:"Gwen",role:"TOP",damage:"AP",tags:["AP","scaling","dps","sideline"],desc:"Scaling AP damage and strong sustained damage into durable targets."},
  {name:"Fiora",role:"TOP",damage:"AD",tags:["AD","sideline","tankKiller","scaling"],desc:"Elite side-lane pressure and anti-tank dueling."},
  {name:"Shen",role:"TOP",damage:"AP",tags:["frontline","peel","global","antiDive"],desc:"Defensive utility, peel and cross-map protection."},
  {name:"Renekton",role:"TOP",damage:"AD",tags:["AD","frontline","early","dive"],desc:"Early pressure, setup and durable short-range dive."},
  {name:"Darius",role:"TOP",damage:"AD",tags:["AD","juggernaut","early","frontline"],desc:"Immobile juggernaut with brutal extended melee trades."},
  {name:"Quinn",role:"TOP",damage:"AD",tags:["AD","range","kite","early"],desc:"Ranged top laner that punishes immobile melee champions through spacing."},
  {name:"Sett",role:"TOP",damage:"AD",tags:["AD","frontline","engage","juggernaut"],desc:"Brawler with powerful short-range trades and counter-engage."},

  // JUNGLE
  {name:"Sejuani",role:"JUNGLE",damage:"AP",tags:["frontline","engage","peel","teamfight"],desc:"Frontline initiation and strong lockdown."},
  {name:"Jarvan IV",role:"JUNGLE",damage:"AD",tags:["AD","engage","dive","early"],desc:"Early ganks, hard engage and backline access."},
  {name:"Kindred",role:"JUNGLE",damage:"AD",tags:["AD","dps","range","scaling"],desc:"Ranged sustained damage and carry scaling from jungle."},
  {name:"Lillia",role:"JUNGLE",damage:"AP",tags:["AP","teamfight","dps","speed"],desc:"AP sustained damage with high-impact teamfight sleep."},
  {name:"Ivern",role:"JUNGLE",damage:"AP",tags:["peel","enchanter","antiDive","utility"],desc:"Shields, peel and protection for carry-centric teams."},
  {name:"Vi",role:"JUNGLE",damage:"AD",tags:["AD","engage","pick","dive"],desc:"Point-and-click access to a priority backliner."},
  {name:"Master Yi",role:"JUNGLE",damage:"AD",tags:["AD","dps","scaling","autoAttack"],desc:"Auto-attack reset carry that wants extended fights after enemy CC is gone."},
  {name:"Rammus",role:"JUNGLE",damage:"AP",tags:["frontline","antiAD","taunt","antiAuto"],desc:"Armor-heavy tank with a taunt that punishes auto-attack carries."},
  {name:"Lee Sin",role:"JUNGLE",damage:"AD",tags:["AD","early","mobility","dive"],desc:"Highly mobile early-game jungler built around dashes and tempo."},
  {name:"Poppy",role:"JUNGLE",damage:"AD",tags:["frontline","antiDash","peel","engage"],desc:"Tank whose Steadfast Presence can deny enemy dashes."},

  // MID
  {name:"Orianna",role:"MID",damage:"AP",tags:["AP","teamfight","scaling","utility"],desc:"Balanced AP control mage with excellent grouped fighting."},
  {name:"Ahri",role:"MID",damage:"AP",tags:["AP","pick","mobility","early"],desc:"Safe mobility and pick creation around objectives."},
  {name:"Viktor",role:"MID",damage:"AP",tags:["AP","scaling","zone","dps"],desc:"Scaling control mage with strong zone control and DPS."},
  {name:"Galio",role:"MID",damage:"AP",tags:["AP","frontline","peel","antiDive","engage"],desc:"Anti-dive protection with secondary engage."},
  {name:"Yasuo",role:"MID",damage:"AD",tags:["AD","dps","dive","combo"],desc:"Melee AD carry that loves knock-up engage."},
  {name:"Jayce",role:"MID",damage:"AD",tags:["AD","poke","range","siege"],desc:"Long-range physical poke and siege pressure."},
  {name:"Katarina",role:"MID",damage:"AP",tags:["AP","dive","reset","mobility"],desc:"Reset assassin that needs openings to channel damage in the middle of fights."},
  {name:"Zed",role:"MID",damage:"AD",tags:["AD","assassin","dive","mobility"],desc:"Physical assassin that commits through mark-based burst and shadow mobility."},
  {name:"Lissandra",role:"MID",damage:"AP",tags:["AP","antiDive","lockdown","selfPeel"],desc:"Point-and-click lockdown, self-ult safety and anti-assassin control."},

  // ADC
  {name:"Jinx",role:"ADC",damage:"AD",tags:["AD","dps","range","scaling","frontToBack"],desc:"Scaling front-to-back carry with reset potential."},
  {name:"Ezreal",role:"ADC",damage:"AD",tags:["AD","poke","safe","range"],desc:"Safe ranged poke with strong neutral-game pressure."},
  {name:"Kai'Sa",role:"ADC",damage:"Mixed",tags:["AD","dive","mobility","scaling"],desc:"Follow-up dive and flexible mixed damage."},
  {name:"Ashe",role:"ADC",damage:"AD",tags:["AD","engage","pick","utility","range"],desc:"Utility marksman with long-range initiation."},
  {name:"Samira",role:"ADC",damage:"AD",tags:["AD","dive","aoe","snowball"],desc:"Short-range all-in carry that wants heavy setup."},
  {name:"Xayah",role:"ADC",damage:"AD",tags:["AD","antiDive","dps","selfPeel"],desc:"Excellent self-peel and damage into champions running at her."},
  {name:"Draven",role:"ADC",damage:"AD",tags:["AD","early","snowball","shortTrade"],desc:"High-pressure lane carry that wants to cash in early kills."},
  {name:"Caitlyn",role:"ADC",damage:"AD",tags:["AD","range","poke","zone"],desc:"Long-range lane control with traps and strong siege pressure."},

  // SUPPORT
  {name:"Nautilus",role:"SUPPORT",damage:"AP",tags:["engage","frontline","pick","dive"],desc:"Reliable hard engage and pick setup."},
  {name:"Lulu",role:"SUPPORT",damage:"AP",tags:["peel","enchanter","antiDive","scaling"],desc:"Strong carry protection and anti-dive tools."},
  {name:"Braum",role:"SUPPORT",damage:"AP",tags:["peel","frontline","antiDive","teamfight"],desc:"Defensive frontline that excels when enemies must run into him."},
  {name:"Rakan",role:"SUPPORT",damage:"AP",tags:["engage","peel","mobility","teamfight"],desc:"Flexible engage with strong follow-up and escape."},
  {name:"Milio",role:"SUPPORT",damage:"AP",tags:["peel","enchanter","range","antiDive"],desc:"Range amplification, cleanse and carry protection."},
  {name:"Zyra",role:"SUPPORT",damage:"AP",tags:["AP","poke","zone","damage"],desc:"Adds magic damage, poke and objective zone control."},
  {name:"Blitzcrank",role:"SUPPORT",damage:"AP",tags:["pick","engage","hook"],desc:"Creates picks by landing a long-range hook on a priority target."},
  {name:"Morgana",role:"SUPPORT",damage:"AP",tags:["antiCC","peel","pick","AP"],desc:"Black Shield can deny key crowd control while binding punishes predictable engages."},
  {name:"Leona",role:"SUPPORT",damage:"AP",tags:["engage","frontline","lockdown"],desc:"Committed engage support with layered crowd control."},
  {name:"Janna",role:"SUPPORT",damage:"AP",tags:["peel","antiDive","disengage","enchanter"],desc:"Disengage specialist who can interrupt and reset enemy all-ins."}
];

const teamScenarios = [
  {role:"MID",ally:["Ornn","Jarvan IV","Jinx","Lulu"],enemy:["Renekton","Vi","Ahri","Kai'Sa","Nautilus"],priorities:["AP","antiDive","teamfight"],threats:["dive","engage"],teaching:"Your team already has engage and a physical carry. Mid should balance the damage profile and make front-to-back fights easier for Jinx rather than adding redundant dive."},
  {role:"SUPPORT",ally:["Gwen","Kindred","Viktor","Jinx"],enemy:["Malphite","Jarvan IV","Yasuo","Samira","Rakan"],priorities:["peel","frontline","antiDive"],threats:["dive","combo","engage"],teaching:"Four damage dealers do not automatically make a good composition. When the enemy has multiple ways to dive your carries, defensive utility can be worth more than another damage source."},
  {role:"JUNGLE",ally:["Fiora","Jayce","Ezreal","Zyra"],enemy:["Ornn","Lillia","Viktor","Jinx","Lulu"],priorities:["engage","frontline","early"],threats:["scaling","range","frontToBack"],teaching:"Poke is much stronger when the opponent must respect being engaged on. Four fragile or ranged champions often need a jungler who can start fights and create space."},
  {role:"ADC",ally:["Malphite","Sejuani","Orianna","Rakan"],enemy:["Gwen","Kindred","Viktor","Jinx","Milio"],priorities:["AD","dps","scaling"],threats:["scaling","range"],teaching:"Your team already has tremendous initiation. The ADC's job is to convert that setup into reliable sustained physical damage."},
  {role:"TOP",ally:["Vi","Ahri","Kai'Sa","Nautilus"],enemy:["Ornn","Kindred","Viktor","Jinx","Lulu"],priorities:["AP","dive","sideline"],threats:["scaling","frontToBack","peel"],teaching:"Against a superior front-to-back scaling draft, a side-lane threat or another dive angle can force the enemy carries to answer more than one problem."},
  {role:"MID",ally:["Renekton","Kindred","Ashe","Braum"],enemy:["Ornn","Sejuani","Viktor","Jinx","Lulu"],priorities:["AP","scaling","zone"],threats:["frontline","scaling","teamfight"],teaching:"Into heavy frontline, sustained magic damage prevents the enemy from simply stacking armor and walking forward."},
  {role:"SUPPORT",ally:["Ornn","Lillia","Jayce","Ezreal"],enemy:["Fiora","Vi","Ahri","Kai'Sa","Nautilus"],priorities:["peel","range","antiDive"],threats:["pick","dive"],teaching:"A poke composition wants to preserve distance. Your support should help Jayce and Ezreal keep that spacing instead of constantly dragging the team into short-range fights."},
  {role:"JUNGLE",ally:["Shen","Orianna","Jinx","Milio"],enemy:["Gwen","Lillia","Jayce","Ezreal","Zyra"],priorities:["engage","AD","pick"],threats:["poke","range","zone"],teaching:"Against long-range poke, reliable initiation gives your team a way to cross the gap before objective setup becomes impossible."}
];

// These are concept-counter scenarios, intentionally explained through mechanics.
// They are not presented as live-patch matchup win-rate rankings.
const counterScenarios = [
  {
    role:"TOP", enemy:"Darius", best:"Quinn",
    choices:["Quinn","Malphite","Gwen","Sett","Ornn"],
    enemyPattern:"Darius is strongest when a melee opponent stays in range long enough for him to stack Hemorrhage and land the outer edge of Q.",
    hint:"Think: which pick can repeatedly damage Darius while refusing the extended melee fight he wants?",
    reasons:{
      "Quinn":"Range lets Quinn pressure Darius without entering his preferred trade distance, and Vault can create space when he tries to run her down.",
      "Malphite":"Durable and useful later, but he does not punish Darius' lack of range as directly as Quinn does.",
      "Gwen":"Can scale and duel, but she still gives Darius access to the extended melee exchanges he wants.",
      "Sett":"Another short-range juggernaut turns the lane into a stat-and-execution fight instead of exploiting Darius' biggest weakness.",
      "Ornn":"Can survive and outscale in team utility, but the lane does not attack Darius' immobility as directly."
    },
    lesson:"Counter-picking a juggernaut often means attacking mobility and range limitations. You do not always need a champion that wins a fistfight; you can choose one that refuses the fistfight."
  },
  {
    role:"TOP", enemy:"Fiora", best:"Malphite",
    choices:["Malphite","Gwen","Sett","Renekton","Ornn"],
    enemyPattern:"Fiora wants repeated vital procs, attack-speed-driven duels and long side-lane fights.",
    hint:"Think: armor, attack-speed disruption and a lane pattern that makes vital access awkward.",
    reasons:{
      "Malphite":"Armor scaling and attack-speed reduction directly lower Fiora's sustained damage pattern, while his simple trades are hard to outplay repeatedly.",
      "Gwen":"A scaling duelist can contest Fiora, but this still accepts the kind of side-lane skill check Fiora is designed to win.",
      "Sett":"Can punish mistakes, but his telegraphed CC also gives Fiora clear Riposte opportunities.",
      "Renekton":"Has early pressure, but his stun is a valuable Riposte target and he can be outscaled in the side lane.",
      "Ornn":"Provides team value and armor, but Fiora's % max-health true damage is specifically threatening to very high-health tanks."
    },
    lesson:"A good counter can reduce the value of the enemy's core stat pattern. Against an auto-attack duelist, armor and attack-speed disruption can be more valuable than trying to out-duel them."
  },
  {
    role:"JUNGLE", enemy:"Master Yi", best:"Rammus",
    choices:["Rammus","Kindred","Lillia","Jarvan IV","Ivern"],
    enemyPattern:"Master Yi relies heavily on repeated basic attacks and wants enemy hard CC to be unavailable before he commits.",
    hint:"Think: which jungler is happiest when an auto-attack carry is forced to hit them?",
    reasons:{
      "Rammus":"Huge armor value plus a taunt forces Yi into the exact interaction he hates: attacking a durable target while unable to freely choose his target.",
      "Kindred":"Can kite and use Lamb's Respite cleverly, but this is a more execution-heavy answer.",
      "Lillia":"Movement speed helps kite, but Yi can become difficult to control once he reaches her.",
      "Jarvan IV":"Can pressure Yi early, but Cataclysm does not inherently stop Yi from attacking through the fight.",
      "Ivern":"Excellent peel for carries, but he is more dependent on teammates converting that protection into a kill."
    },
    lesson:"Against reset carries, reliable hard crowd control is often more valuable than extra damage. Deny the reset window first."
  },
  {
    role:"JUNGLE", enemy:"Lee Sin", best:"Poppy",
    choices:["Poppy","Sejuani","Vi","Kindred","Lillia"],
    enemyPattern:"Lee Sin's playmaking depends heavily on dashes for access, escape and repositioning.",
    hint:"Think: which ability can literally say 'no' to the mechanic Lee uses to make plays?",
    reasons:{
      "Poppy":"Steadfast Presence can stop dashes in its area, directly interfering with Lee Sin's mobility and many of his setup patterns.",
      "Sejuani":"Strong lockdown and durability, but she does not invalidate Lee's movement mechanic as explicitly.",
      "Vi":"Has reliable access, but turns the matchup into competing engage rather than denying Lee's core tool.",
      "Kindred":"Range can punish Lee, but Kindred is vulnerable if Lee finds the first clean access angle.",
      "Lillia":"Can kite with speed, but does not directly shut down Lee's dash-based playmaking."
    },
    lesson:"Some of the clearest counters in League are mechanic counters. If one ability directly disables the mechanic an enemy champion depends on, recognize that interaction."
  },
  {
    role:"MID", enemy:"Katarina", best:"Galio",
    choices:["Galio","Orianna","Viktor","Ahri","Yasuo"],
    enemyPattern:"Katarina wants to enter fights, avoid reliable interruption and snowball resets after the first takedown.",
    hint:"Think: durable magic-damage matchup plus dependable crowd control when Katarina jumps in.",
    reasons:{
      "Galio":"Galio is difficult for Katarina to burst and brings multiple forms of crowd control that can interrupt or punish her commitment.",
      "Orianna":"Can control space and punish predictable movement, but she is less forgiving if Katarina reaches her cleanly.",
      "Viktor":"Strong scaling and zone control, but vulnerable if Katarina finds a good flank or snowball window.",
      "Ahri":"Charm can punish Katarina, but the matchup is more skillshot-dependent than Galio's anti-dive pattern.",
      "Yasuo":"Can fight Katarina, but does not provide the same dependable anti-reset crowd control for the whole team."
    },
    lesson:"Against reset assassins, the first question is often not 'how do I out-damage them?' It is 'how reliably can I stop their first commitment?'"
  },
  {
    role:"MID", enemy:"Zed", best:"Lissandra",
    choices:["Lissandra","Orianna","Ahri","Viktor","Yasuo"],
    enemyPattern:"Zed wants to commit onto a vulnerable target, apply Death Mark and use shadows to escape after the burst.",
    hint:"Think: targeted lockdown, self-protection and a way to make Zed regret committing onto you.",
    reasons:{
      "Lissandra":"Targeted ultimate lockdown, a root and the option to self-cast her ultimate make Zed's commit-and-escape pattern much harder to execute.",
      "Orianna":"Can pressure with spacing, but has fewer emergency tools if Zed reaches her.",
      "Ahri":"Mobility helps avoid Zed, though her most important CC is still a skillshot.",
      "Viktor":"Can punish with zone control but is a more attractive assassination target when caught without spacing.",
      "Yasuo":"Has defensive tools, but the matchup becomes a mechanically volatile melee duel rather than a clean denial of Zed's game plan."
    },
    lesson:"Anti-assassin picks are strongest when they have both prevention and punishment: survive the burst, then lock the assassin down while they are committed."
  },
  {
    role:"ADC", enemy:"Samira", best:"Xayah",
    choices:["Xayah","Caitlyn","Jinx","Ezreal","Ashe"],
    enemyPattern:"Samira wants supports to create an all-in so she can enter short range, chain mobility and clean up the fight.",
    hint:"ADC matchups are support-dependent, so focus on self-peel: who is hardest for Samira to freely dive?",
    reasons:{
      "Xayah":"Feather recall threatens a root on champions running toward her, and Featherstorm gives Xayah a powerful self-peel window when Samira commits.",
      "Caitlyn":"Range can punish Samira before all-ins, but she relies more heavily on spacing and support protection once Samira reaches her.",
      "Jinx":"Outscales strongly but is vulnerable to the exact kind of close-range dive Samira wants.",
      "Ezreal":"Arcane Shift gives safety, making this a reasonable answer, but Xayah has stronger punish-and-turn tools once the dive begins.",
      "Ashe":"Utility and range help control the lane, though she lacks Xayah's emergency untargetability."
    },
    lesson:"For ADC counter-picks, lane support pairings matter enormously. When simplifying the matchup, look at range, escape tools and whether the marksman can punish an enemy who commits forward."
  },
  {
    role:"ADC", enemy:"Draven", best:"Caitlyn",
    choices:["Caitlyn","Jinx","Xayah","Kai'Sa","Ezreal"],
    enemyPattern:"Draven wants short early trades, lane control and kills that cash in Adoration before the opponent stabilizes.",
    hint:"Think: which ADC can contest lane space from farther away and make Draven's axe-catching paths uncomfortable?",
    reasons:{
      "Caitlyn":"Superior range and trap-based space control can pressure Draven while forcing him to think carefully about where he catches axes.",
      "Jinx":"Has range tools but is much more vulnerable to Draven's early all-in pressure.",
      "Xayah":"Self-peel helps later, but she does not pressure Draven's early lane pattern from as far away.",
      "Kai'Sa":"Shorter range can allow Draven to dictate the early lane unless the support matchup compensates.",
      "Ezreal":"Very safe and can farm from distance, but safety is not the same as actively punishing Draven's lane pattern."
    },
    lesson:"A counter is not always about killing the opponent. Sometimes it is about denying the conditions their snowball requires."
  },
  {
    role:"SUPPORT", enemy:"Blitzcrank", best:"Morgana",
    choices:["Morgana","Nautilus","Rakan","Zyra","Leona"],
    enemyPattern:"Blitzcrank creates lane-winning picks by hooking a target and layering crowd control before they can escape.",
    hint:"Think: which support can preemptively deny the crowd-control payoff of a hook?",
    reasons:{
      "Morgana":"Black Shield can prevent the crowd-control component of Blitzcrank's pick pattern while Dark Binding can punish his predictable approach.",
      "Nautilus":"Can counter-engage, but still allows Blitzcrank's hook to create chaos.",
      "Rakan":"Mobile enough to avoid hooks, but his ADC still needs protection from Blitzcrank's primary threat.",
      "Zyra":"Can pressure and sometimes block hooks with plants, but this is less reliable than Black Shield.",
      "Leona":"Can punish Blitz after he engages, but the lane becomes a hard-engage brawl rather than directly denying his win condition."
    },
    lesson:"When a champion's entire lane identity revolves around one crowd-control sequence, an ability that invalidates that sequence has unusually high counter value."
  },
  {
    role:"SUPPORT", enemy:"Leona", best:"Janna",
    choices:["Janna","Braum","Nautilus","Milio","Rakan"],
    enemyPattern:"Leona commits forward and wants her team to pile onto the target while her layered crowd control keeps them in place.",
    hint:"Think: who can interrupt or reset an all-in after Leona commits?",
    reasons:{
      "Janna":"Howling Gale and Monsoon can interrupt or reset the enemy's follow-up, making Leona's committed engage much harder to convert.",
      "Braum":"Strong defensive support and a good alternative, but he absorbs the engage more than he resets the whole fight.",
      "Nautilus":"Creates a competing engage threat rather than specializing in disengaging Leona's commitment.",
      "Milio":"Excellent protection and cleanse utility, but Janna has more direct displacement to break the all-in.",
      "Rakan":"Can peel and reposition, though he is more naturally a flexible engage support than a pure disengage specialist."
    },
    lesson:"Engage champions pay a cost when they go in: they commit their position. Disengage champions counter that by denying the follow-up after the commitment has already happened."
  }
];

// The Academy library favors durable concepts over patch-specific stat trivia.
// Item questions teach a decision process; a real build should still react to the
// current patch, champion, matchup, gold on recall, and both team compositions.
const quizQuestions = [
  // TERMINOLOGY
  {id:"term-peel",category:"terms",level:"easy",visual:"PEEL",context:"A carry is being chased by Vi and Leona.",prompt:"When a teammate asks you to “peel” for the carry, what should you do?",options:["Use crowd control and protection to keep threats away from the carry","Leave the fight and push a side lane","Start Baron immediately","Use every spell on the enemy tank"],answer:"Use crowd control and protection to keep threats away from the carry",hint:"Think about removing danger from a high-value teammate.",explanation:"Peel is defensive protection. Slows, knockbacks, shields, heals, and crowd control can all create the space a carry needs to keep dealing damage.",takeaway:"Peel is about protecting a teammate's ability to play the fight, not necessarily killing the diver."},
  {id:"term-prio",category:"terms",level:"easy",visual:"PRIO",context:"Your jungler wants to contest the river crab.",prompt:"What does it mean when your lane has priority, or “prio”?",options:["You can move first because your opponent must answer the lane state","You have more total kills than your opponent","You are the team's main carry","Your champion always wins the matchup"],answer:"You can move first because your opponent must answer the lane state",hint:"It is about who can leave lane first without giving something up.",explanation:"Lane priority usually comes from controlling the wave or pressuring the opponent so they cannot move before you. It gives your team earlier access to river plays.",takeaway:"Priority is temporary. Re-check the wave before assuming a teammate can move."},
  {id:"term-reset",category:"terms",level:"easy",visual:"RESET",context:"You have 1,300 gold, low mana, and the next wave is secured.",prompt:"What does “reset” usually mean in League?",options:["Recall to spend gold and restore resources, then return to the map","Restart the entire match","Drop all current objectives","Swap lanes with the support"],answer:"Recall to spend gold and restore resources, then return to the map",hint:"A good one converts gold into power without losing much on the map.",explanation:"A reset is a recall timed around waves and objectives. Strong reset timing lets you spend gold and refill before the next important play.",takeaway:"Gold in your inventory gives no combat stats until you spend it."},
  {id:"term-tempo",category:"terms",level:"medium",visual:"TEMPO",context:"Your team recalls first after pushing mid and reaches dragon before the enemy.",prompt:"What advantage did your team create?",options:["Tempo — time to act while the enemy is busy responding","Scaling — permanent late-game power","Leash — help on the first jungle camp","A freeze — a wave held near your turret"],answer:"Tempo — time to act while the enemy is busy responding",hint:"The advantage here is measured in time, not raw stats.",explanation:"Tempo is the time or initiative to make the next move. Pushing, recalling first, or forcing an opponent to respond can buy a window to set vision or start an objective.",takeaway:"Tempo becomes valuable only when you use the window it creates."},
  {id:"term-front-to-back",category:"terms",level:"medium",visual:"FTB",context:"Ornn stands in front while Jinx attacks the closest safe target behind him.",prompt:"Which teamfight pattern is this?",options:["Front-to-back","Split push","Cheese invade","Base race"],answer:"Front-to-back",hint:"The formation and target order are both in the name.",explanation:"Front-to-back teams fight through the enemy frontline while protecting their own carries. Carries usually hit the safest available target instead of forcing access to the backline.",takeaway:"The closest safe target is often the correct target for a sustained-damage carry."},
  {id:"term-freeze",category:"terms",level:"medium",visual:"FREEZE",context:"You keep a small enemy minion advantage just outside your turret range.",prompt:"What are you trying to create?",options:["A freeze that holds the wave in a dangerous position for the opponent","A fast push that crashes immediately","A neutral objective trade","A level-one invade"],answer:"A freeze that holds the wave in a dangerous position for the opponent",hint:"The wave stays in roughly the same place over multiple waves.",explanation:"A freeze uses a controlled enemy minion advantage to keep the wave near your side. It can deny farm and force the opponent to walk farther forward.",takeaway:"A freeze is wave control, not simply last-hitting slowly."},
  {id:"term-weakside",category:"terms",level:"hard",visual:"WEAK",context:"Your jungler invests resources on bot side while top receives little help.",prompt:"What does it mean for top lane to play “weak side”?",options:["Play with fewer allied resources and manage risk while pressure goes elsewhere","Intentionally lose lane so another player gets shutdown gold","Pick only tank champions","Never leave the top lane"],answer:"Play with fewer allied resources and manage risk while pressure goes elsewhere",hint:"It describes resource allocation, not player strength.",explanation:"Weak side is the side receiving less jungle attention, vision, or team investment. Its job is often to limit losses while the strong side creates an advantage.",takeaway:"Playing weak side well means preserving value without demanding resources your team is using elsewhere."},
  {id:"term-zone",category:"terms",level:"hard",visual:"ZONE",context:"An Orianna ball sits in a choke even though Shockwave has not been cast.",prompt:"Why can this still be valuable?",options:["It zones enemies by making an area dangerous to enter","It permanently grants vision through walls","It increases allied objective damage","It prevents enemy recalls everywhere"],answer:"It zones enemies by making an area dangerous to enter",hint:"Threat can change movement even before a spell is used.",explanation:"Zoning is controlling space through the threat of damage or crowd control. Enemies may give up the best route simply because entering it would be too risky.",takeaway:"An unused ability can create value when its threat controls important space."},

  // ITEMS & BUILD ORDER
  {id:"item-armor",category:"items",level:"easy",visual:"ARMOR",context:"Two enemy frontliners are stacking armor and your physical damage is falling off.",prompt:"Which stat should move up your shopping priority?",options:["Percentage armor penetration","Flat health regeneration","Magic resistance","Mana regeneration"],answer:"Percentage armor penetration",hint:"You need a stat that reduces the value of their growing armor total.",explanation:"Percentage armor penetration becomes more valuable as enemy armor totals rise. It is the standard way for a physical-damage carry to keep threatening armored targets.",takeaway:"Build against the defenses enemies actually buy."},
  {id:"item-healing",category:"items",level:"easy",visual:"HEAL",context:"The enemy team has several major healing sources and nobody has anti-heal.",prompt:"What is the best team-level item response?",options:["Have an appropriate teammate add Grievous Wounds without needlessly duplicating it","All five players must immediately buy the same anti-heal item","Ignore healing and only buy movement speed","Sell completed items for starter items"],answer:"Have an appropriate teammate add Grievous Wounds without needlessly duplicating it",hint:"The effect matters; buying it five times is usually inefficient.",explanation:"Grievous Wounds reduces healing. The team should decide who can apply it reliably and whether buying it now is worth delaying another power spike.",takeaway:"Itemization is a team problem: cover the need efficiently, then keep building toward your win condition."},
  {id:"item-boots",category:"items",level:"easy",visual:"BOOTS",context:"You are laning into repeated physical basic attacks and the enemy team has little crowd control.",prompt:"Which boot profile is the most logical defensive choice?",options:["Armor and basic-attack mitigation","Magic resistance and tenacity","Out-of-combat movement only","No boots under any circumstances"],answer:"Armor and basic-attack mitigation",hint:"Match your defense to the damage pattern you face most often.",explanation:"Plated Steelcaps are the familiar example of boots that answer physical basic attacks. Mercury's Treads make more sense when magic damage and reducible crowd control are the larger threat.",takeaway:"Boot choice should react to damage type, crowd control, lane pressure, and your job in fights."},
  {id:"item-components",category:"items",level:"medium",visual:"RECALL",context:"You recall short of the gold needed for your full first item.",prompt:"What is usually better than waiting in base for a large amount of gold?",options:["Buy useful components and return to the map on time","Wait indefinitely until the full item is affordable","Buy random cheap items with no build path","Leave every inventory slot empty for flexibility"],answer:"Buy useful components and return to the map on time",hint:"Map time and immediate combat stats both have value.",explanation:"Strong components let you convert available gold into power and preserve tempo. Waiting a long time in base can cost waves, camps, vision, or an objective setup.",takeaway:"Build order includes recall timing and components, not just the final six-item screenshot."},
  {id:"item-jinx-armor",category:"items",level:"medium",visual:"LDR",context:"Jinx has two core damage items. Malphite and Rammus are now stacking heavy armor and blocking every fight.",prompt:"What should usually move ahead of another luxury damage item?",options:["A percentage armor-penetration item such as Lord Dominik's Regards","A magic-resistance tank item","An AP item with ability haste","A support ward item"],answer:"A percentage armor-penetration item such as Lord Dominik's Regards",hint:"Your next purchase should solve the reason you cannot deal damage now.",explanation:"Against multiple high-armor targets, a percentage armor-penetration item can be a higher-value third purchase than another item that only adds raw damage.",takeaway:"Do not follow a fixed order past the point where the game state asks a different question."},
  {id:"item-survival",category:"items",level:"medium",visual:"STASIS",context:"You are an AP carry against a fed Zed and die during his commitment before casting a second rotation.",prompt:"Which purchase can be more valuable than rushing maximum raw damage?",options:["A stasis item such as Zhonya's Hourglass","Another item that offers only damage","A physical lifesteal item with no useful stats for your champion","A jungle companion"],answer:"A stasis item such as Zhonya's Hourglass",hint:"A dead carry deals no damage after the first rotation.",explanation:"Stasis can deny the assassin's burst window and buy time for cooldowns and teammates. Defensive items are damage items when they let you survive long enough to cast again.",takeaway:"Measure an item by how it changes the fight, not only by the size of its offensive stat line."},
  {id:"item-tank-order",category:"items",level:"hard",visual:"AD x4",context:"You are the frontline into four physical-damage champions, including two crit-based basic attackers.",prompt:"Which build plan best reflects the enemy threat profile?",options:["Prioritize early armor and basic-attack or crit mitigation, then reassess","Stack magic resistance first because all tanks need both defenses equally","Buy only health and ignore resistance types","Copy last game's build in the exact same order"],answer:"Prioritize early armor and basic-attack or crit mitigation, then reassess",hint:"Count damage types and identify how the carries deliver that damage.",explanation:"Armor is unusually efficient into a heavily physical team. Effects that reduce basic-attack or critical-strike damage can add more value when those patterns dominate, though penetration and mixed damage still require reassessment.",takeaway:"Tank builds should be a live threat assessment, not a fixed list."},
  {id:"item-build-framework",category:"items",level:"hard",visual:"BUILD",context:"A guide shows one six-item build, but your lane, enemy threats, and recall gold are different.",prompt:"What is the strongest way to decide your actual order?",options:["Start from the champion's core synergy, then adapt components, defenses, and penetration to the game","Copy all six items in order regardless of context","Buy the most expensive item available every recall","Counter only your lane opponent and ignore the other eight players"],answer:"Start from the champion's core synergy, then adapt components, defenses, and penetration to the game",hint:"Separate the champion's must-have interactions from situational slots.",explanation:"Good itemization combines a champion's core needs with the current game: lane pressure, major enemy threats, team damage profile, objective timing, and the amount of gold on each recall.",takeaway:"A build is a decision tree, not a shopping list."},

  // CHAMPION ABILITIES
  {id:"ability-poppy",category:"abilities",level:"easy",champion:"Poppy",context:"Lee Sin and Irelia need dashes to reach your backline.",prompt:"Which part of Poppy's kit directly interferes with their access?",options:["Steadfast Presence stops nearby enemy dashes","Her passive removes all enemy items","Hammer Shock silences the whole map","Keeper's Verdict permanently lowers attack range"],answer:"Steadfast Presence stops nearby enemy dashes",hint:"Her W creates a defensive zone around her.",explanation:"Poppy's Steadfast Presence can stop enemy dashes in its area and ground the champion it interrupts. Positioning the zone well can deny an engage before it starts.",takeaway:"Learn the one mechanic-defining spell that changes how opponents must approach each champion."},
  {id:"ability-morgana",category:"abilities",level:"easy",champion:"Morgana",context:"Blitzcrank is looking to hook your ADC.",prompt:"Why is Morgana's Black Shield such an important answer?",options:["It can block magic damage and prevent crowd-control effects while it holds","It makes the target permanently invisible","It reflects every projectile","It teleports the target to base"],answer:"It can block magic damage and prevent crowd-control effects while it holds",hint:"The shield is valuable for more than its damage absorption.",explanation:"Black Shield absorbs magic damage and protects against disabling effects while the shield remains. Timing matters because losing the shield removes that protection.",takeaway:"When playing into Black Shield, break or wait out the shield before committing key crowd control."},
  {id:"ability-xayah",category:"abilities",level:"easy",champion:"Xayah",context:"Vi commits her ultimate onto Xayah.",prompt:"What defensive feature makes Xayah's Featherstorm powerful against dive?",options:["Xayah becomes untargetable during the cast","It permanently doubles her armor","It cancels every enemy ultimate globally","It revives all dead teammates"],answer:"Xayah becomes untargetable during the cast",hint:"It can make a committed enemy ability lose its target window.",explanation:"Featherstorm briefly makes Xayah untargetable while also placing feathers she can later recall. Holding it for the enemy's key commitment is often more valuable than using it for damage.",takeaway:"Track defensive cooldowns before committing point-and-click access tools."},
  {id:"ability-kindred",category:"abilities",level:"medium",champion:"Kindred",context:"Both teams are low inside Lamb's Respite.",prompt:"Who can be prevented from dying by Kindred's ultimate?",options:["Any unit inside the zone, ally or enemy, while the effect applies","Only Kindred","Only allied champions","Only jungle monsters"],answer:"Any unit inside the zone, ally or enemy, while the effect applies",hint:"This ultimate is not a normal one-sided protection spell.",explanation:"Lamb's Respite creates a zone where units cannot fall below a health threshold for its duration, then heals units still inside. Enemies can benefit too.",takeaway:"Plan the end of Lamb's Respite: displacement, burst timing, and healing reduction can decide what happens when safety expires."},
  {id:"ability-orianna",category:"abilities",level:"medium",champion:"Orianna",context:"Orianna's ball is attached to Malphite as he dives into the enemy team.",prompt:"Where will Command: Shockwave activate?",options:["Around the current location of Orianna's ball","Always around Orianna herself","At the allied fountain","On the lowest-health enemy anywhere on the map"],answer:"Around the current location of Orianna's ball",hint:"Track the ball, not just Orianna's model.",explanation:"Orianna's spells are centered on her ball. A diver carrying the ball can deliver Shockwave into the enemy team, but losing track of the ball creates missed casts.",takeaway:"The ball's position is Orianna's effective threat position."},
  {id:"ability-malphite",category:"abilities",level:"medium",champion:"Malphite",context:"Malphite is looking for a grouped backline at an objective choke.",prompt:"What makes Unstoppable Force a defining engage tool?",options:["Malphite becomes unstoppable during the dash and knocks up enemies at the destination","It is a global point-and-click execute","It grants permanent invulnerability","It can only hit minions"],answer:"Malphite becomes unstoppable during the dash and knocks up enemies at the destination",hint:"Its reliability comes from both the travel and the crowd control on arrival.",explanation:"Unstoppable Force rapidly crosses space while Malphite is unstoppable, then damages and knocks up enemies in the impact area. Spacing and vision are the main forms of counterplay.",takeaway:"Against Malphite, avoid stacking on top of other high-value targets in his engage range."},
  {id:"ability-caitlyn",category:"abilities",level:"hard",champion:"Caitlyn",context:"An enemy is already rooted by Morgana's Dark Binding.",prompt:"How should Caitlyn use Yordle Snap Trap to extend the punish?",options:["Place a trap under the immobilized target to chain the control and enable a Headshot","Place every trap at her own fountain","Wait until the root ends, then place it far behind the target","Use traps only for minion damage"],answer:"Place a trap under the immobilized target to chain the control and enable a Headshot",hint:"Reliable allied crowd control can remove the normal difficulty of landing a trap.",explanation:"Caitlyn traps arm after placement, so allied crowd control creates a dependable setup. Chaining the trap extends the target's vulnerable window and enables Caitlyn's empowered follow-up.",takeaway:"Many abilities become dramatically stronger when sequenced after allied setup rather than cast independently."},
  {id:"ability-leesin",category:"abilities",level:"hard",champion:"Lee Sin",context:"Lee Sin needs one more angle to reach a carry behind the frontline.",prompt:"What enables his classic ward-hop reposition?",options:["Safeguard can dash Lee Sin to an allied ward or allied unit","Sonic Wave always teleports behind the farthest enemy","Dragon's Rage resets every ward","Tempest creates a permanent tunnel"],answer:"Safeguard can dash Lee Sin to an allied ward or allied unit",hint:"The movement comes from the first cast of his W.",explanation:"Lee Sin can place a ward and cast Safeguard to it, creating a new angle for escape or an ultimate kick. Denying space and tracking ward availability reduces his options.",takeaway:"Advanced champion knowledge often means understanding what their basic abilities are allowed to target."},

  // MACRO & OBJECTIVES
  {id:"macro-wave-first",category:"macro",level:"easy",visual:"0:45",context:"Dragon spawns in 45 seconds and the mid wave is arriving.",prompt:"What is the best default preparation?",options:["Push the wave, recall or move on time, then establish river vision","Ignore the wave and stand in the pit for 45 seconds","Start a distant side-lane fight with no teleport","Spend all wards in your own fountain"],answer:"Push the wave, recall or move on time, then establish river vision",hint:"Prepare the lane before leaving it.",explanation:"Pushing first forces the opponent to choose between catching the wave and matching your move. That priority buys time for vision and better objective positions.",takeaway:"Objective setup starts with nearby waves, not when the monster spawns."},
  {id:"macro-baron-recall",category:"macro",level:"easy",visual:"BARON",context:"Your team wins a fight, but everyone is low and carrying a lot of gold while Baron is not safely finishable.",prompt:"What is often the highest-value next action?",options:["Take safe nearby resources, reset, and return with spent gold","Stay indefinitely until the enemy respawns and catches you","Start Baron at critical health with no damage dealer","Walk separately through unwarded enemy jungle"],answer:"Take safe nearby resources, reset, and return with spent gold",hint:"Do not let a won fight create a losing second fight.",explanation:"A clean reset converts the fight win into items and restores health, mana, and wards. Forcing an unsafe objective can hand the advantage back.",takeaway:"After a win, secure what is safe and preserve the next tempo."},
  {id:"macro-crossmap",category:"macro",level:"easy",visual:"TRADE",context:"Five enemies show bot to take dragon and your team cannot contest in time.",prompt:"What does a useful cross-map response look like?",options:["Take a top-side objective, turret, camps, or waves instead of arriving late","Walk one by one into dragon after it dies","Wait in base until the enemy leaves","Give every resource on the other side too"],answer:"Take a top-side objective, turret, camps, or waves instead of arriving late",hint:"If one side of the map is lost, ask what is free on the other side.",explanation:"Cross-mapping trades value when direct contest is impossible or too late. It reduces the cost of the enemy play and can force them to respond next.",takeaway:"A lost objective does not require a lost minute."},
  {id:"macro-numbers",category:"macro",level:"medium",visual:"5v4",context:"An enemy top laner shows in a side lane without Teleport while Baron is alive.",prompt:"What temporary advantage should your team recognize?",options:["A numbers window to pressure Baron vision, start it, or force a fight","A reason for all five players to recall","Proof that Baron deals no damage","A permanent 5v4 for the rest of the match"],answer:"A numbers window to pressure Baron vision, start it, or force a fight",hint:"Count visible champions and check their ways to join.",explanation:"Showing far from an objective without a global tool creates a temporary numbers disadvantage. Your team can use that window, but must still account for vision, health, and enemy engage.",takeaway:"Macro begins with counting who can reach the next play in time."},
  {id:"macro-split",category:"macro",level:"medium",visual:"1–4",context:"Your Fiora wins side lane, while the other four teammates can safely clear and disengage.",prompt:"What is the core purpose of a 1–4 setup?",options:["Force the enemy to answer the side-lane threat without letting the four-player group be engaged on","Have Fiora join every mid wave and abandon side pressure","Make the four-player group fight 4v5 immediately","Keep all five allies in separate lanes"],answer:"Force the enemy to answer the side-lane threat without letting the four-player group be engaged on",hint:"One player creates pressure; four players must avoid throwing while using it.",explanation:"The side laner pulls a response and creates map pressure. The group of four controls space or an objective but should avoid a losing engage while the split pusher is away.",takeaway:"Split pushing is coordinated pressure, not simply farming alone."},
  {id:"macro-vision",category:"macro",level:"medium",visual:"VISION",context:"Your team arrives first around Baron with control wards and sweepers.",prompt:"Why is denying enemy vision so powerful?",options:["It creates uncertainty: the enemy cannot safely know whether you are starting Baron, setting a trap, or rotating","It makes Baron permanently weaker","It disables every enemy trinket for the full match","It guarantees a win even if your team leaves the area"],answer:"It creates uncertainty: the enemy cannot safely know whether you are starting Baron, setting a trap, or rotating",hint:"Information pressure can force dangerous face-checks.",explanation:"Vision denial hides both your position and your intent. The enemy must spend time checking, give the objective, or enter through controlled choke points.",takeaway:"Objective control is often won through information before combat begins."},
  {id:"macro-death-wave",category:"macro",level:"hard",visual:"WAVE",context:"You can chase a low-health support, but two large enemy waves are about to crash into your side turrets.",prompt:"What is the disciplined macro choice?",options:["Secure the waves first unless the chase is nearly guaranteed and worth more","Chase across the map no matter how long it takes","Let the waves die because minions never matter","Have the whole team wait in a bush with no objective nearby"],answer:"Secure the waves first unless the chase is nearly guaranteed and worth more",hint:"Compare guaranteed gold and experience with uncertain reward and lost time.",explanation:"Large waves are reliable resources and protect turret health. A long chase can lose more guaranteed value than the possible kill provides while also exposing your team to a turn.",takeaway:"Evaluate plays by opportunity cost, not only by whether a kill is possible."},
  {id:"macro-baron-use",category:"macro",level:"hard",visual:"BUFF",context:"Your team has Baron buff, but the enemy clears mid comfortably under turret.",prompt:"How should you create more pressure?",options:["Use empowered waves in multiple lanes while maintaining safe rotations and matching enemy threats","Send all five players mid for the entire buff regardless of wave states","Farm only your own jungle until the buff expires","Fight under the enemy turret without minions"],answer:"Use empowered waves in multiple lanes while maintaining safe rotations and matching enemy threats",hint:"Baron empowers minions, so make the enemy answer more than one wave.",explanation:"Baron is strongest when coordinated lane pressure stretches the defense. The exact setup depends on engage risk and side-lane matchups, but synchronized waves create harder choices than one predictable lane.",takeaway:"The goal of Baron is usually map progress—turrets, inhibitors, and control—not forcing a fight at any cost."},

  // WAVE-MANAGEMENT VOCABULARY
  {id:"term-push-wave",category:"terms",level:"easy",visual:"PUSH",context:"Your jungler pings that they want to contest the next river objective.",prompt:"What does “push the wave” ask you to do?",options:["Kill the enemy minions quickly so your wave advances toward their turret","Only last-hit and keep the wave in the same place","Leave every minion alive and roam immediately","Attack the enemy champion under turret at any cost"],answer:"Kill the enemy minions quickly so your wave advances toward their turret",hint:"The goal is to make the opponent answer minions before they can move.",explanation:"Pushing means clearing the wave so your minions move forward. A successful push can create lane priority, a recall window, turret pressure, or time to roam.",takeaway:"Push with a purpose: know whether the next window is for vision, a reset, a roam, or turret damage."},
  {id:"term-crash-wave",category:"terms",level:"medium",visual:"CRASH",context:"Your full minion wave reaches the enemy turret and begins dying to it.",prompt:"What does it mean to “crash” a wave?",options:["Get your minions fully under the enemy turret so the turret and defender must clear them","Keep the waves locked outside your own turret","Recall while the enemy wave is pushing toward you","Pull the enemy jungler away from an objective"],answer:"Get your minions fully under the enemy turret so the turret and defender must clear them",hint:"A partial push that stops outside turret is not a clean crash.",explanation:"A crash places the wave under the opposing turret. This makes the opponent spend time collecting it and can create a safer recall, roam, ward, or dive timing.",takeaway:"Finish the crash before leaving when possible; an unfinished push can freeze against you."},
  {id:"term-slow-push",category:"terms",level:"medium",visual:"SLOW",context:"You want a large side-lane wave to build over the next minute before an objective.",prompt:"How do you usually start a slow push?",options:["Create a small allied minion advantage, then let reinforcement waves stack","Clear every wave instantly from maximum range","Tank the whole enemy wave outside your turret forever","Ignore which side has more minions"],answer:"Create a small allied minion advantage, then let reinforcement waves stack",hint:"You want your side to win gradually, not reach the next turret immediately.",explanation:"A small minion advantage compounds as new waves arrive, creating a larger wave that eventually demands an answer. Timing and map side matter because an enemy can collect or reverse it.",takeaway:"A slow push is delayed pressure: build it before your team wants to act elsewhere."},
  {id:"term-wave-bounce",category:"terms",level:"hard",visual:"BOUNCE",context:"You crash a large wave into the enemy turret and neither champion touches the next wave immediately.",prompt:"Why is the wave likely to “bounce” back toward you?",options:["Enemy reinforcements arrive sooner and meet your wave closer to their side, creating an enemy minion advantage","Turrets permanently change every minion's damage","The river automatically pulls minions toward your base","A crashed wave always disappears for two minutes"],answer:"Enemy reinforcements arrive sooner and meet your wave closer to their side, creating an enemy minion advantage",hint:"Think about where each new wave enters the fight.",explanation:"After a clean crash, the next enemy wave reaches the meeting point sooner. Unless the opponent changes the wave, that extra time often creates a push back toward your side.",takeaway:"A crash can set up your next safer collection window; wave control is a sequence, not one isolated wave."},

  // AKALI MAIN PATH — durable matchup principles rather than a fixed patch build
  {id:"akali-passive-ring",category:"abilities",level:"easy",champion:"Akali",focus:["Akali"],context:"You hit an enemy champion with Five Point Strike and a ring appears around them.",prompt:"What is Akali trying to do with Assassin's Mark?",options:["Step outside the ring to empower her next basic attack, then re-enter for the trade","Stand still inside the ring until it disappears","Recall immediately to refresh the passive","Attack a turret to make the ring damage every enemy"],answer:"Step outside the ring to empower her next basic attack, then re-enter for the trade",hint:"The passive rewards crossing the ring boundary after an ability hits.",explanation:"Damaging a champion with an ability creates the ring. Crossing its edge grants movement speed and empowers Akali's next basic attack with extra range and damage.",takeaway:"Akali's lane trades are built around movement: spell, exit the ring, then decide whether it is safe to re-enter."},
  {id:"akali-shroud-purpose",category:"abilities",level:"easy",champion:"Akali",focus:["Akali"],context:"Akali has spent most of her energy during a lane trade and the opponent wants to retaliate.",prompt:"What does Twilight Shroud give her besides concealment?",options:["An energy restoration and movement window that can extend or safely end the trade","Permanent invulnerability for the rest of the lane","A global teleport to any allied turret","A full reset of her ultimate"],answer:"An energy restoration and movement window that can extend or safely end the trade",hint:"Shroud affects Akali's resources as well as enemy targeting.",explanation:"Twilight Shroud creates obscured space, restores energy, and gives Akali room to reposition. Revealing herself carelessly with attacks can still let the opponent answer.",takeaway:"Treat Shroud as a resource and timing tool, not only an invisibility button."},
  {id:"akali-ranged-start",category:"items",level:"easy",champion:"Akali",focus:["Akali"],context:"You are Akali into Orianna, who can repeatedly poke you while you walk up for early minions.",prompt:"Which starting purchase is the safest default for surviving repeated ranged poke?",options:["Doran's Shield for lane sustain","A large damage component you cannot afford at level one","Cull to maximize safe ranged farming","No starting item so you can save gold"],answer:"Doran's Shield for lane sustain",hint:"The first job is reaching later levels with enough health to threaten an all-in.",explanation:"Doran's Shield is a common defensive start into repeated poke because its sustain helps Akali absorb early lane pressure. Exact starts can change with balance patches and player confidence.",takeaway:"Choose a starting item for the lane you must survive, not only for the damage you hope to deal later."},
  {id:"akali-push-roam",category:"macro",level:"easy",champion:"Akali",focus:["Akali"],context:"Bot lane looks gankable, but a full enemy wave is arriving mid.",prompt:"What should Akali usually do before starting the roam?",options:["Push or otherwise secure the mid wave, then move during the window","Abandon every arriving wave as soon as bot lane trades","Wait under her turret until the opportunity disappears","Use both ultimate casts on the minion wave"],answer:"Push or otherwise secure the mid wave, then move during the window",hint:"A roam costs much more when the opposing mid can hold the wave and take plates.",explanation:"Securing the wave makes the enemy mid choose between matching Akali and collecting minions. Some urgent fights justify moving first, but the default roam starts by creating priority.",takeaway:"Good roams are funded by wave control; they are not free trips away from lane."},
  {id:"akali-zed-first-buy",category:"items",level:"medium",champion:"Akali",focus:["Akali"],context:"You are Akali into Zed. He has an early lead and his physical burst is deciding every trade.",prompt:"Which first defensive component best changes this lane?",options:["Early armor with a path toward stasis, such as Seeker's Armguard","Magic resistance with no other purpose in the matchup","Attack-speed boots for longer basic-attack trades","A support item that only generates wards"],answer:"Early armor with a path toward stasis, such as Seeker's Armguard",hint:"Match the defense to Zed's damage and his committed ultimate window.",explanation:"Early armor reduces Zed's physical burst, while a later stasis active can deny much of his ultimate timing. Item names and exact efficiency move by patch, but the armor-into-stasis decision remains the key idea.",takeaway:"The best first buy is sometimes the component that removes the opponent's kill window."},
  {id:"akali-yasuo-wall",category:"abilities",level:"medium",champion:"Akali",focus:["Akali"],context:"Yasuo still has Wind Wall available and Akali wants to commit with Shuriken Flip.",prompt:"What interaction should Akali respect?",options:["Wind Wall can block the E projectile, so bait it or find an angle before committing","Wind Wall removes Twilight Shroud from the ground","Wind Wall makes Yasuo immune to Akali's ultimate","Wind Wall reflects Akali's passive attack across the map"],answer:"Wind Wall can block the E projectile, so bait it or find an angle before committing",hint:"Ask which part of Akali's engage begins as a projectile.",explanation:"The first cast of Shuriken Flip is a projectile and can be stopped by Wind Wall. If E is central to Akali's all-in, tracking Wind Wall prevents a high-cost failed commit.",takeaway:"Matchup knowledge means tracking the specific defensive cooldown that interrupts your sequence."},
  {id:"akali-freeze-melee",category:"terms",level:"easy",champion:"Akali",focus:["Akali"],context:"Akali is ahead of a melee opponent with no Teleport. The enemy wave is just outside Akali's turret and her jungler is nearby.",prompt:"Why might holding a freeze be stronger than instantly pushing?",options:["It forces the opponent to walk into a long, dangerous lane to collect farm","It guarantees Akali a turret without attacking it","It makes Akali invisible to enemy wards","It permanently stops every neutral objective"],answer:"It forces the opponent to walk into a long, dangerous lane to collect farm",hint:"Use your lead to control where the opponent is allowed to stand.",explanation:"A stable freeze near Akali's side can deny minions and expose a melee opponent to an all-in or gank. It is only useful while the wider map does not require Akali to create priority elsewhere.",takeaway:"Freeze to deny and threaten; push when you need tempo somewhere else."},
  {id:"akali-galio-plan",category:"macro",level:"medium",champion:"Akali",focus:["Akali"],context:"Galio is hard for Akali to burst and can answer fights with Hero's Entrance.",prompt:"What is the more reliable mid-game plan?",options:["Manage the wave, track his ultimate, and create pressure where he cannot answer for free","Force the same all-in on Galio every time he returns to lane","Ignore side waves and wait permanently in mid","Build only armor because Galio deals physical damage"],answer:"Manage the wave, track his ultimate, and create pressure where he cannot answer for free",hint:"You do not have to win by repeatedly killing your lane opponent.",explanation:"A durable anti-magic champion can deny Akali's preferred lane kills. Wave timing, side pressure, vision denial, and tracking Galio's global response create better openings than forcing his strongest kind of fight.",takeaway:"A difficult matchup changes the route to your win condition, not the existence of one."},
  {id:"akali-mr-pen",category:"items",level:"hard",champion:"Akali",focus:["Akali"],context:"You are Akali with core damage completed, but three enemies now have substantial magic resistance.",prompt:"What should rise in priority before another purely raw-AP luxury item?",options:["Percentage magic penetration","Critical-strike chance","Mana regeneration despite Akali using energy","Armor with no physical threat on the enemy team"],answer:"Percentage magic penetration",hint:"The enemy has invested in the defense that directly reduces your damage.",explanation:"Percentage magic penetration scales against larger magic-resistance totals. The exact item choice depends on the patch and whether utility or haste matters, but ignoring widespread MR makes raw ability power less efficient.",takeaway:"Re-check enemy inventories before every major purchase; your build should answer what changed."},
  {id:"akali-e-mark",category:"abilities",level:"hard",champion:"Akali",focus:["Akali"],context:"Akali marks an enemy carry with Shuriken Flip, but the carry retreats under turret while teammates collapse.",prompt:"What is the disciplined decision before recasting E?",options:["Re-evaluate the landing position, enemy cooldowns, and available exits before following","Always recast because a landed mark guarantees a kill","Recast only to restore health, regardless of position","Wait for the mark to teleport the enemy back to Akali"],answer:"Re-evaluate the landing position, enemy cooldowns, and available exits before following",hint:"Landing E creates an option, not an obligation.",explanation:"The recast carries Akali to the marked target's current position. During that delay, the target can move into turret range or toward teammates, turning a good hit into a losing follow.",takeaway:"Mechanical consistency includes declining a flashy recast when the destination has become bad."},
  {id:"akali-teamfight-flank",category:"macro",level:"hard",champion:"Akali",focus:["Akali"],context:"A five-on-five objective fight is starting. The enemy frontline is grouped in front of two protected carries.",prompt:"Which setup best supports Akali's assassin job?",options:["Approach from fog or a side angle after key control spells are tracked","Stand directly in front and attack the tank before the fight starts","Reveal on the wave and use Shroud before anyone engages","Enter alone while every enemy cooldown is available"],answer:"Approach from fog or a side angle after key control spells are tracked",hint:"Akali wants access and uncertainty more than a fair front-to-back entrance.",explanation:"A flank or fog angle stretches the enemy formation and shortens Akali's route to a carry. Waiting for important crowd control also lowers the cost of committing into the backline.",takeaway:"Assassins often win the fight with position and timing before they win it with damage."},
  {id:"akali-bounce-reset",category:"terms",level:"hard",champion:"Akali",focus:["Akali"],context:"Akali crashes a large wave, recalls, and expects the lane to push back toward her.",prompt:"Why is this reset especially useful for a short-range assassin?",options:["She can return with spent gold to a longer lane where the opponent must walk forward","It permanently removes the enemy turret's protection","It guarantees every minion will wait at the river","It prevents the opposing mid from ever roaming"],answer:"She can return with spent gold to a longer lane where the opponent must walk forward",hint:"Combine the item advantage from resetting with the position created by the bounce.",explanation:"The crash buys Akali recall time, and the bounce can bring the next waves toward her side. Returning stronger to an extended lane creates more room to trade, chase, or threaten a gank.",takeaway:"Wave sequences can manufacture the space an assassin needs; do not treat every wave as an isolated shove."}
];

const labels = {
  AP:"Magic damage",AD:"Physical damage",frontline:"Frontline",engage:"Engage",peel:"Peel",
  antiDive:"Anti-dive",teamfight:"Teamfight",scaling:"Scaling",dps:"Sustained DPS",
  sideline:"Side lane",early:"Early pressure",range:"Range",pick:"Pick threat",
  dive:"Dive",zone:"Zone control",poke:"Poke",combo:"Combo engage",frontToBack:"Front-to-back"
};

const roleNames = {TOP:"Top Lane",JUNGLE:"Jungle",MID:"Mid Lane",ADC:"Bot / ADC",SUPPORT:"Support"};
const quizCategories = {
  terms:{label:"Terminology",short:"WORDS",icon:"Aa"},
  items:{label:"Items & builds",short:"BUILD",icon:"◆"},
  abilities:{label:"Champion abilities",short:"KITS",icon:"QWER"},
  macro:{label:"Macro & objectives",short:"MAP",icon:"⌖"}
};
const championPaths = {
  Akali:{role:"Mid / Top",description:"Matchups, lane states, builds, combos, and teamfight access."}
};
const difficultyRank = {easy:1,medium:2,hard:3};
const XP_PER_LEVEL = 500;
const achievementDefinitions = [
  {id:"first-read",icon:"✦",name:"First Read",description:"Answer your first challenge.",test:p=>p.totals.answers>=1},
  {id:"on-fire",icon:"🔥",name:"On Fire",description:"Reach a 3-answer streak.",test:p=>p.bestStreak>=3},
  {id:"unstoppable",icon:"⚡",name:"Unstoppable",description:"Reach a 7-answer streak.",test:p=>p.bestStreak>=7},
  {id:"draft-reader",icon:"◈",name:"Draft Reader",description:"Get 5 Team Comp answers right.",test:p=>p.modes.comp.correct>=5},
  {id:"counter-pro",icon:"⚔",name:"Counter Pro",description:"Find 5 clean counter picks.",test:p=>p.modes.counter.correct>=5},
  {id:"academy-scholar",icon:"◆",name:"Academy Scholar",description:"Get 10 Academy lessons right.",test:p=>p.modes.quiz.correct>=10},
  {id:"mission-clear",icon:"★",name:"Mission Clear",description:"Complete a five-round mission.",test:p=>p.completedMissions>=1},
  {id:"shotcaller",icon:"♛",name:"Shotcaller",description:"Reach level 5.",test:p=>Math.floor(p.xp/XP_PER_LEVEL)+1>=5}
];
const $ = id => document.getElementById(id);
const getChampion = name => champions.find(c => c.name === name);

function loadAcademyProgress() {
  try {
    const saved=JSON.parse(localStorage.getItem("draftIqAcademyProgress"));
    return saved&&saved.questions&&Array.isArray(saved.missed) ? saved : {questions:{},missed:[]};
  } catch(error) {
    return {questions:{},missed:[]};
  }
}

function freshPlayerProgress() {
  return {
    xp:0,score:0,bestStreak:0,completedMissions:0,achievements:[],
    totals:{answers:0,correct:0},
    modes:{comp:{answers:0,correct:0},counter:{answers:0,correct:0},quiz:{answers:0,correct:0}},
    mission:{results:[],complete:false,success:false}
  };
}

function loadPlayerProgress() {
  const fallback=freshPlayerProgress();
  try {
    const saved=JSON.parse(localStorage.getItem("draftIqPlayerProgress"));
    if(!saved) return fallback;
    return {
      ...fallback,...saved,
      totals:{...fallback.totals,...saved.totals},
      modes:{
        comp:{...fallback.modes.comp,...saved.modes?.comp},
        counter:{...fallback.modes.counter,...saved.modes?.counter},
        quiz:{...fallback.modes.quiz,...saved.modes?.quiz}
      },
      mission:{...fallback.mission,...saved.mission,results:Array.isArray(saved.mission?.results)?saved.mission.results:[]},
      achievements:Array.isArray(saved.achievements)?saved.achievements:[]
    };
  } catch(error) {
    return fallback;
  }
}

const savedPlayerProgress=loadPlayerProgress();

let state = {
  mode:"hub",
  difficulty:"easy",
  score:savedPlayerProgress.score,
  streak:0,
  round:1,
  compIndex:-1,
  counterIndex:-1,
  quizCategory:"all",
  quizPath:"all",
  quizChampion:"Akali",
  quizReview:false,
  quizQueue:[],
  quizCycleTotal:0,
  quizCyclePosition:0,
  quizProgress:loadAcademyProgress(),
  playerProgress:savedPlayerProgress,
  answered:false,
  scenario:null,
  choices:[],
  quizOptions:[]
};

function shuffle(arr) {
  const a=[...arr];
  for(let i=a.length-1;i>0;i--){
    const j=Math.floor(Math.random()*(i+1));
    [a[i],a[j]]=[a[j],a[i]];
  }
  return a;
}

function labelForTag(tag) { return labels[tag] || tag.replace(/([A-Z])/g," $1"); }

function difficultyCopy() {
  if(state.mode==="quiz") {
    const quizCopy = {
      easy:"<strong>Easy:</strong> Foundation lessons include a direct hint and three answer choices.",
      medium:"<strong>Medium:</strong> Foundation and applied lessons use all four choices with a lighter clue.",
      hard:"<strong>Hard:</strong> The full curriculum is unlocked, including expert decision-making questions with no hints."
    };
    $("difficultyInfo").innerHTML = quizCopy[state.difficulty];
    return;
  }
  const copy = {
    easy:"<strong>Easy:</strong> Draft needs, enemy threats and champion descriptions are shown. Focus on learning the concepts.",
    medium:"<strong>Medium:</strong> Explicit need/threat tags disappear and choice descriptions are hidden. You still get one directional hint.",
    hard:"<strong>Hard:</strong> No draft hints, no need tags and no choice descriptions. Read the champions and solve the draft yourself."
  };
  $("difficultyInfo").innerHTML = copy[state.difficulty];
}

function saveAcademyProgress() {
  try { localStorage.setItem("draftIqAcademyProgress",JSON.stringify(state.quizProgress)); }
  catch(error) { /* Progress still works for this session when storage is unavailable. */ }
}

function questionMatchesQuizPath(question) {
  return state.quizPath==="all" || question.focus?.includes(state.quizChampion);
}

function eligibleQuizQuestions() {
  const missed=new Set(state.quizProgress.missed);
  let pool=quizQuestions.filter(q=>
    difficultyRank[q.level]<=difficultyRank[state.difficulty] &&
    (state.quizCategory==="all"||q.category===state.quizCategory) &&
    questionMatchesQuizPath(q)
  );
  if(state.quizReview) pool=pool.filter(q=>missed.has(q.id));
  return pool;
}

function makeQuizQueue() {
  let pool=eligibleQuizQuestions();
  if(!pool.length&&state.quizReview) {
    state.quizReview=false;
    pool=eligibleQuizQuestions();
  }
  const missed=new Set(state.quizProgress.missed);
  const unseen=shuffle(pool.filter(q=>!state.quizProgress.questions[q.id]));
  const review=shuffle(pool.filter(q=>state.quizProgress.questions[q.id]&&missed.has(q.id)));
  const learned=shuffle(pool.filter(q=>state.quizProgress.questions[q.id]&&!missed.has(q.id)));
  state.quizQueue=[...unseen,...review,...learned];
  state.quizCycleTotal=state.quizQueue.length;
  state.quizCyclePosition=0;
  updateReviewButton();
}

function buildQuizOptions(question) {
  if(state.difficulty!=="easy") return shuffle(question.options);
  return shuffle([question.answer,...shuffle(question.options.filter(option=>option!==question.answer)).slice(0,2)]);
}

function quizLevelLabel(level) {
  return {easy:"Foundation",medium:"Applied",hard:"Expert"}[level];
}

function renderMastery() {
  const progress=state.quizProgress.questions;
  let totalAttempts=0,totalCorrect=0;
  $("masteryGrid").innerHTML=Object.entries(quizCategories).map(([key,category])=>{
    const ids=quizQuestions.filter(q=>q.category===key&&questionMatchesQuizPath(q)).map(q=>q.id);
    const stats=ids.reduce((sum,id)=>{
      const entry=progress[id]||{attempts:0,correct:0};
      sum.attempts+=entry.attempts;
      sum.correct+=entry.correct;
      return sum;
    },{attempts:0,correct:0});
    totalAttempts+=stats.attempts;
    totalCorrect+=stats.correct;
    const percent=stats.attempts?Math.round((stats.correct/stats.attempts)*100):0;
    return `<div class="mastery-card ${state.quizCategory===key?"active":""}" data-mastery-category="${key}">
      <div class="mastery-card-top"><span>${category.icon}</span><b>${percent}%</b></div>
      <h3>${category.label}</h3>
      <div class="mastery-meter"><span style="width:${percent}%"></span></div>
      <p>${stats.attempts?`${stats.correct} correct · ${stats.attempts} attempts`:"Not started"}</p>
    </div>`;
  }).join("");
  const overall=totalAttempts?Math.round((totalCorrect/totalAttempts)*100):0;
  $("masterySummary").textContent=totalAttempts
    ? `${overall}% overall accuracy across ${totalAttempts} answer${totalAttempts===1?"":"s"}. Missed lessons return sooner.`
    : "Answer questions to build your knowledge map.";
  document.querySelectorAll("[data-mastery-category]").forEach(card=>card.addEventListener("click",()=>setQuizCategory(card.dataset.masteryCategory)));
}

function updateReviewButton() {
  const count=state.quizProgress.missed.filter(id=>{
    const q=quizQuestions.find(question=>question.id===id);
    return q&&(state.quizCategory==="all"||q.category===state.quizCategory)&&questionMatchesQuizPath(q)&&difficultyRank[q.level]<=difficultyRank[state.difficulty];
  }).length;
  $("missedCount").textContent=count;
  $("reviewMissedBtn").disabled=!count;
  $("reviewMissedBtn").classList.toggle("active",state.quizReview);
}

function renderQuizQuestion() {
  const q=state.scenario;
  const category=quizCategories[q.category];
  state.quizOptions=buildQuizOptions(q);
  $("quizCategoryBadge").textContent=category.label.toUpperCase();
  $("quizLevelBadge").textContent=quizLevelLabel(q.level).toUpperCase();
  $("quizLevelBadge").className=`quiz-level ${q.level}`;
  $("quizContext").textContent=q.context;
  $("quizQuestion").textContent=q.prompt;
  $("quizProgressText").textContent=`Lesson ${state.quizCyclePosition} of ${state.quizCycleTotal}${state.quizReview?" · review":""}`;
  $("quizProgressBar").style.width=`${Math.max(6,(state.quizCyclePosition/state.quizCycleTotal)*100)}%`;

  if(q.champion) {
    $("quizVisual").className="quiz-visual champion-visual";
    $("quizVisual").innerHTML=`<img src="${portrait(q.champion)}" alt=""><span>${q.champion}</span>`;
  } else {
    $("quizVisual").className=`quiz-visual ${q.category}`;
    $("quizVisual").innerHTML=`<small>${category.short}</small><span>${q.visual||category.icon}</span>`;
  }

  if(state.difficulty==="easy") {
    $("quizHint").classList.remove("hidden");
    $("quizHint").innerHTML=`<b>Learning clue:</b> ${q.hint}`;
  } else if(state.difficulty==="medium") {
    $("quizHint").classList.remove("hidden");
    $("quizHint").innerHTML=`<b>Think about:</b> ${q.hint}`;
  } else {
    $("quizHint").classList.add("hidden");
  }

  $("quizChoices").innerHTML=state.quizOptions.map((option,index)=>`<button class="quiz-answer" data-index="${index}">
    <span>${String.fromCharCode(65+index)}</span><b>${option}</b>
  </button>`).join("");
  document.querySelectorAll("#quizChoices .quiz-answer").forEach(btn=>btn.addEventListener("click",()=>answerQuiz(Number(btn.dataset.index))));
  $("quizFeedback").className="quiz-feedback hidden";
}

function nextQuiz() {
  prepareNextMission();
  if(!state.quizQueue.length) makeQuizQueue();
  if(!state.quizQueue.length) return;
  state.scenario=state.quizQueue.shift();
  state.quizCyclePosition+=1;
  renderQuizQuestion();
  renderMastery();
}

function setQuizCategory(category) {
  state.quizCategory=category;
  state.quizReview=false;
  document.querySelectorAll("#quizCategoryControl .category-tab").forEach(btn=>btn.classList.toggle("active",btn.dataset.category===category));
  state.quizQueue=[];
  state.answered=false;
  nextQuiz();
}

function updateQuizPathUI() {
  document.querySelectorAll("#quizPathControl .path-option").forEach(btn=>btn.classList.toggle("active",btn.dataset.quizPath===state.quizPath));
  $("championPicker").classList.toggle("hidden",state.quizPath!=="champion");
  $("championSelect").value=state.quizChampion;
  $("selectedChampionPortrait").src=portrait(state.quizChampion);
  $("selectedChampionPortrait").alt=`${state.quizChampion} portrait`;
  $("selectedChampionName").textContent=state.quizChampion;
  const pathCount=quizQuestions.filter(q=>q.focus?.includes(state.quizChampion)).length;
  $("selectedChampionLessonCount").textContent=`${pathCount} focused lessons · ${championPaths[state.quizChampion].role}`;
  $("quizQuestionCount").textContent=state.quizPath==="all"?quizQuestions.length:pathCount;
  $("quizQuestionCountLabel").textContent=state.quizPath==="all"?"lessons in the full library":`${state.quizChampion} lessons in this path`;
}

function resetQuizPath() {
  state.quizReview=false;
  state.quizQueue=[];
  state.answered=false;
  updateQuizPathUI();
  nextQuiz();
}

function setQuizPath(path) {
  if(path===state.quizPath)return;
  state.quizPath=path;
  resetQuizPath();
}

function populateChampionPicker() {
  $("championSelect").innerHTML=Object.entries(championPaths).map(([name,path])=>
    `<option value="${name}">${name} · ${path.role}</option>`
  ).join("");
  $("hubQuizQuestionCount").textContent=quizQuestions.length;
  updateQuizPathUI();
}

function champCard(name) {
  const c=getChampion(name);
  const desc = state.difficulty==="hard" ? c.role : `${c.role} · ${c.desc}`;
  return `<div class="champ-card">
    <img class="champ-avatar" src="${portrait(name)}" alt="${name}" onerror="this.style.visibility='hidden'">
    <div><b>${name}</b><span>${desc}</span></div>
  </div>`;
}

function scoreChampion(champ,s) {
  let score=0,reasons=[];
  s.priorities.forEach((priority,index)=>{
    const weight=4-index;
    const hit=champ.tags.includes(priority)||champ.damage===priority||(priority==="AP"&&champ.damage==="Mixed");
    if(hit){score+=weight;reasons.push(`Provides ${labelForTag(priority).toLowerCase()}`);}
  });
  if(s.threats.includes("dive")&&champ.tags.includes("antiDive")){score+=2;reasons.push("Directly answers enemy dive");}
  if(s.threats.includes("engage")&&champ.tags.includes("peel")){score+=1.5;reasons.push("Can peel after enemy engage");}
  if(s.threats.includes("poke")&&champ.tags.includes("engage")){score+=2;reasons.push("Can force fights before poke wins");}
  if(s.threats.includes("range")&&champ.tags.includes("engage")){score+=1.5;reasons.push("Helps close distance");}
  if(s.threats.includes("frontline")&&champ.tags.includes("dps")){score+=1.5;reasons.push("Has sustained damage into frontline");}
  if(s.threats.includes("frontline")&&champ.tags.includes("tankKiller")){score+=2;reasons.push("Excellent into durable frontline");}
  if(s.threats.includes("scaling")&&champ.tags.includes("early")){score+=1;reasons.push("Can pressure before the enemy scales");}
  return {score,reasons};
}

function buildCompChoices(s) {
  const ranked=champions.filter(c=>c.role===s.role)
    .map(c=>({champ:c,...scoreChampion(c,s)}))
    .sort((a,b)=>b.score-a.score);
  const best=ranked[0];
  const count = state.difficulty==="easy" ? 4 : 5;
  return shuffle([best,...shuffle(ranked.slice(1)).slice(0,count-1)]);
}

function renderChoice(item, targetId, counterMode=false) {
  const c = counterMode ? getChampion(item.name) : item.champ;
  const name = c.name;
  const descriptionVisible = state.difficulty==="easy";
  const desc = counterMode ? c.desc : c.desc;
  return `<button class="choice" data-name="${name}">
    <img class="choice-portrait" src="${portrait(name)}" alt="${name}">
    <div class="choice-body">
      <span class="role">${c.role}</span>
      <h3>${name}</h3>
      ${descriptionVisible ? `<p>${desc}</p>` : `<p>${state.difficulty==="medium" ? "Read the kit and matchup." : "No hints."}</p>`}
    </div>
  </button>`;
}

function renderCompScenario() {
  const s=state.scenario;
  $("roleLabel").textContent=s.role;
  $("allyTeam").innerHTML=s.ally.map(champCard).join("");
  $("enemyTeam").innerHTML=s.enemy.map(champCard).join("");

  const easy=state.difficulty==="easy";
  $("allyNeeds").innerHTML=easy ? s.priorities.slice(0,3).map(t=>`<span class="tag need">Need: ${labelForTag(t)}</span>`).join("") : "";
  $("enemyThreats").innerHTML=easy ? s.threats.slice(0,3).map(t=>`<span class="tag threat">${labelForTag(t)}</span>`).join("") : "";

  if(state.difficulty==="easy"){
    $("draftQuestion").textContent=`How do you add ${labelForTag(s.priorities[0]).toLowerCase()} while respecting enemy ${labelForTag(s.threats[0]).toLowerCase()}?`;
    $("scenarioHint").textContent=`Main draft needs: ${s.priorities.slice(0,2).map(labelForTag).join(" + ")}.`;
  } else if(state.difficulty==="medium"){
    $("draftQuestion").textContent="Read both compositions. Which job is missing from your team?";
    $("scenarioHint").textContent="Look at damage balance, who starts fights, who protects carries, and how each team wants to fight.";
  } else {
    $("draftQuestion").textContent="Complete the draft.";
    $("scenarioHint").textContent="No hints. Read the full composition.";
  }

  $("choices").innerHTML=state.choices.map(item=>renderChoice(item,"choices")).join("");
  document.querySelectorAll("#choices .choice").forEach(btn=>btn.addEventListener("click",()=>answerComp(btn.dataset.name)));
}

function nextComp() {
  let idx;
  do { idx=Math.floor(Math.random()*teamScenarios.length); }
  while(teamScenarios.length>1&&idx===state.compIndex);
  state.compIndex=idx;
  state.scenario=teamScenarios[idx];
  state.choices=buildCompChoices(state.scenario);
  renderCompScenario();
}

const allBanNames = ["Ornn","Malphite","Fiora","Gwen","Renekton","Sejuani","Jarvan IV","Vi","Kindred","Lillia","Orianna","Ahri","Viktor","Yasuo","Jayce","Jinx","Ezreal","Kai'Sa","Ashe","Samira","Nautilus","Lulu","Braum","Rakan","Zyra"];

function buildBans(exclude=[]) {
  return shuffle(allBanNames.filter(n=>!exclude.includes(n))).slice(0,10);
}
function banIcons(names) {
  return names.map(n=>`<div class="ban-icon" title="${n}"><img src="${portrait(n)}" alt="${n}"></div>`).join("");
}

function renderCounterScenario() {
  const s=state.scenario;
  $("counterRole").textContent=s.role;
  $("roleEmblem").textContent=s.role;
  $("assignedRoleText").textContent=roleNames[s.role];

  $("enemyPickCard").innerHTML=`
    <img class="enemy-large-portrait" src="${portrait(s.enemy)}" alt="${s.enemy}">
    <div>
      <span class="small-label">ENEMY ${s.role}</span>
      <h3>${s.enemy}</h3>
      <p>${state.difficulty==="hard" ? "Enemy champion locked." : s.enemyPattern}</p>
    </div>`;

  const bans=buildBans([s.enemy,...s.choices]);
  $("blueBans").innerHTML=banIcons(bans.slice(0,5));
  $("redBans").innerHTML=banIcons(bans.slice(5,10));

  if(state.difficulty==="easy") {
    $("counterHint").classList.remove("hidden");
    $("counterHint").innerHTML=`<strong>Counter clue:</strong> ${s.hint}`;
    $("counterDecisionText").textContent="Use the enemy's core gameplay pattern to identify the cleanest concept counter.";
  } else if(state.difficulty==="medium") {
    $("counterHint").classList.remove("hidden");
    $("counterHint").textContent="Identify what mechanic the enemy champion relies on, then choose the kit that interferes with it.";
    $("counterDecisionText").textContent="No matchup answer is shown. Think in mechanics, not champion reputation.";
  } else {
    $("counterHint").classList.add("hidden");
    $("counterDecisionText").textContent="No hints. Make the counter pick.";
  }

  const choices=shuffle(s.choices.map(name=>({name})));
  $("counterChoices").innerHTML=choices.map(item=>renderChoice(item,"counterChoices",true)).join("");
  document.querySelectorAll("#counterChoices .choice").forEach(btn=>btn.addEventListener("click",()=>answerCounter(btn.dataset.name)));
}

function nextCounter() {
  let idx;
  do { idx=Math.floor(Math.random()*counterScenarios.length); }
  while(counterScenarios.length>1&&idx===state.counterIndex);
  state.counterIndex=idx;
  state.scenario=counterScenarios[idx];
  renderCounterScenario();
}

function savePlayerProgress() {
  state.playerProgress.score=state.score;
  try { localStorage.setItem("draftIqPlayerProgress",JSON.stringify(state.playerProgress)); }
  catch(error) { /* Keep session progression when persistent storage is unavailable. */ }
}

function playerLevel() {
  return Math.floor(state.playerProgress.xp/XP_PER_LEVEL)+1;
}

function rankForLevel(level) {
  if(level>=12)return "Draft Master";
  if(level>=8)return "Team Captain";
  if(level>=5)return "Shotcaller";
  if(level>=3)return "Draft Analyst";
  return "Draft Recruit";
}

function multiplierForStreak(streak) {
  if(streak>=8)return 2;
  if(streak>=5)return 1.5;
  if(streak>=3)return 1.25;
  return 1;
}

let toastTimer;
function showGameToast(icon,title,copy) {
  const toast=$("gameToast");
  toast.innerHTML=`<span>${icon}</span><div><b>${title}</b><small>${copy}</small></div>`;
  toast.classList.add("visible");
  clearTimeout(toastTimer);
  toastTimer=setTimeout(()=>toast.classList.remove("visible"),3600);
}

function renderProgression() {
  const p=state.playerProgress;
  const level=playerLevel();
  const levelXp=p.xp%XP_PER_LEVEL;
  $("playerLevel").textContent=level;
  $("rankTitle").textContent=rankForLevel(level);
  $("xpText").textContent=`${levelXp} / ${XP_PER_LEVEL} XP`;
  $("xpBar").style.width=`${(levelXp/XP_PER_LEVEL)*100}%`;

  const results=p.mission.results;
  const correct=results.filter(Boolean).length;
  $("missionPips").innerHTML=Array.from({length:5},(_,index)=>{
    const status=index>=results.length?"":results[index]?"correct":"wrong";
    return `<span class="${status}">${index<results.length?(results[index]?"✓":"×"):index+1}</span>`;
  }).join("");
  $("missionText").textContent=p.mission.complete
    ? p.mission.success?"Complete! +150 XP":`${correct}/4 — run it back`
    : `${correct}/4 correct · ${5-results.length} left`;

  const multiplier=multiplierForStreak(state.streak);
  $("comboMultiplier").textContent=`×${multiplier.toFixed(2).replace(/0$/,'')}`;
  $("comboWidget").classList.toggle("hot",multiplier>1);
  $("achievementList").innerHTML=achievementDefinitions.map(achievement=>{
    const unlocked=p.achievements.includes(achievement.id);
    return `<div class="achievement ${unlocked?"unlocked":"locked"}" title="${achievement.description}">
      <span>${unlocked?achievement.icon:"?"}</span><div><b>${achievement.name}</b><small>${unlocked?achievement.description:"Locked"}</small></div>
    </div>`;
  }).join("");
}

function unlockAchievements() {
  const p=state.playerProgress;
  const unlocked=achievementDefinitions.filter(achievement=>
    !p.achievements.includes(achievement.id)&&achievement.test(p)
  );
  unlocked.forEach(achievement=>p.achievements.push(achievement.id));
  return unlocked;
}

function awardRound(grade,mode=state.mode) {
  const correct=grade!=="D";
  if(correct) state.streak+=1;
  else state.streak=0;

  const multiplier=correct?multiplierForStreak(state.streak):1;
  const basePoints=grade==="A"?100:grade==="B"?65:0;
  const points=correct?Math.round(basePoints*multiplier):-(mode==="quiz"?10:20);
  const baseXp=grade==="A"?80:grade==="B"?55:15;
  const xpGain=Math.round(baseXp*({easy:1,medium:1.15,hard:1.3}[state.difficulty]));
  state.score=Math.max(0,state.score+points);

  const p=state.playerProgress;
  const previousLevel=Math.floor(p.xp/XP_PER_LEVEL)+1;
  p.xp+=xpGain;
  p.bestStreak=Math.max(p.bestStreak,state.streak);
  p.totals.answers+=1;
  if(correct)p.totals.correct+=1;
  p.modes[mode].answers+=1;
  if(correct)p.modes[mode].correct+=1;
  p.mission.results.push(correct);

  let missionBonus=0;
  if(p.mission.results.length===5) {
    p.mission.complete=true;
    p.mission.success=p.mission.results.filter(Boolean).length>=4;
    if(p.mission.success) {
      missionBonus=150;
      p.xp+=missionBonus;
      p.completedMissions+=1;
    }
  }

  const unlocked=unlockAchievements();
  const newLevel=Math.floor(p.xp/XP_PER_LEVEL)+1;
  savePlayerProgress();
  renderProgression();
  if(unlocked.length) {
    const achievement=unlocked[unlocked.length-1];
    showGameToast(achievement.icon,"Badge unlocked",achievement.name);
  } else if(p.mission.complete) {
    showGameToast(p.mission.success?"★":"↻",p.mission.success?"Mission complete":"Mission missed",p.mission.success?"Four correct answers earned 150 bonus XP.":"Start a fresh five-round run next.");
  } else if(newLevel>previousLevel) {
    showGameToast("↑",`Level ${newLevel}`,`New rank progress: ${rankForLevel(newLevel)}.`);
  }
  return {grade,points,xp:xpGain,missionBonus,multiplier};
}

function prepareNextMission() {
  const mission=state.playerProgress.mission;
  if(!mission.complete)return;
  state.playerProgress.mission={results:[],complete:false,success:false};
  savePlayerProgress();
  renderProgression();
}

function gradeResult(isBest,isGood=false) {
  return awardRound(isBest?"A":isGood?"B":"D");
}
function updateStats() {
  $("score").textContent=state.score;
  $("streak").textContent=state.streak;
  $("round").textContent=state.round;
  renderProgression();
}

function rewardText(reward) {
  const scorePart=reward.points>=0?`+${reward.points}`:`${reward.points}`;
  const combo=reward.multiplier>1?` · ×${reward.multiplier} combo`:"";
  const mission=reward.missionBonus?` · +${reward.missionBonus} mission XP`:"";
  return `${scorePart} points · +${reward.xp} XP${combo}${mission}`;
}

function showResult({grade,reward,kicker,title,good,heading1,html1,html2,html3,lesson,bestName,selectedName,containerSelector}) {
  const panel=$("resultPanel");
  panel.className=`result-panel ${good?"good":"bad"}`;
  $("resultKicker").textContent=kicker;
  $("resultTitle").textContent=title;
  $("resultGrade").textContent=grade;
  $("resultReward").textContent=rewardText(reward);
  $("explainHeading1").textContent=heading1;
  $("explain1").innerHTML=html1;
  $("explain2").innerHTML=html2;
  $("explain3").innerHTML=html3;
  $("teachingPoint").textContent=lesson;

  document.querySelectorAll(`${containerSelector} .choice`).forEach(btn=>{
    btn.disabled=true;
    if(btn.dataset.name===selectedName) btn.classList.add(good?"correct":"wrong");
    if(btn.dataset.name===bestName) btn.classList.add("correct");
  });
  panel.scrollIntoView({behavior:"smooth",block:"nearest"});
}

function answerComp(name) {
  if(state.answered)return;
  state.answered=true;
  const selected=state.choices.find(x=>x.champ.name===name);
  const best=[...state.choices].sort((a,b)=>b.score-a.score)[0];
  const isBest=selected.champ.name===best.champ.name;
  const isGood=selected.score>=best.score-.5;
  const reward=gradeResult(isBest,isGood);
  const grade=reward.grade;
  updateStats();

  const selectedEval=scoreChampion(selected.champ,state.scenario);
  const misses=state.scenario.priorities.filter(p=>!selected.champ.tags.includes(p)&&selected.champ.damage!==p&&!(p==="AP"&&selected.champ.damage==="Mixed"));

  showResult({
    grade,
    reward,
    kicker:isBest?"BEST ANSWER":isGood?"VIABLE ANSWER":"DRAFT MISMATCH",
    title:isBest?`${name} is the cleanest fit here.`:isGood?`${name} works, but ${best.champ.name} fits a little better.`:`${name} is playable, but the draft needed a different job.`,
    good:isGood,
    heading1:"What your team needed",
    html1:`<p>Highest-value needs: <strong>${state.scenario.priorities.map(labelForTag).join(", ")}</strong>.</p><p>Enemy pressures: <strong>${state.scenario.threats.map(labelForTag).join(", ")}</strong>.</p>`,
    html2:`<p><strong>${name}</strong>: ${selected.champ.desc}</p>${selectedEval.reasons.length?`<p class="good-text">✓ ${selectedEval.reasons.join(". ")}.</p>`:""}${misses.length?`<p class="bad-text">Missing: ${misses.map(labelForTag).join(", ")}.</p>`:""}`,
    html3:`<p><strong>${best.champ.name}</strong>: ${best.champ.desc}</p><p class="good-text">✓ ${best.reasons.join(". ")}.</p><p>It solves more of the jobs the five-man composition needs.</p>`,
    lesson:state.scenario.teaching,
    bestName:best.champ.name,
    selectedName:name,
    containerSelector:"#choices"
  });
}

function answerCounter(name) {
  if(state.answered)return;
  state.answered=true;
  const s=state.scenario;
  const isBest=name===s.best;
  // Counter mode deliberately gives only A or D right now so the lesson is clear.
  const reward=gradeResult(isBest,false);
  const grade=reward.grade;
  updateStats();

  showResult({
    grade,
    reward,
    kicker:isBest?"COUNTER FOUND":"NOT THE CLEANEST COUNTER",
    title:isBest?`${name} attacks ${s.enemy}'s core pattern.`:`${name} can be played, but ${s.best} is the cleaner concept counter.`,
    good:isBest,
    heading1:`What ${s.enemy} wants`,
    html1:`<p>${s.enemyPattern}</p><p>The counter question is: <strong>which kit makes that pattern hardest to execute?</strong></p>`,
    html2:`<p><strong>${name}</strong></p><p class="${isBest?"good-text":"bad-text"}">${isBest?"✓":"✕"} ${s.reasons[name]}</p>`,
    html3:`<p><strong>${s.best}</strong></p><p class="good-text">✓ ${s.reasons[s.best]}</p><p>This is a mechanics-based teaching answer, not a claim that it has the highest live-patch win rate.</p>`,
    lesson:s.lesson,
    bestName:s.best,
    selectedName:name,
    containerSelector:"#counterChoices"
  });
}

function answerQuiz(index) {
  if(state.answered)return;
  state.answered=true;
  const q=state.scenario;
  const selected=state.quizOptions[index];
  const correct=selected===q.answer;
  const entry=state.quizProgress.questions[q.id]||{attempts:0,correct:0};
  entry.attempts+=1;
  if(correct) entry.correct+=1;
  state.quizProgress.questions[q.id]=entry;

  const missed=new Set(state.quizProgress.missed);
  if(correct) {
    missed.delete(q.id);
  } else {
    missed.add(q.id);
  }
  state.quizProgress.missed=[...missed];
  saveAcademyProgress();
  const reward=awardRound(correct?"A":"D","quiz");
  updateStats();

  document.querySelectorAll("#quizChoices .quiz-answer").forEach((btn,buttonIndex)=>{
    btn.disabled=true;
    const option=state.quizOptions[buttonIndex];
    if(option===q.answer) btn.classList.add("correct");
    else if(buttonIndex===index) btn.classList.add("wrong");
  });

  const feedback=$("quizFeedback");
  feedback.className=`quiz-feedback ${correct?"good":"bad"}`;
  $("quizFeedbackMark").textContent=correct?"✓":"!";
  $("quizFeedbackKicker").textContent=correct?"CORRECT READ":"LEARNING MOMENT";
  $("quizFeedbackTitle").textContent=correct?"That's the idea.":`The better answer: ${q.answer}`;
  $("quizExplanation").textContent=q.explanation;
  $("quizTakeaway").textContent=q.takeaway;
  $("quizReward").textContent=rewardText(reward);
  renderMastery();
  updateReviewButton();
  feedback.scrollIntoView({behavior:"smooth",block:"nearest"});
}

function newScenario() {
  prepareNextMission();
  state.answered=false;
  $("resultPanel").className="result-panel hidden";
  if(state.mode==="comp") nextComp();
  else if(state.mode==="counter") nextCounter();
  else nextQuiz();
  updateStats();
}

function setMode(mode) {
  state.mode=mode;
  $("gameHub").classList.add("hidden");
  $("gameControls").classList.remove("hidden");
  $("difficultyInfo").classList.remove("hidden");
  $("compGame").classList.toggle("hidden",mode!=="comp");
  $("counterGame").classList.toggle("hidden",mode!=="counter");
  $("quizGame").classList.toggle("hidden",mode!=="quiz");
  $("newScenarioBtn").textContent=mode==="quiz"?"New lesson":"New scenario";
  state.round=1;
  if(mode==="quiz") state.quizQueue=[];
  difficultyCopy();
  newScenario();
}

function showHub() {
  state.mode="hub";
  state.answered=false;
  $("gameHub").classList.remove("hidden");
  $("gameControls").classList.add("hidden");
  $("difficultyInfo").classList.add("hidden");
  $("compGame").classList.add("hidden");
  $("counterGame").classList.add("hidden");
  $("quizGame").classList.add("hidden");
  $("resultPanel").className="result-panel hidden";
  window.scrollTo({top:0,behavior:"smooth"});
}

function setDifficulty(difficulty) {
  state.difficulty=difficulty;
  document.querySelectorAll("#difficultyControl .segment").forEach(b=>b.classList.toggle("active",b.dataset.difficulty===difficulty));
  if(state.mode==="quiz") state.quizQueue=[];
  difficultyCopy();
  newScenario();
}

document.querySelectorAll("[data-launch-mode]").forEach(btn=>btn.addEventListener("click",()=>setMode(btn.dataset.launchMode)));
document.querySelectorAll("#difficultyControl .segment").forEach(btn=>btn.addEventListener("click",()=>setDifficulty(btn.dataset.difficulty)));
document.querySelectorAll("#quizCategoryControl .category-tab").forEach(btn=>btn.addEventListener("click",()=>setQuizCategory(btn.dataset.category)));
document.querySelectorAll("#quizPathControl .path-option").forEach(btn=>btn.addEventListener("click",()=>setQuizPath(btn.dataset.quizPath)));
$("championSelect").addEventListener("change",event=>{
  state.quizChampion=event.target.value;
  resetQuizPath();
});
$("backToHubBtn").addEventListener("click",showHub);
$("newScenarioBtn").addEventListener("click",newScenario);
$("reviewMissedBtn").addEventListener("click",()=>{
  if($("reviewMissedBtn").disabled)return;
  state.quizReview=!state.quizReview;
  state.quizQueue=[];
  state.answered=false;
  nextQuiz();
});
$("nextQuizBtn").addEventListener("click",()=>{
  state.round+=1;
  state.answered=false;
  nextQuiz();
  $("quizGame").scrollIntoView({behavior:"smooth",block:"start"});
});
$("nextRoundBtn").addEventListener("click",()=>{
  state.round+=1;
  newScenario();
  window.scrollTo({top:0,behavior:"smooth"});
});

populateChampionPicker();
renderMastery();
updateReviewButton();
updateStats();
showHub();
