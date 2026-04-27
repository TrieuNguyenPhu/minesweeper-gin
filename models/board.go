package models

import (
	"crypto/rand"
	"encoding/hex"
	"errors"
	"math/big"
	"sync"
)

const (
	DefaultRows      = 9
	DefaultCols      = 9
	DefaultMineCount = 10
)

type GameStatus string

const (
	StatusPlaying GameStatus = "playing"
	StatusWon     GameStatus = "won"
	StatusLost    GameStatus = "lost"
)

var (
	ErrInvalidBoard = errors.New("invalid board configuration")
	ErrInvalidCell  = errors.New("cell is outside the board")
)

type Cell struct {
	Row      int
	Col      int
	Mine     bool
	Adjacent int
	Revealed bool
	Flagged  bool
	Exploded bool
}

type PublicCell struct {
	Row       int  `json:"row"`
	Col       int  `json:"col"`
	Revealed  bool `json:"revealed"`
	Flagged   bool `json:"flagged"`
	Adjacent  int  `json:"adjacent"`
	Mine      bool `json:"mine"`
	Exploded  bool `json:"exploded"`
	WrongFlag bool `json:"wrongFlag"`
}

type PublicGame struct {
	ID             string       `json:"id"`
	Rows           int          `json:"rows"`
	Cols           int          `json:"cols"`
	MineCount      int          `json:"mineCount"`
	RemainingMines int          `json:"remainingMines"`
	RevealedCount  int          `json:"revealedCount"`
	Status         GameStatus   `json:"status"`
	Cells          []PublicCell `json:"cells"`
}

type Game struct {
	mu        sync.RWMutex
	ID        string
	Rows      int
	Cols      int
	MineCount int
	Status    GameStatus
	Cells     []Cell
}

type GameStore struct {
	mu        sync.RWMutex
	games     map[string]*Game
	rows      int
	cols      int
	mineCount int
}

func NewGameStore(rows, cols, mineCount int) *GameStore {
	return &GameStore{
		games:     make(map[string]*Game),
		rows:      rows,
		cols:      cols,
		mineCount: mineCount,
	}
}

func (s *GameStore) Create() (*Game, error) {
	game, err := NewGame(s.rows, s.cols, s.mineCount)
	if err != nil {
		return nil, err
	}

	s.mu.Lock()
	s.games[game.ID] = game
	s.mu.Unlock()

	return game, nil
}

func (s *GameStore) Get(id string) (*Game, bool) {
	s.mu.RLock()
	game, ok := s.games[id]
	s.mu.RUnlock()
	return game, ok
}

func NewGame(rows, cols, mineCount int) (*Game, error) {
	if rows <= 0 || cols <= 0 || mineCount <= 0 || mineCount >= rows*cols {
		return nil, ErrInvalidBoard
	}

	id, err := randomID()
	if err != nil {
		return nil, err
	}

	game := &Game{
		ID:        id,
		Rows:      rows,
		Cols:      cols,
		MineCount: mineCount,
		Status:    StatusPlaying,
		Cells:     make([]Cell, rows*cols),
	}

	for row := 0; row < rows; row++ {
		for col := 0; col < cols; col++ {
			game.Cells[game.indexUnchecked(row, col)] = Cell{Row: row, Col: col}
		}
	}

	if err := game.placeMines(); err != nil {
		return nil, err
	}
	game.calculateAdjacentMines()

	return game, nil
}

func (g *Game) Reveal(row, col int) error {
	g.mu.Lock()
	defer g.mu.Unlock()

	if g.Status != StatusPlaying {
		return nil
	}

	index, err := g.index(row, col)
	if err != nil {
		return err
	}

	cell := &g.Cells[index]
	if cell.Revealed || cell.Flagged {
		return nil
	}

	if cell.Mine {
		cell.Revealed = true
		cell.Exploded = true
		g.Status = StatusLost
		g.revealAllMines()
		return nil
	}

	g.revealSafeArea(index)
	if g.safeCellsRevealed() == g.Rows*g.Cols-g.MineCount {
		g.Status = StatusWon
		g.flagAllMines()
	}

	return nil
}

func (g *Game) ToggleFlag(row, col int) error {
	g.mu.Lock()
	defer g.mu.Unlock()

	if g.Status != StatusPlaying {
		return nil
	}

	index, err := g.index(row, col)
	if err != nil {
		return err
	}

	cell := &g.Cells[index]
	if cell.Revealed {
		return nil
	}

	if !cell.Flagged && g.flaggedCount() >= g.MineCount {
		return nil
	}

	cell.Flagged = !cell.Flagged
	return nil
}

func (g *Game) PublicView() PublicGame {
	g.mu.RLock()
	defer g.mu.RUnlock()

	showMines := g.Status != StatusPlaying
	cells := make([]PublicCell, 0, len(g.Cells))

	for _, cell := range g.Cells {
		publicCell := PublicCell{
			Row:      cell.Row,
			Col:      cell.Col,
			Revealed: cell.Revealed,
			Flagged:  cell.Flagged,
			Exploded: cell.Exploded,
		}

		if cell.Revealed {
			publicCell.Adjacent = cell.Adjacent
		}

		if showMines && cell.Mine {
			publicCell.Mine = true
		}

		if showMines && cell.Flagged && !cell.Mine {
			publicCell.WrongFlag = true
		}

		cells = append(cells, publicCell)
	}

	return PublicGame{
		ID:             g.ID,
		Rows:           g.Rows,
		Cols:           g.Cols,
		MineCount:      g.MineCount,
		RemainingMines: g.MineCount - g.flaggedCount(),
		RevealedCount:  g.safeCellsRevealed(),
		Status:         g.Status,
		Cells:          cells,
	}
}

func (g *Game) placeMines() error {
	positions := make([]int, len(g.Cells))
	for i := range positions {
		positions[i] = i
	}

	for i := len(positions) - 1; i > 0; i-- {
		j, err := secureRandomInt(i + 1)
		if err != nil {
			return err
		}
		positions[i], positions[j] = positions[j], positions[i]
	}

	for _, position := range positions[:g.MineCount] {
		g.Cells[position].Mine = true
	}

	return nil
}

func (g *Game) calculateAdjacentMines() {
	for i := range g.Cells {
		if g.Cells[i].Mine {
			continue
		}

		count := 0
		for _, neighbor := range g.neighborIndexes(g.Cells[i].Row, g.Cells[i].Col) {
			if g.Cells[neighbor].Mine {
				count++
			}
		}
		g.Cells[i].Adjacent = count
	}
}

func (g *Game) revealSafeArea(start int) {
	queue := []int{start}
	visited := make(map[int]bool)

	for len(queue) > 0 {
		current := queue[0]
		queue = queue[1:]

		if visited[current] {
			continue
		}
		visited[current] = true

		cell := &g.Cells[current]
		if cell.Revealed || cell.Flagged || cell.Mine {
			continue
		}

		cell.Revealed = true
		if cell.Adjacent != 0 {
			continue
		}

		for _, neighbor := range g.neighborIndexes(cell.Row, cell.Col) {
			if !visited[neighbor] {
				queue = append(queue, neighbor)
			}
		}
	}
}

func (g *Game) revealAllMines() {
	for i := range g.Cells {
		if g.Cells[i].Mine {
			g.Cells[i].Revealed = true
		}
	}
}

func (g *Game) flagAllMines() {
	for i := range g.Cells {
		if g.Cells[i].Mine {
			g.Cells[i].Flagged = true
		}
	}
}

func (g *Game) safeCellsRevealed() int {
	count := 0
	for _, cell := range g.Cells {
		if cell.Revealed && !cell.Mine {
			count++
		}
	}
	return count
}

func (g *Game) flaggedCount() int {
	count := 0
	for _, cell := range g.Cells {
		if cell.Flagged {
			count++
		}
	}
	return count
}

func (g *Game) neighborIndexes(row, col int) []int {
	var neighbors []int
	for rowOffset := -1; rowOffset <= 1; rowOffset++ {
		for colOffset := -1; colOffset <= 1; colOffset++ {
			if rowOffset == 0 && colOffset == 0 {
				continue
			}

			nextRow := row + rowOffset
			nextCol := col + colOffset
			if nextRow < 0 || nextRow >= g.Rows || nextCol < 0 || nextCol >= g.Cols {
				continue
			}
			neighbors = append(neighbors, g.indexUnchecked(nextRow, nextCol))
		}
	}
	return neighbors
}

func (g *Game) index(row, col int) (int, error) {
	if row < 0 || row >= g.Rows || col < 0 || col >= g.Cols {
		return 0, ErrInvalidCell
	}
	return g.indexUnchecked(row, col), nil
}

func (g *Game) indexUnchecked(row, col int) int {
	return row*g.Cols + col
}

func randomID() (string, error) {
	bytes := make([]byte, 16)
	if _, err := rand.Read(bytes); err != nil {
		return "", err
	}
	return hex.EncodeToString(bytes), nil
}

func secureRandomInt(max int) (int, error) {
	value, err := rand.Int(rand.Reader, big.NewInt(int64(max)))
	if err != nil {
		return 0, err
	}
	return int(value.Int64()), nil
}
