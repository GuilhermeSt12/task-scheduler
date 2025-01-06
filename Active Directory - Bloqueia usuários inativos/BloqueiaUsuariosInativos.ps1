# Diretório e arquivo de log
$logPath = "C:\scripts\BloqueiaUsuariosInativos"
$logFile = Join-Path -Path $logPath -ChildPath "BloqueiaUsuariosInativos.log"

# Criar diretório se não existir
if (!(Test-Path -Path $logPath)) {
    New-Item -ItemType Directory -Path $logPath
}

# Lista de exceções (nomes ou fragmentos de nomes de usuários a serem ignorados)
$excecoes = @("svc", "sophos", "Administrador", "Administrator", "Admin", "VSS")

# Obter data atual para comparação
$dataAtual = Get-Date
$dataLimite = $dataAtual.AddDays(-30)

# Adicionar cabeçalho no log indicando início de execução
if (!(Test-Path -Path $logFile)) {
    Add-Content -Path $logFile -Value "Username,DisplayName,LastLogon,DeactivationDate"
}

# Capturar todos os usuários do domínio
$users = Get-ADUser -Filter * -Property DisplayName | Where-Object { $_.Enabled -eq $true }

# Loop para verificar último logon de cada usuário
foreach ($user in $users) {
    $username = $user.SamAccountName
    $displayName = $user.DisplayName

    # Verificar se o usuário está na lista de exceções
    $ignorarUsuario = $excecoes | ForEach-Object { 
        if ($username -like "*$_*" -or $displayName -like "*$_*") { 
            $true 
        } 
    } | Where-Object { $_ -eq $true }

    if ($ignorarUsuario) {
        # Ignorar usuários na lista de exceções
        continue
    }

    # Capturar informações de logon com net user
    $output = net user $username /domain | Select-String -Pattern "Last logon\s+(\d+/\d+/\d+\s+\d+:\d+:\d+|\s+Never)" -AllMatches

    if ($output) {
        $lastLogon = $output.Matches.Groups[1].Value.Trim()
        
        if ($lastLogon -eq "Never") {
            # Se nunca logou, definir como null
            $lastLogonDate = $null
        } else {
            # Tentar converter a data; caso falhe, atribuir $null
            try {
                $lastLogonDate = [datetime]::ParseExact($lastLogon, "dd/MM/yyyy HH:mm:ss", $null)
            } catch {
                $lastLogonDate = $null
            }
        }
    } else {
        $lastLogonDate = $null
    }

    # Verificar se o último logon é maior que a data limite
    if (-not $lastLogonDate -or $lastLogonDate -lt $dataLimite) {
        # Registrar a ação no log em uma única linha
        $logEntry = "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss') = Usuario bloqueado: $username | $displayName | Ultimo logon em: $lastLogon"
        Add-Content -Path $logFile -Value $logEntry

        # Desabilitar usuário
        Disable-ADAccount -Identity $username
    }
}

Write-Host "Script finalizado. Relatório salvo em $logFile"
