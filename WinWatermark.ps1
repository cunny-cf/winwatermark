Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Prompt for the main text (default: "Activate Windows")
$mainText = Read-Host "Enter the main text (default: 'Activate Windows')"
if ([string]::IsNullOrWhiteSpace($mainText)) {
    $mainText = "Activate Windows"
}

# Prompt for the description text (default: "Go to Settings to activate Windows")
$subText = Read-Host "Enter the description text (default: 'Go to Settings to activate Windows')"
if ([string]::IsNullOrWhiteSpace($subText)) {
    $subText = "Go to Settings to activate Windows."
}

# Create the form
$form = New-Object Windows.Forms.Form
$form.FormBorderStyle = 'None'
$form.TopMost = $true
$form.ShowInTaskbar = $false
$form.BackColor = 'Gray'
$form.TransparencyKey = 'Gray'
$form.Size = [Drawing.Size]::new(300, 60)
$form.StartPosition = 'Manual'

# Position the form at bottom-right corner
$screen = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
$x = $screen.Width - $form.Width - 10
$y = $screen.Height - $form.Height - 50
$form.Location = New-Object System.Drawing.Point($x, $y)

# Paint event for drawing transparent text
$form.Add_Paint({
    $g = $_.Graphics
    $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAlias

    # Fonts
    $fontMain = New-Object System.Drawing.Font("Segoe UI", 16, [System.Drawing.FontStyle]::Regular)
    $fontSub  = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Regular)

    # Brushes with transparency
    $brushMain = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(75, 105, 105, 105))   # ~20% opacity
    $brushSub  = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(50, 105, 105, 105))  # ~50% opacity

    # Draw strings
    $g.DrawString($mainText, $fontMain, $brushMain, 10, 5)
    $g.DrawString($subText, $fontSub, $brushSub, 10, 30)
})

# Make it click-through
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class WinAPI {
    [DllImport("user32.dll")]
    public static extern int SetWindowLong(IntPtr hWnd, int nIndex, int dwNewLong);
    [DllImport("user32.dll")]
    public static extern int GetWindowLong(IntPtr hWnd, int nIndex);
}
"@

$hwnd = $form.Handle
$exStyle = [WinAPI]::GetWindowLong($hwnd, -20)
[WinAPI]::SetWindowLong($hwnd, -20, $exStyle -bor 0x80000 -bor 0x20)

# Background job to refresh TopMost
$script:running = $true
$job = Start-Job -ScriptBlock {
    $lastUpdate = [DateTime]::MinValue
    while ($script:running) {
        $now = [DateTime]::Now
        if (($now - $lastUpdate).TotalSeconds -ge 10) {
            $form.Invoke([Action]{
                $form.TopMost = $false
                $form.TopMost = $true
            })
            $lastUpdate = $now
        }
        Start-Sleep -Seconds 1
    }
}

Write-Host "Job started successfully."

# Stop job when form closes
$form.Add_FormClosed({
    Write-Host "Form closed. Stopping the background task."
    $script:running = $false
    Stop-Job $job
    Remove-Job $job
})

# Show the form
Write-Host "Showing form..."
$form.ShowDialog()
Write-Host "Form closed."
