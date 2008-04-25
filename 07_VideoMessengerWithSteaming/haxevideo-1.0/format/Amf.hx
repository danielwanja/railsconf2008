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

enum AmfValue {
	ANumber( f : Float );
	ABool( b : Bool );
	AString( s : String );
	AObject( fields : Hash<AmfValue>, ?size : Int );
	ADate( d : Date );
	AUndefined;
	ANull;
}

class Amf {

	public static function readWithCode( i : neko.io.Input, id ) {
		return switch( id ) {
		case 0x00:
			ANumber( i.readDoubleB() );
		case 0x01:
			ABool(
				switch( i.readChar() ) {
				case 0: false;
				case 1: true;
				default: throw "Invalid AMF";
				}
			);
		case 0x02:
			AString( i.read(i.readUInt16B()) );
		case 0x03,0x08:
			var h = new Hash();
			var ismixed = (id == 0x08);
			var size = if( ismixed ) i.readUInt32B() else null;
			while( true ) {
				var c1 = i.readChar();
				var c2 = i.readChar();
				var name = i.read((c1 << 8) | c2);
				var k = i.readChar();
				if( k == 0x09 )
					break;
				h.set(name,readWithCode(i,k));
			}
			AObject(h,size);
		case 0x05:
			ANull;
		case 0x06:
			AUndefined;
		case 0x07:
			throw "Not supported : Reference";
		case 0x0B:
			var time_ms = i.readDoubleB();
			var tz_min = i.readUInt16B();
			ADate( Date.fromTime(time_ms + tz_min * 60 * 1000.0) );
		case 0x0C:
			AString( i.read(i.readUInt32B()) );
		default:
			throw "Unknown AMF "+id;
		}
	}

	public static function read( i : neko.io.Input ) {
		return readWithCode(i,i.readChar());
	}

	public static function write( o : neko.io.Output, v : AmfValue ) {
		switch( v ) {
		case ANumber(n):
			o.writeChar(0x00);
			o.writeDoubleB(n);
		case ABool(b):
			o.writeChar(0x01);
			o.writeChar(if( b ) 1 else 0);
		case AString(s):
			if( s.length <= 0xFFFF ) {
				o.writeChar(0x02);
				o.writeUInt16B(s.length);
			} else {
				o.writeChar(0x0C);
				o.writeUInt32B(s.length);
			}
			o.write(s);
		case AObject(h,size):
			if( size == null )
				o.writeChar(0x03);
			else {
				o.writeChar(0x08);
				o.writeUInt32B(size);
			}
			for( f in h.keys() ) {
				o.writeUInt16B(f.length);
				o.write(f);
				write(o,h.get(f));
			}
			o.writeChar(0);
			o.writeChar(0);
			o.writeChar(0x09);
		case ANull:
			o.writeChar(0x05);
		case AUndefined:
			o.writeChar(0x06);
		case ADate(d):
			o.writeDoubleB(d.getTime());
			o.writeUInt16B(0); // loose TZ
		}
	}

	public static function encode( o : Dynamic ) {
		return switch( Type.typeof(o) ) {
		case TNull: ANull;
		case TInt: ANumber(o);
		case TFloat: ANumber(o);
		case TBool: ABool(o);
		case TObject:
			var h = new Hash();
			for( f in Reflect.fields(o) )
				h.set(f,encode(Reflect.field(o,f)));
			AObject(h);
		case TClass(c):
			switch( c ) {
			case cast String:
				AString(o);
			case cast Hash:
				var o : Hash<Dynamic> = o;
				var h = new Hash();
				for( f in o.keys() )
					h.set(f,encode(o.get(f)));
				AObject(h);
			default:
				throw "Can't encode instance of "+Type.getClassName(c);
			}
		default:
			throw "Can't encode "+Std.string(o);
		}
	}

	public static function number( a : AmfValue ) {
		if( a == null ) return null;
		return switch( a ) {
		case ANumber(n): n;
		default: null;
		}
	}

	public static function string( a : AmfValue ) {
		if( a == null ) return null;
		return switch( a ) {
		case AString(s): s;
		default: null;
		}
	}

	public static function object( a : AmfValue ) {
		if( a == null ) return null;
		return switch( a ) {
		case AObject(o,_): o;
		default: null;
		}
	}

	public static function bool( a : AmfValue ) {
		if( a == null ) return null;
		return switch( a ) {
		case ABool(b): b;
		default: null;
		}
	}

}
