
FileBrowserController = function() {
  this.selectedFile = null;
}

FileBrowserController.prototype.selectRootFolder = function(folder) {
  $("path").value = folder.nativePath;
  $('list').innerHTML = ""
   this.selectFolder(folder);
}

FileBrowserController.prototype.selectFolder = function(folder, root) {
  var files = folder.getDirectoryListing();          
  var list = $('list');
  var br = new Element('br');
  for (var i = 0; i < files.length; i++) {
    var cssclass = files[i].isDirectory ? "folder" : "file";
    var content = new Element('div', { name: "file", 'class': cssclass} );
    content.insert(files[i].name);
    content.data = files[i];
    Event.observe(content, "click", this.labelClicked.bind(this));
    list.insert(content);
    list.insert(br);
  }
}

FileBrowserController.prototype.labelClicked = function(node) {
  var file = node.currentTarget.data;
  if (file.isDirectory) this.selectedFile = file;
  var attributes = ['name', 'extension', 'type', 'size', 'modificationDate', 'creationDate' ];
  var description = "";
  for (var i=0; i<attributes.length; i++)
     description += attributes[i]+": "+file[attributes[i]]+"<br/>";
  $('details').innerHTML = description;
} 

FileBrowserController.prototype.openSelectedFile = function() {
  this.selectRootFolder(this.selectedFile);
}

