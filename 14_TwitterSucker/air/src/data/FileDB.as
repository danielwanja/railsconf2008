package data
{
	import flash.filesystem.File;
	import flash.filesystem.FileMode;
	import flash.filesystem.FileStream;
	
	/**
	 * Save and loads TweetDataAggregator from File system
	 */
	public class FileDB
	{
		public function FileDB()
		{
		}

		static public function accountNames():Array {
			var file:File = File.documentsDirectory;
			file = file.resolvePath("TwitterSucker");
			if (!file.exists) return [];
			var files:Array = file.getDirectoryListing();
			var results:Array = [];
			for each (var f:File in files) {
				if (!f.isDirectory&&!f.isHidden&&!f.isPackage&&!f.isSymbolicLink) 
					if (f.name.indexOf(".dat")>0)
						results.push(f.name.replace(".dat",""));
			}
			return results;
		}
		static public function load(aggregator:TweetDataAggregator):void {
			trace("Reading:"+aggregator.accountName);
			var file:File = File.documentsDirectory;			
			file = file.resolvePath("TwitterSucker/"+aggregator.accountName+".dat");
			var fileStream:FileStream = new FileStream();
			fileStream.open(file, FileMode.READ);
			try {
				var tweets:Array = fileStream.readObject();
				trace("loaded :"+tweets.length);
				aggregator.setTweets(tweets);
			} finally {
				fileStream.close();
			}							
		}
		
		static public function save(aggregator:TweetDataAggregator):void {
			var tweets:Array = aggregator.getTweets();
			var file:File = File.documentsDirectory;
			file = file.resolvePath("TwitterSucker/"+aggregator.accountName+".dat");
			var fileStream:FileStream = new FileStream();
			fileStream.open(file, FileMode.WRITE);
			try {
				fileStream.writeObject(aggregator.accountName);
				fileStream.writeObject(tweets);
			} finally {
				fileStream.close();
			}				
		}
	}
}