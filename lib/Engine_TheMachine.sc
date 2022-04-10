Engine_TheMachine : CroneEngine {
	classvar luaOscPort = 10111;

  var pitchFinderSynth, infoBus, quantizedVoice, harmonyVoices, pitchHandler, leadBus, choirBus, endOfChainSynth;
  
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
		
		this.addCommand("setInputRange", "ff", { |msg|
		  var low = msg[1].asFloat;
		  var high = msg[2].asFloat;
		  Routine({
  		  if (pitchFinderSynth != nil, {
  		    "freeing pitch".postln;
    		  pitchFinderSynth.free;
  	  	  pitchFinderSynth = nil;
    		});
    		Server.sync;
    		"starting pitch".postln;
	  	  pitchFinderSynth = Synth(\follower, [out: choirBus, infoBus: infoBus, minFreq:low, maxFreq:high]);
	  	}).play;
		});
		
		this.addCommand("acceptQuantizedPitch", "ffffffffff", { |msg|
			var pitch = msg[1].asFloat;
			var pull = msg[2].asFloat;
			var amp = msg[3].asFloat;
			var formantRatio = msg[4].asFloat;
			var acquisition = msg[5].asFloat;
			var pan = msg[6].asFloat;
			var voicechan = msg[7].asFloat;
			var passchan = msg[8].asFloat;
			var passamp = msg[9].asFloat;
			var passpan = msg[10].asFloat;
			pitchFinderSynth.set(\voicechan,voicechan);
			if(quantizedVoice != nil, {
  			quantizedVoice.set(\targetHz, pitch, \pull, pull, \amp, amp, \formantRatio, formantRatio, \acquisition, acquisition, \pan, pan,
  				\voicechan,voicechan,\passchan,passchan,\passamp,passamp,\passpan,passpan);
  		});
		});
		
		this.addCommand("noteOn", "fffffffiffff", { |msg|
			var pitch = msg[1].asFloat;
			var velocity = msg[2].asFloat;
			var delay = msg[3].asFloat;
			var vibratoAmount = msg[4].asFloat;
			var vibratoSpeed = msg[5].asFloat;
			var formantRatio = msg[6].asFloat;
			var pan = msg[7].asFloat;
			var voice = msg[8].asInteger;
			var voicechan = msg[9].asFloat;
			var passchan = msg[10].asFloat;
			var passamp = msg[11].asFloat;
			var passpan = msg[12].asFloat;
			pitchFinderSynth.set(\voicechan,voicechan);
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
  		    pan: pan,
  		    voicechan: voicechan,
  		    passchan: passchan,
  		    passamp: passamp,
  		    passpan: passpan,
  		    vibratoAmount: vibratoAmount,
  		    vibratoSpeed: vibratoSpeed,
  		    formantRatio: formantRatio], addAction: \addAfter, target: pitchFinderSynth);
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
      leadBus = Bus.audio(numChannels: 2);
      choirBus = Bus.audio(numChannels: 2);
      
      SynthDef(\endOfChain, { 
        Out.ar(0, (In.ar(leadBus, numChannels: 2) + In.ar(choirBus, numChannels: 2)).softclip);      
      }).add;
      
      SynthDef(\follower, { |infoBus, minFreq=82, maxFreq=1046, voicechan=0|
				var snd = SelectX.ar(LinLin.kr(voicechan,-1,1,0,1),[SoundIn.ar(0),SoundIn.ar(1)]);
        var reference = LocalIn.kr(1);
        var info = Pitch.kr(snd, minFreq: minFreq, maxFreq: maxFreq);
        var midi = info[0].cpsmidi;
        var trigger = info[1]*((midi - reference).abs > 0.2);
        LocalOut.kr([Latch.kr(midi, trigger)]);
        SendTrig.kr(trigger, 0, info[0]);
        Out.kr(infoBus, info);
      }).add;
    
      SynthDef(\grainVoice, { |out, infoBus, targetHz, amp=1, delay=0, formantRatio=1, gate=1, vibratoAmount = 0, 
                               vibratoSpeed = 3, pull = 1, timeDispersion = 0.01, acquisition = 0.1, pan = 0, voicechan=0, passchan=0, passamp=0, passpan=0|
        var info = DelayN.kr(In.kr(infoBus, 2), delay+0.01, delay);
        var env = Env.asr(0.2);
        var envUgen = EnvGen.kr(env, gate, doneAction: Done.freeSelf);        
				var sndin = SoundIn.ar([0,1]);
				var sndvoice = SelectX.ar(LinLin.kr(voicechan,-1,1,0,1),sndin);
				var sndpass = SelectX.ar(LinLin.kr(passchan,-1,1,0,1),sndin);
        var snd = DelayN.ar(sndvoice, delay+0.01, delay);
        var adjustedTargetHz = (targetHz.cpsmidi.lag(0.05) + (envUgen * Amplitude.kr(snd)*vibratoAmount*SinOsc.kr(vibratoSpeed))).midicps;
        var ratio = (pull*info[1].lag(acquisition).if(adjustedTargetHz/info[0], 1)) + (1 - pull);
        var shiftedSound, pannedSound;
        
        ratio = Sanitize.kr(ratio, 1);
        shiftedSound = amp.lag(0.1)*envUgen*PitchShiftPA.ar(snd, freq: info[0], pitchRatio: ratio, formantRatio: formantRatio, timeDispersion: timeDispersion);
        pannedSound = Pan2.ar(shiftedSound, pan);
        Out.ar(out, Pan2.ar(sndpass*passamp,passpan));
        Out.ar(out, pannedSound); 
      }).add;    
      
      Server.default.sync;
      // This runs the whole time.
      pitchFinderSynth = Synth(\follower, [infoBus: infoBus]);
      quantizedVoice = Synth(\grainVoice, [out: leadBus, infoBus: infoBus, targetHz: 180, timeDispersion: 0.01], addAction: \addAfter, target: pitchFinderSynth);
      endOfChainSynth = Synth(\endOfChain, addAction: \addToTail);
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
    endOfChainSynth.free;
    choirBus.free;
    leadBus.free;
  }
}
