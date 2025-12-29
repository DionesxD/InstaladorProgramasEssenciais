###############################################################################
# INSTALADOR AUTÔNOMO v4.6 — FINAL (PATCH: renomear, log arquivo, opções, progresso)
# Versão adaptada para ps2exe — sem saída indesejada no pipeline
###############################################################################

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Drawing

###############################################################################
# Verifica se está em modo Administrador
###############################################################################
function Test-Admin {
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
    if (-not $isAdmin) {
        [System.Windows.MessageBox]::Show("Este instalador precisa ser executado como Administrador.`nExecute como Administrador e rode novamente.", "Permissão necessária", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning) | Out-Null
        [System.Environment]::Exit(1)
    }
}
Test-Admin

###############################################################################
# LOG FÍSICO + RICH TEXT
###############################################################################

$LogFile = Join-Path $env:TEMP "Instalador_v4.6.log"

function Initialize-Log {
    try {
        $dir = Split-Path $LogFile -Parent
        if (!(Test-Path $dir)) { New-Item -Path $dir -ItemType Directory -Force | Out-Null }
        if (!(Test-Path $LogFile)) { "" | Out-File -FilePath $LogFile -Encoding UTF8 }
    } catch {}
}
Initialize-Log

function Is-AppInstalled {
    param([string]$appID)

    try {
        $pkg = winget list --id $appID --source winget 2>$null
        return ($pkg -match $appID)
    }
    catch { return $false }
}

function FileLog {
    param([string]$msg)
    try { Add-Content -Path $LogFile -Value ("{0} - {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $msg) } catch {}
}

function Log {
    param([string]$msg, [string]$color = "White")
    if ($Global:TxtLog -ne $null) {
        try {
            $range = New-Object System.Windows.Documents.TextRange($Global:TxtLog.Document.ContentEnd, $Global:TxtLog.Document.ContentEnd)
            $range.Text = "$(Get-Date -Format 'HH:mm:ss') - $msg`n"
            $range.ApplyPropertyValue([System.Windows.Documents.TextElement]::ForegroundProperty, $color)
            $Global:TxtLog.ScrollToEnd()
        } catch {}
    }
    FileLog $msg
}

###############################################################################
# LOGO BASE64 (placeholder)
###############################################################################
$LogoBase64 = @"
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
"@

# Carrega logo Base64 -> BitmapImage (se existir)
$bmp = $null
if ($LogoBase64 -and $LogoBase64.Trim().Length -gt 10) {
    try {
        $logoBytes = [Convert]::FromBase64String(($LogoBase64 -replace '\s',''))
        $ms = New-Object System.IO.MemoryStream(,$logoBytes)
        $bmp = New-Object System.Windows.Media.Imaging.BitmapImage
        $bmp.BeginInit()
        $bmp.StreamSource = $ms
        $bmp.CacheOption = 'OnLoad'
        $bmp.EndInit()
        $null = $ms   # suprime possíveis outputs
    } catch {
        Log ("Aviso: falha ao carregar logo embutida: {0}" -f $_.ToString(), "Yellow")
        $bmp = $null
    }
} else {
    Log "Logo base64 vazio ou muito curto. A splash usará texto." "Yellow"
}

###############################################################################
# SPLASH
###############################################################################
$SplashXAML = @"
<Window xmlns='http://schemas.microsoft.com/winfx/2006/xaml/presentation'
        WindowStyle='None' AllowsTransparency='True' Background='Transparent'
        ShowInTaskbar='False' ResizeMode='NoResize' WindowStartupLocation='CenterScreen'
        Width='520' Height='320'>
  <Border CornerRadius='12' Background='White' Padding='14' BorderBrush='LightGray' BorderThickness='1'>
    <Grid>
      <Grid.RowDefinitions>
        <RowDefinition Height='*'/>
        <RowDefinition Height='40'/>
      </Grid.RowDefinitions>
      <StackPanel HorizontalAlignment='Center' VerticalAlignment='Center'>
        <Image Name='SplashLogo' Width='280' Height='160' Stretch='Uniform'/>
        <TextBlock Text='Carregando instalador...' FontWeight='SemiBold' FontSize='15'
                   Foreground='#333' HorizontalAlignment='Center' Margin='0,10,0,0'/>
      </StackPanel>
      <ProgressBar Name='SplashProgress' Grid.Row='1' Height='12' IsIndeterminate='False' Minimum='0' Maximum='100'/>
    </Grid>
  </Border>
</Window>
"@

function Show-Splash {
    param([int]$durationMs = 3000)
    try {
        $reader = New-Object System.Xml.XmlNodeReader ([xml]$SplashXAML)
        $null = $reader
        $splash = [Windows.Markup.XamlReader]::Load($reader)
        $null = $splash

        $SplashLogo = $splash.FindName("SplashLogo")
        $SplashProgress = $splash.FindName("SplashProgress")

        if ($bmp) { $SplashLogo.Source = $bmp } else { $SplashLogo.Visibility = 'Collapsed' }

        $splash.Opacity = 0
        $splash.Show()
        $null = $splash.Dispatcher.Invoke([action]{}, 'Render')

        $fadeIn = New-Object System.Windows.Media.Animation.DoubleAnimation(0,1,[TimeSpan]::FromMilliseconds(500))
        $splash.BeginAnimation([System.Windows.UIElement]::OpacityProperty, $fadeIn) | Out-Null

        $steps = 40
        $visible = [math]::Max(0, $durationMs - 1000)
        $sleep = [int]([math]::Max(10, $visible / $steps))

        for ($i=0; $i -le $steps; $i++) {
            $progress = [int](($i / $steps) * 100)
            # atualiza UI sem produzir saída
            $null = $SplashProgress.Dispatcher.Invoke([action]{ $SplashProgress.Value = $progress })
            Start-Sleep -Milliseconds $sleep
            $null = $splash.Dispatcher.Invoke([action]{}, 'Background')
        }

        $fadeOut = New-Object System.Windows.Media.Animation.DoubleAnimation(1,0,[TimeSpan]::FromMilliseconds(500))
        $splash.BeginAnimation([System.Windows.UIElement]::OpacityProperty, $fadeOut) | Out-Null
        Start-Sleep -Milliseconds 550
        $splash.Close()
    } catch {
        Log ("Aviso: splash falhou: {0}" -f $_.ToString(), "Red")
    }
    # não retorna nada no pipeline
    $null = $true
}

###############################################################################
# Fallback apps (mapa)
###############################################################################

# Detecta diretório real do script ou do EXE
if ($MyInvocation.MyCommand.Path) {
    $BaseDir = Split-Path -Parent $MyInvocation.MyCommand.Path
} else {
    # Em EXE
    $BaseDir = Split-Path -Parent ([System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName)
}

$FallbackApps = @{
    "Google Chrome" = Join-Path $BaseDir "fallback\ChromeSetup.exe"
    "Mozilla Firefox" = Join-Path $BaseDir "fallback\FirefoxSetup.exe"
    "WinRAR" = Join-Path $BaseDir "fallback\WinRAR.exe"
    "AnyViewer" = Join-Path $BaseDir "fallback\AnyViewer.exe"
    "AnyDesk" = Join-Path $BaseDir "fallback\AnyDesk.exe"
    "Adobe Reader" = Join-Path $BaseDir "fallback\AdobeReader.exe"
    "CrystalDiskInfo" = Join-Path $BaseDir "fallback\CrystalDisk.exe"
    "Spybot Search & Destroy" = Join-Path $BaseDir "fallback\SpyBot.exe"
    "Microsoft Office" = Join-Path $BaseDir "fallback\office365"
    "Panda" = Join-Path $BaseDir "fallback\Panda.msi"
}

$ForceInstallApps = @(
    "Panda",
    "Microsoft Office"
)


###############################################################################
# FUNÇÃO DE INSTALAÇÃO (sem retornar valor no pipeline)
# grava resultado em $script:LastInstallSuccess
###############################################################################
function Install-App {
    param(
        [string]$id,
        [string]$name,
        [string]$LocalExePath = ""
    )

    $script:LastInstallSuccess = $false

    for ($attempt=1; $attempt -le 3; $attempt++) {
        Log "Tentativa $attempt para $name via winget..." "Cyan"
        $cmd = "winget install --id `"$id`" -e --silent --accept-package-agreements --accept-source-agreements"
        try {
            $proc = Start-Process -FilePath "cmd.exe" -ArgumentList "/c $cmd" -PassThru -Wait -WindowStyle Hidden
if ($proc -and $proc.ExitCode -eq 0) {
    Start-Sleep -Seconds 3

    if (Is-AppInstalled $id) {
        Log "$name -> Instalado via winget (confirmado)." "LightGreen"
        $script:LastInstallSuccess = $true
        break
    }
    else {
        Log "$name -> Winget retornou sucesso, mas app NÃO foi detectado." "Yellow"
    }
}

             else {
                Log "$name falhou (tentativa $attempt). Código: $($proc.ExitCode)" "Yellow"
            }
        } catch {
            Log ("Erro ao executar winget para {0}: {1}" -f $name, $_.Exception.Message) "Warn"
        }
        Start-Sleep -Seconds 2
    }

    if (-not $script:LastInstallSuccess -and $LocalExePath -and (Test-Path $LocalExePath)) {
        Log "$name -> Tentando instalar via EXE local: $LocalExePath" "Cyan"
        try {
           if ($LocalExePath.ToLower().EndsWith(".msi")) {
    Log "$name -> Instalando via MSI local." "Cyan"
   
    Start-Process "msiexec.exe" -ArgumentList "/i `"$LocalExePath`"" -Wait

    # --- MSI corporativo (instalação manual) ---
if ($name -eq "Panda" -and $LocalExePath.ToLower().EndsWith(".msi")) {

    Log "Panda requer instalação manual. Abrindo instalador..." "Yellow"

    try {
        $proc = Start-Process "msiexec.exe" `
            -ArgumentList "/i `"$LocalExePath`"" `
            -Wait -PassThru

        if ($proc.ExitCode -eq 0) {
            Log "Panda: instalação manual concluída." "LightGreen"
            $script:LastInstallSuccess = $true
        } else {
            Log "Panda: instalação manual encerrada com código $($proc.ExitCode)." "Yellow"
        }
    } catch {
        Log "Erro ao abrir instalador manual do Panda: $($_.Exception.Message)" "Red"
    }

    return
}


    } else {
    Log "$name -> Instalando via EXE local." "Cyan"
    Start-Process -FilePath $LocalExePath `
        -ArgumentList "/silent","/norestart" `
        -Wait
}
            Log "$name -> Instalado com sucesso via EXE local!" "LightGreen"
            $script:LastInstallSuccess = $true
        } catch {
            Log ("Erro ao instalar {0} via EXE local: {1}" -f $name, $_.Exception.Message) "Red"
        }
    }

    # garante que nada seja enviado ao pipeline
    $null = $script:LastInstallSuccess
}

###############################################################################
# XAML DA JANELA PRINCIPAL
###############################################################################
$MainXaml = @"
<Window xmlns='http://schemas.microsoft.com/winfx/2006/xaml/presentation'
        Width='1000' Height='640'
        Title='Instalador Autônomo de Programas Essenciais - by Johnny Alejandro.'
        Background='#F3F3F3' WindowStartupLocation='CenterScreen'>

    <Grid Margin='20'>
        <Grid.ColumnDefinitions>
            <ColumnDefinition Width='320'/>
            <ColumnDefinition Width='*'/>
        </Grid.ColumnDefinitions>

        <!-- Esquerda — Lista + Opções -->
        <StackPanel Grid.Column='0' Margin='10'>
            <GroupBox Header='Programas Disponíveis' Margin='0,0,0,8'>
                <ScrollViewer Height='360'>
                    <StackPanel Name='AppsPanel'/>
                </ScrollViewer>
            </GroupBox>

            <GroupBox Header='Opções'>
                <StackPanel>
                    <CheckBox Name='ChkRename' Content='Alterar nome do computador' Margin='0,4,0,4'/>
                    <TextBox Name='TxtNewName' IsEnabled='False' Width='260' Margin='0,0,0,6' Foreground='Gray' Text='Novo nome...' />
                    <CheckBox Name='ChkRestart' Content='Reiniciar após conclusão' IsChecked='False' Margin='0,0,0,4'/>
                </StackPanel>
            </GroupBox>
        </StackPanel>

        <!-- Direita -->
        <StackPanel Grid.Column='1' Margin='20'>
            <DockPanel Margin='0,0,0,8'>
                <Image Name='LogoImg' Width='64' Height='64' DockPanel.Dock='Left' Margin='0,0,12,0' />
                <TextBlock Text='Instalador Autônomo v4.6' FontSize='18' VerticalAlignment='Center' FontWeight='Bold'/>
            </DockPanel>

            <TextBlock Text='Status:' FontWeight='Bold' FontSize='16'/>
            <ProgressBar Name='ProgressTotal' Height='18' Margin='0,8,0,4'/>
            <TextBlock Name='TbProgressStatus' Text='Aguardando início...' Margin='0,0,0,12'/>

            <TextBlock Text='Log:' FontWeight='Bold' FontSize='16'/>
            <RichTextBox Name='TxtLog' Height='320' Background='Black' Foreground='White' FontFamily='Consolas' BorderBrush='#444'/>

            <StackPanel Orientation='Horizontal' Margin='0,8,0,0' HorizontalAlignment='Right'>
                <Button Name='BtnInstall' Content='Instalar' Width='140' Margin='0,0,10,0' Background='#0078D7' Foreground='White'/>
                <Button Name='BtnClose' Content='Fechar' Width='120' Background='#444' Foreground='White'/>
            </StackPanel>
        </StackPanel>
    </Grid>

</Window>
"@

# Carregar interface (suprimir objetos)
$reader = New-Object System.Xml.XmlNodeReader ([xml]$MainXaml)
$null = $reader
$window = [Windows.Markup.XamlReader]::Load($reader)
$null = $window

# Referências UI
$Global:AppsPanel = $window.FindName("AppsPanel")
$Global:TxtLog = $window.FindName("TxtLog")
$Global:ProgressTotal = $window.FindName("ProgressTotal")
$TbProgressStatus = $window.FindName("TbProgressStatus")
$BtnInstall = $window.FindName("BtnInstall")
$BtnClose = $window.FindName("BtnClose")
$LogoImg = $window.FindName("LogoImg")
$ChkRename = $window.FindName("ChkRename")
$TxtNewName = $window.FindName("TxtNewName")
$ChkRestart = $window.FindName("ChkRestart")

# Aplica logo (se existir)
if ($bmp -and $LogoImg) {
    try { $LogoImg.Source = $bmp } catch { Log ("Aviso: nao foi possivel aplicar logo: {0}" -f $_.ToString(), "Yellow") }
} elseif ($LogoImg) {
    $LogoImg.Visibility = 'Collapsed'
}

###############################################################################
# Lista de programas
###############################################################################
$apps = @(
    @{Name="Microsoft Office"; ID="Microsoft Office"},
    @{Name="Google Chrome"; ID="Google.Chrome"},
    @{Name="Mozilla Firefox"; ID="Mozilla.Firefox"},
    @{Name="Panda"; ID= "Panda" },  
    @{Name="Adobe Reader"; ID="Adobe.Acrobat.Reader.64-bit"},
    @{Name="WinRAR"; ID="RARLab.WinRAR"},
    @{Name="AnyDesk"; ID="AnyDeskSoftwareGmbH.AnyDesk"},
    @{Name="AnyViewer"; ID="AnyViewer.AnyViewer"},
    @{Name="CrystalDiskInfo"; ID="CrystalDewWorld.CrystalDiskInfo"},
    @{Name="Spybot Search & Destroy"; ID="SaferNetworkingLtd.SpybotAntiBeacon"}
)

$appEntries = @()
foreach ($a in $apps) {
    $cb = New-Object System.Windows.Controls.CheckBox
    $cb.Content = $a.Name
    $cb.Tag = $a.ID
    $cb.Margin = "6"
    [void]($AppsPanel.Children.Add($cb))

    $entry = [PSCustomObject]@{ Name = $a.Name; ID = $a.ID; Checkbox = $cb }
    $appEntries += $entry
}

# Placeholder behavior for TxtNewName
$Placeholder = "Novo nome..."
$TxtNewName.Tag = $Placeholder
$TxtNewName.Text = $Placeholder
$TxtNewName.Foreground = [System.Windows.Media.Brushes]::Gray
$TxtNewName.Add_GotFocus({
    if ($TxtNewName.Text -eq $TxtNewName.Tag) { $TxtNewName.Text = ""; $TxtNewName.Foreground = [System.Windows.Media.Brushes]::Black }
})
$TxtNewName.Add_LostFocus({
    if ([string]::IsNullOrWhiteSpace($TxtNewName.Text)) { $TxtNewName.Text = $TxtNewName.Tag; $TxtNewName.Foreground = [System.Windows.Media.Brushes]::Gray }
})
$ChkRename.Add_Checked({ $TxtNewName.IsEnabled = $true; if ($TxtNewName.Text -eq $TxtNewName.Tag) { $TxtNewName.Text = ""; $TxtNewName.Foreground = [System.Windows.Media.Brushes]::Black } })
$ChkRename.Add_Unchecked({ $TxtNewName.IsEnabled = $false; if ([string]::IsNullOrWhiteSpace($TxtNewName.Text)) { $TxtNewName.Text = $TxtNewName.Tag; $TxtNewName.Foreground = [System.Windows.Media.Brushes]::Gray } })

# Botão fechar
$BtnClose.Add_Click({ $window.Close() | Out-Null })

###############################################################################
# Função para coletar apps selecionados (sem imprimir)
###############################################################################
function Get-SelectedApps {
    $list = @()
    foreach ($e in $appEntries) {
        if ($e.Checkbox.IsChecked -eq $true) { $list += $e }
    }
    $null = $list
}

###############################################################################
# Start-RealInstallation (mantém fallback local e contabiliza progresso)
###############################################################################
function Start-RealInstallation {
    $selected = Get-SelectedApps
    # Get-SelectedApps coloca o resultado em $null — recuperar por variável local:
    $selected = @()
foreach ($e in $appEntries) { if ($e.Checkbox.IsChecked -eq $true) { $selected += $e } }

    $total = $selected.Count
    if ($total -eq 0) {
        Log "Nenhum programa selecionado." "Yellow"
        [System.Windows.MessageBox]::Show("Nenhum programa selecionado.","Aviso",[System.Windows.MessageBoxButton]::OK,[System.Windows.MessageBoxImage]::Warning) | Out-Null
        return
    }

    Log "Iniciando instalação de $total programas..." "Cyan"
    $BtnInstall.IsEnabled = $false
foreach ($e in $appEntries) { if ($e.Checkbox) { $e.Checkbox.IsEnabled = $false } }
    $ChkRename.IsEnabled = $false
    $TxtNewName.IsEnabled = $false
    $ChkRestart.IsEnabled = $false

    $Global:ProgressTotal.Minimum = 0
    $Global:ProgressTotal.Maximum = $total
    $Global:ProgressTotal.Value = 0
    $completed = 0
    $TbProgressStatus.Text = "Instalando 0 de $total programas..."

foreach ($e in $selected) {

    $appName = $e.Name
    $appID = $e.ID

    Log ("Enfileirado: {0} ({1})" -f $appName, $appID) "Cyan"
    $null = $TbProgressStatus.Dispatcher.Invoke([action]{ 
        $TbProgressStatus.Text = "Instalando $completed de $total programas..."
    }, 'Background')

        # ============================
    # MICROSOFT OFFICE (ODT)
    # ============================
    if ($appName -eq "Microsoft Office") {

        $officeDir = ".\fallback\office365"
        $setupExe  = Join-Path $officeDir "setup.exe"
        $configXml = Join-Path $officeDir "configuration.xml"

        if (!(Test-Path $setupExe) -or !(Test-Path $configXml)) {
            Log "ERRO: setup.exe ou configuration.xml ausente para Office 365!" "Red"
        }
        else {
            Log "Instalação forçada de Microsoft Office — usando Office Deployment Tool." "Cyan"

            Start-Process -FilePath $setupExe `
                -ArgumentList "/configure `"$configXml`"" `
                -Wait

            Log "Microsoft Office instalado com sucesso (ODT)." "LightGreen"
        }

        $completed++
        $Global:ProgressTotal.Value = $completed
        continue
    }

    # ============================
    # PANDA (MSI)
    # ============================
    if ($appName -eq "Panda") {

        $msiPath = Join-Path $BaseDir "fallback\Panda.msi"

        if (!(Test-Path $msiPath)) {
            Log "ERRO: Panda.msi não encontrado!" "Red"
        }
        else {
            Log "Instalação forçada de Panda via MSI." "Cyan"
           
            # Aviso para ativação manual
                    [System.Windows.MessageBox]::Show(
            "O Panda Endpoint Protection Plus requer ativação manual.`n`n" +
            "Uma janela será aberta para concluir a instalação com token ou login.",
            "Atenção - Instalação Manual",
            [System.Windows.MessageBoxButton]::OK,
            [System.Windows.MessageBoxImage]::Information
        ) | Out-Null


           $proc = Start-Process "msiexec.exe" `
            -ArgumentList "/i `"$msiPath`"" `
            -Wait -PassThru


            if ($proc.ExitCode -eq 0) {
                Log "Panda instalado com sucesso (MSI)." "LightGreen"
            }
            else {
                Log "ERRO ao instalar Panda. ExitCode: $($proc.ExitCode)" "Red"
            }
        }

        $completed++
        $Global:ProgressTotal.Value = $completed
        continue
    }



# ============================
# INSTALAÇÃO
# ============================

if ($ForceInstallApps -contains $appName) {

    Log "[$appName] MODO FORÇADO ATIVO — ignorando winget." "Yellow"

    $fallbackPath = $FallbackApps[$appName]

    if (-not (Test-Path $fallbackPath)) {
        Log "ERRO: fallback não encontrado: $fallbackPath" "Red"
        continue
    }

    if ($appName -eq "Microsoft Office") {

        $setupExe = Join-Path $fallbackPath "setup.exe"
        $xmlPath  = Join-Path $fallbackPath "configuration.xml"

        if (!(Test-Path $setupExe) -or !(Test-Path $xmlPath)) {
            Log "ERRO: ODT incompleto (setup.exe ou configuration.xml ausente)" "Red"
            continue
        }

        Start-Process $setupExe -ArgumentList "/configure `"$xmlPath`"" -Wait
        Log "Office instalado via ODT (forçado)." "LightGreen"

    } else {

        if ($fallbackPath -like "*.msi") {
          $proc = Start-Process "msiexec.exe" `
    -ArgumentList "/i `"$fallbackPath`" /qn /norestart /l*v `"$env:TEMP\PandaMSI.log`"" `
    -Wait -PassThru

    if ($proc.ExitCode -eq 0) {
    Log "Panda instalado com sucesso via MSI." "LightGreen"
    } else {
    Log "ERRO ao instalar Panda. ExitCode: $($proc.ExitCode). Log em PandaMSI.log" "Red"
    }

        } else {
            Start-Process $fallbackPath -ArgumentList "/silent /norestart" -Wait
            Log "$appName instalado via EXE (forçado)." "LightGreen"
        }
    }

}
else {
    Install-App -id $appID -name $appName -LocalExePath $FallbackApps[$appName]
}


    $completed++
    $Global:ProgressTotal.Value = $completed

    $null = $TbProgressStatus.Dispatcher.Invoke([action]{ 
        $TbProgressStatus.Text = "Instalando $completed de $total programas..."
    })

    Start-Sleep -Milliseconds 300
}


    # RENOMEAR se selecionado
    $finalNewName = $TxtNewName.Text.Trim()
    if ($finalNewName -eq $TxtNewName.Tag) { $finalNewName = "" }
    if ($ChkRename.IsChecked -eq $true -and -not [string]::IsNullOrWhiteSpace($finalNewName)) {
        try {
            Log ("Renomeando computador para {0}..." -f $finalNewName) "Cyan"
            Rename-Computer -NewName $finalNewName -Force -ErrorAction Stop
            Log ("Nome alterado para {0}. Será necessário reiniciar para aplicar." -f $finalNewName) "LightGreen"
            $ChkRestart.IsChecked = $true
        } catch {
            Log ("ERRO ao renomear: {0}" -f $_.Exception.Message, "Red")
            [System.Windows.MessageBox]::Show(("Falha ao renomear: {0}" -f $_.Exception.Message), "Erro", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error) | Out-Null
        }
    } elseif ($ChkRename.IsChecked -eq $true) {
        Log "Renomeação solicitada, porém nome vazio. Ignorando." "Yellow"
    }

    # desbloqueia UI e finaliza
    $BtnInstall.IsEnabled = $true
foreach ($e in $appEntries) { if ($e.Checkbox) { $e.Checkbox.IsEnabled = $true } }
    $ChkRename.IsEnabled = $true
    $TxtNewName.IsEnabled = $true
    $ChkRestart.IsEnabled = $true

    Log "Instalação concluída." "LightGreen"
    $TbProgressStatus.Text = "Instalação concluída."

    if ($ChkRestart.IsChecked -eq $true) {
        $res = [System.Windows.MessageBox]::Show("Instalação e/ou renomeação concluída. Reiniciar agora?", "Reiniciar", [System.Windows.MessageBoxButton]::YesNo, [System.Windows.MessageBoxImage]::Question)
        if ($res -eq [System.Windows.MessageBoxResult]::Yes) {
            Log "Reiniciando (usuario confirmou)." "Cyan"
            $window.Close()
            Restart-Computer -Force
        } else {
            Log "Usuario optou por nao reiniciar." "Info"
        }
    } else {
        [System.Windows.MessageBox]::Show(("Instalação concluída. Log em: {0}" -f $LogFile), "Concluído", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information) | Out-Null
    }

    # garante que nada seja impresso no pipeline
    $null = $true
}

# Eventos dos botões (sem produzir saída)
$BtnInstall.Add_Click({ Start-RealInstallation })
$BtnClose.Add_Click({ $window.Close() | Out-Null })

# Mostra splash antes da GUI
Show-Splash -durationMs 3000

# Exibe janela principal e encerra sem emitir valor
$null = $window.ShowDialog()
exit 0
