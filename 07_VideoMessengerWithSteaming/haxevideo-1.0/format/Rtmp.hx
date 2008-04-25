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
package format;
import format.Amf;
import format.SharedObject;

enum RtmpKind {
	KCall;
	KVideo;
	KAudio;
	KMeta;
	KChunkSize;
	KBytesReaded;
	KCommand;
	KShared;
	KUnknown( v : Int );
}

enum RtmpCommand {
	CClear;
	CPlay;
	CReset;
	CPing( v : Int );
	CPong( v : Int );
	CClientBuffer( v : Int );
	CUnknown( kind : Int, ?v1 : Int, ?v2 : Int );
}

enum RtmpPacket {
	PCall( name : String, iid : Int, args : Array<AmfValue> );
	PVideo( data : String );
	PAudio( data : String );
	PMeta( data : String );
	PCommand( sid : Int, v : RtmpCommand );
	PBytesReaded( nbytes : Int );
	PShared( data : SOData );
	PUnknown( kind : Int, body : String );
}

typedef RtmpHeader = {
	var channel : Int;
	var timestamp : Int;
	var kind : RtmpKind;
	var src_dst : Int;
	var size : Int;
}

class Rtmp {

	public static var HANDSHAKE_SIZE = 0x600;

	static var HEADER_SIZES = [12,8,4,1];
	static var INV_HSIZES = [null,3,null,null,2,null,null,null,1,null,null,null,0];
	static var COMMAND_SIZES = [0,0,null,4,0,4,4];

	static function kindToInt(k) {
		return switch(k) {
		case KChunkSize: 0x01;
		case KBytesReaded: 0x03;
		case KCommand: 0x04;
		case KAudio: 0x08;
		case KVideo: 0x09;
		case KMeta: 0x12;
		case KShared: 0x13;
		case KCall: 0x14;
		case KUnknown(b): b;
		}
	}

	static function kindOfInt(n) {
		var k = HKINDS[n];
		if( k == null )
			return KUnknown(n);
		return k;
	}

	static var HKINDS = {
		var a = new Array<RtmpKind>();
		for( kname in Type.getEnumConstructs(cast RtmpKind) ) {
			if( kname == "KUnknown" )
				continue;
			var k = Reflect.field(RtmpKind,kname);
			a[kindToInt(k)] = k;
		}
		a;
	};

	var channels : Array<{ header : RtmpHeader, buffer : StringBuf, bytes : Int }>;
	var saves : Array<RtmpHeader>;
	var read_chunk_size : Int;
	var write_chunk_size : Int;
	public var i : neko.io.Input;
	public var o : neko.io.Output;

	public function new(input,output) {
		i = input;
		o = output;
		read_chunk_size = 128;
		write_chunk_size = 128;
		channels = new Array();
		saves = new Array();
	}

	public function readWelcome() {
		if( i.readChar() != 3 )
			throw "Invalid Welcome";
	}

	public function readHandshake() {
		var uptime = i.readUInt32B();
		var ping = i.readUInt32B();
		return i.read(HANDSHAKE_SIZE - 8);
	}

	public function writeWelcome() {
		o.writeChar(3);
	}

	public function writeHandshake( hs ) {
		o.writeUInt32B(1); // uptime
		o.writeUInt32B(1); // ping
		o.write(hs);
	}

	public function getHeaderSize( h : Int ) {
		return HEADER_SIZES[h >> 6];
	}

	function getLastHeader( channel ) {
		var h = saves[channel];
		if( h == null ) {
			h = {
				channel : channel,
				timestamp : null,
				size : null,
				kind : null,
				src_dst : null,
			};
			saves[channel] = h;
		}
		return h;
	}

	public function readHeader() : RtmpHeader {
		var h = i.readChar();
		var hsize = HEADER_SIZES[h >> 6];
		var channel = h & 63;
		var last = getLastHeader(channel);
		if( hsize >= 4 ) last.timestamp = i.readUInt24B();
		if( hsize >= 8 ) last.size = i.readUInt24B();
		if( hsize >= 8 ) last.kind = kindOfInt(i.readChar());
		if( hsize == 12 ) last.src_dst = i.readInt32();
		return {
			channel : channel,
			timestamp : last.timestamp,
			kind : last.kind,
			src_dst : last.src_dst,
			size : last.size,
		};
	}

	function writeHeader( p : RtmpHeader ) {
		var hsize;
		if( p.src_dst != null )
			hsize = 12;
		else if( p.kind != null )
			hsize = 8;
		else if( p.timestamp != null )
			hsize = 4;
		else
			hsize = 1;
		o.writeChar(p.channel | (INV_HSIZES[hsize] << 6));
		if( hsize >= 4 )
			o.writeUInt24B(p.timestamp);
		if( hsize >= 8 ) {
			o.writeUInt24B(p.size);
			o.writeChar(kindToInt(p.kind));
		}
		if( hsize == 12 )
			o.writeInt32(p.src_dst);
	}

	public function send( channel : Int, p : RtmpPacket, ?ts, ?streamid ) {
		var h = {
			channel : channel,
			timestamp : if( ts != null ) ts else 0,
			kind : null,
			src_dst : if( streamid != null ) streamid else 0,
			size : null
		};
		var data = null;
		switch( p ) {
		case PCommand(sid,cmd):
			var o = new neko.io.StringOutput();
			var kind,v1,v2;
			switch( cmd ) {
			case CClear:
				kind = 0;
			case CPlay:
				kind = 1;
			case CClientBuffer(v):
				kind = 3;
				v1 = v;
			case CReset:
				kind = 4;
			case CPing(v):
				kind = 6;
				v1 = v;
			case CPong(v):
				kind = 7;
				v1 = v;
			case CUnknown(k,a,b):
				kind = k;
				v1 = a;
				v2 = b;
			}
			o.writeUInt16B(kind);
			o.writeUInt32B(sid);
			if( v1 != null )
				o.writeUInt32B(v1);
			if( v2 != null )
				o.writeUInt32B(v2);
			data = o.toString();
			h.kind = KCommand;
		case PCall(cmd,iid,args):
			var o = new neko.io.StringOutput();
			Amf.write(o,AString(cmd));
			Amf.write(o,ANumber(iid));
			for( x in args )
				Amf.write(o,x);
			data = o.toString();
			h.kind = KCall;
		case PAudio(d):
			data = d;
			h.kind = KAudio;
		case PVideo(d):
			data = d;
			h.kind = KVideo;
		case PMeta(d):
			data = d;
			h.kind = KMeta;
		case PBytesReaded(n):
			var s = new neko.io.StringOutput();
			s.writeUInt32B(n);
			data = s.toString();
			h.kind = KBytesReaded;
		case PShared(so):
			var s = new neko.io.StringOutput();
			SharedObject.write(s,so);
			data = s.toString();
			h.kind = KShared;
		case PUnknown(k,d):
			data = d;
			h.kind = KUnknown(k);
		}
		h.size = data.length;
		// write packet header + data
		writeHeader(h);
		var pos = write_chunk_size;
		if( data.length <= pos )
			o.write(data);
		else {
			var len = data.length - pos;
			o.writeFullBytes(data,0,pos);
			while( len > 0 ) {
				o.writeChar(channel | (INV_HSIZES[1] << 6));
				var n = if( len > write_chunk_size ) write_chunk_size else len;
				o.writeFullBytes(data,pos,n);
				pos += n;
				len -= n;
			}
		}
	}

	function processBody( h : RtmpHeader, body : String ) {
		switch( h.kind ) {
		case KCall:
			var i = new neko.io.StringInput(body);
			var name = switch( Amf.read(i) ) { case AString(s): s; default: throw "Invalid name"; }
			var iid = switch( Amf.read(i) ) { case ANumber(n): Std.int(n); default: throw "Invalid nargs"; }
			var args = new Array();
			while( true ) {
				var c = try i.readChar() catch( e : Dynamic ) break;
				args.push(Amf.readWithCode(i,c));
			}
			return PCall(name,iid,args);
		case KVideo:
			return PVideo(body);
		case KAudio:
			return PAudio(body);
		case KMeta:
			return PMeta(body);
		case KCommand:
			var i = new neko.io.StringInput(body);
			var kind = i.readUInt16B();
			var sid = i.readUInt32B();
			var bsize = COMMAND_SIZES[kind];
			if( bsize != null && body.length != bsize + 6 )
				throw "Invalid command size ("+kind+","+body.length+")";
			var cmd = switch( kind ) {
			case 0:
				CClear;
			case 1:
				CPlay;
			case 3:
				CClientBuffer( i.readUInt32B() );
			case 4:
				CReset;
			case 6:
				CPing( i.readUInt32B() );
			default:
				if( body.length != 6 && body.length != 10 && body.length != 14 )
					throw "Invalid command size ("+kind+","+body.length+")";
				var a = if( body.length > 6 ) i.readUInt32B() else null;
				var b = if( body.length > 10 ) i.readUInt32B() else null;
				CUnknown(kind,a,b);
			};
			return PCommand(sid,cmd);
		case KShared:
			var so = SharedObject.read(new neko.io.StringInput(body));
			return PShared(so);
		case KUnknown(k):
			return PUnknown(k,body);
		case KChunkSize:
			read_chunk_size = new neko.io.StringInput(body).readUInt32B();
			return null;
		case KBytesReaded:
			return PBytesReaded(new neko.io.StringInput(body).readUInt32B());
		}
	}

	public function bodyLength( h : RtmpHeader, read : Bool ) {
		var chunk_size = if( read ) read_chunk_size else write_chunk_size;
		var s = channels[h.channel];
		if( s == null ) {
			if( h.size < chunk_size )
				return h.size;
			return chunk_size;
		} else {
			if( s.bytes < chunk_size )
				return s.bytes;
			return chunk_size;
		}
	}

	public function readPacket( h : RtmpHeader ) {
		var s = channels[h.channel];
		if( s == null ) {
			if( h.size <= read_chunk_size )
				return processBody(h,i.read(h.size));
			var buf = new StringBuf();
			buf.add(i.read(read_chunk_size));
			channels[h.channel] = { header : h, buffer : buf, bytes : h.size - read_chunk_size };
		} else {
			if( h.timestamp != s.header.timestamp )
				throw "Timestamp changing";
			if( h.src_dst != s.header.src_dst )
				throw "Src/dst changing";
			if( h.kind != s.header.kind )
				throw "Kind changing";
			if( h.size != s.header.size )
				throw "Size changing";
			if( s.bytes > read_chunk_size ) {
				s.buffer.add(i.read(read_chunk_size));
				s.bytes -= read_chunk_size;
			} else {
				s.buffer.add(i.read(s.bytes));
				channels[h.channel] = null;
				return processBody(s.header,s.buffer.toString());
			}
		}
		return null;
	}

	public function close() {
		if( i != null )
			i.close();
		if( o != null )
			o.close();
	}

}
