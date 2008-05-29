
FileBrowserController = function() {
  this.selectRootFolder(air.File.userDirectory)
}

FileBrowserController.prototype.selectRootFolder = function(folder) {
  $("path").value = folder.nativePath;
  $('fileList').innerHTML = ""
  $('directoryList').innerHTML = ""
  this.selectFolder(folder);
}

// called when a folder is selected
FileBrowserController.prototype.selectFolder = function(folder, root) {
  var files = folder.getDirectoryListing();
  var totalSize = this.directorySize(folder)         
  var dirList = $('directoryList');
  var fileList = $('fileList');

  // add a dot-dot listing for folder's parent directory
  var fileRef = new Element('a', { rel: folder.nativePath+"/..", 'class': 'folder' } ).update("..");
  dirList.insert(fileRef);
  dirList.insert(new Element('br'));
  Event.observe(fileRef, "click", this.labelClicked.bind(this));

  // iterate over directories and add a link to those directories to the file list
  for (var i = 0; i < files.length; i++) {
	if (files[i].isDirectory) {
	  	var fileRef = new Element('a', { rel: files[i].nativePath, 'class': 'folder' } ).update(files[i].name);
	    dirList.insert(fileRef);
	    dirList.insert(new Element('br'));
	    Event.observe(fileRef, "click", this.labelClicked.bind(this));
	}
  }

  // iterate over files in directory and place a link in the 'cloud' area
  var content = new Element('div', { name: "fileRow1" } );
  fileList.insert(content);
  for (var i = 0; i < files.length; i++) {
	if (!files[i].isDirectory && files[i].exists) {
		var style = this.styleForSize(files[i], totalSize);
		// keep the file's path in the rel attribute of the anchor tag for later use
		var fileRef = new Element('a', { rel: files[i].nativePath, 'class': style}).update(files[i].name)
		content.insert(fileRef);
		content.insert(" ");
		Event.observe(fileRef, "click", this.labelClicked.bind(this));
		// every six files start a new row
		if (i > 0 && (i % 6) == 0) {
		  var content = new Element('div', { name: "fileRow"+i } );
		  fileList.insert(content);
		}
	}
  }
}

// called when a file or directory label is clicked
FileBrowserController.prototype.labelClicked = function(node) {
  // get the file's path, stored in the rel attribute of the anchor tag that was clicked
  var file = new air.File(node.currentTarget.rel);
  // if the file is a directory, navigate to that directory
  if (file.isDirectory) {
    this.selectedFile = file;
	return this.openSelectedFile()
  }
  // otherwise display file attributes
  var attributes = ['name', 'extension', 'type', 'size', 'modificationDate', 'creationDate' ];
  var description = "";
  for (var i=0; i<attributes.length; i++)
     description += attributes[i]+": "+file[attributes[i]]+"<br/>";
  $('details').innerHTML = description;
} 

FileBrowserController.prototype.openSelectedFile = function() {
  this.selectRootFolder(this.selectedFile);
}

// picks out a css class to use based on the relative size of the file to 
// the total size of a directory
FileBrowserController.prototype.styleForSize = function(file, totalSize) {
	var ratio = file.size/totalSize;
	if (ratio <= .2) {
		return 'little-file';
	} else if (ratio >= .8) {
		return 'big-file'
	} else {
		return 'normal-file';
	}
	
}

// calculates the size of all files in a directory
FileBrowserController.prototype.directorySize = function(dir) {
	var files = dir.getDirectoryListing();
    var size = 0 
	for (var i = 0; i < files.length; i++) {
		// links and possibly other files don't "exist" and cause problems for size
		if (files[i].exists && files[i].size > 0) {
			size += files[i].size;
		}
	}
	return size;
}
