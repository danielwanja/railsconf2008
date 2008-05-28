/* ************************************************************************ */
/*																			*/
/*  haXe Video 																*/
/*  Copyright (c)2007 Nicolas Cannasse										*/
/*																			*/
/* This library is free software; you can redistribute it and/or			*/
/* modify it under the terms of the GNU Lesser General Public				*/
/* License as published by the Free Software Foundation; either				*/
/* version 2.1 of the License, or (at your option) any later version.		*/
/*																			*/
/* This library is distributed in the hope that it will be useful,			*/
/* but WITHOUT ANY WARRANTY; without even the implied warranty of			*/
/* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU		*/
/* Lesser General Public License or the LICENSE file for more details.		*/
/*																			*/
/* ************************************************************************ */
package samples;

class Main {

	static var video = "test.flv";
	static var record = "record.flv";
	static var share = "myWebCam";
	static var current : Display = null;
	static var trace : flash.text.TextField;
	static var bpos : Float = 2;

	static function select( mode ) {
		if( current != null ) {
			current.doStop();
			current.parent.removeChild(current);
		}
		var mc = flash.Lib.current;
		var st = mc.stage;
		current = mode;
		if( current == null )
			return;
		current.width = st.stageWidth;
		current.height = st.stageHeight - 20;
		current.y = 20;
		mc.addChild(current);
	}

	static function doClick( onClick, e ) {
		try {
			onClick();
		} catch( e : Dynamic ) {
			doTrace(e);
		}
	}

	static function addButton( text, onClick ) {
		var t = new flash.text.TextField();
		t.text = text;
		t.width = t.textWidth + 6;
		t.height = 18;
		t.selectable = false;
		t.x = 2;

		var b = new flash.display.MovieClip();
		b.graphics.beginFill(0xFFEEDD);
		b.graphics.lineStyle(2,0x000000);
		b.graphics.drawRect(0,0,t.width,18);
		b.addChild(t);

		var sb = new flash.display.SimpleButton();
		sb.upState = b;
		sb.overState = b;
		sb.downState = b;
		sb.hitTestState = b;
		sb.useHandCursor = true;
		sb.addEventListener(flash.events.MouseEvent.CLICK,callback(doClick,onClick));
		flash.Lib.current.addChild(sb);

		sb.x = bpos;
		sb.y = 2;
		bpos += t.width + 5;
	}

	static function initTrace() {
		var mc = flash.Lib.current;
		trace = new flash.text.TextField();
		trace.y = 20;
		trace.thickness = 2;
		trace.width = mc.stage.stageWidth;
		trace.height = mc.stage.stageHeight - 20;
		trace.selectable = false;
		trace.textColor = 0xFFFFFF;
		trace.mouseEnabled = false;
		trace.filters = [new flash.filters.GlowFilter(0x7F7F7F,90,2,2,10)];
	}

	static function doTrace( v : Dynamic, ?pos : haxe.PosInfos ) {
		trace.text += pos.fileName+"("+pos.lineNumber+") : "+Std.string(v)+"\n";
		flash.Lib.current.addChild(trace);
	}

	static function main() {
		initTrace();
		haxe.Log.trace = doTrace;
		var host = "rtmp://"+flash.Lib.current.loaderInfo.parameters.host;
		flash.net.NetConnection.defaultObjectEncoding = flash.net.ObjectEncoding.AMF0;
		addButton("Play Test Video",function() { select(new VideoPlayer(host,video)); });
		addButton("Record Cam",function() { select(new Webcam(host,record,share)); });
		addButton("Play Rec. Video",function() { select(new VideoPlayer(host,record)); });
		addButton("View Cam",function() { select(new VideoPlayer(host,share,true)); });
		addButton("Stop",function() { select(null); });
		addButton("Clear Log",function() { trace.text = ""; });
	}

}
