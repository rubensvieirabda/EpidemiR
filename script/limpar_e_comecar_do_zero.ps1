# Limpa dados brutos e artefatos gerados, preservando os .gitkeep.
# Uso:
#   pwsh -File script/limpar_e_comecar_do_zero.ps1
#   pwsh -File script/limpar_e_comecar_do_zero.ps1 -WhatIf   # so simula
#
# Funciona de qualquer diretorio: a raiz e derivada daqui mesmo.

[CmdletBinding(SupportsShouldProcess = $true)]
param()

$root = Split-Path -Parent $PSScriptRoot
$dirs = @(
    (Join-Path $root 'data\raw'),
    (Join-Path $root 'data\processed'),
    (Join-Path $root 'data\reports')
)

$acao = if ($WhatIfPreference) { 'simulado' } else { 'removido' }
$removidos = 0

foreach ($dir in $dirs) {
    if (-not (Test-Path -LiteralPath $dir)) { continue }

    Get-ChildItem -LiteralPath $dir -File |
        Where-Object { $_.Name -ne '.gitkeep' } |
        ForEach-Object {
            if ($PSCmdlet.ShouldProcess($_.FullName, 'Remover')) {
                Remove-Item -LiteralPath $_.FullName -Force
            }
            $relativo = $_.FullName.Replace($root + [IO.Path]::DirectorySeparatorChar, '')
            Write-Output ("[$acao] $relativo")
            $removidos++
        }
}

Write-Output ("Pronto. $removidos arquivo(s) [$acao].")
Write-Output 'Para recomecar: Rscript tools/buscar_dados_reais.R ; Rscript run_analysis.R'
