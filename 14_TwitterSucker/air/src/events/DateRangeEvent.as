package events
{
	import flash.events.Event;

	public class DateRangeEvent extends Event
	{
		public var fromRange:Number;
		public var toRange:Number;
		
		public function DateRangeEvent(type:String, fromRange:Number, toRange:Number)
		{
			super(type, false, false);
			this.fromRange = fromRange;
			this.toRange = toRange;
		}
		
	}
}