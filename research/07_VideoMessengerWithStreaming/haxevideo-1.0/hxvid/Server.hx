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
package hxvid;
import hxvid.Client;

class Server extends RealtimeServer<Client> {

	public static var FLV_BUFFER_TIME : Float = 5; // 5 seconds of buffering
	public static var CLIENT_BUFFER_SIZE = (1 << 18); // 256 KB buffer
	public static var BASE_DIR = "videos/";
	static var CID = 0;

	public override function clientConnected( s : neko.net.Socket ) {
		return new Client(this,s);
	}

	public override function clientDisconnected( c : Client ) {
		c.cleanup();
	}

	public override function readClientMessage( c : Client, buf : String, pos : Int, len : Int ) {
		var m = c.readProgressive(buf,pos,len);
		if( m == null )
			return null;
		if( m.msg != null )
			c.processPacket(m.msg.header,m.msg.packet);
		return m.bytes;
	}

	public override function clientFillBuffer( c : Client ) {
		c.updateTime(neko.Sys.time());
	}

	public override function clientWakeUp( c : Client ) {
		c.updateTime(neko.Sys.time());
	}

	static function main() {
		var s = new Server();
		s.config.writeBufferSize = CLIENT_BUFFER_SIZE;
		s.config.blockingBytes = CLIENT_BUFFER_SIZE >> 2;
		if( s.config.blockingBytes < (1 << 16) ) // 64 KB
			s.config.blockingBytes = (1 << 16);
		var args = neko.Sys.args();
		var server = args[0];
		var port = Std.parseInt(args[1]);
		if( server == null )
			server = "localhost";
		if( port == null )
			port = 1935;
		neko.Lib.println("Starting haXe Video Server on "+server+":"+port);
		try {
			s.run(server,port);
		} catch( e : String ) {
			if( e == "std@socket_bind" )
				e = "Error : the port cannot be opened (already used by another server ?)";
			neko.Lib.rethrow(e);
		}
	}

}
