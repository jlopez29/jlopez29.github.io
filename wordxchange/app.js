(() => {
  "use strict";

  const ROUND_SECONDS = 30;
  const MAX_WORD_LENGTH = 8;
  const DICTIONARY_URL = "https://raw.githubusercontent.com/dwyl/english-words/master/words_dictionary.json";
  const starterWords = ["stone", "heart", "smart", "plant", "crate", "light", "bread", "flame", "shore", "clear"];
  const fallbackWords = `
    a i an am as at be by do go he if in is it me my no of oh on or so to up us we
    ad add aid aim air ale all and ant any ape arc are arm art ash ask ate awe axe bad bag ban bar bat bay bed bee beg bet bid big bin bit bog bow box boy bud bug bun bus buy bye cab can cap car cat cod cop cot cow cry cup cut dad dam day den did die dig dim din dip dog dot dry due dug ear eat eel egg ego elf elm end era eve eye fan far fat fed fee few fig fin fit fix fly fog for fox fun fur gap gas gel gem get gig gin god gum gun gut guy had ham has hat hay hen her hid him hip hit hog hop hot how hub hug hut ice ill ink jam jar jaw jet job jog joy key kid kit lab lad lag lap law lay led leg let lid lie lip lit log lot low mad man map mat may men met mix mob mop mud mug nap net new nod nor not now nut oak odd oil old one opt ore owl own pad pan pat paw pay pea pen pet pie pig pin pit pod pop pot pot put rag ram ran rat raw ray red rid rig rim rip rob rod rot row rub rug run sad sag sat saw say sea see set sew shy sin sip sir sit ski sky sob son sun tab tag tan tap tar tea ten the tie tin tip toe ton top toy try tub tug two use van vet war was wax way web wet who why win wit won wow yes yet zip zoo
    able ache acid acre acts aged also area army away baby back bake bald ball band bank bare bark barn base bath bats beam bean bear beat been beer bell belt bend bent best bill bind bird bite blow blue boat body bold bone book boom boot bore born boss bowl bulk burn bush busy cake call calm came camp card care cart case cash cast cave cell chat chip city clay clip club coal coat code cold come cook cool cope copy core cost crew crop dark data date dawn days dead deal dear debt deck deep deer desk dial diet dirt dish disk does done door dose down draw drop drug drum duck dull duty each earn ease east easy edge else even ever face fact fade fail fair fall fame farm fast fate fear feed feel feet fell felt file fill film find fine fire firm fish five flat flow fold food foot form fort four free frog from fuel full gain game gate gave gear gift girl give glad goal goes gold golf gone good gray grew grow hair half hall hand hang hard harm hate have head heal hear heat held help hero hide high hike hill hint hire hold hole holy home hope host hour huge hunt hurt idea into iron item join jump just keep kept kick kind king kiss knew know lack lake land last late lead leaf lean left lens life lift like line link list live load loan lock long look lord lose loss lost love luck made mail main make male many mark mass meal mean meat meet menu mere mild mile milk mind mine miss moon more most move much must name near neck need nest news next nice nine none nose note okay once open over pace pack page paid pain pair pale park part past path peak pear pick pile pink pipe plan plane plans plant plate play plot plug poem pole pool poor port pose post pull pure push race rain rank rare rate read real rent rest rice rich ride ring rise risk road rock role roof room rose rule safe said sail sale salt same sand save seat seed seek seem seen self sell send shop shot show shut sick side sign site size skin slip slow snow soft sold sole some song soon sort soul spot star stars start stay stem step stop stone store story suite sweet table take tale talk tall tank team tear tell tend tent term test text than that them then thin thing think this tide tidy tile time tiny told tone tool tour town tree trip true tune turn type unit upon used user vast very view vote wage wait wake walk wall want warm wash wave weak wear week well went were west what when wide wife wild will wind wing wish wood word wore work yard year zone
    alone atone clone clove glove globe slope slate state stake stale scale scare share shark sharp spark spare space spade shade shake shame shape shave shelf shell shift shine shirt shock shoot short shore shown sight since skill sleep slice slide small smell smile smoke snake solid sound south speak speed spend spice spike spine split sport stack stage stain stair stamp stand steam steel steep stick still stock stole stood storm stove strap straw strip stuck style sugar super swing sword thank their theme there these thick threw throw tight today total touch tough tower track trade train treat trend trial tribe trick truck truly trust truth twice under upper value visit voice waste watch water wheel where which while white whole woman world write young
    create planet plates please player played bright flight slight fright lights plants hearts heated heater smartly starter stated states stones stoned cloned gloves globes shores shared shares clears learns breads flames framed frames traced traces crates crane cranes
  `.trim().split(/\s+/);

  const dictionary = new Set(fallbackWords.map((word) => word.toLowerCase()));
  let dictionaryExpanded = false;
  let currentWord = "stone";
  let usedWords = new Set();
  let chain = [];
  let score = 0;
  let timeLeft = ROUND_SECONDS;
  let selectedEdit = null;
  let timerId = null;
  let playing = false;
  let feedbackTimer = null;

  const elements = {
    menuScreen: document.querySelector("#menu-screen"),
    gameScreen: document.querySelector("#game-screen"),
    gameOverScreen: document.querySelector("#game-over-screen"),
    startButton: document.querySelector("#start-button"),
    replayButton: document.querySelector("#replay-button"),
    menuButton: document.querySelector("#menu-button"),
    score: document.querySelector("#score"),
    bestScore: document.querySelector("#best-score"),
    timer: document.querySelector("#timer"),
    timerWrap: document.querySelector("#timer-wrap"),
    timerProgress: document.querySelector("#timer-progress"),
    board: document.querySelector("#word-board"),
    keyboard: document.querySelector("#keyboard"),
    deleteButton: document.querySelector("#delete-button"),
    feedback: document.querySelector("#feedback"),
    instruction: document.querySelector("#instruction"),
    chainList: document.querySelector("#chain-list"),
    chainCount: document.querySelector("#chain-count"),
    finalScore: document.querySelector("#final-score"),
    resultCopy: document.querySelector("#result-copy"),
    finalChain: document.querySelector("#final-chain"),
    dictionaryStatus: document.querySelector("#dictionary-status"),
    rulesButton: document.querySelector("#rules-button"),
    rulesDialog: document.querySelector("#rules-dialog"),
    dialogClose: document.querySelector("#dialog-close"),
    dialogAction: document.querySelector("#dialog-action")
  };

  function getBestScore() {
    try {
      return Number(localStorage.getItem("wordxchange-best") || 0);
    } catch {
      return 0;
    }
  }

  function setBestScore(value) {
    try {
      localStorage.setItem("wordxchange-best", String(value));
    } catch {
      // The game still works when storage is unavailable.
    }
  }

  function switchScreen(target) {
    [elements.menuScreen, elements.gameScreen, elements.gameOverScreen].forEach((screen) => {
      screen.classList.toggle("is-active", screen === target);
    });
  }

  function startGame() {
    clearInterval(timerId);
    currentWord = starterWords[Math.floor(Math.random() * starterWords.length)];
    usedWords = new Set([currentWord]);
    chain = [currentWord];
    score = 0;
    timeLeft = ROUND_SECONDS;
    selectedEdit = null;
    playing = true;
    elements.score.textContent = "0";
    elements.bestScore.textContent = String(getBestScore());
    elements.feedback.textContent = "";
    switchScreen(elements.gameScreen);
    renderBoard();
    renderChain();
    updateTimer();
    window.setTimeout(beginTimer, 350);
  }

  function beginTimer() {
    clearInterval(timerId);
    timerId = window.setInterval(() => {
      if (!playing) return;
      timeLeft -= 1;
      updateTimer();
      if (timeLeft <= 0) endGame();
    }, 1000);
  }

  function updateTimer() {
    const circumference = 125.66;
    elements.timer.textContent = String(timeLeft);
    elements.timerProgress.style.strokeDashoffset = String(circumference * (1 - timeLeft / ROUND_SECONDS));
    elements.timerWrap.classList.toggle("is-low", timeLeft <= 8);
  }

  function renderBoard() {
    elements.board.replaceChildren();
    const characters = [...currentWord.toUpperCase()];

    for (let index = 0; index <= characters.length; index += 1) {
      const addButton = document.createElement("button");
      addButton.type = "button";
      addButton.className = "add-letter";
      addButton.textContent = "+";
      addButton.setAttribute("aria-label", `Add a letter ${index === 0 ? "before the word" : index === characters.length ? "after the word" : `between ${characters[index - 1]} and ${characters[index]}`}`);
      if (selectedEdit?.type === "add" && selectedEdit.index === index) addButton.classList.add("is-selected");
      addButton.addEventListener("click", () => selectEdit("add", index));
      elements.board.append(addButton);

      if (index < characters.length) {
        const tile = document.createElement("button");
        tile.type = "button";
        tile.className = "letter-tile";
        tile.textContent = characters[index];
        tile.style.setProperty("--i", String(index));
        tile.setAttribute("aria-label", `Select ${characters[index]} to replace or remove`);
        if (selectedEdit?.type === "replace" && selectedEdit.index === index) tile.classList.add("is-selected");
        tile.addEventListener("click", () => selectEdit("replace", index));
        addLongPressDelete(tile, index);
        elements.board.append(tile);
      }
    }

    updateEditControls();
  }

  function selectEdit(type, index) {
    if (!playing) return;
    selectedEdit = { type, index };
    renderBoard();
    if (type === "replace") {
      elements.instruction.textContent = `Choose a letter to replace ${currentWord[index].toUpperCase()}.`;
    } else {
      elements.instruction.textContent = "Choose the letter you want to add.";
    }
  }

  function updateEditControls() {
    const canDelete = selectedEdit?.type === "replace" && currentWord.length > 2;
    elements.deleteButton.disabled = !canDelete;
  }

  function useLetter(letter) {
    if (!playing) return;
    if (!selectedEdit) {
      showFeedback("Select a letter or plus sign first.", "error");
      shakeBoard();
      return;
    }

    const normalizedLetter = letter.toLowerCase();
    const index = selectedEdit.index;
    const candidate = selectedEdit.type === "replace"
      ? `${currentWord.slice(0, index)}${normalizedLetter}${currentWord.slice(index + 1)}`
      : `${currentWord.slice(0, index)}${normalizedLetter}${currentWord.slice(index)}`;
    tryWord(candidate);
  }

  function removeSelectedLetter() {
    if (!playing || selectedEdit?.type !== "replace" || currentWord.length <= 2) return;
    const index = selectedEdit.index;
    tryWord(`${currentWord.slice(0, index)}${currentWord.slice(index + 1)}`);
  }

  function tryWord(candidate) {
    if (candidate === currentWord) {
      rejectMove("Change at least one letter.");
      return;
    }
    if (candidate.length > MAX_WORD_LENGTH) {
      rejectMove(`Words can be up to ${MAX_WORD_LENGTH} letters long.`);
      return;
    }
    if (usedWords.has(candidate)) {
      rejectMove("That word is already in your chain.");
      return;
    }
    if (!dictionary.has(candidate)) {
      rejectMove(dictionaryExpanded ? "That word isn't in the dictionary." : "That word isn't in the current library.");
      return;
    }

    currentWord = candidate;
    usedWords.add(candidate);
    chain.push(candidate);
    score += 1;
    timeLeft = ROUND_SECONDS;
    selectedEdit = null;
    elements.score.textContent = String(score);
    elements.instruction.textContent = "Choose a letter to replace, or a gap to add one.";
    showFeedback(`${candidate.toUpperCase()} +1`, "success");
    renderBoard();
    renderChain();
    updateTimer();
    elements.board.classList.remove("is-success");
    void elements.board.offsetWidth;
    elements.board.classList.add("is-success");
  }

  function rejectMove(message) {
    showFeedback(message, "error");
    shakeBoard();
  }

  function shakeBoard() {
    elements.board.classList.remove("is-shaking");
    void elements.board.offsetWidth;
    elements.board.classList.add("is-shaking");
  }

  function showFeedback(message, type) {
    clearTimeout(feedbackTimer);
    elements.feedback.textContent = message;
    elements.feedback.className = `feedback is-${type}`;
    feedbackTimer = window.setTimeout(() => {
      elements.feedback.textContent = "";
      elements.feedback.className = "feedback";
    }, 2200);
  }

  function renderChain() {
    elements.chainList.replaceChildren();
    const visibleWords = chain.slice(-7);
    visibleWords.forEach((word) => elements.chainList.append(createWordChip(word)));
    elements.chainCount.textContent = `${chain.length} ${chain.length === 1 ? "word" : "words"}`;
  }

  function createWordChip(word) {
    const chip = document.createElement("span");
    chip.className = "chain-word";
    chip.textContent = word.toUpperCase();
    return chip;
  }

  function endGame() {
    playing = false;
    clearInterval(timerId);
    const best = Math.max(score, getBestScore());
    setBestScore(best);
    elements.finalScore.textContent = String(score);
    elements.resultCopy.textContent = score === 0
      ? "Your first move is waiting. Give the next chain another shot."
      : `You made ${score} ${score === 1 ? "exchange" : "exchanges"} across ${chain.length} words.`;
    elements.finalChain.replaceChildren();
    chain.forEach((word) => elements.finalChain.append(createWordChip(word)));
    switchScreen(elements.gameOverScreen);
  }

  function returnToMenu() {
    playing = false;
    clearInterval(timerId);
    switchScreen(elements.menuScreen);
  }

  function buildKeyboard() {
    ["QWERTYUIOP", "ASDFGHJKL", "ZXCVBNM"].forEach((rowLetters) => {
      const row = document.createElement("div");
      row.className = "keyboard-row";
      [...rowLetters].forEach((letter) => {
        const key = document.createElement("button");
        key.type = "button";
        key.className = "key";
        key.textContent = letter;
        key.setAttribute("aria-label", `Use letter ${letter}`);
        key.addEventListener("click", () => useLetter(letter));
        row.append(key);
      });
      elements.keyboard.append(row);
    });
  }

  function addLongPressDelete(tile, index) {
    let pressTimer = null;
    let didLongPress = false;
    const cancel = () => window.clearTimeout(pressTimer);
    tile.addEventListener("pointerdown", () => {
      didLongPress = false;
      pressTimer = window.setTimeout(() => {
        didLongPress = true;
        selectedEdit = { type: "replace", index };
        removeSelectedLetter();
      }, 600);
    });
    tile.addEventListener("pointerup", cancel);
    tile.addEventListener("pointerleave", cancel);
    tile.addEventListener("pointercancel", cancel);
    tile.addEventListener("click", (event) => {
      if (didLongPress) event.stopImmediatePropagation();
    }, true);
  }

  async function expandDictionary() {
    const controller = new AbortController();
    const timeout = window.setTimeout(() => controller.abort(), 15000);
    elements.dictionaryStatus.textContent = "Expanding the word library…";
    try {
      const response = await fetch(DICTIONARY_URL, { signal: controller.signal });
      if (!response.ok) throw new Error("Dictionary request failed");
      const words = await response.json();
      Object.keys(words).forEach((word) => {
        const cleanWord = word.toLowerCase();
        if (/^[a-z]{2,8}$/.test(cleanWord)) dictionary.add(cleanWord);
      });
      dictionaryExpanded = true;
      elements.dictionaryStatus.textContent = `${dictionary.size.toLocaleString()} words ready`;
    } catch {
      elements.dictionaryStatus.textContent = "Built-in word library ready · offline mode";
    } finally {
      window.clearTimeout(timeout);
    }
  }

  function showRules() {
    if (typeof elements.rulesDialog.showModal === "function") elements.rulesDialog.showModal();
    else elements.rulesDialog.setAttribute("open", "");
  }

  function closeRules() {
    if (typeof elements.rulesDialog.close === "function") elements.rulesDialog.close();
    else elements.rulesDialog.removeAttribute("open");
  }

  elements.startButton.addEventListener("click", startGame);
  elements.replayButton.addEventListener("click", startGame);
  elements.menuButton.addEventListener("click", returnToMenu);
  elements.deleteButton.addEventListener("click", removeSelectedLetter);
  elements.rulesButton.addEventListener("click", showRules);
  elements.dialogClose.addEventListener("click", closeRules);
  elements.dialogAction.addEventListener("click", closeRules);
  elements.rulesDialog.addEventListener("click", (event) => {
    if (event.target === elements.rulesDialog) closeRules();
  });
  document.addEventListener("keydown", (event) => {
    if (!playing || elements.rulesDialog.open) return;
    if (/^[a-z]$/i.test(event.key)) useLetter(event.key);
    if ((event.key === "Backspace" || event.key === "Delete") && selectedEdit?.type === "replace") removeSelectedLetter();
  });

  buildKeyboard();
  elements.bestScore.textContent = String(getBestScore());
  expandDictionary();
})();
