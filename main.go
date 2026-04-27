package main

import (
	"log"

	"github.com/gin-gonic/gin"

	"minesweeper-gin/controllers"
)

func main() {
	router := gin.Default()

	router.LoadHTMLGlob("views/*.html")
	router.Static("/static", "./static")

	gameController := controllers.NewGameController()
	gameController.RegisterRoutes(router)

	log.Println("Minesweeper Gin is running at http://localhost:8080")
	if err := router.Run(":8080"); err != nil {
		log.Fatal(err)
	}
}
