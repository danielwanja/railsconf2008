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

class Webcam extends Display {

	var file : String;
	var share : String;
	var nc : flash.net.NetConnection;
	var ns : flash.net.NetStream;
	var cam : flash.media.Camera;
	var mic : flash.media.Microphone;

	public function new(host,file,?share) {
		super();
		this.file = file;
		this.share = share;
		cam = flash.media.Camera.getCamera();
		mic = flash.media.Microphone.getMicrophone();
		if( cam == null )
			throw "Webcam not found";
		nc = new flash.net.NetConnection();
		nc.addEventListener(flash.events.NetStatusEvent.NET_STATUS,onEvent);
		nc.connect(host);
	}

	function onKey( e : flash.events.KeyboardEvent ) {
		ns.send("onMetaData",{ keypress : e.keyCode });
	}

	function onEvent(e) {
		trace(e.info);
		if( e.info.code == "NetConnection.Connect.Success" ) {
			ns = new flash.net.NetStream(nc);
			ns.addEventListener(flash.events.NetStatusEvent.NET_STATUS,onEvent);
			this.stage.addEventListener(flash.events.KeyboardEvent.KEY_DOWN,onKey);
			ns.attachCamera(cam);
			ns.attachAudio(mic);
			video.attachCamera(cam);
			ns.publish(file,share);
		}
	}

	public function doStop() {
		stage.removeEventListener(flash.events.KeyboardEvent.KEY_DOWN,onKey);
		if( ns != null )
			ns.close();
		nc.close();
	}

}