
# ARGon - Generador de datos para la app interna
# Ejecutar para actualizar datos.json

$CLIENTES_PATH = "C:\Users\Luis\OneDrive\Favoritos\CLIENTES"
$OUTPUT_PATH   = Join-Path $PSScriptRoot "datos.json"

$ANIOS_VIGENTES = @("2025", "2026")

$KW_POLIZA  = @("poliza","pza","cert","certif","circulaci","circ ","mercosur","conosur","credencial","chequera","endoso")
$KW_FACTURA = @("factura","fc ","fc-","recibo","lw-recibo","cuota","vep","pago")
$KW_EXCLUIR = @(".lnk","dni ","domicilio","constancia afip","constancia suss","poder ","denuncia","foto ","presupuesto","baja ")

function Quitar-Acentos($s) {
    $nfd = $s.Normalize([System.Text.NormalizationForm]::FormD)
    $sb  = [System.Text.StringBuilder]::new()
    foreach ($c in $nfd.ToCharArray()) {
        if ([System.Globalization.CharUnicodeInfo]::GetUnicodeCategory($c) -ne `
            [System.Globalization.UnicodeCategory]::NonSpacingMark) {
            [void]$sb.Append($c)
        }
    }
    return $sb.ToString()
}

function Get-TipoArchivo($nombre) {
    $n = (Quitar-Acentos $nombre).ToLower()
    foreach ($x in $KW_EXCLUIR) { if ($n -like "*$x*") { return $null } }
    foreach ($k in $KW_POLIZA)  { if ($n -like "*$k*") { return "poliza" } }
    foreach ($k in $KW_FACTURA) { if ($n -like "*$k*") { return "factura" } }
    if ($n -match "\.(pdf|xlsx|xls|docx)$") { return "otro" }
    return $null
}

function Format-Nombre($raw) {
    ($raw -split " " | ForEach-Object {
        if ($_.Length -le 2) { $_.ToUpper() }
        else { $_.Substring(0,1).ToUpper() + $_.Substring(1).ToLower() }
    }) -join " "
}

$clientes = @()
$total = 0
$conVigentes = 0

Write-Host "Escaneando $CLIENTES_PATH ..."
$carpetas = Get-ChildItem $CLIENTES_PATH -Directory | Sort-Object Name

foreach ($carpeta in $carpetas) {
    $total++
    $archivosCliente = @()
    $todosArchivos = Get-ChildItem $carpeta.FullName -Recurse -File -ErrorAction SilentlyContinue

    foreach ($archivo in $todosArchivos) {
        $enAnioVigente = $false
        $anioDetectado = $null
        $ruta = $archivo.FullName

        foreach ($anio in $ANIOS_VIGENTES) {
            if ($ruta -match "\\$anio\\") {
                $enAnioVigente = $true
                $anioDetectado = $anio
                break
            }
        }

        if (-not $enAnioVigente) {
            $n = $archivo.Name
            if     ($n -match "-25\." -or $n -match " 25\.") { $anioDetectado = "2025"; $enAnioVigente = $true }
            elseif ($n -match "-26\." -or $n -match " 26\.") { $anioDetectado = "2026"; $enAnioVigente = $true }
            elseif ($n -match "2025")                         { $anioDetectado = "2025"; $enAnioVigente = $true }
            elseif ($n -match "2026")                         { $anioDetectado = "2026"; $enAnioVigente = $true }
        }

        if (-not $enAnioVigente) { continue }

        $tipo = Get-TipoArchivo $archivo.Name
        if ($null -eq $tipo) { continue }

        $rutaRelativa = $archivo.FullName.Substring($carpeta.FullName.Length + 1)
        $partes = $rutaRelativa -split "\\"
        # Cobertura: bajar hasta la carpeta más específica antes del año o carpeta excluida
        $cobertura = "General"
        for ($pi = 0; $pi -lt ($partes.Count - 1); $pi++) {
            $parte = $partes[$pi]
            if ($parte -match "^\d{4}$" -and [int]$parte -ge 2015 -and [int]$parte -le 2030) { break }   # llegamos al año, parar
            if ($parte -match "(?i)^(documentos|siniestro[s]?|fc|cotizaciones|siniestro\s)") { break }
            $cobertura = $parte   # usar nivel más profundo encontrado
        }

        # Ruta relativa desde la raiz de CLIENTES (para que el servidor pueda servirla)
        $rutaDesdeClientes = $carpeta.Name + "\" + $rutaRelativa

        $archivosCliente += [ordered]@{
            nombre    = $archivo.Name
            tipo      = $tipo
            anio      = $anioDetectado
            cobertura = $cobertura
            ruta      = $rutaDesdeClientes   # ← NUEVO: ruta completa desde CLIENTES
        }
    }

    if ($archivosCliente.Count -eq 0) { continue }
    $conVigentes++

    # Leer .metadata.json si existe (generado por los agentes descargadores)
    $metadataFile = Join-Path $carpeta.FullName ".metadata.json"
    $cuotaImpaga    = $false
    $fechaNacimiento = $null
    $polizasMeta     = @()
    if (Test-Path $metadataFile) {
        try {
            $meta = Get-Content $metadataFile -Raw -Encoding UTF8 | ConvertFrom-Json
            if ($meta.fechaNacimiento) { $fechaNacimiento = $meta.fechaNacimiento }
            if ($meta.polizas) {
                foreach ($prop in $meta.polizas.PSObject.Properties) {
                    $p = $prop.Value
                    if ($p.pagada -eq $false) { $cuotaImpaga = $true }
                    $polizasMeta += [ordered]@{
                        nro          = $prop.Name
                        compania     = $p.compania
                        ramo         = $p.ramo
                        vigHasta     = $p.vigHasta
                        pagada       = if ($null -ne $p.pagada) { $p.pagada } else { $true }
                        proximaCuota = $p.proximaCuota
                        montoCuota   = $p.montoCuota
                    }
                }
            }
        } catch {}
    }

    $clienteObj = [ordered]@{
        id               = $carpeta.Name
        nombre           = (Format-Nombre $carpeta.Name)
        vigente          = $true
        archivos         = $archivosCliente
    }
    if ($null -ne $fechaNacimiento) { $clienteObj.fechaNacimiento = $fechaNacimiento }
    if ($cuotaImpaga)               { $clienteObj.cuotaImpaga     = $true }
    if ($polizasMeta.Count -gt 0)   { $clienteObj.polizas         = $polizasMeta }

    $clientes += $clienteObj

    if ($total % 100 -eq 0) { Write-Host "  $total carpetas procesadas..." }
}

$resultado = [ordered]@{
    generado      = (Get-Date -Format "yyyy-MM-ddTHH:mm:ss")
    totalClientes = $conVigentes
    clientes      = $clientes
}

$json = $resultado | ConvertTo-Json -Depth 10 -Compress
[System.IO.File]::WriteAllText($OUTPUT_PATH, $json, [System.Text.Encoding]::UTF8)

Write-Host ""
Write-Host "OK: $conVigentes clientes vigentes de $total totales"
Write-Host "Archivo: $OUTPUT_PATH"
