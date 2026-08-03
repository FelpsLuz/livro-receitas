; ============================================================
; REINO POR CONQUISTA - instalador Windows (NSIS)
; Compilar: makensis installer.nsi
; Gera: ReinoPorConquista-Setup.exe
; Instala sem precisar de administrador (vai para %LOCALAPPDATA%),
; cria atalhos na area de trabalho e no menu Iniciar, com
; desinstalador registrado em "Adicionar ou remover programas".
; ============================================================
Unicode true
!define NOME "Reino por Conquista"
!define PASTA "ReinoPorConquista"
!define REG "Software\Microsoft\Windows\CurrentVersion\Uninstall\${PASTA}"

Name "${NOME}"
OutFile "ReinoPorConquista-Setup.exe"
RequestExecutionLevel user
InstallDir "$LOCALAPPDATA\${PASTA}"
SetCompressor /SOLID lzma

Page directory
Page instfiles
UninstPage uninstConfirm
UninstPage instfiles

Section "Instalar"
  SetOutPath "$INSTDIR"
  File "index.html"
  File "ReinoPorConquista.vbs"
  File "ReinoPorConquista.bat"
  File "icone.ico"
  File "manifest.json"
  File "sw.js"
  SetOutPath "$INSTDIR\icons"
  File "icons\icon-192.png"
  File "icons\icon-512.png"
  SetOutPath "$INSTDIR\img\retratos"
  File "img\retratos\*.png"
  SetOutPath "$INSTDIR\img\duelo"
  File "img\duelo\*.png"
  SetOutPath "$INSTDIR\img\estruturas"
  File "img\estruturas\*.png"
  SetOutPath "$INSTDIR\img\bandeiras"
  File "img\bandeiras\*.png"
  SetOutPath "$INSTDIR\img\hud"
  File "img\hud\*.png"
  SetOutPath "$INSTDIR\img\armas"
  File "img\armas\*.png"
  SetOutPath "$INSTDIR\img\icones"
  File "img\icones\*.png"
  SetOutPath "$INSTDIR\fonts"
  File "fonts\VT323.ttf"
  SetOutPath "$INSTDIR\css"
  File "css\style.css"
  SetOutPath "$INSTDIR\js"
  File "js\data.js"
  File "js\assets.js"
  File "js\duelo.js"
  File "js\sfx.js"
  File "js\portraits.js"
  File "js\clans.js"
  File "js\production.js"
  File "js\politics.js"
  File "js\barbaras.js"
  File "js\gossip.js"
  File "js\agenda.js"
  File "js\mapa.js"
  File "js\lore.js"
  File "js\dialogue.js"
  File "js\llm_nuvem.js"
  File "js\economy.js"
  File "js\combat.js"
  File "js\intrigue.js"
  File "js\city.js"
  File "js\game.js"
  File "js\ui.js"
  SetOutPath "$INSTDIR"

  ; atalhos
  CreateShortCut "$DESKTOP\${NOME}.lnk" "$SYSDIR\wscript.exe" '"$INSTDIR\ReinoPorConquista.vbs"' "$INSTDIR\icone.ico" 0
  CreateDirectory "$SMPROGRAMS\${NOME}"
  CreateShortCut "$SMPROGRAMS\${NOME}\${NOME}.lnk" "$SYSDIR\wscript.exe" '"$INSTDIR\ReinoPorConquista.vbs"' "$INSTDIR\icone.ico" 0

  ; desinstalador
  WriteUninstaller "$INSTDIR\Desinstalar.exe"
  CreateShortCut "$SMPROGRAMS\${NOME}\Desinstalar.lnk" "$INSTDIR\Desinstalar.exe"
  WriteRegStr HKCU "${REG}" "DisplayName" "${NOME}"
  WriteRegStr HKCU "${REG}" "DisplayIcon" "$INSTDIR\icone.ico"
  WriteRegStr HKCU "${REG}" "UninstallString" "$INSTDIR\Desinstalar.exe"
  WriteRegStr HKCU "${REG}" "Publisher" "FelpsLuz"
  WriteRegStr HKCU "${REG}" "DisplayVersion" "2.0"
SectionEnd

Section "Uninstall"
  Delete "$DESKTOP\${NOME}.lnk"
  Delete "$SMPROGRAMS\${NOME}\${NOME}.lnk"
  Delete "$SMPROGRAMS\${NOME}\Desinstalar.lnk"
  RMDir "$SMPROGRAMS\${NOME}"
  RMDir /r "$INSTDIR"
  DeleteRegKey HKCU "${REG}"
SectionEnd
