# ─── Stage 1: Build ────────────────────────────────────────────────────────────
FROM golang:1.25-alpine AS builder

WORKDIR /app

# Cache dependencies first
COPY go.mod go.sum ./
RUN go mod download

# Copy source and build
COPY . .
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -ldflags="-s -w" -o minesweeper .

# ─── Stage 2: Runtime ──────────────────────────────────────────────────────────
FROM alpine:3.19

RUN apk add --no-cache ca-certificates tzdata

WORKDIR /app

# Copy binary
COPY --from=builder /app/minesweeper .

# Copy static assets (required at runtime by gin)
COPY --from=builder /app/views ./views
COPY --from=builder /app/static ./static

EXPOSE 8080

HEALTHCHECK --interval=10s --timeout=5s --retries=3 \
  CMD wget -qO- http://localhost:8080/ || exit 1

CMD ["./minesweeper"]
