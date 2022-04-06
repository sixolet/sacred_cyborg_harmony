# Sacred Cyborg Harmony

@sixolet (eng) & @nonverbalpoetry (specifications)

Summon a choir of blessed part-human part-machine voices to sing with you.

Sacred Cyborg Harmony is an autotune and midi harmonization script for Norns.

## Getting Started

Install the script on Norns; restart Norns.

Connect a microphone to the input of Norns, and a MIDI keyboard or other polyphonic controller to USB. In the main menu screen us E1 to navigate to the mixer, and lower the monitor volume to 0, since you'll be monitoring through the script. Use headphones for cleaner input.

Now run the script. Open the Parameters menu. Set the `in range low` and `in range high` parameters to the furthest extents of your vocal range; this helps the pitch detection lock on to the right pitch. 

Set the scale and root to your favorite key, and close the parameters menu. Sing into the microphone. A line will radiate from the center of the screen to a circle representing the note you're singing, and a smaller line will indicate how accurately you're singing that note. If you sing a tune, note how your voice gets pulled to the nearest in-scale note.

Now sing a note, and as you're singing play a chord on your keyboard. Play more chords. Play along with your singing. Sing along with your playing. Enjoy.

The keys and encoders are currently unused by this script. There's only the script parameters and your lovely voice as inputs.

## Parameter Details

### Quantization

* `root` - the root of the scale.
* `scale` - the scale to use.
* `in range low` - the low end of pitches you expect. Setting it accurately makes the pitch detection more accurate and avoids artifacts.
* `in range high` - the high end of pitches you expect. Setting it accurately makes the pitch detection more accurate and avoids artifacts.

### Lead cyborg

* `quantize amount` - the amount to pull your pitch toward the detected scale note. 1 is "all the way" and 0 is "not at all".
* `amp` - amplitude of lead voice.
* `formants` - shift ratio for formants in the lead voice; > 1 goes toward chipmunking and < 1 goes toward... whatever the sound of a slowed down voice is.
* `acquisition speed` - speed at which to start tuning a voice when a pitch is detected. Set higher to leave transients relatively unaffected.
* `pan` - the Greek god of nature, the wild, shepherds, and music. Also which speaker you want the sound to come out of. Tip: Pan the lead left and the choir right (or vice versa) to multitrack them as different voices.

### Cyborg Choir

* `max random delay` - the maximum delay to apply to each note. Each note you play has a random delay chosen from 0 to this number; a small amount of random delay "humanizes" the choir a little. 
* `vibrato amount` - amount of vibrato to apply. This is relative to amplitude, and is the vibrato at maximum volume in half-steps. The louder you sing, the more the vibrato. 
* `vibrato speed` - speed of the sine wave vibrato.
* `amp` - amplitude of the choir.
* `formants @C3` - formant ratio to apply at the note C3. If `formant keytrack` is 0, then this is the formant ratio to apply throughout. 
* `formant keytrack` - amount to raise or lower the formants as we get higher or lower than C3. 0 keeps the formants constant across all pitches; positive values will raise the formants as you go up in pitch and vice versa; negative values will lower the formants as you go up in pitch. A value of 1 will match the timbre of a speed-manipulated recording. Values less than zero or greater than 1 are silly.
* `pan` - the speaker the sound should come out of.
* `sensitivity` - velocity sensitivity. 

## Thanks

The PSOLA pseudo-ugen this script uses was written by Marcin Pączkowski.