<#
.SYNOPSIS
    Find-DuplicateFiles.ps1 - Scans a computer for duplicate files and exports a report.

.DESCRIPTION
    Phase 1: Collects all files above the minimum size threshold.
    Phase 2: Groups files by size — only same-size files are hashed (fast pre-filter).
    Phase 3: Hashes candidate files with SHA256 to confirm true duplicates.
    Phase 4: Groups by hash, calculates wasted space, exports CSV report.

    The CSV groups duplicates by a DuplicateGroup number so you can sort/filter in Excel.

.PARAMETER ScanPath
    One or more root paths to scan. Defaults to all fixed drives on the system.
    Example: -ScanPath "C:\Users", "D:\"

.PARAMETER OutputPath
    Full path for the CSV report. Defaults to Desktop\DuplicateFiles_<timestamp>.csv

.PARAMETER MinSizeKB
    Minimum file size in kilobytes to include in the scan. Default: 1 KB.
    Increase this (e.g. -MinSizeKB 500) to focus only on large duplicates.

.PARAMETER ExcludePath
    Path fragments to skip during scan (e.g. "Windows", "Program Files").
    Defaults to common system directories that should not be modified.

.EXAMPLE
    # Scan all fixed drives with default settings
    .\Find-DuplicateFiles.ps1

.EXAMPLE
    # Scan only the Users folder, minimum 1 MB files
    .\Find-DuplicateFiles.ps1 -ScanPath "C:\Users" -MinSizeKB 1024

.EXAMPLE
    # Full scan, save report to a specific location
    .\Find-DuplicateFiles.ps1 -OutputPath "C:\Reports\duplicates.csv"

.NOTES
    Author : Kopo Keitumetse
    Version: 1.0
    Requires: PowerShell 5.1+, run as Administrator for full system access.
    Safe to run — this script is READ-ONLY. It never moves or deletes files.
#>

[CmdletBinding()]
param(
    [string[]] $ScanPath,
    [string]   $OutputPath,
    [int]      $MinSizeKB   = 1,
    [string[]] $ExcludePath = @(
        '\Windows\',
        '\Program Files\',
        '\Program Files (x86)\',
        '\ProgramData\',
        '\AppData\Local\Temp\',
        '\AppData\LocalLow\',
        '\$Recycle.Bin\',
        '\System Volume Information\'
    )
)

#region ── Helpers ─────────────────────────────────────────────────────────────

function Write-Header {
    param([string]$Text)
    Write-Host "`n  $Text" -ForegroundColor Green
}

function Write-Step {
    param([string]$Text)
    Write-Host "  [*] $Text" -ForegroundColor Yellow
}

function Write-OK {
    param([string]$Text)
    Write-Host "  [+] $Text" -ForegroundColor Cyan
}

function Write-Banner {
    $banner = @"

  ╔══════════════════════════════════════════════════════╗
  ║         DUPLICATE FILE SCANNER  v1.0                 ║
  ║         github.com/kopokeitumetse                    ║
  ╚══════════════════════════════════════════════════════╝

"@
    Write-Host $banner -ForegroundColor Green
}

#endregion

#region ── Setup ───────────────────────────────────────────────────────────────

Write-Banner

# Default scan paths: all fixed drives
if (-not $ScanPath) {
    $ScanPath = Get-WmiObject Win32_LogicalDisk -Filter "DriveType=3" |
                Select-Object -ExpandProperty DeviceID |
                ForEach-Object { "$_\" }

    if (-not $ScanPath) {
        # Fallback if WMI is unavailable
        $ScanPath = @("C:\")
    }
}

# Default output path
if (-not $OutputPath) {
    $timestamp  = Get-Date -Format "yyyy-MM-dd_HHmmss"
    $OutputPath = "$env:USERPROFILE\Desktop\DuplicateFiles_$timestamp.csv"
}

$MinSizeBytes = $MinSizeKB * 1024

Write-OK "Scan paths   : $($ScanPath -join ' | ')"
Write-OK "Min file size: $MinSizeKB KB"
Write-OK "Output file  : $OutputPath"
Write-OK "Excluded     : system directories (Windows, Program Files, Temp, etc.)`n"

#endregion

#region ── Phase 1: Collect files ──────────────────────────────────────────────

Write-Header "Phase 1 — Collecting files"

$allFiles  = [System.Collections.Generic.List[object]]::new()
$skipCount = 0

foreach ($root in $ScanPath) {
    Write-Step "Scanning $root ..."
    try {
        $files = Get-ChildItem -Path $root -Recurse -File -ErrorAction SilentlyContinue |
            Where-Object {
                $_.Length -ge $MinSizeBytes -and
                -not ($ExcludePath | Where-Object { $_.FullName -like "*$_*" })
            }
        $allFiles.AddRange([object[]]$files)
        Write-OK "  $($files.Count) files collected from $root"
    }
    catch {
        Write-Warning "  Could not fully scan $root — some paths may be restricted."
    }
}

Write-OK "Total files collected: $($allFiles.Count)"

#endregion

#region ── Phase 2: Group by file size ─────────────────────────────────────────

Write-Header "Phase 2 — Grouping by size (pre-filter)"

$sizeGroups      = $allFiles | Group-Object -Property Length | Where-Object { $_.Count -gt 1 }
$candidateFiles  = $sizeGroups | ForEach-Object { $_.Group }
$skippedUnique   = $allFiles.Count - $candidateFiles.Count

Write-OK "Unique-size files skipped (cannot be duplicates): $skippedUnique"
Write-OK "Candidate files for hashing: $($candidateFiles.Count)"

if ($candidateFiles.Count -eq 0) {
    Write-Host "`n  [OK] No duplicate files found. All files are unique sizes." -ForegroundColor Green
    exit 0
}

#endregion

#region ── Phase 3: Hash candidates ────────────────────────────────────────────

Write-Header "Phase 3 — Hashing candidate files (SHA256)"
Write-Step "This may take several minutes on a full system scan..."

$hashed    = [System.Collections.Generic.List[object]]::new()
$total     = $candidateFiles.Count
$counter   = 0
$errorCount = 0

foreach ($file in $candidateFiles) {
    $counter++
    if ($counter % 100 -eq 0 -or $counter -eq $total) {
        $pct = [math]::Round(($counter / $total) * 100)
        Write-Progress -Activity "Hashing files" `
                       -Status "$counter / $total ($pct%)" `
                       -PercentComplete $pct
    }
    try {
        $hash = (Get-FileHash -Path $file.FullName -Algorithm SHA256 -ErrorAction Stop).Hash
        $hashed.Add([PSCustomObject]@{
            Hash         = $hash
            FullPath     = $file.FullName
            FileName     = $file.Name
            Extension    = $file.Extension.ToLower()
            SizeBytes    = $file.Length
            SizeMB       = [math]::Round($file.Length / 1MB, 3)
            LastModified = $file.LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss")
            Directory    = $file.DirectoryName
            Drive        = $file.PSDrive.Name + ":"
        })
    }
    catch {
        $errorCount++
    }
}

Write-Progress -Activity "Hashing files" -Completed
Write-OK "Files hashed successfully: $($hashed.Count)"
if ($errorCount -gt 0) { Write-Warning "  Files skipped (locked/inaccessible): $errorCount" }

#endregion

#region ── Phase 4: Find duplicates & build report ─────────────────────────────

Write-Header "Phase 4 — Identifying duplicates"

$duplicateGroups = $hashed | Group-Object -Property Hash | Where-Object { $_.Count -gt 1 }

if ($duplicateGroups.Count -eq 0) {
    Write-Host "`n  [OK] No duplicate files found after hashing." -ForegroundColor Green
    exit 0
}

# Sort groups by wasted space descending (biggest waste first)
$sortedGroups = $duplicateGroups | Sort-Object { $_.Group[0].SizeBytes * ($_.Count - 1) } -Descending

$results    = [System.Collections.Generic.List[object]]::new()
$groupNum   = 1
$totalWaste = [long]0

foreach ($group in $sortedGroups) {
    $fileSize   = $group.Group[0].SizeBytes
    $copies     = $group.Count
    $wastedBytes = $fileSize * ($copies - 1)
    $totalWaste += $wastedBytes

    $sortedFiles = $group.Group | Sort-Object LastModified  # oldest first (likely the original)

    foreach ($file in $sortedFiles) {
        $results.Add([PSCustomObject]@{
            DuplicateGroup   = $groupNum
            FileName         = $file.FileName
            Extension        = $file.Extension
            FullPath         = $file.FullPath
            Drive            = $file.Drive
            Directory        = $file.Directory
            SizeMB           = $file.SizeMB
            LastModified     = $file.LastModified
            CopiesInGroup    = $copies
            WastedSpaceMB    = [math]::Round($wastedBytes / 1MB, 3)
            SHA256Hash       = $file.Hash
        })
    }
    $groupNum++
}

#endregion

#region ── Export & Summary ────────────────────────────────────────────────────

$results | Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8

$totalWasteMB = [math]::Round($totalWaste / 1MB, 2)
$totalWasteGB = [math]::Round($totalWaste / 1GB, 3)

Write-Host @"

  ╔══════════════════════════════════════════════════════╗
  ║                     SCAN COMPLETE                    ║
  ╚══════════════════════════════════════════════════════╝

"@ -ForegroundColor Green

Write-OK "Duplicate groups found : $($duplicateGroups.Count)"
Write-OK "Total duplicate files  : $($results.Count)"
Write-OK "Reclaimable space      : $totalWasteMB MB  ($totalWasteGB GB)"
Write-OK "Report saved to        : $OutputPath"

Write-Host @"

  HOW TO USE THE REPORT:
  ─────────────────────
  > Open the CSV in Excel (or any spreadsheet app).
  > Filter/sort by DuplicateGroup to see each set of duplicates together.
  > The oldest file in each group is listed first (likely the original).
  > WastedSpaceMB shows how much you would recover by keeping one copy.
  > ALWAYS verify before deleting — this script never removes files.

"@ -ForegroundColor White

#endregion
