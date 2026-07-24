// Reino por Conquista — invólucro desktop (Electron)
// npm install && npm start   → roda como aplicativo
// npm run dist               → gera instalador Windows em dist/
'use strict';

const { app, BrowserWindow, Menu } = require('electron');
const path = require('path');

function criarJanela() {
  const win = new BrowserWindow({
    width: 1100,
    height: 780,
    minWidth: 720,
    minHeight: 560,
    backgroundColor: '#2b1d12',
    title: 'Reino por Conquista',
    autoHideMenuBar: true,
    webPreferences: {
      contextIsolation: true,
      nodeIntegration: false,
    },
  });
  Menu.setApplicationMenu(null);
  win.loadFile(path.join(__dirname, 'index.html'));
}

app.whenReady().then(() => {
  criarJanela();
  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) criarJanela();
  });
});

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') app.quit();
});
