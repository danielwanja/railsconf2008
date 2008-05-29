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

SQLExplorerController.prototype.executeSQL = function() {
	this.createStatement($('queryText').value);
	this.statement.execute();
}

SQLExplorerController.prototype.formatSQLResults = function() {
	result = this.statement.getResult();
	air.Introspector.Console.dump(result)
	if (result.data != null && result.data.length > 0) {
		t = $('resultsTable');
		t.innerHTML = '';
		// alias
		data = result.data
		headerRow = new Element('tr')
		t.insert(headerRow)
		columns = [];
		// get all column names from first object in first row
		for (column in data[0]) {
			air.Introspector.Console.log("found column: " + column)
			columns.push(column);
			th = new Element('th').update(column);
			headerRow.insert(th);
		}
		// create rows for each row of data
		for (var i=0; i < data.length; i++) {
			tr = new Element('tr')
			t.insert(tr)
			air.Introspector.Console.log("found data: ")
			for (var c=0; c<columns.length; c++) {
				td = new Element('td').update(data[i][columns[c]])
				tr.insert(td)
			}
		}
	} else if (result != null && result.complete) { //good result, but no data selected
		t = $('resultsTable');
		t.innerHTML = '';
		tr = new Element('tr')
		t.insert(tr)
		td = new Element('td')
		tr.insert(td)
		td.update('Successful')
		if (result.rowsAffected) {
			td = new Element('td')
			tr.insert(td)
			td.update(result.rowsAffected + ' rows affected')
		}
		if (result.lastInsertRowID) {
			td = new Element('td')
			tr.insert(td)
			td.update('Last inserted id: ' + result.lastInsertRowID)
		}
	}
	$('resultsContainer').show();
}

// {
//   complete=true
//   data=null
// [null]  lastInsertRowID=2
//   rowsAffected=1
// }

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

SQLResultHandler = function() { }

SQLResultHandler.controller = null;

SQLResultHandler.prototype.sqlResult = function(event) {
	SQLResultHandler.controller.formatSQLResults();
}

SQLResultHandler.prototype.sqlError = function(event) {
	alert("Error executing query: " + event.error.message)
}

