package
{
	import com.adobe.flex.extras.controls.springgraph.Graph;
	
	import flash.events.Event;
	

	public class MyGraph extends Graph
	{
		private var notificationDisabled:Boolean = false;
		public function MyGraph()
		{
			super();
		}

		public function disableNotification():void {
			notificationDisabled = true;
		}
		public function enableNotification():void {
			notificationDisabled = false;
			dispatchEvent(new Event(CHANGE));
		}
		
		override public function dispatchEvent(event:Event):Boolean {
			if (!notificationDisabled) return super.dispatchEvent(event);
			return false;
		}		
		
	}
	
}