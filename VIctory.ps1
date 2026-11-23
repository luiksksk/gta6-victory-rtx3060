#requires -Version 5.1
[CmdletBinding()]
param(
    [ValidateSet('Compilar','Executar','Config')]
    [string]$Acao = 'Executar',
    [ValidateSet('Execucao','Diagnostico')]
    [string]$Variante = 'Execucao',
    [string]$PastaJogo,
    [string]$PerfilOrigem,
    [ValidateSet('series-x','series-s')]
    [string]$Console = 'series-x'
)

$ErrorActionPreference = 'Stop'
$base = '015d45bfff4d82e7afad89afe10dd24e5a402ef8'
$arvores = @{
    Execucao = '5cbdcebfd72456bf885d9f0bf1a713424c7b951b'
    Diagnostico = '78f8c7a553a8cd0cd5fd1a3af3a95821e8a6b702'
}
# PowerShell accepts case-insensitive parameter values. Keep paths canonical.
$tipo = if ($Variante -eq 'Diagnostico') { 'Diagnostico' } else { 'Execucao' }
$arvore = $arvores[$tipo]
$raiz = Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'VIctory-RTX3060-Publico'
$fontes = Join-Path $raiz 'fontes'
$fonte = Join-Path $fontes $arvore
$build = Join-Path (Join-Path $raiz 'build') $arvore
$binario = Join-Path $build 'diag\victory.exe'
$dados = Join-Path (Join-Path $raiz 'dados') $tipo
$cache = Join-Path (Join-Path $raiz 'cache') $tipo

function Invoke-Git([string[]]$Argumentos) {
    & git @Argumentos
    if ($LASTEXITCODE -ne 0) { throw "Git retornou $LASTEXITCODE ao executar $($Argumentos -join ' ')." }
}

# All staging directories are created in this invocation under the supplied parent.
function Remove-Staging([string]$Pasta, [string]$Pai) {
    if (!(Test-Path -LiteralPath $Pasta)) { return }
    $item = Get-Item -LiteralPath $Pasta -Force
    $esperado = (Get-Item -LiteralPath $Pai).FullName
    if ($item.Parent.FullName -ne $esperado -or $item.Name -notmatch '^preparo-[a-f0-9]{32}$' -or
        ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
        throw "Diretorio de preparo inesperado: $Pasta"
    }
    Remove-Item -LiteralPath $item.FullName -Recurse -Force
}

function Get-PatchedSource {
    if (!(Test-Path -LiteralPath $fonte)) {
        [void][IO.Directory]::CreateDirectory($fontes)
        $tmp = Join-Path $fontes ('preparo-' + [guid]::NewGuid().ToString('N'))
        [void][IO.Directory]::CreateDirectory($tmp)
        try {
            Invoke-Git @('-C',$tmp,'init','--quiet')
            Invoke-Git @('-C',$tmp,'config','core.autocrlf','false')
            Invoke-Git @('-C',$tmp,'fetch','--quiet','--depth=1','https://github.com/Marvisak/VIctory.git',$base)
            Invoke-Git @('-C',$tmp,'checkout','--quiet','--detach','FETCH_HEAD')
            $patches = @('execucao-rtx3060.patch')
            if ($tipo -eq 'Diagnostico') { $patches += 'diagnostico-cena.patch' }
            foreach ($patch in $patches) {
                $arquivo = Join-Path (Join-Path $PSScriptRoot 'patches') $patch
                Invoke-Git @('-C',$tmp,'apply','--index','--whitespace=error-all',$arquivo)
            }
            if ((Invoke-Git @('-C',$tmp,'write-tree')) -ne $arvore) {
                throw 'A fonte preparada divergiu da versao testada.'
            }
            try { [IO.Directory]::Move($tmp, $fonte) }
            catch { if (!(Test-Path -LiteralPath $fonte -PathType Container)) { throw } }
        } finally { Remove-Staging $tmp $fontes }
    }
    if ((Invoke-Git @('-C',$fonte,'rev-parse','HEAD')) -ne $base -or
        (Invoke-Git @('-C',$fonte,'write-tree')) -ne $arvore) {
        throw "A copia de compilacao em $fonte tem outra revisao."
    }
    Invoke-Git @('-C',$fonte,'diff','--quiet','--')
}

function Copy-TestProfile([string]$Origem) {
    $titulo = '7952987A'
    $entrada = Get-Item -LiteralPath (Join-Path $Origem $titulo)
    if (!$entrada.PSIsContainer) { throw "Informe a pasta de dados que contem $titulo." }
    [void][IO.Directory]::CreateDirectory($dados)
    $destino = Join-Path $dados $titulo
    if (Test-Path -LiteralPath $destino) {
        throw "Ja existe um perfil em $destino. Para utiliza-lo, execute sem -PerfilOrigem."
    }
    $tmp = Join-Path $dados ('preparo-' + [guid]::NewGuid().ToString('N'))
    [void][IO.Directory]::CreateDirectory($tmp)
    try {
        $copiados = 0
        foreach ($rel in @('saves','storage\settings')) {
            $de = Join-Path $entrada.FullName $rel
            if (!(Test-Path -LiteralPath $de -PathType Container)) { continue }
            $dir = Get-Item -LiteralPath $de
            $links = @(Get-ChildItem -LiteralPath $de -Force -Recurse -Attributes ReparsePoint)
            if (($dir.Attributes -band [IO.FileAttributes]::ReparsePoint) -or $links.Count) {
                throw "A copia de perfil requer arquivos e diretorios comuns em $de."
            }
            $para = Join-Path $tmp $rel
            [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($para))
            Copy-Item -LiteralPath $de -Destination $para -Recurse -Force
            $copiados++
        }
        if (!$copiados) { throw 'O perfil informado nao contem saves ou storage\settings.' }
        [IO.Directory]::Move($tmp, $destino)
    } finally { Remove-Staging $tmp $dados }
}

if ($Acao -eq 'Compilar') {
    if ($PastaJogo -or $PerfilOrigem) { throw 'A compilacao usa somente a fonte do emulador.' }
    $cargo = Get-Command cargo.exe -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($cargo) { $cargoExe = $cargo.Source }
    else {
        $cargoHome = if ($env:CARGO_HOME) { $env:CARGO_HOME } else { Join-Path $env:USERPROFILE '.cargo' }
        $cargoExe = Join-Path $cargoHome 'bin\cargo.exe'
        if (!(Test-Path -LiteralPath $cargoExe -PathType Leaf)) { throw 'Instale o Rust via rustup com o alvo x86_64-pc-windows-msvc.' }
    }
    Get-PatchedSource
    Push-Location -LiteralPath $fonte
    try {
        & $cargoExe '+1.98.1' build --locked --profile diag --features diagnostics -p victory --target-dir $build -j 2
        if ($LASTEXITCODE -ne 0) { throw "A compilacao falhou com o codigo $LASTEXITCODE." }
    } finally { Pop-Location }
    if (!(Test-Path -LiteralPath $binario -PathType Leaf)) { throw 'O Cargo terminou sem produzir victory.exe.' }
    Write-Host "Compilado em $binario"
    return
}

if (!(Test-Path -LiteralPath $binario -PathType Leaf)) {
    throw "Compile primeiro com: .\VIctory.ps1 -Acao Compilar -Variante $tipo"
}
if (!$PastaJogo) { $PastaJogo = Read-Host 'Caminho da pasta da sua instalacao de GTA VI para Xbox' }
$jogo = Get-Item -LiteralPath ($PastaJogo.Trim().Trim('"'))
if (!$jogo.PSIsContainer) { throw 'Informe a pasta da instalacao.' }
$tituloExe = Join-Path $jogo.FullName 'game_scarlett_master.exe'
if ($Acao -eq 'Executar' -and !(Test-Path -LiteralPath $tituloExe -PathType Leaf)) {
    throw "Executavel do titulo ausente na pasta informada: $tituloExe"
}
if ($PerfilOrigem) { Copy-TestProfile $PerfilOrigem }

$config = @{
    VICTORY_GAME_DIR = $jogo.FullName
    VICTORY_DATA_DIR = $dados
    VICTORY_CACHE_DIR = $cache
    VICTORY_D3D12_WARP = $null
}
if ($tipo -eq 'Execucao') {
    $config['VICTORY_KEYS'] = $null
    $config['VICTORY_LIVE_KEYS'] = $null
}
$anterior = @{}
foreach ($nome in $config.Keys) { $anterior[$nome] = [Environment]::GetEnvironmentVariable($nome) }
function Set-ProcessEnvironment([string]$Nome, $Valor) {
    if ($null -eq $Valor) {
        Remove-Item -LiteralPath "Env:\$Nome" -ErrorAction SilentlyContinue
    } else {
        [Environment]::SetEnvironmentVariable($Nome, [string]$Valor)
    }
}
try {
    foreach ($nome in $config.Keys) { Set-ProcessEnvironment $nome $config[$nome] }
    Write-Host "Pasta do perfil de teste: $dados"
    if ($Acao -eq 'Config') { & $binario config }
    else { & $binario run $tituloExe --execute --console $Console }
    $codigo = $LASTEXITCODE
} finally {
    foreach ($nome in $config.Keys) { Set-ProcessEnvironment $nome $anterior[$nome] }
}
exit $codigo
