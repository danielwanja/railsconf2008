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

class VideoPlayer extends Display {

	var nc : flash.net.NetConnection;
	var ns : flash.net.NetStream;
	var file : String;
	var live : Bool;

	public function new(host,file,?live) {
		super();
		trace("Connecting...");
		this.file = file;
		this.live = live;
		nc = new flash.net.NetConnection();
		nc.addEventListener(flash.events.NetStatusEvent.NET_STATUS,onEvent);
		nc.connect(host);
	}

	function onClick(e) {
		if( ns == null )
			return;
		ns.togglePause();
	}

	function onKey( e : flash.events.KeyboardEvent ) {
		switch( e.keyCode ) {
		case 39: // RIGHT
			ns.seek(ns.time + 30);
		default:
			trace("KEY "+e.keyCode);
		}
	}

	function onMetaData( data : Dynamic ) {
		// copy fields so they will be displayed nicely
		// for some reason, 'data' is an Array
		var metas = Reflect.copy(data);
		trace("META "+Std.string(metas));
	}

	function onEvent(e) {
		if( StringTools.startsWith(e.info.code,"NetStream.Buffer") )
			return;
		trace(e.info);
		if( e.info.code == "NetConnection.Connect.Success" ) {
			ns = new flash.net.NetStream(nc);
			ns.addEventListener(flash.events.NetStatusEvent.NET_STATUS,onEvent);
			this.addEventListener(flash.events.MouseEvent.CLICK,onClick);
			this.stage.addEventListener(flash.events.KeyboardEvent.KEY_DOWN,onKey);
			video.attachNetStream(ns);
			ns.client = { onMetaData : onMetaData };
			//ns.receiveAudio(false);
			ns.play(if( live ) "#"+file else file);
		}
	}

	public function doStop() {
		stage.removeEventListener(flash.events.KeyboardEvent.KEY_DOWN,onKey);
		if( ns != null )
			ns.close();
		nc.close();
	}

}
