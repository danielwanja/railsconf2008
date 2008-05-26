
FileBrowserController = function() {
  this.selectedFile = null;
}

FileBrowserController.prototype.selectRootFolder = function(folder) {
  $("path").value = folder.nativePath;
  $('fileList').innerHTML = ""
  $('directoryList').innerHTML = ""
  this.selectFolder(folder);
}

FileBrowserController.prototype.selectFolder = function(folder, root) {
  var files = folder.getDirectoryListing(); 
  var totalSize = this.directorySize(folder)         
  var dirList = $('directoryList');
  var fileList = $('fileList');

  var fileRef = new Element('a', { rel: folder.nativePath+"/..", 'class': 'folder' } ).update("..");
  dirList.insert(fileRef);
  dirList.insert(new Element('br'));
  Event.observe(fileRef, "click", this.labelClicked.bind(this));

  for (var i = 0; i < files.length; i++) {
	if (files[i].isDirectory) {
	  	var fileRef = new Element('a', { rel: files[i].nativePath, 'class': 'folder' } ).update(files[i].name);
	    dirList.insert(fileRef);
	    dirList.insert(new Element('br'));
	    Event.observe(fileRef, "click", this.labelClicked.bind(this));
	}
  }

  var content = new Element('div', { name: "fileRow1" } );
  fileList.insert(content);
  for (var i = 0; i < files.length; i++) {
	if (!files[i].isDirectory) {
		var style = this.styleForSize(files[i], totalSize);
		var fileRef = new Element('a', { rel: files[i].nativePath, 'class': style}).update(files[i].name)
		content.insert(fileRef);
		content.insert(" ");
		Event.observe(fileRef, "click", this.labelClicked.bind(this));
		if (i > 0 && (i % 6) == 0) {
		  var content = new Element('div', { name: "fileRow"+i } );
		  fileList.insert(content);
		}
	}
  }
}

FileBrowserController.prototype.labelClicked = function(node) {
  var file = new air.File(node.currentTarget.rel);
  if (file.isDirectory) {
    this.selectedFile = file;
	return this.openSelectedFile()
  }
  var attributes = ['name', 'extension', 'type', 'size', 'modificationDate', 'creationDate' ];
  var description = "";
  for (var i=0; i<attributes.length; i++)
     description += attributes[i]+": "+file[attributes[i]]+"<br/>";
  $('details').innerHTML = description;
} 

FileBrowserController.prototype.openSelectedFile = function() {
  this.selectRootFolder(this.selectedFile);
}

FileBrowserController.prototype.styleForSize = function(file, totalSize) {
	var ratio = file.size/totalSize;
	if (ratio <= .4) {
		return 'little-file';
	} else if (ratio >= .6) {
		return 'big-file'
	} else {
		return 'normal-file';
	}
	
}

FileBrowserController.prototype.directorySize = function(dir) {
	var files = dir.getDirectoryListing();
    var size = 0 
	for (var i = 0; i < files.length; i++) {
		air.Introspector.Console.log("file size " + files[i].size)
		if (files[i].size > 0) {
			size += files[i].size;
		}
	}
	return size;
}
