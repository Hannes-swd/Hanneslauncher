<#
.SYNOPSIS
    Baut eine neue Version und veroeffentlicht sie als GitHub-Release mit APK.

.DESCRIPTION
    Macht in einem Rutsch: Version in pubspec.yaml setzen (Build-Nummer wird
    automatisch hochgezaehlt), Release-APK bauen, Aenderung committen und
    pushen, Release auf GitHub anlegen und die APK anhaengen.

    Genau dieses Release ist das, was die App prueft - siehe
    lib/update_controller.dart. Was jeder Schritt tut und wie man ihn von
    Hand macht, steht in RELEASE.md.

.PARAMETER Version
    Die neue Versionsnummer, drei Zahlen mit Punkten: 1.1.0

.PARAMETER Notes
    Der Text, der im Release steht und in der App unter "Was ist neu"
    auftaucht. Weggelassen entstehen die Notizen aus den Commit-Titeln seit
    dem letzten Release.

.PARAMETER DryRun
    Zeigt nur, was passieren wuerde. Aendert nichts, baut nichts, laedt
    nichts hoch.

.EXAMPLE
    .\tool\release.ps1 1.1.0 -Notes "Neue Uhr-Stile, schnellerer Start"

.EXAMPLE
    .\tool\release.ps1 1.1.0 -DryRun
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Version,

    [string]$Notes = '',

    [switch]$DryRun
)

# Absichtlich nicht 'Stop': git, gh und flutter schreiben im Normalbetrieb
# nach stderr, was PowerShell 5.1 sonst als Abbruchfehler behandelt. Ob
# etwas geklappt hat, wird hier ueber $LASTEXITCODE geprueft.
$ErrorActionPreference = 'Continue'

$root = Split-Path -Parent $PSScriptRoot
$pubspecPath = Join-Path $root 'pubspec.yaml'
$builtApk = Join-Path $root 'build\app\outputs\flutter-apk\app-release.apk'

function Write-Step($text) {
    Write-Host ''
    Write-Host "==> $text" -ForegroundColor Cyan
}

function Write-Problem($text) {
    Write-Host ''
    Write-Host "FEHLER: $text" -ForegroundColor Red
}

# Schreibt UTF-8 ohne BOM - Set-Content/Out-File setzen hier eins, und ein
# BOM am Anfang von pubspec.yaml verwirrt manche YAML-Leser.
function Set-TextNoBom($path, $text) {
    $utf8 = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($path, $text, $utf8)
}

# Vergleicht "1.10.0" und "1.9.0" als Zahlen, nicht als Text - dieselbe Regel
# wie compareVersions() in lib/update_controller.dart, damit Skript und App
# sich nie uneinig sind, welche Version die neuere ist.
function Compare-Version($a, $b) {
    $left = $a.Split('.')
    $right = $b.Split('.')
    for ($i = 0; $i -lt 3; $i++) {
        $l = [int]$left[$i]
        $r = [int]$right[$i]
        if ($l -gt $r) { return 1 }
        if ($l -lt $r) { return -1 }
    }
    return 0
}

# --- 1. Eingaben und Werkzeuge pruefen -------------------------------------

if ($Version -notmatch '^\d+\.\d+\.\d+$') {
    Write-Problem "Die Version muss aus drei Zahlen mit Punkten bestehen, z.B. 1.1.0 (bekommen: '$Version')"
    exit 1
}

foreach ($tool in @('git', 'gh', 'flutter')) {
    if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
        Write-Problem "'$tool' ist nicht installiert oder nicht im PATH."
        exit 1
    }
}

gh auth status | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Problem 'Bei GitHub nicht angemeldet. Einmalig ausfuehren:  gh auth login'
    exit 1
}

# Sonst enthaelt die hochgeladene APK Aenderungen, die im Repository nicht
# stehen - beim naechsten Build auf einem anderen Rechner (oder nach einem
# git checkout) waere die Version dann eine andere als die veroeffentlichte.
$dirty = git status --porcelain
if (-not [string]::IsNullOrWhiteSpace(($dirty -join ''))) {
    Write-Problem 'Es gibt noch nicht committete Aenderungen:'
    Write-Host ($dirty -join "`n")
    Write-Host ''
    Write-Host 'Erst committen, dann das Release bauen:' -ForegroundColor Yellow
    Write-Host '  git add -A'
    Write-Host '  git commit -m "..."'
    exit 1
}

# --- 2. Alte Version lesen, neue pruefen -----------------------------------

$pubspec = Get-Content $pubspecPath -Raw
# [ \t]* statt \s* am Zeilenende: \s schliesst den Zeilenumbruch mit ein,
# und im Multiline-Modus wuerde das Ersetzen unten damit die Leerzeile
# hinter der Version mit auffressen. Das Zeilenende steht im Vorausblick,
# nicht im Treffer: pubspec.yaml hat hier CRLF, und ein $ direkt hinter
# [ \t]* wuerde am \r scheitern - beim Ersetzen bliebe es dafuer erhalten.
if ($pubspec -notmatch '(?m)^version:[ \t]*(\d+\.\d+\.\d+)\+(\d+)[ \t]*(?=\r?$)') {
    Write-Problem "In pubspec.yaml steht keine Zeile der Form 'version: 1.0.0+1'."
    exit 1
}
$oldVersion = $Matches[1]
$oldBuild = [int]$Matches[2]
$newBuild = $oldBuild + 1

if ((Compare-Version $Version $oldVersion) -le 0) {
    Write-Problem "$Version ist nicht neuer als die aktuelle Version $oldVersion. Android installiert eine APK nur ueber eine bestehende, wenn sie hoeher ist."
    exit 1
}

$tag = "v$Version"
git rev-parse -q --verify "refs/tags/$tag" | Out-Null
if ($LASTEXITCODE -eq 0) {
    Write-Problem "Das Tag $tag gibt es schon. Nimm eine hoehere Version."
    exit 1
}

Write-Host "Aktuell:  $oldVersion+$oldBuild"
Write-Host "Neu:      $Version+$newBuild"

# --- 3. Release-Notizen zusammenstellen ------------------------------------

if ([string]::IsNullOrWhiteSpace($Notes)) {
    # Ueber die Tag-Liste statt ueber 'git describe': das schimpft nach
    # stderr, wenn es noch gar kein Tag gibt, und genau das ist beim ersten
    # Release der Normalfall.
    $lastTag = git tag --list --sort=-v:refname | Select-Object -First 1
    if (-not [string]::IsNullOrWhiteSpace($lastTag)) {
        $log = git log --pretty=format:"- %s" "$lastTag..HEAD"
    } else {
        # Noch kein einziges Release: die letzten Commits als Anhaltspunkt.
        $log = git log --pretty=format:"- %s" -n 20
    }
    if ($null -eq $log -or $log.Count -eq 0) {
        $Notes = "Version $Version"
    } else {
        $Notes = ($log -join "`n")
    }
}

Write-Host ''
Write-Host 'Release-Notizen:' -ForegroundColor DarkGray
Write-Host $Notes -ForegroundColor DarkGray

if ($DryRun) {
    Write-Host ''
    Write-Host 'DryRun: es wurde nichts geaendert, gebaut oder hochgeladen.' -ForegroundColor Yellow
    exit 0
}

# --- 4. Version setzen und bauen -------------------------------------------

Write-Step "Version in pubspec.yaml auf $Version+$newBuild setzen"
$updated = $pubspec -replace '(?m)^version:[ \t]*\d+\.\d+\.\d+\+\d+[ \t]*(?=\r?$)', "version: $Version+$newBuild"
Set-TextNoBom $pubspecPath $updated

Write-Step 'Release-APK bauen (dauert ein paar Minuten)'
flutter build apk --release
$buildOk = ($LASTEXITCODE -eq 0) -and (Test-Path $builtApk)
if (-not $buildOk) {
    # Die alte Version zurueckschreiben: ein bereits erhoehtes pubspec.yaml
    # nach einem fehlgeschlagenen Build waere beim naechsten Versuch nur im
    # Weg (das Skript wuerde die Version dann fuer "nicht neuer" halten).
    Set-TextNoBom $pubspecPath $pubspec
    Write-Problem 'Build fehlgeschlagen. pubspec.yaml wurde zurueckgesetzt, es wurde nichts hochgeladen.'
    exit 1
}

# Unter einem Namen mit Versionsnummer hochladen: im Download-Ordner des
# Handys liegen sonst irgendwann zehn Dateien namens app-release.apk.
$namedApk = Join-Path (Split-Path $builtApk) "hanneslauncher-$Version.apk"
Copy-Item $builtApk $namedApk -Force

# --- 5. Committen, pushen, Release anlegen ---------------------------------

Write-Step 'Versionsaenderung committen und pushen'
git add -- pubspec.yaml
git commit -m "release: $tag"
if ($LASTEXITCODE -ne 0) {
    Write-Problem 'Commit fehlgeschlagen. pubspec.yaml steht auf der neuen Version, sonst ist nichts passiert.'
    exit 1
}
git push
if ($LASTEXITCODE -ne 0) {
    Write-Problem "Push fehlgeschlagen. Der Commit liegt lokal vor. Nach dem Beheben weiter mit:  git push  und dann  gh release create $tag `"$namedApk`" --title $tag --notes `"...`""
    exit 1
}

Write-Step "Release $tag auf GitHub anlegen und APK anhaengen"
$notesFile = Join-Path $env:TEMP 'hanneslauncher-release-notes.md'
Set-TextNoBom $notesFile $Notes
gh release create $tag $namedApk --title $tag --notes-file $notesFile
$releaseOk = ($LASTEXITCODE -eq 0)
Remove-Item $notesFile -ErrorAction SilentlyContinue
if (-not $releaseOk) {
    Write-Problem "Release konnte nicht angelegt werden. Commit und Push sind durch, es fehlt nur noch:  gh release create $tag `"$namedApk`" --title $tag --notes `"...`""
    exit 1
}

Write-Host ''
Write-Host "Fertig: $tag ist veroeffentlicht." -ForegroundColor Green
Write-Host 'Auf dem Handy: Panel herunterziehen -> Einstellungen -> App -> Update.'
Write-Host 'Der rote Punkt kommt spaetestens 6 Stunden nach dem Upload von allein,'
Write-Host 'mit "Jetzt pruefen" sofort.'
