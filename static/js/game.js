const boardElement = document.querySelector("#board");
const mineCounterElement = document.querySelector("#mineCounter");
const revealedCounterElement = document.querySelector("#revealedCounter");
const statusTextElement = document.querySelector("#statusText");
const newGameButton = document.querySelector("#newGameButton");
const flagModeButton = document.querySelector("#flagModeButton");

const state = {
  game: null,
  flagMode: false,
  busy: false,
};

newGameButton.addEventListener("click", () => {
  startNewGame();
});

flagModeButton.addEventListener("click", () => {
  state.flagMode = !state.flagMode;
  flagModeButton.setAttribute("aria-pressed", String(state.flagMode));
});

startNewGame();

async function startNewGame() {
  await requestGame("/api/games", { method: "POST" });
}

async function revealCell(row, col) {
  if (!state.game) return;
  await requestGame(`/api/games/${state.game.id}/reveal`, cellActionOptions(row, col));
}

async function toggleFlag(row, col) {
  if (!state.game) return;
  await requestGame(`/api/games/${state.game.id}/flag`, cellActionOptions(row, col));
}

function cellActionOptions(row, col) {
  return {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ row, col }),
  };
}

async function requestGame(url, options) {
  if (state.busy) return;

  state.busy = true;
  setControlsDisabled(true);

  try {
    const response = await fetch(url, options);
    const payload = await response.json();

    if (!response.ok) {
      throw new Error(payload.error || "Request failed.");
    }

    state.game = payload;
    renderGame();
  } catch (error) {
    statusTextElement.textContent = error.message;
  } finally {
    state.busy = false;
    setControlsDisabled(false);
  }
}

function setControlsDisabled(disabled) {
  newGameButton.disabled = disabled;
  flagModeButton.disabled = disabled;
  boardElement.setAttribute("aria-busy", String(disabled));
}

function renderGame() {
  const { game } = state;
  if (!game) return;

  boardElement.innerHTML = "";
  boardElement.style.gridTemplateColumns = `repeat(${game.cols}, var(--cell-size))`;

  mineCounterElement.textContent = game.remainingMines;
  revealedCounterElement.textContent = game.revealedCount;
  statusTextElement.textContent = statusLabel(game.status);

  for (const cell of game.cells) {
    const button = document.createElement("button");
    button.type = "button";
    button.className = cellClassName(cell);
    button.dataset.row = cell.row;
    button.dataset.col = cell.col;
    button.setAttribute("role", "gridcell");
    button.setAttribute("aria-label", cellLabel(cell));

    if (cell.revealed && cell.adjacent > 0) {
      button.dataset.value = String(cell.adjacent);
    }

    button.textContent = cellText(cell);
    button.disabled = game.status !== "playing" || cell.revealed;

    button.addEventListener("click", () => {
      if (state.flagMode) {
        toggleFlag(cell.row, cell.col);
        return;
      }
      revealCell(cell.row, cell.col);
    });

    button.addEventListener("contextmenu", (event) => {
      event.preventDefault();
      toggleFlag(cell.row, cell.col);
    });

    boardElement.appendChild(button);
  }
}

function cellClassName(cell) {
  const classes = ["cell"];

  if (cell.revealed) classes.push("revealed");
  if (cell.flagged) classes.push("flagged");
  if (cell.mine) classes.push("mine");
  if (cell.exploded) classes.push("exploded");
  if (cell.wrongFlag) classes.push("wrong-flag");

  return classes.join(" ");
}

function cellText(cell) {
  if (cell.wrongFlag) return "x";
  if (cell.exploded) return "!";
  if (cell.flagged) return "F";
  if (cell.mine) return "*";
  if (cell.revealed && cell.adjacent > 0) return String(cell.adjacent);
  return "";
}

function cellLabel(cell) {
  const position = `Hàng ${cell.row + 1}, cột ${cell.col + 1}`;

  if (cell.flagged) return `${position}, đã cắm cờ`;
  if (!cell.revealed) return `${position}, chưa mở`;
  if (cell.mine) return `${position}, có mìn`;
  if (cell.adjacent > 0) return `${position}, ${cell.adjacent} mìn lân cận`;
  return `${position}, ô trống`;
}

function statusLabel(status) {
  if (status === "won") return "Bạn thắng";
  if (status === "lost") return "Bạn thua";
  return "Đang chơi";
}
