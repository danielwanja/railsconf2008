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

import format.Amf;
import format.Flv;
import format.Rtmp;
import hxvid.Commands;

typedef CommandInfos = {
	var id : Int;
	var h : RtmpHeader;
	var p : RtmpPacket;
}

typedef RtmpMessage = {
	header : RtmpHeader,
	packet : RtmpPacket
}

typedef RtmpStream = {
	var id : Int;
	var channel : Int;
	var audio : Bool;
	var video : Bool;
	var cache : List<{ data : RtmpPacket, time : Int }>;
	var play : {
		var file : String;
		var flv : neko.io.Input;
		var startTime : Float;
		var curTime : Int;
		var blocked : Null<Float>;
		var paused : Null<Float>;
	};
	var record : {
		var file : String;
		var startTime : Float;
		var flv : neko.io.Output;
		var shareName : String;
		var listeners : List<RtmpStream>;
		var bytes : Int;
		var lastPing : Int;
	};
	var shared : {
		var lock : neko.vm.Lock;
		var stream : RtmpStream;
		var client : Client;
		var paused : Null<Float>;
	};
}

enum ClientState {
	WaitHandshake;
	WaitHandshakeResponse( hs : String );
	Ready;
	WaitBody( h : RtmpHeader, blen : Int );
}

class Client {

	static var file_security = ~/^[A-Za-z0-9_-][A-Za-z0-9_\/-]*(\.flv)?$/;
	static var globalLock = {
		var l = new neko.vm.Lock();
		l.release();
		l;
	}
	static var sharedStreams = new Hash<RtmpStream>();

	public var socket : neko.net.Socket;
	var server : Server;
	var rtmp : Rtmp;
	var state : ClientState;
	var streams : Array<RtmpStream>;
	var dir : String;
	var commands : Commands<CommandInfos>;

	public function new( serv, s ) {
		server = serv;
		socket = s;
		dir = Server.BASE_DIR;
		state = WaitHandshake;
		streams = new Array();
		rtmp = new Rtmp(null,socket.output);
		commands = new Commands();
		initializeCommands();
	}

	function initializeCommands() {
		commands.add1("connect",cmdConnect,T.Object);
		commands.add1("createStream",cmdCreateStream,T.Null);
		commands.add2("play",cmdPlay,T.Null,T.String);
		commands.add2("deleteStream",cmdDeleteStream,T.Null,T.Int);
		commands.add3("publish",cmdPublish,T.Null,T.String,T.Opt(T.String));
		commands.add3("pause",cmdPause,T.Null,T.Opt(T.Bool),T.Int);
		commands.add2("receiveAudio",cmdReceiveAudio,T.Null,T.Bool);
		commands.add2("receiveVideo",cmdReceiveVideo,T.Null,T.Bool);
		commands.add1("closeStream",cmdCloseStream,T.Null);
		commands.add2("seek",cmdSeek,T.Null,T.Int);
	}

	function addData( h : RtmpHeader, data : String, kind, p ) {
		var s = streams[h.src_dst];
		if( s == null )
			throw "Unknown stream "+h.src_dst;
		var r = s.record;
		if( r == null )
			throw "Publish not done on stream "+h.src_dst;
		var time = Std.int((neko.Sys.time() - r.startTime) * 1000);
		var chunk = kind(data,time);
		Flv.writeChunk(r.flv,chunk);
		r.bytes += data.length;
		if( r.bytes - r.lastPing > 100000 ) {
			rtmp.send(2,PBytesReaded(r.bytes));
			r.lastPing = r.bytes;
		}
		for( s in r.listeners ) {
			s.shared.lock.wait();
			if( s.shared.paused == null ) {
				if( s.cache == null ) {
					s.cache = new List();
					server.wakeUp(s.shared.client.socket,0);
				}
				s.cache.add({ data : p, time : time });
			}
			s.shared.lock.release();
		}
	}

	function error( i : CommandInfos, msg : String ) {
		rtmp.send(i.h.channel,PCall("onStatus",0,[
			ANull,
			Amf.encode({
				level : "error",
				code : "NetStream.Error",
				details : msg,
			})
		]),null,i.h.src_dst);
		throw "ERROR "+msg;
	}

	function securize( i, file : String ) {
		if( !file_security.match(file) )
			error(i,"Invalid file name "+file);
		if( file.indexOf(".") == -1 )
			file += ".flv";
		return dir + file;
	}

	function getStream( i : CommandInfos, ?play : Bool ) {
		var s = streams[i.h.src_dst];
		if( s == null || (play && s.play == null) )
			error(i,"Invalid stream id "+i.h.src_dst);
		return s;
	}

	function openFLV( file ) : neko.io.Input {
		var flv;
		try {
			flv = neko.io.File.read(file,true);
			Flv.readHeader(flv);
		} catch( e : Dynamic ) {
			if( flv != null ) {
				flv.close();
				neko.Lib.rethrow("Corrupted FLV File '"+file+"' ("+Std.string(e)+")");
			}
			throw "FLV file not found '"+file+"'";
		}
		return flv;
	}

	function cmdConnect( i : CommandInfos, obj : Hash<AmfValue> ) {
		var app;
		if( (app = Amf.string(obj.get("app"))) == null )
			error(i,"Invalid 'connect' parameters");
		if( app != "" && !file_security.match(app) )
			error(i,"Invalid application path");
		dir = dir + app;
		if( dir.charAt(dir.length-1) != "/" )
			dir = dir + "/";
		rtmp.send(i.h.channel,PCall("_result",i.id,[
			ANull,
			Amf.encode({
				level : "status",
				code : "NetConnection.Connect.Success",
				description : "Connection succeeded."
			})
		]));
	}

	function cmdCreateStream( i : CommandInfos, _ : Void ) {
		var s = allocStream();
		rtmp.send(i.h.channel,PCall("_result",i.id,[
			ANull,
			ANumber(s.id)
		]));
	}

	function sendStatus( s : RtmpStream, status : String, infos : Dynamic ) {
		infos.code = status;
		infos.level = "status";
		rtmp.send(s.channel,PCall("onStatus",0,[ANull,Amf.encode(infos)]),null,s.id);
	}

	function cmdPlay( i : CommandInfos, _ : Void, file : String ) {
		var s = streams[i.h.src_dst];
		if( s == null )
			error(i,"Unknown 'play' channel");
		if( s.play != null )
			error(i,"This channel is already playing a FLV");
		s.channel = i.h.channel;
		if( file.charAt(0) == '#' ) {
			file = file.substr(1);
			globalLock.wait();
			var sh = sharedStreams.get(file);
			if( sh == null ) {
				globalLock.release();
				error(i,"Unknown shared stream '"+file+"'");
			}
			s.shared = {
				lock : new neko.vm.Lock(),
				client : this,
				stream : sh,
				paused : null,
			};
			s.shared.lock.release();
			sh.record.listeners.add(s);
			globalLock.release();
		} else {
			file = securize(i,file);
			s.play = {
				file : file,
				flv : null,
				startTime : null,
				curTime : 0,
				blocked : null,
				paused : null,
			};
		}
		seek(s,0);
		sendStatus(s,"NetStream.Play.Reset",{
			description : "Resetting "+file+".",
			details : file,
			clientId : s.id
		});
		sendStatus(s,"NetStream.Play.Start",{
			description : "Start playing "+file+".",
			clientId : s.id
		});
	}

	function cmdDeleteStream( i : CommandInfos, _ : Void, stream : Int ) {
		var s = streams[stream];
		if( s == null )
			error(i,"Invalid 'deleteStream' streamid");
		closeStream(s);
	}

	function cmdPublish( i : CommandInfos, _ : Void, file : String, shareName : String ) {
		var s = streams[i.h.src_dst];
		if( s == null || s.record != null )
			error(i,"Invalid 'publish' streamid'");
		file = securize(i,file);
		var flv : neko.io.Output = neko.io.File.write(file,true);
		Flv.writeHeader(flv);
		s.channel = i.h.channel;
		s.record = {
			file : file,
			startTime : neko.Sys.time(),
			flv : flv,
			shareName : null,
			listeners : new List(),
			bytes : 0,
			lastPing : 0,
		};
		if( shareName != null ) {
			globalLock.wait();
			if( sharedStreams.exists(shareName) ) {
				globalLock.release();
				error(i,"The stream '"+shareName+"' is already shared by another user");
			}
			sharedStreams.set(shareName,s);
			s.record.shareName = shareName;
			globalLock.release();
		}
		sendStatus(s,"NetStream.Publish.Start",{ details : file });
	}

	function cmdPause( i : CommandInfos, _ : Void, ?pause : Bool, time : Int ) {
		var s = getStream(i);
		var p : { paused : Null<Float> } = s.play;
		if( p == null )
			p = s.shared;
		if( p == null )
			return;
		if( pause == null )
			pause = (p.paused == null); // toggle
		if( pause ) {
			if( p.paused == null )
				p.paused = neko.Sys.time();
			rtmp.send(2,PCommand(s.id,CPlay));
		} else {
			if( p.paused != null ) {
				p.paused = null;
				seek(s,time);
			}
		}
		rtmp.send(i.h.channel,PCall("_result",i.id,[
			ANull,
			Amf.encode({
				level : "status",
				code : if( pause ) "NetStream.Pause.Notify" else "NetStream.Unpause.Notify",
			})
		]));
	}

	function cmdReceiveAudio( i : CommandInfos, _ : Void, flag : Bool ) {
		var s = getStream(i);
		s.audio = flag;
	}

	function cmdReceiveVideo( i : CommandInfos, _ : Void, flag : Bool ) {
		var s = getStream(i);
		s.video = flag;
	}

	function cmdCloseStream( i : CommandInfos, _ : Void ) {
		var s = getStream(i);
		closeStream(s);
	}

	function cmdSeek( i : CommandInfos, _ : Void, time : Int ) {
		var s = getStream(i,true);
		seek(s,time);
		rtmp.send(s.channel,PCall("_result",0,[
			ANull,
			Amf.encode({
				level : "status",
				code : "NetStream.Seek.Notify",
			})
		]),null,s.id);
		sendStatus(s,"NetStream.Play.Start",{
			time : time
		});
	}

	public function processPacket( h : RtmpHeader, p : RtmpPacket ) {
		switch( p ) {
		case PCall(cmd,iid,args):
			if( !commands.has(cmd) )
				throw "Unknown command "+cmd+"("+args.join(",")+")";
			var infos = {
				id : iid,
				h : h,
				p : p,
			};
			if( !commands.execute(cmd,infos,args) )
				throw "Mismatch arguments for '"+cmd+"' : "+Std.string(args);
		case PAudio(data):
			addData(h,data,FLVAudio,p);
		case PVideo(data):
			addData(h,data,FLVVideo,p);
		case PMeta(data):
			addData(h,data,FLVMeta,p);
		case PCommand(sid,cmd):
			trace("COMMAND "+Std.string(cmd)+":"+sid);
		case PBytesReaded(b):
			//trace("BYTESREADED "+b);
		case PShared(so):
			trace("SHARED OBJECT "+Std.string(so));
		case PUnknown(k,data):
			trace("UNKNOWN "+k+" ["+data.length+"bytes]");
		}
	}

	function allocStream() {
		var ids = new Array();
		for( s in streams )
			if( s != null )
				ids[s.id] = true;
		var id = 1;
		while( id < ids.length ) {
			if( ids[id] == null )
				break;
			id++;
		}
		var s = {
			id : id,
			channel : null,
			play : null,
			record : null,
			audio : true,
			video : true,
			shared : null,
			cache : null,
		};
		streams[s.id] = s;
		return s;
	}

	function closeStream( s : RtmpStream ) {
		if( s.play != null && s.play.flv != null )
			s.play.flv.close();
		if( s.record != null ) {
			if( s.record.shareName != null ) {
				globalLock.wait();
				sharedStreams.remove(s.record.shareName);
				globalLock.release();
			}
			s.record.flv.close();
		}
		if( s.shared != null ) {
			globalLock.wait();
			// on more check in case our shared stream just closed
			if( s.shared != null )
				s.shared.stream.record.listeners.remove(s);
			globalLock.release();
		}
		streams[s.id] = null;
	}

	function seek( s : RtmpStream, seekTime : Int ) {
		// clear
		rtmp.send(2,PCommand(s.id,CPlay));
		rtmp.send(2,PCommand(s.id,CReset));
		rtmp.send(2,PCommand(s.id,CClear));

		// no need to send more data for shared streams
		if( s.shared != null )
			return;

		// reset infos
		var p = s.play;
		var now = neko.Sys.time();
		p.startTime = now - Server.FLV_BUFFER_TIME - seekTime / 1000;
		if( p.paused != null )
			p.paused = now;
		p.blocked = null;
		if( p.flv != null )
			p.flv.close();
		p.flv = openFLV(p.file);
		s.cache = new List();

		// prepare to send first audio + video chunk (with null timestamp)
        var audio = s.audio;
        var video = s.video;
		var audioCache = null;
		var metaCache = null;
		while( true ) {
			var c = Flv.readChunk(s.play.flv);
			if( c == null )
				break;
			switch( c ) {
			case FLVAudio(data,time):
				if( time < seekTime )
					continue;
				audioCache = { data : PAudio(data), time : time };
				if( !audio )
					break;
				audio = false;
			case FLVVideo(data,time):
				var keyframe = Flv.isVideoKeyFrame(data);
				if( keyframe )
					s.cache = new List();
				if( s.video )
					s.cache.add({ data : PVideo(data), time : time });
				if( time < seekTime )
					continue;
				if( !video )
					break;
				video = false;
			case FLVMeta(data,time):
				if( time < seekTime )
					continue;
				if( metaCache != null )
					s.cache.add(metaCache);
				metaCache = { data : PMeta(data), time : time };
				if( seekTime != 0 ) {
					s.cache.add(metaCache);
					metaCache = null;
				}
			}
			if( !audio && !video )
				break;
		}
		if( s.audio && audioCache != null )
			s.cache.push(audioCache);
		if( seekTime == 0 && metaCache != null )
			s.cache.push(metaCache);
	}

	function playShared( s : RtmpStream ) {
		s.shared.lock.wait();
		try {
			if( s.cache != null )
				while( true ) {
					var f = s.cache.pop();
					if( f == null ) {
						s.cache = null;
						break;
					}
					rtmp.send(s.channel,f.data,f.time,s.id);
					if( server.isBlocking(socket) )
						break;
				}
		} catch( e : Dynamic ) {
			s.shared.lock.release();
			neko.Lib.rethrow(e);
		}
		s.shared.lock.release();
	}

	function playFLV( t : Float, s : RtmpStream ) {
		var p = s.play;
		if( p.paused != null )
			return;
		if( p.blocked != null ) {
			var delta = t - p.blocked;
			p.startTime += delta;
			p.blocked = null;
		}
		if( s.cache != null ) {
			while( true ) {
				var f = s.cache.pop();
				if( f == null ) {
					s.cache = null;
					break;
				}
				rtmp.send(s.channel,f.data,f.time,s.id);
				p.curTime = f.time;
				if( server.isBlocking(socket) ) {
					p.blocked = t;
					return;
				}
			}
		}
		var reltime = Std.int((t - p.startTime) * 1000);
		while( reltime > p.curTime ) {
			var c = Flv.readChunk(p.flv);
			if( c == null ) {
				p.flv.close();
				s.play = null;
/*				// this will abort the video before the end
 				sendStatus(s,"NetStream.Play.Stop",{ details : p.file });
				rtmp.send(2,PCommand(s.id,CClear));
				rtmp.send(2,PCommand(s.id,CReset));
*/				return;
			}
			switch( c ) {
			case FLVAudio(data,time):
				if( s.audio )
					rtmp.send(s.channel,PAudio(data),time,s.id);
				p.curTime = time;
			case FLVVideo(data,time):
				if( s.video )
					rtmp.send(s.channel,PVideo(data),time,s.id);
				p.curTime = time;
			case FLVMeta(data,time):
				rtmp.send(s.channel,PMeta(data),time,s.id);
				p.curTime = time;
			}
			if( server.isBlocking(socket) ) {
				p.blocked = t;
				return;
			}
		}
		server.wakeUp( socket, Server.FLV_BUFFER_TIME / 2 );
	}

	public function updateTime( t : Float ) {
		for( s in streams )
			if( s != null ) {
				if( s.play != null )
					playFLV(t,s);
				else if( s.shared != null )
					playShared(s);
			}
	}

	public function cleanup() {
		for( s in streams )
			if( s != null )
				closeStream(s);
		streams = new Array();
	}

	public function readProgressive( buf, pos, len ) {
		switch( state ) {
		case WaitHandshake:
			if( len < Rtmp.HANDSHAKE_SIZE + 1 )
				return null;
			rtmp.i = new neko.io.StringInput(buf,pos,len);
			rtmp.readWelcome();
			var hs = rtmp.readHandshake();
			rtmp.writeWelcome();
			rtmp.writeHandshake(hs);
			state = WaitHandshakeResponse(hs);
			return { msg : null, bytes : Rtmp.HANDSHAKE_SIZE + 1 };
		case WaitHandshakeResponse(hs):
			if( len < Rtmp.HANDSHAKE_SIZE )
				return null;
			rtmp.i = new neko.io.StringInput(buf,pos,len);
			var hs2 = rtmp.readHandshake();
			if( hs != hs2 )
				throw "Invalid Handshake";
			rtmp.writeHandshake(hs);
			state = Ready;
			return { msg : null, bytes : Rtmp.HANDSHAKE_SIZE };
		case Ready:
			var hsize = rtmp.getHeaderSize(buf.charCodeAt(pos));
			if( len < hsize )
				return null;
			rtmp.i = new neko.io.StringInput(buf,pos,len);
			var h = rtmp.readHeader();
			state = WaitBody(h,rtmp.bodyLength(h,true));
			return { msg : null, bytes : hsize };
		case WaitBody(h,blen):
			if( len < blen )
				return null;
			rtmp.i = new neko.io.StringInput(buf,pos,len);
			var p = rtmp.readPacket(h);
			var msg = if( p != null ) { header : h, packet : p } else null;
			state = Ready;
			return { msg : msg, bytes : blen };
		}
		return null;
	}
}
