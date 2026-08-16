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

const labels = {
  AP:"Magic damage",AD:"Physical damage",frontline:"Frontline",engage:"Engage",peel:"Peel",
  antiDive:"Anti-dive",teamfight:"Teamfight",scaling:"Scaling",dps:"Sustained DPS",
  sideline:"Side lane",early:"Early pressure",range:"Range",pick:"Pick threat",
  dive:"Dive",zone:"Zone control",poke:"Poke",combo:"Combo engage",frontToBack:"Front-to-back"
};

const roleNames = {TOP:"Top Lane",JUNGLE:"Jungle",MID:"Mid Lane",ADC:"Bot / ADC",SUPPORT:"Support"};
const $ = id => document.getElementById(id);
const getChampion = name => champions.find(c => c.name === name);

let state = {
  mode:"comp",
  difficulty:"easy",
  score:0,
  streak:0,
  round:1,
  compIndex:-1,
  counterIndex:-1,
  answered:false,
  scenario:null,
  choices:[]
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
  const copy = {
    easy:"<strong>Easy:</strong> Draft needs, enemy threats and champion descriptions are shown. Focus on learning the concepts.",
    medium:"<strong>Medium:</strong> Explicit need/threat tags disappear and choice descriptions are hidden. You still get one directional hint.",
    hard:"<strong>Hard:</strong> No draft hints, no need tags and no choice descriptions. Read the champions and solve the draft yourself."
  };
  $("difficultyInfo").innerHTML = copy[state.difficulty];
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

function gradeResult(isBest,isGood=false) {
  if(isBest){state.score+=100;state.streak+=1;return "A";}
  if(isGood){state.score+=65;state.streak+=1;return "B";}
  state.score=Math.max(0,state.score-20);state.streak=0;return "D";
}
function updateStats() {
  $("score").textContent=state.score;
  $("streak").textContent=state.streak;
  $("round").textContent=state.round;
}

function showResult({grade,kicker,title,good,heading1,html1,html2,html3,lesson,bestName,selectedName,containerSelector}) {
  const panel=$("resultPanel");
  panel.className=`result-panel ${good?"good":"bad"}`;
  $("resultKicker").textContent=kicker;
  $("resultTitle").textContent=title;
  $("resultGrade").textContent=grade;
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
  const grade=gradeResult(isBest,isGood);
  updateStats();

  const selectedEval=scoreChampion(selected.champ,state.scenario);
  const misses=state.scenario.priorities.filter(p=>!selected.champ.tags.includes(p)&&selected.champ.damage!==p&&!(p==="AP"&&selected.champ.damage==="Mixed"));

  showResult({
    grade,
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
  const grade=gradeResult(isBest,false);
  updateStats();

  showResult({
    grade,
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

function newScenario() {
  state.answered=false;
  $("resultPanel").className="result-panel hidden";
  if(state.mode==="comp") nextComp();
  else nextCounter();
  updateStats();
}

function setMode(mode) {
  state.mode=mode;
  document.querySelectorAll("#modeControl .segment").forEach(b=>b.classList.toggle("active",b.dataset.mode===mode));
  $("compGame").classList.toggle("hidden",mode!=="comp");
  $("counterGame").classList.toggle("hidden",mode!=="counter");
  state.round=1;
  state.streak=0;
  newScenario();
}

function setDifficulty(difficulty) {
  state.difficulty=difficulty;
  document.querySelectorAll("#difficultyControl .segment").forEach(b=>b.classList.toggle("active",b.dataset.difficulty===difficulty));
  difficultyCopy();
  newScenario();
}

document.querySelectorAll("#modeControl .segment").forEach(btn=>btn.addEventListener("click",()=>setMode(btn.dataset.mode)));
document.querySelectorAll("#difficultyControl .segment").forEach(btn=>btn.addEventListener("click",()=>setDifficulty(btn.dataset.difficulty)));
$("newScenarioBtn").addEventListener("click",newScenario);
$("nextRoundBtn").addEventListener("click",()=>{
  state.round+=1;
  newScenario();
  window.scrollTo({top:0,behavior:"smooth"});
});

difficultyCopy();
newScenario();
