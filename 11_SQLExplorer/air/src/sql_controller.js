SQLExplorerController = function() {
	this.connection = new air.SQLConnection();
	this.statement = null;
	this.init();
}

SQLExplorerController.databaseFile = air.File.applicationStorageDirectory.resolvePath("sample.db")

SQLExplorerController.prototype.init = function() {
	SQLResultHandler.controller = this;
	this.initializeDatabase();
	this.centerAndShowApp();
}

SQLExplorerController.prototype.centerAndShowApp = function() {
	// haxx: only works if on mainScreen
	var height = window.nativeWindow.height;
	var width = window.nativeWindow.width;
	var screenSizeY = air.Screen.mainScreen.visibleBounds.bottom;
	var screenSizeX = air.Screen.mainScreen.visibleBounds.right;
	
	window.nativeWindow.x = screenSizeX/2 - width/2;
	window.nativeWindow.y = screenSizeY/2 - height/2;
	
	window.nativeWindow.visible = true;
}

SQLExplorerController.prototype.executeSQL = function() {
	this.createStatement($('queryText').value);
	this.statement.execute();
}

SQLExplorerController.prototype.formatSQLResults = function() {
	result = this.statement.getResult();
	alert(result.rowsAffected + " rows affected");
	alert(result.data != null);
	if (result.data != null) {
		alert(result.data[0]['firstName']);
	}
}

SQLExplorerController.prototype.createStatement = function(sql) {
	this.statement = new air.SQLStatement();
	this.statement.addEventListener(air.SQLEvent.RESULT, new SQLResultHandler().sqlResult);
	this.statement.addEventListener(air.SQLErrorEvent.ERROR, new SQLResultHandler().sqlError);
	this.statement.sqlConnection = this.connection;
	this.statement.text = sql;
}

SQLExplorerController.prototype.initializeDatabase = function() {
	try {
		
		this.connection.open(SQLExplorerController.databaseFile);
		
	} catch (error) {
		alert("error opening database: " + error.message);
	}

	sql = "CREATE TABLE IF NOT EXISTS people (" + 
    "    id INTEGER PRIMARY KEY AUTOINCREMENT, " + 
    "    firstName TEXT, " + 
    "    lastName TEXT " + 
    ")";

	this.createStatement(sql);
	this.statement.execute();
    
}

SQLResultHandler = function() { }

SQLResultHandler.controller = null;

SQLResultHandler.prototype.sqlResult = function(event) {
	SQLResultHandler.controller.formatSQLResults();
}

SQLResultHandler.prototype.sqlError = function(event) {
	alert("Error executing query: " + event.error.message)
}

