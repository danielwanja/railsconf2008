package data
{
	import mx.collections.ArrayCollection;
	import mx.utils.ObjectUtil;
	
	/**
	 * Incrementally sumarize tweets
	 */
	public class TweetDataAggregator
	{
		private var tweets:Array;
		private var tweetsInTimeRange:Array;
		private var dateRange:Object; 
		private var ids:Object;
		private var account:String;
		
		[Bindable]public var tweetsPerDay:ArrayCollection = new ArrayCollection();
		[Bindable]public var tweetsDayOfWeek:ArrayCollection = new ArrayCollection();
		[Bindable]public var tweetsDateOfMonth:ArrayCollection = new ArrayCollection();
		[Bindable]public var tweetsByMonth:ArrayCollection = new ArrayCollection();		
		[Bindable]public var tweetsByHour:ArrayCollection = new ArrayCollection();
		[Bindable]public var tweetsReplies:ArrayCollection = new ArrayCollection();
		[Bindable]public var tweetsHourAndDay:ArrayCollection = new ArrayCollection();
		
		
		public function TweetDataAggregator(account:String) {
			this.tweets = [];
			this.ids = {};
			this.account = account;
		}

		public function get accountName():String {
			return account;
		}
		
		/**
		 * Add tweets. Allow to add incrementally tweets.
		 */
		public function addTweets(tweets:Array):Boolean {
			var overlap:Boolean = false;
			for each (var tweet:Object in tweets) {
				if (ids[tweet.id] != null) {
					overlap = true;
				} else {
					ids[tweet.id] = tweet;
					this.tweets.push(tweet);
				}
			}
			return overlap;
		}		
		
		public function getTweets():Array {
			return tweets;
		}
		public function getTweetsInTimeRange():Array {
			return tweetsInTimeRange;
		}
		public function setTweets(tweets:Array):void {
			this.tweets = tweets;
			aggregate(); // resets ids
		}
		private function idRange(tweets:Array):Array {
			if (tweets.length>1) {
				return [tweets[0].id, tweets[tweets.length-1].id];
			} else if (tweets.length>0) {
				return [tweets[0].id, tweets[0].id];
			} else {
				return [-1, -1];
			}
		}
		public function aggregate():void {
			tweetsInTimeRange = [];
			var agg:Object = getAggregationStructure();
			for each (var tweet:Object in tweets) {
				if (tweet.time_breakdown==null) tweet.time_breakdown = timeBreakdown(tweet.time);
				if (ids[tweet.id] == null) ids[tweet.id] = tweet;
				tweetsInTimeRange.push(tweet);
				increment(agg.tweetsPerDay, tweet.time_breakdown.date);
				increment(agg.tweetsDayOfWeek, tweet.time_breakdown.w);
				increment(agg.tweetsDateOfMonth, tweet.time_breakdown.d);
				increment(agg.tweetsByMonth, tweet.time_breakdown.m);				
				increment(agg.tweetsByHour, tweet.time_breakdown.h);
				if (tweet.in_reply_to != "<public>")
					increment(agg.tweetsReplies, tweet.in_reply_to);
				
				// hour and day
				var k:String = tweet.time_breakdown.h+"."+tweet.time_breakdown.w
				var hourAndDay:Object = increment(agg.tweetsHourAndDay, k)
				hourAndDay.h = tweet.time_breakdown.h;
				hourAndDay.w = tweet.time_breakdown.w;	
			}
			
			tweetsPerDay = new ArrayCollection(mapToArray(agg.tweetsPerDay, true, 'key', Array.NUMERIC));
			tweetsDayOfWeek = new ArrayCollection(mapToArray(agg.tweetsDayOfWeek));
			tweetsDateOfMonth = new ArrayCollection(mapToArray(agg.tweetsDateOfMonth));
			tweetsByMonth = new ArrayCollection(mapToArray(agg.tweetsByMonth));			
			tweetsByHour = new ArrayCollection(mapToArray(agg.tweetsByHour));
			tweetsReplies = new ArrayCollection(mapToArray(agg.tweetsReplies, true, 'value', Array.DESCENDING||Array.NUMERIC, 10));
			tweetsHourAndDay = new ArrayCollection(mapHourAndDayToArray(agg.tweetsHourAndDay));
			// Sort
			//this.tweets.sortOn('time', Array.NUMERIC);
			this.tweets.sort(tweetDateCompare);
			dateRange = getFullDateRange();
		}
		private function tweetDateCompare(t0:Object, t1:Object):Number {
			return ObjectUtil.numericCompare(t1.time_breakdown.date, t0.time_breakdown.date);
		}
		
		public function getFullDateRange():Object {
			//FIXME: that doesn't work...!
			//FIXME: add support for zero tweets.
			return {fromDate:tweets[0].time_breakdown.date, 
				   toDate:tweets[tweets.length-1].time_breakdown.date}
		}
		public function getDateRange():Object {
			return dateRange;
		}
		
		//FIXME: refactor with above to remove duplicate code.
		public function aggregateForDateRange(fromDate:Number, toDate:Number):void {
			dateRange = {fromDate:fromDate, toDate:toDate};
			tweetsInTimeRange = [];
			var agg:Object = getAggregationStructure();
			for each (var tweet:Object in tweets) {
				if (tweet.time_breakdown==null) tweet.time_breakdown = timeBreakdown(tweet.time);
				if (tweet.time_breakdown.date<fromDate || tweet.time_breakdown.date>toDate) continue;
				tweetsInTimeRange.push(tweet);
				//increment(agg.tweetsPerDay, tweet.time_breakdown.date);
				increment(agg.tweetsDayOfWeek, tweet.time_breakdown.w);
				increment(agg.tweetsDateOfMonth, tweet.time_breakdown.d);
				increment(agg.tweetsByMonth, tweet.time_breakdown.m);				
				increment(agg.tweetsByHour, tweet.time_breakdown.h);
				if (tweet.in_reply_to != "<public>")
					increment(agg.tweetsReplies, tweet.in_reply_to);
				
				// hour and day
				var k:String = tweet.time_breakdown.h+"."+tweet.time_breakdown.w
				var hourAndDay:Object = increment(agg.tweetsHourAndDay, k)
				hourAndDay.h = tweet.time_breakdown.h;
				hourAndDay.w = tweet.time_breakdown.w;	
			}
			
			//tweetsPerDay = new ArrayCollection(mapToArray(agg.tweetsPerDay, true, 'key', Array.NUMERIC));
			tweetsDayOfWeek.source = mapToArray(agg.tweetsDayOfWeek);
			tweetsDateOfMonth.source = mapToArray(agg.tweetsDateOfMonth);
			tweetsByMonth.source = mapToArray(agg.tweetsByMonth);			
			tweetsByHour.source = mapToArray(agg.tweetsByHour);
			tweetsReplies.source = mapToArray(agg.tweetsReplies, true, 'value', Array.DESCENDING||Array.NUMERIC, 10);
			tweetsHourAndDay.source = mapHourAndDayToArray(agg.tweetsHourAndDay);			
		}
		
		
		private function increment(obj:Object, k:Object):Object {
			if (obj[k]==undefined) obj[k]={count:0};
			obj[k].count += 1;
			return obj[k];
		}
		private function mapToArray(map:Object, sort:Boolean=false, sortField:String='value', sortOptions:Object=null, limit:Number=-1):Array {			
			var result:Array = [];
			for (var attr:String in map) {
				result.push({key:attr, value:map[attr].count});
			}
			if (sort) result.sortOn(sortField, sortOptions);
			if (limit>0) result = result.slice(0, limit);
			return result;
		}
		private function mapHourAndDayToArray(map:Object):Array {
			var result:Array = [];
			for (var attr:String in map) {
				result.push({key:attr, count:map[attr].count, h:map[attr].h, w:map[attr].w});
			}
			return result;			
		}
		private function getAggregationStructure():Object {
			return {
				tweetsPerDay: {},
				tweetsDayOfWeek: {},
				tweetsDateOfMonth: {},
				tweetsByMonth: {},				
				tweetsByHour: {},
				tweetsReplies: {},
				tweetsHourAndDay: {}
			}
		}	
		/**
		 * Parse data 2008-04-25T01:35:32+00:00
		 */
		private function timeBreakdown(time:String):Object {
			var parts:Array = time.split(/-|T|:|\+/)
			var y:Number = Number(parts[0]);
			var m:Number = Number(parts[1]);
			var d:Number = Number(parts[2]);
			var h:Number = Number(parts[3]);
			var dt:Date = new Date(y,m-1,d);
			var dateAndTime:Date = new Date(y,m-1,d, h, parts[4], parts[5]);
			var w:Number = dt.getDay();
			return {dateandtime:dateAndTime, date:dt.getTime(), y:y, m:m, d:d, h:h, w:w}
		}
	}
}