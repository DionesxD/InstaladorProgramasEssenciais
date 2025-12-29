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

