Write-Host "=== ROLLCHART-BLDR: RUN WEB SERVER ===" -ForegroundColor Cyan
Set-Location $PSScriptRoot

$port = 5050
Write-Host "Starting Flutter web-server on port $port" -ForegroundColor Green
Write-Host "When ready, open this manually in your browser:" -ForegroundColor Yellow
Write-Host "  http://localhost:$port" -ForegroundColor Yellow
Write-Host ""
Write-Host "Press Ctrl+C here to stop the server." -ForegroundColor DarkGray

flutter run -d web-server --web-port $port
