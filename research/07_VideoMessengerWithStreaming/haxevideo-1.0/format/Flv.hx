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

enum FLVChunk {
	FLVAudio( data : String, time : Int );
	FLVVideo( data : String, time : Int );
	FLVMeta( data : String, time : Int );
}

class Flv {

	public static function readHeader( ch : neko.io.Input ) {
		if( ch.read(3) != 'FLV' )
			throw "Invalid signature";
		if( ch.readChar() != 0x01 )
			throw "Invalid version";
		var flags = ch.readChar();
		if( flags & 0xF2 != 0 )
			throw "Invalid type flags "+flags;
		var offset = ch.readUInt32B();
		if( offset != 0x09 )
			throw "Invalid offset "+offset;
		var prev = ch.readUInt32B();
		if( prev != 0 )
			throw "Invalid prev "+prev;
		return {
			hasAudio : (flags & 1) != 1,
			hasVideo : (flags & 4) != 1,
			hasMeta : (flags & 8) != 1,
		};
	}

	public static function writeHeader( ch : neko.io.Output ) {
		ch.write("FLV");
		ch.writeChar(0x01);
		ch.writeChar(0x05);
		ch.writeUInt32B(0x09);
		ch.writeUInt32B(0x00);
	}

	public static function readChunk( ch : neko.io.Input ) {
		var k = try ch.readChar() catch( e : neko.io.Eof ) return null;
		var size = ch.readUInt24B();
		var time = ch.readUInt24B();
		var reserved = ch.readUInt32B();
		if( reserved != 0 )
			throw "Invalid reserved "+reserved;
		var data = ch.read(size);
		var size2 = ch.readUInt32B();
		if( size2 != 0 && size2 != size + 11 )
			throw "Invalid size2 ("+size+" != "+size2+")";
		return switch( k ) {
		case 0x08:
			FLVAudio(data,time);
		case 0x09:
			FLVVideo(data,time);
		case 0x12:
			FLVMeta(data,time);
		default:
			throw "Invalid FLV tag "+k;
		}
	}

	public static function writeChunk( ch : neko.io.Output, chunk : FLVChunk ) {
		var k, data, time;
		switch( chunk ) {
		case FLVAudio(d,t): k = 0x08; data = d; time = t;
		case FLVVideo(d,t): k = 0x09; data = d; time = t;
		case FLVMeta(d,t): k = 0x12; data = d; time = t;
		}
		ch.writeChar(k);
		ch.writeUInt24B(data.length);
		ch.writeUInt24B(time);
		ch.writeUInt32B(0);
		ch.write(data);
		ch.writeUInt32B(data.length + 11);
	}

	public static function isVideoKeyFrame( data : String ) {
		return (data.charCodeAt(0) >> 4) == 1;
	}

}