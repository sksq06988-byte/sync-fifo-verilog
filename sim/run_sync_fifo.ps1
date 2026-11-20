param(
    [int]$DataWidth = 8,
    [int]$Depth = 4,
    [int]$Seed = 1,
    [int]$RandomCycles = 1000,
    [switch]$Matrix
)
$ErrorActionPreference = 'Continue'
$Root = Split-Path -Parent $PSScriptRoot
function Resolve-IcarusTool([string]$Name, [string[]]$Fallbacks) {
    $command = Get-Command $Name -CommandType Application -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if ($null -ne $command) { return $command.Source }

    foreach ($candidate in $Fallbacks) {
        if (Test-Path -LiteralPath $candidate) { return $candidate }
    }

    $searched = $Fallbacks -join ', '
    throw "$Name not found. Add Icarus to PATH or install it in one of: $searched"
}

$Iverilog = Resolve-IcarusTool 'iverilog' @(
    'C:\iverilog\bin\iverilog.exe',
    'C:\Program Files\iverilog\bin\iverilog.exe',
    'C:\Program Files\Icarus Verilog\bin\iverilog.exe'
)
$Vvp = Resolve-IcarusTool 'vvp' @(
    'C:\iverilog\bin\vvp.exe',
    'C:\Program Files\iverilog\bin\vvp.exe',
    'C:\Program Files\Icarus Verilog\bin\vvp.exe'
)
$logDir = Join-Path $PSScriptRoot 'logs'
$waveDir = Join-Path $PSScriptRoot 'waves'
New-Item -ItemType Directory -Force $logDir, $waveDir | Out-Null

function Invoke-FifoCase([int]$W, [int]$D, [int]$S, [int]$Cycles) {
    $tag = "w${W}_d${D}_s${S}"
    $out = Join-Path $PSScriptRoot "sync_$tag.vvp"
    $log = Join-Path $logDir "sync_$tag.log"
    $vcd = Join-Path $waveDir "sync_$tag.vcd"
    $compileArgs = @(
        '-g2012', '-s', 'tb_sync_fifo',
        "-Ptb_sync_fifo.DATA_WIDTH=$W",
        "-Ptb_sync_fifo.DEPTH=$D",
        "-Ptb_sync_fifo.SEED=$S",
        "-Ptb_sync_fifo.RANDOM_CYCLES=$Cycles",
        '-o', $out,
        (Join-Path $Root 'rtl\sync_fifo.v'),
        (Join-Path $Root 'tb\tb_sync_fifo.sv')
    )
    & $Iverilog @compileArgs *> $log
    $compileExit = $LASTEXITCODE
    Get-Content -LiteralPath $log
    if ($compileExit -ne 0) { throw "sync compile failed: $tag" }
    Push-Location $waveDir
    try {
        & $Vvp $out "+SEED=$S" "+VCD=$(Split-Path -Leaf $vcd)" *> $log
    } finally {
        Pop-Location
    }
    $simExit = $LASTEXITCODE
    Get-Content -LiteralPath $log
    if ($simExit -ne 0) { throw "sync simulation failed: $tag" }
    if (-not (Select-String -LiteralPath $log -Pattern 'SYNC_FIFO_PASS')) {
        throw "sync test did not pass: $tag"
    }
    Remove-Item -LiteralPath $out -Force
}

if ($Matrix) {
    foreach ($cfg in @(@(8,1), @(8,3), @(8,4), @(16,4))) {
        foreach ($s in @(1,7,42)) {
            Invoke-FifoCase -W $cfg[0] -D $cfg[1] -S $s -Cycles $RandomCycles
        }
    }
} else {
    Invoke-FifoCase -W $DataWidth -D $Depth -S $Seed -Cycles $RandomCycles
}
Write-Output 'SYNC FIFO REGRESSION PASS'
