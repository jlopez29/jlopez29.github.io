(() => {
  "use strict";

  const CATEGORIES = window.RECERT_CATEGORIES;
  const QUESTIONS = window.RECERT_QUESTIONS;
  const FLASHCARDS = window.RECERT_FLASHCARDS || QUESTIONS.map((question) => ({
    id: `card_${question.id}`, category: question.category, prompt: question.stem,
    answer: `${question.correct}. ${question.explanation}`, pearl: question.pearl, source: question.source
  }));
  const STORAGE_KEY = "recert-ready-progress-v1";
  const DAY = 86400000;
  const $ = (selector, root = document) => root.querySelector(selector);
  const $$ = (selector, root = document) => [...root.querySelectorAll(selector)];
  const categoryMap = Object.fromEntries(CATEGORIES.map((category) => [category.id, category]));
  const questionMap = Object.fromEntries(QUESTIONS.map((question) => [question.id, question]));
  const todayKey = (date = new Date()) => date.toISOString().slice(0, 10);
  const shuffle = (items) => {
    const output = [...items];
    for (let index = output.length - 1; index > 0; index -= 1) {
      const swap = Math.floor(Math.random() * (index + 1));
      [output[index], output[swap]] = [output[swap], output[index]];
    }
    return output;
  };
  const safePercent = (correct, total) => total ? Math.round((correct / total) * 100) : null;
  const escapeHTML = (value) => String(value).replace(/[&<>'"]/g, (char) => ({"&":"&amp;","<":"&lt;",">":"&gt;","'":"&#39;",'"':"&quot;"}[char]));

  const defaultState = () => ({attempts: {}, events: [], sessions: [], cards: {}, streak: {days: 0, last: null}, xp: 0});
  function loadState() {
    try {
      return {...defaultState(), ...JSON.parse(localStorage.getItem(STORAGE_KEY) || "{}")};
    } catch (error) {
      return defaultState();
    }
  }
  let state = loadState();
  let selectedCategory = "all";
  let selectedLength = 5;
  let flashCategory = "all";
  let flashDeck = [];
  let flashIndex = 0;
  let activeSession = null;
  let timerId = null;
  let toastId = null;

  function saveState() {
    try { localStorage.setItem(STORAGE_KEY, JSON.stringify(state)); } catch (error) { /* App remains usable without storage. */ }
  }

  function updateStreak() {
    const today = todayKey();
    if (state.streak.last === today) return;
    const yesterday = todayKey(new Date(Date.now() - DAY));
    state.streak.days = state.streak.last === yesterday ? state.streak.days + 1 : 1;
    state.streak.last = today;
  }

  function statsForCategory(categoryId) {
    const ids = QUESTIONS.filter((question) => question.category === categoryId).map((question) => question.id);
    return ids.reduce((stats, id) => {
      const attempt = state.attempts[id] || {correct: 0, total: 0};
      stats.correct += attempt.correct;
      stats.total += attempt.total;
      return stats;
    }, {correct: 0, total: 0});
  }

  function totals() {
    return Object.values(state.attempts).reduce((sum, item) => ({correct: sum.correct + item.correct, total: sum.total + item.total}), {correct: 0, total: 0});
  }

  function weakestCategory() {
    const attempted = CATEGORIES.map((category) => ({category, ...statsForCategory(category.id)})).filter((item) => item.total > 0);
    if (!attempted.length) return CATEGORIES[0];
    attempted.sort((a, b) => (a.correct / a.total) - (b.correct / b.total) || b.category.weight - a.category.weight);
    return attempted[0].category;
  }

  function showToast(message) {
    const toast = $("#toast");
    toast.textContent = message;
    toast.classList.add("is-visible");
    clearTimeout(toastId);
    toastId = setTimeout(() => toast.classList.remove("is-visible"), 2200);
  }

  function routeTo(route) {
    if (route !== "session" && activeSession && !activeSession.finished) {
      if (!window.confirm("Leave this session? Current answers in this set will be lost.")) return;
      clearInterval(timerId);
      activeSession = null;
    }
    $$(".view").forEach((view) => view.classList.toggle("is-active", view.dataset.view === route));
    $$("[data-route]").forEach((button) => button.classList.toggle("is-active", button.dataset.route === route));
    if (route === "dashboard") renderDashboard();
    if (route === "practice") renderPractice();
    if (route === "flashcards") renderFlashcards();
    if (route === "insights") renderInsights();
    window.scrollTo({top: 0, behavior: "smooth"});
    $("#app").focus({preventScroll: true});
  }

  function renderBlueprint() {
    $("#blueprintList").innerHTML = CATEGORIES.map((category) => `
      <div class="blueprint-row" style="--dot:${category.color}"><i></i><span title="${escapeHTML(category.name)}">${escapeHTML(category.name)}</span><b>${category.weight}%</b></div>
    `).join("");
    const curriculum = window.RECERT_CURRICULUM || {concepts: FLASHCARDS.length};
    $("#curriculumStats").innerHTML = [
      [QUESTIONS.length,"clinical questions"],[FLASHCARDS.length,"recall cards"],[curriculum.concepts,"core concepts"],[15,"reference hubs"]
    ].map(([value,label]) => `<div><strong>${value}</strong><span>${label}</span></div>`).join("");
    $("#referenceLibrary").innerHTML = CATEGORIES.map((category) => {
      const source = window.RECERT_REFERENCES?.[category.id];
      return source ? `<a href="${source.url}" target="_blank" rel="noreferrer"><span>${escapeHTML(category.name)}</span><small>${escapeHTML(source.label)} ↗</small></a>` : "";
    }).join("");
  }

  function renderDashboard() {
    const all = totals();
    const accuracy = safePercent(all.correct, all.total);
    const focus = weakestCategory();
    const weekAgo = Date.now() - (7 * DAY);
    const weeklyEvents = state.events.filter((event) => event.time >= weekAgo);
    $("#headerStreak").textContent = state.streak.days;
    $("#questionCount").textContent = `${QUESTIONS.length} questions + ${FLASHCARDS.length} cards`;
    $("#heroWeekly").textContent = weeklyEvents.length;
    $("#heroAccuracy").textContent = accuracy === null ? "—" : `${accuracy}%`;
    $("#heroMastery").textContent = accuracy === null ? "Start learning" : accuracy >= 80 ? "Strong foundation" : accuracy >= 65 ? "Building steadily" : "Growth in progress";
    $("#heroRing").style.setProperty("--value", accuracy || 0);
    $("#heroFocus").textContent = focus.name;
    $("#heroFocusReason").textContent = all.total ? "Your best next opportunity" : "Highest blueprint weight";
    $("#dueCount").textContent = `${dueCards().length} due`;
    const counts = Array.from({length: 7}, (_, offset) => {
      const key = todayKey(new Date(Date.now() - ((6 - offset) * DAY)));
      return state.events.filter((event) => todayKey(new Date(event.time)) === key).length;
    });
    const max = Math.max(...counts, 1);
    $("#weeklyBars").innerHTML = counts.map((count) => `<i style="height:${Math.max(3, (count / max) * 26)}px"></i>`).join("");
  }

  function renderPractice() {
    $("#bankCount").textContent = QUESTIONS.length;
    $("#categoryPicker").innerHTML = [
      `<button class="category-option ${selectedCategory === "all" ? "is-selected" : ""}" type="button" data-category="all" style="--dot:var(--teal)"><i></i><span><b>All categories</b><small>Blueprint weighted</small></span></button>`,
      ...CATEGORIES.map((category) => `<button class="category-option ${selectedCategory === category.id ? "is-selected" : ""}" type="button" data-category="${category.id}" style="--dot:${category.color}"><i></i><span><b>${escapeHTML(category.name)}</b><small>${QUESTIONS.filter((question) => question.category === category.id).length} questions · ${category.weight}%</small></span></button>`)
    ].join("");
    $("#sessionHistory").innerHTML = state.sessions.length ? state.sessions.slice(0, 6).map((session) => `
      <div class="history-row"><span><b>${escapeHTML(session.label)}</b><small>${new Date(session.time).toLocaleDateString(undefined,{month:"short",day:"numeric"})} · ${session.total} questions</small></span><strong>${session.accuracy}%</strong><small>${Math.round(session.seconds / 60)} min</small></div>
    `).join("") : `<div class="empty-state">Your completed practice and mock sessions will appear here.</div>`;
  }

  function dueCards() {
    const now = Date.now();
    return FLASHCARDS.filter((card) => !state.cards[card.id] || state.cards[card.id].due <= now);
  }

  function buildFlashDeck() {
    const available = FLASHCARDS.filter((card) => flashCategory === "all" || card.category === flashCategory);
    const due = available.filter((card) => !state.cards[card.id] || state.cards[card.id].due <= Date.now());
    flashDeck = shuffle(due.length ? due : available);
    flashIndex = 0;
  }

  function renderFlashcards(resetDeck = false) {
    const due = dueCards();
    $("#flashDueHead").textContent = due.length;
    $("#deckFilters").innerHTML = [`<button type="button" class="${flashCategory === "all" ? "is-selected" : ""}" data-deck="all"><span>All due cards</span><small>${due.length}</small></button>`, ...CATEGORIES.map((category) => {
      const count = due.filter((card) => card.category === category.id).length;
      return `<button type="button" class="${flashCategory === category.id ? "is-selected" : ""}" data-deck="${category.id}"><span>${escapeHTML(category.name)}</span><small>${count}</small></button>`;
    })].join("");
    const learned = FLASHCARDS.filter((card) => state.cards[card.id]?.level >= 2).length;
    const mastery = Math.round((learned / FLASHCARDS.length) * 100);
    $("#deckMastery").textContent = `${mastery}%`;
    $("#deckMasteryBar").style.width = `${mastery}%`;
    if (resetDeck || !flashDeck.length) buildFlashDeck();
    renderFlashCard();
  }

  function renderFlashCard() {
    if (!flashDeck.length) buildFlashDeck();
    const card = flashDeck[flashIndex % flashDeck.length];
    if (!card) return;
    const category = categoryMap[card.category];
    $("#flashCounter").textContent = `Card ${(flashIndex % flashDeck.length) + 1} of ${flashDeck.length}`;
    $("#flashCategory").textContent = category.name;
    $("#flashPrompt").textContent = card.prompt;
    $("#flashAnswer").textContent = `${card.answer} Memory hook: ${card.pearl}`;
    $("#flashSource").textContent = `${card.source?.label || "Review category reference"} ↗`;
    $("#flashSource").href = card.source?.url || "https://www.nccpa.net/resources/panre-panre-la-content-blueprint/";
    $("#flashHint").textContent = "Tap the card to reveal the answer";
    $("#flashcard").classList.remove("is-revealed");
    $("#confidenceControls").hidden = true;
  }

  function renderInsights() {
    const all = totals();
    const accuracy = safePercent(all.correct, all.total);
    const studied = new Set(state.events.map((event) => todayKey(new Date(event.time)))).size;
    const mastered = CATEGORIES.filter((category) => {
      const stats = statsForCategory(category.id);
      return stats.total >= 5 && stats.correct / stats.total >= .8;
    }).length;
    $("#insightSummary").innerHTML = [
      [all.total,"Questions answered"],[accuracy === null ? "—" : `${accuracy}%`,"Overall accuracy"],[state.streak.days,"Day streak"],[`${mastered}/15`,"Categories ≥80%"]
    ].map(([value,label]) => `<div class="summary-stat"><span>${label.toUpperCase()}</span><strong>${value}</strong><small>${label === "Questions answered" ? `${studied} active study days` : "Saved only on this device"}</small></div>`).join("");
    $("#strengthMap").innerHTML = CATEGORIES.map((category) => {
      const stats = statsForCategory(category.id);
      const score = safePercent(stats.correct, stats.total);
      return `<div class="mastery-row"><span>${escapeHTML(category.name)}</span><div class="mastery-track"><i style="width:${score || 0}%;--bar:${category.color}"></i></div><small>${score === null ? "—" : `${score}%`} / ${stats.total}</small></div>`;
    }).join("");
    const focus = weakestCategory();
    const focusStats = statsForCategory(focus.id);
    $("#nextPlan").innerHTML = `<p class="kicker">RECOMMENDED NEXT</p><h2>Strengthen ${escapeHTML(focus.name)}.</h2><p>${focusStats.total ? `Your current accuracy is ${safePercent(focusStats.correct,focusStats.total)}% across ${focusStats.total} attempts.` : `This is the highest-weight blueprint area and a strong place to begin.`}</p><ul><li>Complete a focused 10-question set</li><li>Rate the related recall cards</li><li>Re-test missed concepts after a delay</li></ul><button type="button" data-focus="${focus.id}">Start focused practice →</button>`;
    const days = Array.from({length: 14}, (_, offset) => new Date(Date.now() - ((13 - offset) * DAY)));
    const counts = days.map((day) => state.events.filter((event) => todayKey(new Date(event.time)) === todayKey(day)).length);
    const max = Math.max(...counts, 1);
    $("#trendChart").innerHTML = days.map((day,index) => `<div class="trend-day"><i title="${counts[index]} questions" style="height:${Math.max(3,(counts[index] / max) * 155)}px"></i><span>${index % 2 === 0 ? day.toLocaleDateString(undefined,{weekday:"narrow"}) : ""}</span></div>`).join("");
    $("#trendLabel").textContent = all.total ? `${counts.reduce((sum,count) => sum + count,0)} answers in this window` : "No sessions yet";
  }

  function chooseQuestions(count, category = "all", adaptive = false) {
    if (category !== "all") return shuffle(QUESTIONS.filter((question) => question.category === category)).slice(0, count);
    if (!adaptive) {
      const allocation = CATEGORIES.map((item) => {
        const exact = (item.weight / 100) * count;
        return {item, count: Math.floor(exact), remainder: exact - Math.floor(exact)};
      });
      let unassigned = count - allocation.reduce((sum, item) => sum + item.count, 0);
      [...allocation].sort((a, b) => b.remainder - a.remainder || b.item.weight - a.item.weight).forEach((item) => {
        if (unassigned > 0) { item.count += 1; unassigned -= 1; }
      });
      return shuffle(allocation.flatMap(({item, count: categoryCount}) =>
        shuffle(QUESTIONS.filter((question) => question.category === item.id)).slice(0, categoryCount)
      ));
    }
    const remaining = shuffle(QUESTIONS);
    const selected = [];
    while (selected.length < Math.min(count, remaining.length)) {
      const weights = CATEGORIES.map((item) => {
        const stats = statsForCategory(item.id);
        const accuracy = stats.total ? stats.correct / stats.total : .65;
        const multiplier = adaptive ? 1 + ((1 - accuracy) * 1.4) : 1;
        return {id: item.id, value: item.weight * multiplier};
      });
      const availableWeights = weights.filter((weight) => remaining.some((question) => question.category === weight.id));
      const totalWeight = availableWeights.reduce((sum, weight) => sum + weight.value, 0);
      let roll = Math.random() * totalWeight;
      const pickedCategory = availableWeights.find((weight) => (roll -= weight.value) <= 0) || availableWeights[0];
      const candidates = remaining.filter((question) => question.category === pickedCategory.id);
      const picked = candidates[Math.floor(Math.random() * candidates.length)];
      selected.push(picked);
      remaining.splice(remaining.indexOf(picked), 1);
    }
    return selected;
  }

  function prepareQuestion(question) {
    return {...question, choices: shuffle([{text: question.correct, correct: true}, ...question.distractors.map((text) => ({text, correct: false}))])};
  }

  function startSession(mode, count = 10, category = "all") {
    clearInterval(timerId);
    const isMock = mode === "mock";
    const isSprint = mode === "sprint";
    const questions = chooseQuestions(count, category, mode === "smart").map(prepareQuestion);
    activeSession = {mode, questions, index: 0, responses: [], started: Date.now(), selected: null, answered: false, finished: false, seconds: isSprint ? 180 : isMock ? 300 : null, category, combo: 0, bestCombo: 0};
    routeTo("session");
    renderSession();
    if (isSprint || isMock) startTimer();
  }

  function startTimer() {
    clearInterval(timerId);
    timerId = setInterval(() => {
      if (!activeSession || activeSession.finished) return clearInterval(timerId);
      activeSession.seconds -= 1;
      const timer = $("#questionTimer");
      if (timer) {
        timer.textContent = formatTime(activeSession.seconds);
        timer.classList.toggle("is-low", activeSession.seconds <= 30);
      }
      if (activeSession.seconds <= 0) {
        if (activeSession.mode === "sprint") finishSession();
        else submitMockAnswer(true);
      }
    }, 1000);
  }

  function formatTime(seconds) {
    const safe = Math.max(0, seconds);
    return `${String(Math.floor(safe / 60)).padStart(2,"0")}:${String(safe % 60).padStart(2,"0")}`;
  }

  function renderSession() {
    const session = activeSession;
    const current = session.questions[session.index];
    const progress = Math.round((session.index / session.questions.length) * 100);
    const isMock = session.mode === "mock";
    const modeLabel = {mock:"Mock quarter", sprint:"Clinical sprint", smart:"Smart practice", practice:"Custom practice"}[session.mode];
    $("#sessionShell").innerHTML = `
      ${session.mode === "sprint" ? `<div class="sprint-hud"><div><span>SCORE</span><b>${session.responses.filter((response) => response.correct).length * 100}</b></div><div><span>COMBO</span><b>×${session.combo}</b></div><div><span>TIME</span><b id="questionTimer">${formatTime(session.seconds)}</b></div></div>` : ""}
      <div class="session-topline"><div><div class="session-meta"><span>${modeLabel.toUpperCase()}</span><span>${session.index + 1} / ${session.questions.length}</span></div><div class="session-progress"><span style="width:${progress}%"></span></div></div><button class="close-session" type="button" aria-label="Close session">×</button></div>
      <section class="question-card">
        <div class="question-head"><span class="question-category">${escapeHTML(categoryMap[current.category].name)} · ${escapeHTML(current.task || "Clinical reasoning")}</span>${isMock ? `<span class="question-timer" id="questionTimer">${formatTime(session.seconds)}</span>` : `<span class="question-timer">${current.difficulty.toUpperCase()}</span>`}</div>
        <h1>${escapeHTML(current.stem)}</h1>
        <div class="answer-list">${current.choices.map((choice,index) => `<button class="answer-option" type="button" data-answer="${index}"><span>${String.fromCharCode(65 + index)}</span><b>${escapeHTML(choice.text)}</b></button>`).join("")}</div>
        <div id="feedbackSlot"></div>
        <div class="question-actions"><button class="primary-button" id="submitAnswer" type="button" disabled>${isMock ? "Lock answer" : session.mode === "sprint" ? "Submit" : "Check answer"} <span>→</span></button></div>
      </section>`;
  }

  function selectAnswer(index) {
    if (!activeSession || activeSession.answered) return;
    activeSession.selected = index;
    $$(".answer-option").forEach((button, buttonIndex) => button.classList.toggle("is-selected", buttonIndex === index));
    $("#submitAnswer").disabled = false;
  }

  function recordAttempt(question, correct, mode) {
    const item = state.attempts[question.id] || {correct: 0, total: 0};
    item.total += 1;
    item.correct += correct ? 1 : 0;
    item.last = Date.now();
    state.attempts[question.id] = item;
    state.events.push({time: Date.now(), category: question.category, correct, mode});
    state.events = state.events.slice(-600);
    state.xp += correct ? 20 : 7;
    updateStreak();
    saveState();
  }

  function submitAnswer() {
    const session = activeSession;
    if (session.mode === "mock") return submitMockAnswer(false);
    if (session.selected === null || session.answered) return;
    const question = session.questions[session.index];
    const correct = question.choices[session.selected].correct;
    session.answered = true;
    session.responses.push({id: question.id, category: question.category, correct});
    session.combo = correct ? session.combo + 1 : 0;
    session.bestCombo = Math.max(session.bestCombo, session.combo);
    recordAttempt(question, correct, session.mode);
    $$(".answer-option").forEach((button,index) => {
      button.disabled = true;
      if (question.choices[index].correct) button.classList.add("is-correct");
      else if (index === session.selected) button.classList.add("is-wrong");
    });
    if (session.mode === "sprint") {
      setTimeout(nextQuestion, correct ? 550 : 850);
      return;
    }
    $("#feedbackSlot").innerHTML = `<div class="feedback-panel ${correct ? "" : "is-wrong"}"><h2>${correct ? "You got it." : "Lock in the learning."}</h2><p>${escapeHTML(question.explanation)}</p><small>MEMORY HOOK · ${escapeHTML(question.pearl)}</small>${question.source ? `<a href="${question.source.url}" target="_blank" rel="noreferrer">${escapeHTML(question.source.label)} ↗</a>` : ""}</div>`;
    $("#submitAnswer").innerHTML = session.index === session.questions.length - 1 ? "See my results <span>→</span>" : "Next case <span>→</span>";
    $("#submitAnswer").disabled = false;
  }

  function submitMockAnswer(timedOut) {
    const session = activeSession;
    const question = session.questions[session.index];
    const correct = !timedOut && session.selected !== null ? question.choices[session.selected].correct : false;
    session.responses.push({id: question.id, category: question.category, correct});
    recordAttempt(question, correct, "mock");
    session.selected = null;
    session.answered = false;
    if (session.index >= session.questions.length - 1) return finishSession();
    session.index += 1;
    session.seconds = 300;
    renderSession();
  }

  function nextQuestion() {
    if (!activeSession || activeSession.finished) return;
    if (activeSession.index >= activeSession.questions.length - 1) return finishSession();
    activeSession.index += 1;
    activeSession.selected = null;
    activeSession.answered = false;
    renderSession();
  }

  function finishSession() {
    clearInterval(timerId);
    const session = activeSession;
    session.finished = true;
    const correct = session.responses.filter((response) => response.correct).length;
    const total = session.responses.length;
    const accuracy = safePercent(correct, total) || 0;
    const elapsed = Math.round((Date.now() - session.started) / 1000);
    const label = session.mode === "mock" ? "Mock quarter" : session.mode === "sprint" ? "Clinical sprint" : session.category === "all" ? "Mixed practice" : `${categoryMap[session.category].name} practice`;
    state.sessions.unshift({time: Date.now(), label, accuracy, total, seconds: elapsed});
    state.sessions = state.sessions.slice(0, 30);
    saveState();
    const breakdown = CATEGORIES.map((category) => {
      const responses = session.responses.filter((response) => response.category === category.id);
      return {category, correct: responses.filter((response) => response.correct).length, total: responses.length};
    }).filter((item) => item.total);
    const strongest = [...breakdown].sort((a,b) => (b.correct/b.total) - (a.correct/a.total))[0];
    const weakest = [...breakdown].sort((a,b) => (a.correct/a.total) - (b.correct/b.total))[0];
    $("#sessionShell").innerHTML = `
      <section class="result-hero"><div class="result-score"><div><strong>${accuracy}%</strong><small>${correct} OF ${total} CORRECT</small></div></div><h1>${accuracy >= 80 ? "Excellent clinical command." : accuracy >= 65 ? "A solid base to build on." : "Every miss is useful data."}</h1><p>${session.mode === "mock" ? "Your mock-quarter report is ready. Use the category breakdown to choose the next focused set." : "This session is now part of your strength map and adaptive recommendations."}</p></section>
      <div class="result-grid"><div class="result-stat"><span>STRONGEST IN SET</span><b>${strongest ? escapeHTML(strongest.category.name) : "—"}</b></div><div class="result-stat"><span>NEXT FOCUS</span><b>${weakest ? escapeHTML(weakest.category.name) : "—"}</b></div><div class="result-stat"><span>BEST COMBO</span><b>${session.bestCombo || "—"}</b></div></div>
      <section class="result-breakdown"><h2>Category breakdown</h2>${breakdown.map((item) => `<div class="mastery-row"><span>${escapeHTML(item.category.name)}</span><div class="mastery-track"><i style="width:${safePercent(item.correct,item.total)}%;--bar:${item.category.color}"></i></div><small>${item.correct}/${item.total}</small></div>`).join("")}</section>
      <div class="result-actions"><button class="outline-button" type="button" data-result-route="insights">View full insights</button><button class="primary-button" type="button" data-result-route="practice">Practice again <span>→</span></button></div>`;
  }

  document.addEventListener("click", (event) => {
    const routeButton = event.target.closest("[data-route]");
    if (routeButton) { event.preventDefault(); routeTo(routeButton.dataset.route); return; }
    const action = event.target.closest("[data-action]")?.dataset.action;
    if (action === "smart-session") return startSession("smart", 10, "all");
    if (action === "mock") return startSession("mock", 25, "all");
    if (action === "sprint") return startSession("sprint", Math.min(25, QUESTIONS.length), "all");
    if (action === "custom-practice") return startSession("practice", selectedLength, selectedCategory);
    const categoryButton = event.target.closest("[data-category]");
    if (categoryButton) { selectedCategory = categoryButton.dataset.category; renderPractice(); return; }
    const lengthButton = event.target.closest("[data-length]");
    if (lengthButton) {
      selectedLength = Number(lengthButton.dataset.length);
      $$("[data-length]").forEach((button) => { const active = button === lengthButton; button.classList.toggle("is-selected",active); button.setAttribute("aria-pressed",String(active)); });
      return;
    }
    const deckButton = event.target.closest("[data-deck]");
    if (deckButton) { flashCategory = deckButton.dataset.deck; renderFlashcards(true); return; }
    if (event.target.closest("#flashcard")) {
      $("#flashcard").classList.add("is-revealed");
      $("#flashHint").textContent = "Rate the card below to schedule its next review";
      $("#confidenceControls").hidden = false;
      return;
    }
    const confidence = event.target.closest("[data-confidence]")?.dataset.confidence;
    if (confidence) {
      const card = flashDeck[flashIndex % flashDeck.length];
      const settings = {again:{level:0,delay:60000},hard:{level:1,delay:DAY},got:{level:3,delay:3*DAY}}[confidence];
      state.cards[card.id] = {level: settings.level, due: Date.now() + settings.delay};
      state.xp += confidence === "got" ? 10 : 4;
      updateStreak(); saveState(); flashIndex += 1; renderFlashCard(); renderDashboard(); return;
    }
    if (event.target.closest("#shuffleCards")) { flashDeck = shuffle(flashDeck); flashIndex = 0; renderFlashCard(); showToast("Deck shuffled"); return; }
    const answer = event.target.closest("[data-answer]");
    if (answer) { selectAnswer(Number(answer.dataset.answer)); return; }
    if (event.target.closest("#submitAnswer")) {
      if (activeSession?.answered) nextQuestion(); else submitAnswer();
      return;
    }
    if (event.target.closest(".close-session")) { routeTo("practice"); return; }
    const resultRoute = event.target.closest("[data-result-route]")?.dataset.resultRoute;
    if (resultRoute) { activeSession = null; routeTo(resultRoute); return; }
    const focusButton = event.target.closest("[data-focus]");
    if (focusButton) return startSession("practice", 10, focusButton.dataset.focus);
    if (event.target.closest("#resetProgress")) {
      if (window.confirm("Reset all ReCert Ready study history on this device?")) { state = defaultState(); saveState(); renderInsights(); renderDashboard(); showToast("Progress reset"); }
    }
  });

  $("#themeToggle").addEventListener("click", () => {
    const next = document.documentElement.dataset.theme === "dark" ? "light" : "dark";
    document.documentElement.dataset.theme = next;
    $("#themeToggle").setAttribute("aria-label", `Switch to ${next === "dark" ? "light" : "dark"} theme`);
    try { localStorage.setItem("recert-theme", next); } catch (error) { /* no-op */ }
  });
  document.addEventListener("keydown", (event) => {
    if (!activeSession || activeSession.finished) return;
    if (/^[1-4]$/.test(event.key)) selectAnswer(Number(event.key) - 1);
    if (event.key === "Enter" && !$("#submitAnswer")?.disabled) $("#submitAnswer").click();
  });

  renderBlueprint();
  renderDashboard();
  renderPractice();
  renderFlashcards(true);
  renderInsights();
})();
