# Minesweeper Gin

Web game do min gon nhe bang Gin va HTML/CSS/JS thuan.

## Chay local

```powershell
go mod tidy
go run .
```

Mo trinh duyet tai:

```text
http://localhost:8080
```

## API

- `POST /api/games`: tao van moi 9x9 voi 10 min.
- `POST /api/games/:id/reveal`: mo o, body JSON `{ "row": 0, "col": 0 }`.
- `POST /api/games/:id/flag`: cam/go co, body JSON `{ "row": 0, "col": 0 }`.
