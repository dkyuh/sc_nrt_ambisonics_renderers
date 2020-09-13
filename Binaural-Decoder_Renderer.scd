//////////////////////////////////////////////////////////////////////////////////
//                                                                              //
// ----------------------- AMBISONICS BINAURAL RENDERER ----------------------- //
//                                                                              //
// B-Format --> Binaural                                                        //
//                                                                              //
// Michele Samarotto & Daniel Höpfner - 2020 - @ IMWI HfM-Karlsruhe             //
//                                                                              //
// For usage information see README                                             //
//                                                                              //
//////////////////////////////////////////////////////////////////////////////////

(
Task({
	// args: input-path decoder=CIPIC output-path=./Binaural_YYYYMMDD_HHMMSS.wav
	var args = thisProcess.argv;

	if ((args.size >= 1) && (args.size < 4))
	{
		var
		filePath, currentDirectory, currentDirectoryPath,
		soundFile, soundFileDuration,
		sampleRate, numChannels,
		whichDecoderMatrix, decoderMatrix,
		score, buffer, synth,
		outputPath;

		filePath = args[0];

		currentDirectory = thisProcess.nowExecutingPath.dirname;
		currentDirectoryPath = PathName(currentDirectory);

		switch (args.size,
			1, { whichDecoderMatrix = "0"; outputPath = currentDirectory +/+ "Binaural_" ++ Date.getDate.format("%Y%m%d_%H%M%S") ++ ".wav"; },
			2, { whichDecoderMatrix = args[1]; outputPath = currentDirectory +/+ "Binaural_" ++ Date.getDate.format("%Y%m%d_%H%M%S") ++ ".wav"; },
			3, { whichDecoderMatrix = args[1]; outputPath = args[2]; }
		);

		// get sound file duration
		if (PathName(filePath).isFile) {

			try {
				soundFile = SoundFile.openRead(filePath);
				soundFileDuration = soundFile.duration.postln;
				sampleRate = soundFile.sampleRate;
				numChannels = soundFile.numChannels;
				soundFile.close;
			}
			{ // catch
				arg error;
				if (error.species.name == 'DoesNotUnderstandError') {
					(filePath + "is not an audio file!").postln;
					// error.throw;
					0.exit;
					nil.yield;
				}
			};

			if (numChannels == 4) {
				// >------------------------------------------------------------------------------
				// define decoder matrix and render-synth

				score = Score.new;

				switch(whichDecoderMatrix,
					"0", { decoderMatrix = FoaDecoderKernel.newCIPIC(sampleRate: sampleRate, score: score); },
					"1", { decoderMatrix = FoaDecoderKernel.newSpherical(sampleRate: sampleRate, score: score); },
					"2", { decoderMatrix = FoaDecoderKernel.newSpherical(sampleRate: sampleRate, score: score); },
					{ (whichDecoderMatrix + "is not a valid decoder option").postln; 0.exit; nil.yield; }
				);

				// synth for binaural decoding
				SynthDef(\decode, { |buffer, out = 0|
					var input, snd;
					snd = PlayBuf.ar(4, buffer, BufRateScale.ir(buffer), doneAction: 2);
					snd = FoaDecode.ar(snd, decoderMatrix);
					OffsetOut.ar(0, snd);
				}).load(s);
				// ------------------------------------------------------------------------------<

				// >------------------------------------------------------------------------------
				// score construction and NRT (non realtime) rendering

				// add buffer to score
				buffer = Buffer.new(numChannels: 4);
				score.add([0, buffer.allocReadMsg(filePath);]);

				// add synth to score
				synth = Synth.basicNew(\decode);
				score.add([0.1, synth.newMsg(s, [buffer: buffer])]);

				// end of score
				score.add([soundFileDuration, 0]);
				score.sort;

				outputPath = PathName(outputPath);
				if (outputPath.pathOnly.isFolder &&
					((outputPath.extension == "wav") || (outputPath.extension == "aiff")))
				{
					// render score
					score.recordNRT(
						Platform.defaultTempDir ++ Date.getDate.format("%Y%m%d_%H%M%S"),
						outputPath.fullPath,
						options: ServerOptions.new.numOutputBusChannels_(2),
						action: { 0.exit; }
					);
				}
				{
					(outputPath.fullPath + "is not a valid path!").postln;
					0.exit;
					nil.yield;
				}
			}
			{ // if not 4 channels
				(filePath + "does not have 4 channels!").postln;
				0.exit;
				nil.yield;
			}
		}
		{ // if filePath is not a file
			(filePath + "is not a file!").postln;
			0.exit;
			nil.yield;
		}
	}
	{ // if more than one arguments
		"Wrong number of arguments!".postln;
		0.exit;
		nil.yield;
	};
	// ------------------------------------------------------------------------------<
}).start;
)



// Tests:
//
// sclang Binaural-Decoder_Renderer.scd
// --> Wrong number of arguments!
//
// sclang Binaural-Decoder_Renderer.scd 1 2 3 4
// --> Wrong number of arguments!
//
// sclang Binaural-Decoder_Renderer.scd ~/Downloads/atk-sounds/tralala
// --> /Users/danielhopfner/Downloads/atk-sounds/tralala is not a file!
//
// sclang Binaural-Decoder_Renderer.scd ~/Downloads/atk-sounds/LICENSE.md
// --> /Users/danielhopfner/Downloads/atk-sounds/LICENSE.md is not an audio file!
//
// sclang Binaural-Decoder_Renderer.scd ~/Downloads/atk-sounds/stereo/Aurora_Surgit-Dies_Irae.wav
// --> /Users/danielhopfner/Downloads/atk-sounds/stereo/Aurora_Surgit-Dies_Irae.wav does not have 4 channels!
//
// sclang Binaural-Decoder_Renderer.scd ~/Downloads/atk-sounds/b-format/Leonard-Orfeo_Trio.wav
// --> läuft
//
// sclang Binaural-Decoder_Renderer.scd ~/Downloads/atk-sounds/b-format/Leonard-Orfeo_Trio.wav 0
// --> läuft
//
// sclang Binaural-Decoder_Renderer.scd ~/Downloads/atk-sounds/b-format/Leonard-Orfeo_Trio.wav 1
// --> läuft
//
// sclang Binaural-Decoder_Renderer.scd ~/Downloads/atk-sounds/b-format/Leonard-Orfeo_Trio.wav 2
// --> läuft
//
// sclang Binaural-Decoder_Renderer.scd ~/Downloads/atk-sounds/b-format/Leonard-Orfeo_Trio.wav 200
// --> 200 is not a valid decoder option
//
// sclang Binaural-Decoder_Renderer.scd ~/Downloads/atk-sounds/b-format/Leonard-Orfeo_Trio.wav 2 ~/Dow
// --> /Users/danielhopfner/Dow is not a valid path!
//
// sclang Binaural-Decoder_Renderer.scd ~/Downloads/atk-sounds/b-format/Leonard-Orfeo_Trio.wav 2 ~/Dow/test.wav
// --> /Users/danielhopfner/Dow/test.wav is not a valid path!
//
// sclang Binaural-Decoder_Renderer.scd ~/Downloads/atk-sounds/b-format/Leonard-Orfeo_Trio.wav 2 ~/Downloads/
// --> /Users/danielhopfner/Downloads/ is not a valid path!
//
// sclang Binaural-Decoder_Renderer.scd ~/Downloads/atk-sounds/b-format/Leonard-Orfeo_Trio.wav 2 ~/Downloads/test.tralala
// --> /Users/danielhopfner/Downloads/test.tralala is not a valid path!
//
// sclang Binaural-Decoder_Renderer.scd ~/Downloads/atk-sounds/b-format/Leonard-Orfeo_Trio.wav 2 ~/Downloads/test.wav
// --> läuft
//
// sclang Binaural-Decoder_Renderer.scd ~/Downloads/atk-sounds/b-format/Leonard-Orfeo_Trio.wav 2 ~/Downloads/test.aiff
// --> läuft