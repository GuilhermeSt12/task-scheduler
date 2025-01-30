# Caminho do log
$logPath = "C:\scripts\DesativaUsuariosInativos\DesativaUsuariosInativos.log"
# Lista de exceções
$excecoes = @("svc", "sophos", "Administrador", "Administrator", "Admin", "VSS", "carlos casemiro")

# Função para registrar log
Function Escrever-Log {
    param (
        [string]$mensagem
    )
    Add-Content -Path $logPath -Value "$((Get-Date).ToString()): $mensagem"
}

# Obter a data atual e a data de 30 dias atrás
$dataAtual = Get-Date
$dataLimite = $dataAtual.AddDays(-30)

# Obter lista de usuários do AD
$usuarios = Get-ADUser -Filter * -Property LastLogonDate, PasswordLastSet, WhenCreated, PasswordNeverExpires, Enabled

foreach ($usuario in $usuarios) {
    $nomeUsuario = $usuario.SamAccountName
    $descricaoUsuario = $usuario.Description
    $enabled = $usuario.Enabled

    # Verificar se o nome de usuário contém alguma das palavras de exceção
    $excecaoEncontrada = $false
    foreach ($excecao in $excecoes) {
        if ($nomeUsuario -like "*$excecao*") {
            $excecaoEncontrada = $true
            break
        }
    }

    if (-not $excecaoEncontrada -and $enabled) {
        $lastLogon = $usuario.LastLogonDate
        $passwordLastSet = $usuario.PasswordLastSet
        $whenCreated = $usuario.WhenCreated
        $passwordNeverExpires = $usuario.PasswordNeverExpires

        $motivo = ""
        $desativar = $true
        
        # Verificar se o usuário logou nos últimos 30 dias
        if ($lastLogon -ne $null -and $lastLogon -ge $dataLimite) {
            $motivo = "Usuário logou recentemente em $lastLogon."
            $desativar = $false
        } elseif ($passwordLastSet -ne $null -and $passwordLastSet -ge $dataLimite) {
            # Verificar se o usuário alterou a senha nos últimos 30 dias
            $motivo = "Senha alterada recentemente em $passwordLastSet."
            $desativar = $false
        } elseif ($passwordNeverExpires) {
            # Verificar se a senha nunca expira
            $motivo = "Senha nunca expira."
            $desativar = $false
        } elseif ($whenCreated -ge $dataLimite) {
            # Se o usuário foi criado recentemente
            $motivo = "Usuário criado recentemente em $whenCreated."
            $desativar = $false
        } else {
            # Se nenhum critério acima foi atendido
            $motivo = "Último logon em $lastLogon. Última definição de senha em $passwordLastSet."
        }

        if ($desativar) {
            # Desativar usuário (comentado para validação)
            Disable-ADAccount -Identity $usuario

            # Registrar no log
            Escrever-Log "Usuário desativado: $nomeUsuario. Motivo: $motivo"
        }
    }
}
Escrever-Log "Verificação concluída."
