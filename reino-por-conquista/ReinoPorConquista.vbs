' Reino por Conquista - lancador silencioso para Windows
' Abre o jogo em janela propria de aplicativo (Edge/Chrome), sem console.
On Error Resume Next
Set sh = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")
pasta = fso.GetParentFolderName(WScript.ScriptFullName)
jogo = Replace(pasta & "\index.html", "\", "/")

pf86 = sh.ExpandEnvironmentStrings("%ProgramFiles(x86)%")
pf = sh.ExpandEnvironmentStrings("%ProgramFiles%")
lad = sh.ExpandEnvironmentStrings("%LocalAppData%")

caminhos = Array( _
  pf86 & "\Microsoft\Edge\Application\msedge.exe", _
  pf & "\Microsoft\Edge\Application\msedge.exe", _
  pf & "\Google\Chrome\Application\chrome.exe", _
  pf86 & "\Google\Chrome\Application\chrome.exe", _
  lad & "\Google\Chrome\Application\chrome.exe")

achou = False
For Each c In caminhos
  If fso.FileExists(c) Then
    sh.Run """" & c & """ --app=""file:///" & jogo & """", 1, False
    achou = True
    Exit For
  End If
Next

If Not achou Then sh.Run """" & pasta & "\index.html""", 1, False
