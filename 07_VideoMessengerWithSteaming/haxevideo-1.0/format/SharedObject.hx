/* ************************************************************************ */
/*																			*/
/*  haXe Video 																*/
/*  Copyright (c)2007 Nicolas Cannasse										*/
/*  SharedObject contributed by Russell Weir								*/
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
package format;
import format.Amf;

enum SOCommand {
	SOConnect;
	SODisconnect;
	SOSetAttribute( name : String, value : AmfValue );
	SOUpdateData( data : Hash<AmfValue> );
	SOUpdateAttribute( name : String );
	SOSendMessage( msg : AmfValue );
	SOStatus( msg : String, type : String );
	SOClearData;
	SODeleteData;
	SODeleteAttribute( name : String );
	SOInitialData;
}

typedef SOData = {
	var name : String;
	var version : Int;
	var persist : Bool;
	var unknown : Int;
	var commands : List<SOCommand>;
}

class SharedObject {

	static function readString( i : neko.io.Input ) {
		return i.read(i.readUInt16B());
	}

	public static function read( i : neko.io.Input ) : SOData {
		var name = readString(i);
		var ver = i.readUInt32B();
		var persist = i.readUInt32B() == 2;
		var unk = i.readUInt32B();
		var cmds = new List();
		while( true ) {
			var c = try i.readChar() catch( e : neko.io.Eof ) break;
			var size = i.readUInt32B();
			var cmd = switch( c ) {
			case 1:
				SOConnect;
			case 2:
				SODisconnect;
			case 3:
				var name = readString(i);
				SOSetAttribute(name,Amf.read(i));
			case 4:
				var values = new neko.io.StringInput(i.read(size));
				var hash = new Hash();
				while( true ) {
					var size = try values.readUInt16B() catch( e : neko.io.Eof ) break;
					var name = values.read(size);
					hash.set(name,Amf.read(values));
				}
				SOUpdateData(hash);
			case 5:
				SOUpdateAttribute(readString(i));
			case 6:
				SOSendMessage(Amf.read(i));
			case 7:
				var msg = readString(i);
				var type = readString(i);
				SOStatus(msg,type);
			case 8:
				SOClearData;
			case 9:
				SODeleteData;
			case 10:
				SODeleteAttribute(readString(i));
			case 11:
				SOInitialData;
			}
		}
		return {
			name : name,
			version : ver,
			persist : persist,
			unknown : unk,
			commands : cmds,
		};
	}

	static function writeString( o : neko.io.Output, s : String ) {
		o.writeUInt16B(s.length);
		o.write(s);
	}

	static function writeCommandData( o : neko.io.Output, cmd ) {
		switch( cmd ) {
		case SOConnect,SODisconnect,SOClearData,SODeleteData,SOInitialData:
			// nothing
		case SOSetAttribute(name,value):
			writeString(o,name);
			Amf.write(o,value);
		case SOUpdateData(data):
			for( k in data.keys() ) {
				writeString(o,k);
				Amf.write(o,data.get(k));
			}
		case SOUpdateAttribute(name):
			writeString(o,name);
		case SOSendMessage(msg):
			Amf.write(o,msg);
		case SOStatus(msg,type):
			writeString(o,msg);
			writeString(o,type);
		case SODeleteAttribute(name):
			writeString(o,name);
		}
	}

	public static function write( o : neko.io.Output, so : SOData ) {
		o.writeUInt16B(so.name.length);
		o.write(so.name);
		o.writeUInt32B(so.version);
		o.writeUInt32B(so.persist?2:0);
		o.writeUInt32B(so.unknown);
		for( cmd in so.commands ) {
			o.writeChar( Type.enumIndex(cmd) + 1 );
			var s = new neko.io.StringOutput();
			writeCommandData(s,cmd);
			var data = s.toString();
			o.writeUInt32B(data.length);
			o.write(data);
		}
	}

}
