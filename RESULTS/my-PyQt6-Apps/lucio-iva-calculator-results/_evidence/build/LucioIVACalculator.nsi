!define APP_NAME "Lucio IVA Calculator"
!define APP_DIR "LucioIVACalculator"
!define VERSION "0.1.0.0"
!define COPYRIGHT "Washington Indacochea Delgado and Joseph Lucio Guerrero 2026"
!define DESCRIPTION "VAT calculator"
!define LICENSE_TXT "LICENSE"
!define INSTALLER_NAME "LucioIVACalculator-0.1.0-setup.exe"
!define MAIN_APP_EXE "LucioIVACalculator\LucioIVACalculator.exe"
!define WEB_SITE "https://wachin.github.io/lucio-iva-calculator/"

VIFileVersion "${VERSION}"
VIProductVersion "${VERSION}"
VIAddVersionKey "ProductName" "${APP_NAME}"
VIAddVersionKey "CompanyName" "Lucio"
VIAddVersionKey "LegalCopyright" "${COPYRIGHT}"
VIAddVersionKey "FileDescription" "${DESCRIPTION}"
VIAddVersionKey "FileVersion" "${VERSION}"
VIAddVersionKey "ProductVersion" "${VERSION}"
VIAddVersionKey "InternalName" "${APP_NAME} Installer"
VIAddVersionKey "OriginalFilename" "${INSTALLER_NAME}"

SetCompressor ZLIB
Name "${APP_NAME}"
Caption "${APP_NAME}"
OutFile "${INSTALLER_NAME}"
BrandingText "${APP_NAME}"
XPStyle on
RequestExecutionLevel user
InstallDir "$LOCALAPPDATA\Programs\${APP_DIR}"
Icon "app-icon.ico"
UninstallIcon "app-icon.ico"

!include "MUI.nsh"

!define MUI_ABORTWARNING
!define MUI_ICON "app-icon.ico"
!define MUI_UNICON "app-icon.ico"
!define MUI_HEADERIMAGE
!define MUI_HEADERIMAGE_RIGHT
!define MUI_HEADERIMAGE_BITMAP "nsis-header.bmp"
!define MUI_WELCOMEFINISHPAGE_BITMAP "nsis-welcome.bmp"
!define MUI_WELCOMEPAGE_TITLE "$(WelcomeTitle)"
!define MUI_WELCOMEPAGE_TEXT "$(WelcomeText)"
!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_LICENSE "${LICENSE_TXT}"
!insertmacro MUI_PAGE_COMPONENTS
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!define MUI_FINISHPAGE_RUN "$INSTDIR\${MAIN_APP_EXE}"
!insertmacro MUI_PAGE_FINISH
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_UNPAGE_FINISH
!insertmacro MUI_LANGUAGE "Spanish"
!insertmacro MUI_LANGUAGE "English"

LangString WelcomeTitle ${LANG_SPANISH} "Bienvenido a Lucio IVA Calculator"
LangString WelcomeTitle ${LANG_ENGLISH} "Welcome to Lucio IVA Calculator"
LangString WelcomeText ${LANG_SPANISH} "Este asistente instalara Lucio IVA Calculator, una calculadora de IVA sencilla, moderna y multiplataforma.$\r$\n$\r$\nPuedes elegir los accesos directos que deseas crear antes de instalar.$\r$\n$\r$\nPresiona Siguiente para continuar."
LangString WelcomeText ${LANG_ENGLISH} "This wizard will install Lucio IVA Calculator, a simple, modern, cross-platform VAT calculator.$\r$\n$\r$\nYou can choose which shortcuts to create before installing.$\r$\n$\r$\nClick Next to continue."
LangString SectionMain ${LANG_SPANISH} "Programa principal"
LangString SectionMain ${LANG_ENGLISH} "Main program"
LangString SectionStartMenu ${LANG_SPANISH} "Accesos en el menu Inicio"
LangString SectionStartMenu ${LANG_ENGLISH} "Start Menu shortcuts"
LangString SectionDesktop ${LANG_SPANISH} "Acceso directo en el Escritorio"
LangString SectionDesktop ${LANG_ENGLISH} "Desktop shortcut"
LangString SectionWebsite ${LANG_SPANISH} "Enlace al sitio web"
LangString SectionWebsite ${LANG_ENGLISH} "Website link"

Function .onInit
  System::Call "kernel32::GetUserDefaultUILanguage() i .r0"
  IntOp $1 $0 & 0x3ff
  IntCmp $1 9 0 +2 +2
    StrCpy $LANGUAGE ${LANG_ENGLISH}
  IntCmp $1 10 0 +2 +2
    StrCpy $LANGUAGE ${LANG_SPANISH}
FunctionEnd

Function un.onInit
  System::Call "kernel32::GetUserDefaultUILanguage() i .r0"
  IntOp $1 $0 & 0x3ff
  IntCmp $1 9 0 +2 +2
    StrCpy $LANGUAGE ${LANG_ENGLISH}
  IntCmp $1 10 0 +2 +2
    StrCpy $LANGUAGE ${LANG_SPANISH}
FunctionEnd

Section "$(SectionMain)" SecMain
SectionIn RO
SetOverwrite ifnewer
SetOutPath "$INSTDIR"
File /r "LucioIVACalculator"
File "LICENSE"
WriteUninstaller "$INSTDIR\uninstall.exe"
WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APP_NAME}" "DisplayName" "${APP_NAME}"
WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APP_NAME}" "UninstallString" "$INSTDIR\uninstall.exe"
WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APP_NAME}" "DisplayIcon" "$INSTDIR\${MAIN_APP_EXE}"
WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APP_NAME}" "DisplayVersion" "0.1.0"
WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APP_NAME}" "Publisher" "Lucio"
WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APP_NAME}" "URLInfoAbout" "${WEB_SITE}"
SectionEnd

Section "$(SectionStartMenu)" SecStartMenu
SetOutPath "$INSTDIR"
CreateDirectory "$SMPROGRAMS\${APP_NAME}"
CreateShortCut "$SMPROGRAMS\${APP_NAME}\${APP_NAME}.lnk" "$INSTDIR\${MAIN_APP_EXE}" "" "$INSTDIR\${MAIN_APP_EXE}"
CreateShortCut "$SMPROGRAMS\${APP_NAME}\Uninstall ${APP_NAME}.lnk" "$INSTDIR\uninstall.exe" "" "$INSTDIR\uninstall.exe"
SectionEnd

Section "$(SectionDesktop)" SecDesktop
SetOutPath "$INSTDIR"
CreateShortCut "$DESKTOP\${APP_NAME}.lnk" "$INSTDIR\${MAIN_APP_EXE}" "" "$INSTDIR\${MAIN_APP_EXE}"
SectionEnd

Section "$(SectionWebsite)" SecWebsite
SetOutPath "$INSTDIR"
CreateDirectory "$SMPROGRAMS\${APP_NAME}"
WriteIniStr "$INSTDIR\${APP_NAME} website.url" "InternetShortcut" "URL" "${WEB_SITE}"
CreateShortCut "$SMPROGRAMS\${APP_NAME}\${APP_NAME} Website.lnk" "$INSTDIR\${APP_NAME} website.url"
SectionEnd

Section Uninstall
RmDir /r "$INSTDIR"
Delete "$SMPROGRAMS\${APP_NAME}\${APP_NAME}.lnk"
Delete "$SMPROGRAMS\${APP_NAME}\Uninstall ${APP_NAME}.lnk"
Delete "$SMPROGRAMS\${APP_NAME}\${APP_NAME} Website.lnk"
Delete "$DESKTOP\${APP_NAME}.lnk"
RmDir "$SMPROGRAMS\${APP_NAME}"
DeleteRegKey HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APP_NAME}"
SectionEnd
