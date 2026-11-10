param([switch]$SkipBuild, [switch]$NoBrowser, [int]$Port = 8765)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $projectRoot

if (-not $SkipBuild) {
    $localFlutter = Join-Path $projectRoot '.tools\flutter\bin\flutter.bat'
    if (Test-Path -LiteralPath $localFlutter) {
        $flutterCommand = $localFlutter
    } else {
        $flutterCommand = (Get-Command flutter -ErrorAction SilentlyContinue).Source
    }
    if (-not $flutterCommand) { throw 'Flutter SDK was not found. See README.md.' }
    Write-Host 'Preparing Carscape. The first launch may take a few minutes.'
    & $flutterCommand build web --release --no-wasm-dry-run --no-web-resources-cdn
    if ($LASTEXITCODE -ne 0) { throw 'Flutter build failed. Please keep this window open and share the error.' }
}

$webRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot 'build\web'))
if (-not (Test-Path -LiteralPath (Join-Path $webRoot 'index.html'))) { throw 'Build not found. Run play-tutorial.cmd first.' }
$listener = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, $Port)
try { $listener.Start() } catch { throw "Port $Port is already in use. Close the previous preview window and retry." }
$url = "http://127.0.0.1:$Port/"
Write-Host "Carscape is ready: $url"
Write-Host 'Keep this window open while playing. Close it to stop the preview.'
if (-not $NoBrowser) { Start-Process $url }

$mime = @{
    '.html' = 'text/html; charset=utf-8'; '.js' = 'application/javascript; charset=utf-8'
    '.json' = 'application/json; charset=utf-8'; '.css' = 'text/css; charset=utf-8'
    '.wasm' = 'application/wasm'; '.png' = 'image/png'; '.svg' = 'image/svg+xml'
    '.ttf' = 'font/ttf'; '.otf' = 'font/otf'; '.woff2' = 'font/woff2'
}
try {
    while ($true) {
        $client = $listener.AcceptTcpClient()
        try {
            $client.ReceiveTimeout = 5000
            $stream = $client.GetStream()
            $reader = [IO.StreamReader]::new($stream, [Text.Encoding]::ASCII, $false, 1024, $true)
            $request = $reader.ReadLine()
            if (-not $request) { continue }
            do { $headerLine = $reader.ReadLine() } while ($headerLine)
            $parts = $request.Split(' ')
            $method = $parts[0]
            $requestPath = [Uri]::UnescapeDataString(($parts[1] -split '\?')[0]).TrimStart('/')
            if (-not $requestPath) { $requestPath = 'index.html' }
            $filePath = [IO.Path]::GetFullPath((Join-Path $webRoot $requestPath))
            $status = '200 OK'
            $contentType = 'text/plain; charset=utf-8'
            if ($method -notin @('GET', 'HEAD')) {
                $status = '405 Method Not Allowed'
                $bytes = [Text.Encoding]::UTF8.GetBytes('Method not allowed')
            } elseif (-not $filePath.StartsWith($webRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
                $status = '403 Forbidden'
                $bytes = [Text.Encoding]::UTF8.GetBytes('Forbidden')
            } elseif (-not (Test-Path -LiteralPath $filePath -PathType Leaf)) {
                $status = '404 Not Found'
                $bytes = [Text.Encoding]::UTF8.GetBytes('Not found')
            } else {
                $bytes = [IO.File]::ReadAllBytes($filePath)
                $extension = [IO.Path]::GetExtension($filePath)
                $contentType = if ($mime.ContainsKey($extension)) { $mime[$extension] } else { 'application/octet-stream' }
            }
            $response = "HTTP/1.1 $status`r`nContent-Type: $contentType`r`nContent-Length: $($bytes.Length)`r`nCache-Control: no-cache`r`nConnection: close`r`n`r`n"
            $headerBytes = [Text.Encoding]::ASCII.GetBytes($response)
            $stream.Write($headerBytes, 0, $headerBytes.Length)
            if ($method -ne 'HEAD') { $stream.Write($bytes, 0, $bytes.Length) }
            $stream.Flush()
        } catch {
            Write-Verbose $_
        } finally {
            $client.Dispose()
        }
    }
} finally {
    $listener.Stop()
}
