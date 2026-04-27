package controllers

import (
	"errors"
	"net/http"

	"github.com/gin-gonic/gin"

	"minesweeper-gin/models"
)

type GameController struct {
	store *models.GameStore
}

type cellActionRequest struct {
	Row int `json:"row"`
	Col int `json:"col"`
}

func NewGameController() *GameController {
	return &GameController{
		store: models.NewGameStore(
			models.DefaultRows,
			models.DefaultCols,
			models.DefaultMineCount,
		),
	}
}

func (controller *GameController) RegisterRoutes(router *gin.Engine) {
	router.GET("/", controller.Index)

	api := router.Group("/api")
	api.POST("/games", controller.CreateGame)
	api.POST("/games/:id/reveal", controller.RevealCell)
	api.POST("/games/:id/flag", controller.ToggleFlag)
}

func (controller *GameController) Index(context *gin.Context) {
	context.HTML(http.StatusOK, "index.html", gin.H{
		"title": "Minesweeper Gin",
	})
}

func (controller *GameController) CreateGame(context *gin.Context) {
	game, err := controller.store.Create()
	if err != nil {
		context.JSON(http.StatusInternalServerError, gin.H{
			"error": "Could not create a new game.",
		})
		return
	}

	context.JSON(http.StatusCreated, game.PublicView())
}

func (controller *GameController) RevealCell(context *gin.Context) {
	game, ok := controller.store.Get(context.Param("id"))
	if !ok {
		context.JSON(http.StatusNotFound, gin.H{"error": "Game not found."})
		return
	}

	request, ok := bindCellAction(context)
	if !ok {
		return
	}

	if err := game.Reveal(request.Row, request.Col); err != nil {
		writeMoveError(context, err)
		return
	}

	context.JSON(http.StatusOK, game.PublicView())
}

func (controller *GameController) ToggleFlag(context *gin.Context) {
	game, ok := controller.store.Get(context.Param("id"))
	if !ok {
		context.JSON(http.StatusNotFound, gin.H{"error": "Game not found."})
		return
	}

	request, ok := bindCellAction(context)
	if !ok {
		return
	}

	if err := game.ToggleFlag(request.Row, request.Col); err != nil {
		writeMoveError(context, err)
		return
	}

	context.JSON(http.StatusOK, game.PublicView())
}

func bindCellAction(context *gin.Context) (cellActionRequest, bool) {
	var request cellActionRequest
	if err := context.ShouldBindJSON(&request); err != nil {
		context.JSON(http.StatusBadRequest, gin.H{"error": "Invalid request body."})
		return request, false
	}
	return request, true
}

func writeMoveError(context *gin.Context, err error) {
	if errors.Is(err, models.ErrInvalidCell) {
		context.JSON(http.StatusBadRequest, gin.H{"error": "Invalid cell."})
		return
	}

	context.JSON(http.StatusInternalServerError, gin.H{"error": "Could not apply move."})
}
