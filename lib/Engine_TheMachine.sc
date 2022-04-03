Engine_TheMachine : CroneEngine {
	classvar luaOscPort = 10111;

  var pitchFinderSynth, infoBus, quantizedVoice, harmonyVoices, pitchHandler;
  
	*new { arg context, doneCallback;
    	  
		^super.new(context, doneCallback);
	}
	  

  alloc {
  	var luaOscAddr = NetAddr("localhost", luaOscPort);

	  harmonyVoices = Dictionary.new;
	  
	  pitchHandler == OSCdef.new(\pitchHandler, { |msg, time|
			var pitch = msg[3].asFloat;

			luaOscAddr.sendMsg("/measuredPitch", pitch);
		}, '/tr');
		
		this.addCommand("acceptQuantizedPitch", "fff", { |msg|
			var pitch = msg[1].asFloat;
			var pull = msg[2].asFloat;
			var amp = msg[3].asFloat;
			if(quantizedVoice != nil, {
  			quantizedVoice.set(\targetHz, pitch, \pull, pull, \amp, amp);
  		});
		});
		
		this.addCommand("noteOn", "fffffi", { |msg|
			var pitch = msg[1].asFloat;
			var velocity = msg[2].asFloat;
			var delay = msg[3].asFloat;
			var vibratoAmount = msg[4].asFloat;
			var vibratoSpeed = msg[5].asFloat;
			var voice = msg[6].asInteger;
			if(harmonyVoices.includesKey(voice), {
  			harmonyVoices[voice].set(\targetHz, pitch);
  			harmonyVoices[voice].set(\amp, velocity);
  		}, {
  		  harmonyVoices[voice] = Synth(\grainVoice, [
  		    out: 0, 
  		    infoBus: infoBus, 
  		    targetHz: pitch, 
  		    amp: velocity, 
  		    timeDispersion: 0.01,
  		    delay: delay,
  		    vibratoAmount: vibratoAmount,
  		    vibratoSpeed: vibratoSpeed], addAction: \addAfter, target: pitchFinderSynth);
  		});
		});
		
		this.addCommand("noteOff", "i", { |msg|
		  var voice = msg[1].asInteger;
		  if(harmonyVoices.includesKey(voice), {
		    harmonyVoices[voice].set(\gate, 0);
		    harmonyVoices[voice] = nil;
		  });
		});
  
    Routine.new({
      infoBus = Bus.control(numChannels: 2);
      SynthDef(\follower, { |infoBus|
        var snd = Mix.ar(SoundIn.ar([0, 1]));
        var reference = LocalIn.kr(1);
        var info = Pitch.kr(snd);
        var midi = info[0].cpsmidi;
        var trigger = info[1]*((midi - reference).abs > 0.2);
        LocalOut.kr([Latch.kr(midi, trigger)]);
        SendTrig.kr(trigger, 0, info[0]);
        Out.kr(infoBus, info);
      
      }).add;
    
      SynthDef(\grainVoice, { |out, infoBus, targetHz, amp=1, delay=0, formantRatio=1, gate=1, vibratoAmt = 0, vibratoRate = 3, pull = 1|
        var info = DelayN.kr(In.kr(infoBus, 2), delay+0.01, delay);
        var env = Env.asr(0.2);
        var envUgen = EnvGen.kr(env, gate, doneAction: Done.freeSelf);        
        var snd = DelayN.ar(Mix.ar(SoundIn.ar([0, 1])), delay+0.01, delay);
        var adjustedTargetHz = (targetHz.cpsmidi + (envUgen * Amplitude.kr(snd)*vibratoAmt*SinOsc.kr(vibratoRate))).midicps;
        var ratio = (pull*info[1].if(adjustedTargetHz.lag(0.05)/info[0], 1)) + (1 - pull);

        ratio = Sanitize.kr(ratio, 1);
        Out.ar(out, amp.lag(0.1)*envUgen*PitchShiftPA.ar(snd, freq: info[0], pitchRatio: ratio)!2); 
      }).add;    
      
      Server.default.sync;
      // This runs the whole time.
      pitchFinderSynth = Synth(\follower, [infoBus: infoBus]);
      quantizedVoice = Synth(\grainVoice, [out: 0, infoBus: infoBus, targetHz: 180, timeDispersion: 0.01], addAction: \addAfter, target: pitchFinderSynth);
    }).play;
  }
  
  free {
    quantizedVoice.free;
    harmonyVoices.do { |v|
      v.free
    };    
    pitchFinderSynth.free;
    infoBus.free;
    pitchHandler.free;
  }
}