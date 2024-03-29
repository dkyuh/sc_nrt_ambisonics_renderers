//////////////////////////////////////////////////////////////////////////////////
//                                                                              //
// ----------------------- AMBISONICS BINAURAL RENDERER ----------------------- //
//                                                                              //
//                            B-Format --> Binaural                             //
//                                                                              //
//      Michele Samarotto & Daniel Höpfner - 2021 - @ IMWI HfM-Karlsruhe        //
//                                                                              //
//////////////////////////////////////////////////////////////////////////////////

(
Task({
	// args: input-path decoder=CIPIC output-path=./Binaural_YYYYMMDD_HHMMSS.wav
	var args = thisProcess.argv;

	if ((args.size >= 1) && (args.size < 4))
	{
		var
		filePath,
		soundFile, soundFileDuration,
		sampleRate, numChannels,
		whichDecoderMatrix, decoderMatrix,
		score, buffer, synth,
		outputPath;

		filePath = args[0];

		// number of arguments
		switch (args.size,
			1, { whichDecoderMatrix = "0"; outputPath = File.getcwd +/+ "Binaural_" ++ Date.getDate.format("%Y%m%d_%H%M%S") ++ ".wav"; },
			2, { whichDecoderMatrix = args[1]; outputPath = File.getcwd +/+ "Binaural_" ++ Date.getDate.format("%Y%m%d_%H%M%S") ++ ".wav"; },
			3, { whichDecoderMatrix = args[1]; outputPath = args[2]; }
		);

		// get sound file duration
		if (PathName(filePath).isFile) {
			if ((PathName(filePath).extension == "wav") || (PathName(filePath).extension == "aiff")) {
				try {
					soundFile = SoundFile.openRead(filePath);
					soundFile.close;
				}
				{ // catch
					arg error;
					if (error.species.name == 'DoesNotUnderstandError') {
						(filePath + "seems to be not readable!").postln;
						// error.throw;
						soundFile.close;
						0.exit;
						nil.yield;
					}
				};

				soundFileDuration = soundFile.duration;
				sampleRate = soundFile.sampleRate;
				numChannels = soundFile.numChannels;

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

					outputPath = PathName(outputPath);
					if (outputPath.pathOnly.isFolder &&
						((outputPath.extension == "wav") || (outputPath.extension == "aiff")))
					{

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

						// render score
						score.recordNRT(
							Platform.defaultTempDir ++ Date.getDate.format("%Y%m%d_%H%M%S"),
							outputPath.fullPath,
							options: ServerOptions.new.numOutputBusChannels_(2),
							action: { 0.exit; }
						);
					}
					{
						(outputPath.fullPath + "is not a valid output-audio-file-path!").postln;
						0.exit;
					}
				}
				{ // if not 4 channels
					(filePath + "does not have 4 channels!").postln;
					0.exit;
				}
			}
			{
				(filePath + "is not an audio file!").postln;
				0.exit;
			}
		}
		{ // if filePath is not a file
			(filePath + "is not a file!").postln;
			0.exit;
		}
	}
	{ // if more than one arguments
		"Wrong number of arguments!".postln;
		0.exit;
	};
	// ------------------------------------------------------------------------------<
}).start;
)