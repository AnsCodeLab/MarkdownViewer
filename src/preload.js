const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('electronAPI', {
  openFile: () => ipcRenderer.invoke('dialog:openFile'),
  renderMarkdown: (text, filePath) => ipcRenderer.invoke('render:markdown', text, filePath),
  beautify: (text, filePath) => ipcRenderer.invoke('format:beautify', text, filePath),
  minify: (text, filePath) => ipcRenderer.invoke('format:minify', text, filePath),
  exportFile: (format, payload) => ipcRenderer.invoke('export:' + format, payload),
  getStylesCss: () => ipcRenderer.invoke('get-styles-css'),
  saveFile: (filePath, content) => ipcRenderer.invoke('file:save', filePath, content),
  saveFileAs: (content) => ipcRenderer.invoke('file:saveAs', content),
  readFile: (filePath) => ipcRenderer.invoke('file:read', filePath),

  getInitialFile: () => ipcRenderer.invoke('get-initial-file'),
  onAutoOpen: (callback) => ipcRenderer.on('auto-open', (event, data) => callback(data)),
});
