# Automated release packaging script for StackSoothe Windows x64
param (
    [string]$ReleaseTag = "v0.1.0-challenge"
)

$ErrorActionPreference = "Stop"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "  Packaging StackSoothe Release Candidate: $ReleaseTag" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

$RepoRoot = $PSScriptRoot
$AppReleaseDir = Join-Path $RepoRoot "app\build\windows\x64\runner\Release"
$ServiceDir = Join-Path $RepoRoot "service"
$DistDir = Join-Path $RepoRoot "dist"
$StagingDir = Join-Path $DistDir "staging\stacksoothe-$ReleaseTag-windows-x64"
$ZipPath = Join-Path $DistDir "stacksoothe-$ReleaseTag-windows-x64.zip"
$ManifestPath = Join-Path $RepoRoot "release-manifest.json"

# 1. Verify required build artifacts exist
Write-Host "`n[1/6] Verifying built binaries..." -ForegroundColor Yellow
$RequiredFiles = @(
    (Join-Path $AppReleaseDir "stacksoothe.exe"),
    (Join-Path $AppReleaseDir "flutter_windows.dll"),
    (Join-Path $AppReleaseDir "data\app.so"),
    (Join-Path $AppReleaseDir "data\icudtl.dat"),
    (Join-Path $ServiceDir "src\server.ts"),
    (Join-Path $ServiceDir "src\diagnosis.ts"),
    (Join-Path $ServiceDir "package.json"),
    (Join-Path $ServiceDir "node_modules\zod")
)

foreach ($file in $RequiredFiles) {
    if (-not (Test-Path $file)) {
        throw "Missing required build artifact: $file. Ensure 'flutter build windows --release' and npm dependencies are satisfied."
    }
}
Write-Host "All required build artifacts verified." -ForegroundColor Green

# 2. Prepare staging directory
Write-Host "`n[2/6] Preparing clean staging directory..." -ForegroundColor Yellow
if (Test-Path $StagingDir) {
    Remove-Item -Path $StagingDir -Recurse -Force
}
New-Item -Path (Join-Path $StagingDir "app") -ItemType Directory -Force | Out-Null
New-Item -Path (Join-Path $StagingDir "service\src") -ItemType Directory -Force | Out-Null
New-Item -Path (Join-Path $StagingDir "service\node_modules") -ItemType Directory -Force | Out-Null

# 3. Copy files into staging
Write-Host "`n[3/6] Staging release files..." -ForegroundColor Yellow

# Copy Flutter release files
Copy-Item -Path (Join-Path $AppReleaseDir "*") -Destination (Join-Path $StagingDir "app") -Recurse -Force

# Copy Service production files (zod only, zero devDependencies)
Copy-Item -Path (Join-Path $ServiceDir "package.json") -Destination (Join-Path $StagingDir "service\package.json") -Force
Copy-Item -Path (Join-Path $ServiceDir "src\server.ts") -Destination (Join-Path $StagingDir "service\src\server.ts") -Force
Copy-Item -Path (Join-Path $ServiceDir "src\diagnosis.ts") -Destination (Join-Path $StagingDir "service\src\diagnosis.ts") -Force
Copy-Item -Path (Join-Path $ServiceDir "src\schemas") -Destination (Join-Path $StagingDir "service\src\schemas") -Recurse -Force
Copy-Item -Path (Join-Path $ServiceDir "src\types") -Destination (Join-Path $StagingDir "service\src\types") -Recurse -Force
Copy-Item -Path (Join-Path $ServiceDir "node_modules\zod") -Destination (Join-Path $StagingDir "service\node_modules\zod") -Recurse -Force

# Copy distribution launchers & docs
Copy-Item -Path (Join-Path $RepoRoot "dist-templates\launch.bat") -Destination (Join-Path $StagingDir "launch.bat") -Force
Copy-Item -Path (Join-Path $RepoRoot "dist-templates\stop.bat") -Destination (Join-Path $StagingDir "stop.bat") -Force
Copy-Item -Path (Join-Path $RepoRoot "dist-templates\README.txt") -Destination (Join-Path $StagingDir "README.txt") -Force

# 4. Enforce strict privacy and credential exclusion scan
Write-Host "`n[4/6] Auditing staged files for secrets and forbidden artifacts..." -ForegroundColor Yellow
$ForbiddenPatterns = @(".stacksoothe-token", ".env", "notebook.json", ".git", "@sentry")
$StagedFiles = Get-ChildItem -Path $StagingDir -Recurse -File

foreach ($f in $StagedFiles) {
    foreach ($pat in $ForbiddenPatterns) {
        if ($f.Name -like "*$pat*" -or $f.FullName -like "*$pat*") {
            throw "SECURITY VIOLATION: Staged release contains forbidden file/pattern '$pat': $($f.FullName)"
        }
    }
}
Write-Host "Security audit passed: 0 secrets, 0 tokens, 0 telemetry modules in release bundle." -ForegroundColor Green

# 5. Compress archive
Write-Host "`n[5/6] Creating release archive: $ZipPath..." -ForegroundColor Yellow
if (Test-Path $ZipPath) {
    Remove-Item -Path $ZipPath -Force
}
Compress-Archive -Path (Join-Path $StagingDir "*") -DestinationPath $ZipPath -CompressionLevel Optimal
$ZipItem = Get-Item $ZipPath
$ZipSizeMB = [math]::Round($ZipItem.Length / 1MB, 2)
Write-Host "Archive created: $ZipPath ($ZipSizeMB MB)" -ForegroundColor Green

# 6. Compute SHA-256 and generate release manifest
Write-Host "`n[6/6] Computing cryptographic SHA-256 checksums..." -ForegroundColor Yellow
$ZipHash = (Get-FileHash -Path $ZipPath -Algorithm SHA256).Hash.ToLower()
$ExeHash = (Get-FileHash -Path (Join-Path $AppReleaseDir "stacksoothe.exe") -Algorithm SHA256).Hash.ToLower()
$DllHash = (Get-FileHash -Path (Join-Path $AppReleaseDir "flutter_windows.dll") -Algorithm SHA256).Hash.ToLower()
$AppSoHash = (Get-FileHash -Path (Join-Path $AppReleaseDir "data\app.so") -Algorithm SHA256).Hash.ToLower()

$CommitSha = (git rev-parse HEAD).Trim()
$BuildTimestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")

$Manifest = [ordered]@{
    project = "StackSoothe"
    release_tag = $ReleaseTag
    commit_sha = $CommitSha
    build_timestamp = $BuildTimestamp
    platform = "windows-x64"
    architecture = "Flutter Desktop + Loopback Node/TypeScript + Local Ollama"
    license = "MIT"
    prerequisites = [ordered]@{
        os = "Windows 10 or 11 (64-bit)"
        node = ">=24.0.0"
        ollama = ">=0.40.8"
        model = "qwen3:1.7b (ID: 8f68893c685c, Apache-2.0)"
        ram = ">=8 GB (16 GB recommended)"
    }
    assets = @(
        [ordered]@{
            filename = [System.IO.Path]::GetFileName($ZipPath)
            size_bytes = $ZipItem.Length
            size_mb = $ZipSizeMB
            sha256 = $ZipHash
            description = "Standalone packaged Windows release candidate containing Flutter runner, runtime DLLs, compiled assets, loopback service, and launchers"
        },
        [ordered]@{
            filename = "stacksoothe.exe"
            size_bytes = (Get-Item (Join-Path $AppReleaseDir "stacksoothe.exe")).Length
            sha256 = $ExeHash
            description = "Windows native x64 Flutter desktop application executable"
        },
        [ordered]@{
            filename = "flutter_windows.dll"
            size_bytes = (Get-Item (Join-Path $AppReleaseDir "flutter_windows.dll")).Length
            sha256 = $DllHash
            description = "Flutter Windows engine runtime dynamic library"
        },
        [ordered]@{
            filename = "app.so"
            size_bytes = (Get-Item (Join-Path $AppReleaseDir "data\app.so")).Length
            sha256 = $AppSoHash
            description = "AOT-compiled Flutter Dart application binary"
        }
    )
}

$ManifestJson = $Manifest | ConvertTo-Json -Depth 5
[System.IO.File]::WriteAllText($ManifestPath, $ManifestJson)
Write-Host "Release manifest saved to: $ManifestPath" -ForegroundColor Green

Write-Host "`n==========================================================" -ForegroundColor Cyan
Write-Host "  Release Packaging Complete!" -ForegroundColor Cyan
Write-Host "  Archive: $ZipPath" -ForegroundColor Cyan
Write-Host "  Archive SHA-256: $ZipHash" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
