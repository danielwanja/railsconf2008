package data
{
	import mx.controls.HTML;
	import mx.controls.Text;
	
	/**
	 * Programatically parsing html and not using mx:HTML with css selector.
	 * Note this is 'brittle' as whe Twitter will change their html it would break this class.
	 */
	public class HTMLParser
	{
		private var _html:String;
		private var _stats:XML;
		private var _tweets:XML;
		private var _ids:Array;
		private var _pageNumber:Number
		
		public function HTMLParser(html:String, pageNumber:Number=1)
		{
			this._html = html;
			this._pageNumber = !isNaN(pageNumber) ? pageNumber : 1;
		}
		
		public function get updates():Number {
			return Number(stats.children()[3].span.toString().replace(',',''));
		}
		public function get pageCount():Number {
			return Math.ceil(updates/20);
		}
		public function get hasNextPage():Boolean {
			return _html.indexOf('class="section_links" rel="prev">Older &#187;</a>')>-1;
		}
		public function get pageNumber():Number {
			trace("pageNumber:"+_pageNumber);
			return _pageNumber;
		}
		
		/**
		 * Converts these
		 * <ul class="stats">
		 * <li><a class="label" href="/Scobleizer/friends">Following</a> <span class="numeric stats_count">21,164</span></li>
    	 * <li><a class="label" href="/Scobleizer/followers">Followers</a><span class="stats_count numeric">23,874</span></li>
		 * <li><a href="/Scobleizer/favorites" class="label">Favorites</a> <span class="stats_count numeric">8</span></li>
		 * <li><a href="/Scobleizer" class="label">Updates</a> <span class="stats_count numeric">11,862</span></li>
		 * </ul>
		 */
		public function get stats():XML {
			if (_stats != null) return _stats;
			_stats = partial('<ul class="stats">', '</ul>')
			return _stats;
		}
		
		public function get tweets():XML {
			if (_tweets != null) return _tweets;
			_tweets = partial('<table class="doing" id="timeline" cellspacing="0">', '</table>');
			return _tweets;
		}
		
		public function get ids():Array {
			if (_ids != null) return _ids;
			var list:XMLList = tweets.tr.(attribute('class')=='hentry'||attribute('class')=='hentry_over').@id;
			var result:Array = [];
			for each (var xml:XML in list) {
				result.push(Number(xml.toString().replace("status_", "")));
			}
			_ids = result;
			return _ids;
		}
		
		/**
		 * Extracting all content tds.
		 * <tr class="hentry" id="status_812722710">
		    <td class="content">
		      <span...</span>
		    </td>
		  </tr>
		*/
		public function get tweetsContent():XMLList {
			var list:XMLList = tweets.tr.td.(attribute('class')=='content');
			return list;
		}
		
		/**
		 * Convert list of td into array of stat objects
		 */		
		public function get tweetsArray():Array {
			var list:XMLList = tweetsContent;
			var result:Array = [];
			var count:Number = 0;
			for each (var xml:XML in list) {
				var stat:Object = contentToStats(xml);
				stat.id = ids[count++];
				result.push(stat);
			}
			return result;			
		}
		
		
		/**
		 * Extracting message, published_time
		 * returns {message, time, time_breakdown:{y, m, d, h}, client, in_reply_to, 
		 * <td class="content">
			  <span class="entry-content">
			    @
			    <a href="/Veronica">Veronica</a>
			    . I am gladly giving you one of mine.
			  </span>
			  <span class="meta entry-meta">
			    <a href="http://twitter.com/danielwanja/statuses/796387374" class="entry-date" rel="bookmark">
			      <abbr class="published" title="2008-04-25T01:35:32+00:00">07:35 PM April 24, 2008</abbr>
			    </a>
			    from
			    <a href="http://www.twhirl.org/">twhirl</a>
			    <a href="http://twitter.com/Veronica/statuses/796374204">in reply to Veronica</a>
			  </span>
			</td>
		  */
		public function contentToStats(content:XML):Object {
			//1. from im
			//2.  from 
			//     <a> <a/>
			//3  [responds To]
			
			var entryMeta:XMLList = content.span.(attribute('class')=='meta entry-meta');
			var entryMetaChildren:XMLList = entryMeta.children(); 
			var from:String;
			var respondsTo:String="<public>";
			var respondsToIndex:Number = 2;
			if (entryMetaChildren[1].toString()=="from") {
					from = entryMetaChildren[2].toString()
					respondsToIndex = 3
			} else {
					from = entryMetaChildren[1].toString().replace("from ","");
			}
			if (respondsToIndex<entryMetaChildren.length()) {
				respondsTo = entryMetaChildren[respondsToIndex].toString().replace("in reply to ","");
			}
			return {
				message: content.span.(attribute('class')=='entry-content').toString(),
				time:entryMeta.a.abbr.@title,
				time_breakdown:null,
				client: from,
				in_reply_to: respondsTo
			}
		}

		private function partial(fromToken:String, toToken:String):XML {
			var start:Number = _html.indexOf(fromToken);
			if (start==-1) return <nil/>;
			var end:Number = _html.indexOf(toToken, start);
			if (end==-1) return <nil/>;
			var substr:String = _html.substring(start, end+toToken.length);
			try {
			   return new XML(substr);
			} catch (err:Error) {
			  return <nil/>; // couldn't convert xml
			}
			return <nil/>;
		}
	}
}