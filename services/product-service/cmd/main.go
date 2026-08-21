package main

import (
	"context"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/scalecart/product-service/internal/db"
	"github.com/scalecart/product-service/internal/handlers"
)

func main() {
	mongoURI := getEnv("MONGO_URI", "mongodb://localhost:27017")
	dbName := getEnv("MONGO_DB", "scalecart_products")
	port := getEnv("PORT", "4002")

	client, err := db.Connect(mongoURI)
	if err != nil {
		log.Fatalf("mongo connect failed: %v", err)
	}
	collection := client.Database(dbName).Collection("products")

	health := &handlers.HealthHandler{Mongo: client}
	products := &handlers.ProductHandler{Collection: collection}

	router := gin.New()
	router.Use(gin.Recovery(), handlers.PrometheusMiddleware())

	router.GET("/health/live", health.Live)
	router.GET("/health/ready", health.Ready)
	router.GET("/metrics", handlers.MetricsHandler())

	router.GET("/products", products.List)
	router.GET("/products/:id", products.Get)
	router.POST("/products", products.Create)
	router.POST("/products/:id/reserve", products.ReserveStock)

	srv := &http.Server{Addr: ":" + port, Handler: router}

	go func() {
		log.Printf("product-service listening on :%s", port)
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("server error: %v", err)
		}
	}()

	// Graceful shutdown on SIGTERM/SIGINT - same pattern as the other
	// services: stop taking new work, let in-flight requests finish.
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	if err := srv.Shutdown(ctx); err != nil {
		log.Fatalf("forced shutdown: %v", err)
	}
	_ = client.Disconnect(ctx)
	log.Println("product-service stopped")
}

func getEnv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}
