package events
{
	import flash.events.Event;

	public class AccountEvent extends Event
	{
		public var account:Object;
		
		public function AccountEvent(type:String, bubbles:Boolean=false, cancelable:Boolean=false)
		{
			super(type, bubbles, cancelable);
		}
		
	}
}