package
{
	import flash.display.BitmapData;
	import flash.events.Event;
	import flash.filesystem.File;
	import flash.filesystem.FileMode;
	import flash.filesystem.FileStream;
	import flash.media.Video;
	import flash.utils.ByteArray;
	import flash.utils.clearInterval;
	import flash.utils.setInterval;
	
	import mx.controls.Alert;
	
	public class RecorderBuffer
	{
		private var video:Video;
		private var interval:Number;
		
		public function RecorderBuffer(video:Video)
		{
			bitmaps = [];		
			this.video = video;
		}
		
		public function start():void {
			bitmaps = [];		
			var delay:Number = 1000 /* milliseconds */ / 5 /* fps */ // = 200
			interval = setInterval(snap, delay);	
		}
		
		public function stop():void {
			clearInterval(interval);
		}
		
		public function hasContent():Boolean {
			return bitmaps.length > 0;
		}
		
		private var targetDirectory:File = File.desktopDirectory; 
		public function processContent():void {
			// Add to SmipleFlvWriter
			trace("Recorded frames:"+bitmaps.length);
			trace("Duration in seconds:"+(bitmaps.length * 200 / 1000));
			targetDirectory.browseForSave("Save Flv");
			targetDirectory.addEventListener(Event.SELECT, saveData);
		}
		
		private function saveData(event:Event):void {
		    var newFile:File = event.target as File;
		    if (newFile.parent.nativePath != targetDirectory.nativePath) {
		    	targetDirectory = newFile.parent;
		    } 
			var flv:SimpleFlvWriter = SimpleFlvWriter.getInstance();
			flv.createFile(null, 320,240, 5, 120);
			for (var i:Number=0; i < bitmaps.length; i++) {
				trace("Saving bitmap:"+i);
				flv.saveFrame(bitmaps[i]);
			}
			var ba:ByteArray = flv.getAndClearFlvBytes();
			ba.position = 0;
			trace("Size:"+ba.length);		    	
	    	
	        var stream:FileStream = new FileStream();
	        stream.open(newFile, FileMode.WRITE);
	        stream.writeBytes(ba);
	        stream.close();
		}
		

		private function snap():void {
			var snapshot:BitmapData = new BitmapData(320, 240, true);			
			snapshot.draw(video);
			bitmaps.push(snapshot);	
		}

		private var bitmaps:Array;
	}
}