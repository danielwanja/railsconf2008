SQLExplorerController = function() {
	//create a reusuable connection
	this.connection = new air.SQLConnection();
	//this.statemetn is the current sql statement
	this.statement = null;
	
	this.debug = false;
	this.init();
}

// create a static pointer to a database file in the application's storage directory
// when accessed through a SQLConnection.open statement, this database file will be
// created if it doesn't already exist
SQLExplorerController.databaseFile = air.File.applicationStorageDirectory.resolvePath("sample.db")

SQLExplorerController.prototype.init = function() {
	// create a reference on the result handler class, so callbacks can reach this object
	SQLResultHandler.controller = this;
	this.initializeDatabase();
	this.centerAndShowApp();
}

// creates and executes a SQL statement
SQLExplorerController.prototype.executeSQL = function() {
	// re-initialize the current sql statement from the queryText field
	this.createStatement($('queryText').value);
	// execute the current statement
	this.statement.execute();
}

// decides how to format the current results of a sql statement
SQLExplorerController.prototype.formatSQLResults = function() {
	// get the results of the current statement
	result = this.statement.getResult();
	if (this.debug) air.Introspector.Console.dump(result)

	this.clearResultsTable();
	$('resultsContainer').show();
	
	// if records were returned in the result
	if (result.data && result.data.length > 0) {
		data = result.data
		columns = [];
		headerRow = new Element('tr');
		this.resultsTable().insert(headerRow);
		// get all column names from first object in first row
		for (column in data[0]) {
			if (this.debug) air.Introspector.Console.log("found column: " + column)
			columns.push(column);
			th = new Element('th').update(column);
			headerRow.insert(th);
		}
		// create rows for each row of data in result
		for (var i=0; i < data.length; i++) {
			tr = new Element('tr');
			this.resultsTable().insert(tr);
			// loop over all columns and get values for column from current row object
			for (var c=0; c<columns.length; c++) {
				td = new Element('td').update(data[i][columns[c]]);
				tr.insert(td);
			}
		}
	//otherwise, if it's still a good result, but no data was selected:
	} else if (result != null && result.complete) { 
		tr = new Element('tr');
		this.resultsTable().insert(tr);
		td = new Element('td');
		tr.insert(td);
		td.update('Successful');
		
		// show if any rows were affected
		if (result.rowsAffected != null) {
			td = new Element('td')
			tr.insert(td)
			td.update(result.rowsAffected + ' rows affected')
		}
		// if the operation was an insert, show the id from that insert
		if (result.lastInsertRowID) {
			td = new Element('td')
			tr.insert(td)
			td.update('Last inserted id: ' + result.lastInsertRowID)
		}
	}
}

// creates and configures the current statement given a sql query
SQLExplorerController.prototype.createStatement = function(sql) {
	this.statement = new air.SQLStatement();
	
	// a SQLResultHandler will call back to when a result is recieved
	this.statement.addEventListener(air.SQLEvent.RESULT, new SQLResultHandler().sqlResult);
	this.statement.addEventListener(air.SQLErrorEvent.ERROR, new SQLResultHandler().sqlError);
	this.statement.sqlConnection = this.connection;
	this.statement.text = sql;
}

// initializes database and standard tables
SQLExplorerController.prototype.initializeDatabase = function() {
	try {
		// if the database file doesn't exist, opening a connection on it will create it
		this.connection.open(SQLExplorerController.databaseFile);
		
	} catch (error) {
		alert("error opening database: " + error.message);
	}

	// we'll also create a default people table for demo purposes
	// in case one doesn't exist
	sql = "CREATE TABLE IF NOT EXISTS people (" + 
    "    id INTEGER PRIMARY KEY AUTOINCREMENT, " + 
    "    firstName TEXT, " + 
    "    lastName TEXT " + 
    ")";

	this.createStatement(sql);
	this.statement.execute();
    
}

// The application starts out hidden
// This method centers the app window on the main screen 
// and then makes the app visible
SQLExplorerController.prototype.centerAndShowApp = function() {
	var height = window.nativeWindow.height;
	var width = window.nativeWindow.width;
	var screenSizeY = air.Screen.mainScreen.visibleBounds.bottom;
	var screenSizeX = air.Screen.mainScreen.visibleBounds.right;
	
	window.nativeWindow.x = screenSizeX/2 - width/2;
	window.nativeWindow.y = screenSizeY/2 - height/2;
	
	window.nativeWindow.visible = true;
}

SQLExplorerController.prototype.clearResultsTable = function() {
	this.resultsTable().innerHTML = '';
}

// points to the results table HTML element
SQLExplorerController.prototype.resultsTable = function() {
	// prototype is cool
	return $('resultsTable');
}

SQLResultHandler = function() { }

SQLResultHandler.controller = null;

SQLResultHandler.prototype.sqlResult = function(event) {
	SQLResultHandler.controller.formatSQLResults();
}

SQLResultHandler.prototype.sqlError = function(event) {
	air.trace("Error executing query: " + event.error.message)
}

