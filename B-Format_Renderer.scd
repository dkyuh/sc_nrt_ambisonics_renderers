//////////////////////////////////////////////////////////////////////////////////
//                                                                              //
// ----------------------- AMBISONICS B-FORMAT RENDERER ----------------------- //
//                                                                              //
// Discrete Channels --> B-Format                                               //
//                                                                              //
// Michele Samarotto & Daniel Höpfner - May 2018 - @ IMWI HfM-Karlsruhe         //
//                                                                              //
// for usage information see README                                             //
//                                                                              //
//////////////////////////////////////////////////////////////////////////////////

// channel number (uebereinstimmung in xml)
(
Task({
	// args: input-path xml-path amp-scale=1/chan_num out-path=./B-Format_YYYYMMDD_HHMMSS.wav
	var args = thisProcess.argv;

	if ((args.size >= 2) && (args.size < 5))
	{
		var
		filePath, xmlPath,
		extensions, inputFiles,

		ampScale,

		numChannels, sampleRate,

		document, speakerPosXMLFile, xmlString, speakerList,
		soundFile, soundFileDuration,
		score,
		buffers, synth,
		encoderMatrix, decoderMatrix,
		outputPath;

		filePath = args[0];

		xmlPath = args[1];

		if (PathName(filePath).isFolder) {

			extensions = ["wav", "aiff"];

			inputFiles = [];

			extensions.do{
				arg extension;

				inputFiles = inputFiles ++ (filePath +/+ "*." ++ extension).pathMatch;
			};

			if (inputFiles.size > 0) {

				inputFiles.do{
					arg inputFile, index;
					try {
						soundFile = SoundFile.openRead(inputFile);
						soundFileDuration = soundFile.duration;
						sampleRate = soundFile.sampleRate;
						numChannels = soundFile.numChannels;
						soundFile.close;

						if (numChannels > 1) {
							(inputFile + "is not a mono-file!").postln;
							0.exit;
							nil.yield;
						};
					}
					{ // catch
						arg error;
						if (error.species.name == 'DoesNotUnderstandError') {
							// (filePath + "is not an audio file!").postln;
							("couldn't open").postln;
							// error.throw;
							0.exit;
							nil.yield;
						};
					};
				};

				xmlPath = PathName(xmlPath);
				if (xmlPath.isFile;) {

					if (xmlPath.extension == "xml") {
						document = DOMDocument.new;
						speakerPosXMLFile = File(xmlPath.fullPath, "rb+");
						xmlString = String.readNew(speakerPosXMLFile);
						speakerPosXMLFile.close;
						document.parseXML(xmlString);

						try {
							speakerList = List.newClear(document.getDocumentElement.getElementsByTagName("Speaker").size);
						}
						{
							arg error;
							if (error.species.name == 'DoesNotUnderstandError') {
								(xmlPath.fullPath + "seems to be a corrupt XML-file!").postln;
								// error.throw;
								0.exit;
								nil.yield;
							}
						};

						if (inputFiles.size == speakerList.size) {
							document.getDocumentElement.getElementsByTagName("Speaker").do{
								|tag, index|
								var x, y, z, azi, ele, dist;

								x = tag.getAttribute("x").asFloat;
								y = tag.getAttribute("y").asFloat;
								z = tag.getAttribute("z").asFloat;

								dist = sqrt((x * x) + (y * y) + (z * z));

								// ele = acos(z / dist).raddeg;
								ele = asin(z / dist).raddeg;

								azi = atan2(y, x).raddeg; // mathematically correct (azi = 0 right)

								// rotate for spat-standart (azi = 0 front)
								azi = azi - 90.0;
								if (azi < -180) { azi = azi % 180 };

								// ([azi, ele]).postln;

								speakerList[tag.getAttribute("lsNo").asInteger] = [azi, ele]; // [  [ speaker-number, azimuth, elevation ], ...  ]
							};

							// args: input-path xml-path amp-scale=1/chan_num out-path=./B-Format_YYYYMMDD_HHMMSS.wav
							switch (args.size,
								2, {
									ampScale = 1 / speakerList.size;
									outputPath = File.getcwd +/+ "B-format_" ++ Date.getDate.format("%Y%m%d_%H%M%S") ++ ".wav";
								},
								3, {
									ampScale = args[2];
									outputPath = File.getcwd +/+ "B-format_" ++ Date.getDate.format("%Y%m%d_%H%M%S") ++ ".wav";
								},
								4, {
									ampScale = args[2];
									outputPath = args[3];
								}
							);

							// is amp-scale a number?
							if ((ampScale > 0) && (ampScale <= 1)) {
								// does outpath exist?
								outputPath = PathName(outputPath);
								if (outputPath.pathOnly.isFolder &&
									((outputPath.extension == "wav") || (outputPath.extension == "aiff")))
								{
									// >------------------------------------------------------------------------------
									// define render-synths and en-/decoder matrices

									SynthDef(\playback, {
										|buffer, out = 0|
										var snd;
										snd = PlayBuf.ar(1, buffer, BufRateScale.ir(buffer), doneAction: 2);
										OffsetOut.ar(out, snd);
									}).load(s);

									encoderMatrix = FoaEncoderMatrix.newDirections(speakerList.degrad); // discrete channels --> b-format
									decoderMatrix = FoaDecoderMatrix.newHoa1(normalisation: 'sn3d'); // b-format --> b-format (acn, sn3d)

									SynthDef(\encode, {
										var input, snd;
										input = In.ar((0..(speakerList.size - 1)) + 100);
										snd = FoaEncode.ar(input, encoderMatrix);
										// snd = FoaDecode.ar(snd, decoderMatrix);
										OffsetOut.ar(0, snd);
									}).load(s);
									// ------------------------------------------------------------------------------<

									// >------------------------------------------------------------------------------
									// score construction and NRT (non realtime) rendering

									score = Score.new;
									buffers = List.newClear;

									// load buffers and play discrete channel audio
									inputFiles.do{ |path, index|

										// load buffers
										buffers.add(Buffer.new);
										score.add([0, buffers[index].allocReadMsg(path);]);

										// synths for discrete channel audio playback
										synth = Synth.basicNew(\playback);
										score.add([0.1, synth.newMsg(s, [buffer: buffers[index], out: index + 100])]);

									};

									// synth for encoding all discrete channels
									synth = Synth.basicNew(\encode);
									score.add([0.1, synth.newMsg(s, addAction: 'addToTail')]);

									// end of score
									score.add([soundFileDuration, 0]);
									score.sort;

									// render score
									score.recordNRT(
										"/tmp/osc_nrt_" ++ Date.getDate.format("%Y%m%d_%H%M%S"),
										outputPath.fullPath,
										options: ServerOptions.new.numOutputBusChannels_(4),
										action: { 0.exit; }
									);
									// ------------------------------------------------------------------------------<*/
								}
								{
									(outputPath.fullPath + "is not a valid output-audio-file-path!").postln;
									0.exit;
								}
							}
							{
								("your amplitude-scaling (" ++ ampScale ++ ") must be a number > zero and <= 1!").postln;
								0.exit;
							}

						}
						{
							("number of audio-files (" ++ inputFiles.size ++ ") and number of speakers from XML-file (" ++ speakerList.size ++ ") does not match!").postln;
							0.exit;
						}
					}
					{
						(xmlPath.fullPath + "is not an XML-file!").postln;
						0.exit;
					}
				}
				{
					(xmlPath.fullPath + "is not a valid file!").postln;
					0.exit;
				}

			}
			{// if input files are not aiff or wav:
				("There are no 'aiff' or 'wav' files in" + filePath ++ "!").postln;
				0.exit;
			};
		}
		{ // if filePath is not a folder
			(filePath + "is not a valid path to a folder!").postln;
			0.exit;
		}


		/*switch (args.size,
			2, {},
			3, {},
		);

		// create render folder
		if ((currentDirectory +/+ "render").pathMatch[0].isNil) { ("mkdir " ++ currentDirectory +/+ "render").unixCmd };

		// get sound file duration
		soundFile = SoundFile.openRead((currentDirectory +/+ "*.wav").pathMatch[0]);
		soundFileDuration = soundFile.duration;
		soundFile.close;

		// >------------------------------------------------------------------------------
		// load xml-file, read speaker positions and transform into spherical coordinates

		document = DOMDocument.new;
		speakerPosXMLFile = File((currentDirectory +/+ "*.xml").pathMatch[0], "rb+");
		xmlString = String.readNew(speakerPosXMLFile);
		document.parseXML(xmlString);


		speakerList = List.newClear(document.getDocumentElement.getElementsByTagName("Speaker").size);

		document.getDocumentElement.getElementsByTagName("Speaker").do{
			|tag, index|
			var x, y, z, azi, ele, dist;

			x = tag.getAttribute("x").asFloat;
			y = tag.getAttribute("y").asFloat;
			z = tag.getAttribute("z").asFloat;

			dist = sqrt((x * x) + (y * y) + (z * z));

			ele = acos(z / dist).raddeg;

			azi = atan2(y, x).raddeg; // mathematically correct (azi = 0 right)

			// rotate for spat-standart (azi = 0 front)
			azi = azi - 90.0;
			if (azi < -180) { azi = azi % 180 };

			speakerList[tag.getAttribute("lsNo").asInteger - 1] = [azi, ele]; // [  [ speaker-number, azimuth, elevation ], ...  ]
		};
		// ------------------------------------------------------------------------------<

		// >------------------------------------------------------------------------------
		// define render-synths and en-/decoder matrices

		SynthDef(\playback, {
			|buffer, out = 0|
			var snd;
			snd = PlayBuf.ar(1, buffer, BufRateScale.ir(buffer), doneAction: 2);
			OffsetOut.ar(out, snd);
		}).load(s);

		encoderMatrix = FoaEncoderMatrix.newDirections(speakerList.degrad); // discrete channels --> b-format
		decoderMatrix = FoaDecoderMatrix.newHoa1(normalisation: 'sn3d'); // b-format --> b-format (acn, sn3d)

		SynthDef(\encode, {
			var input, snd;
			input = In.ar((0..(speakerList.size - 1)) + 100);
			snd = FoaEncode.ar(input, encoderMatrix);
			snd = FoaDecode.ar(snd, decoderMatrix);
			OffsetOut.ar(0, snd);
		}).load(s);
		// ------------------------------------------------------------------------------<

		// >------------------------------------------------------------------------------
		// score construction and NRT (non realtime) rendering

		score = Score.new;
		buffers = List.newClear;

		// load buffers and play discrete channel audio
		(currentDirectory +/+ "*.wav").pathMatch.do{ |path, index|

			// load buffers
			buffers.add(Buffer.new);
			score.add([0, buffers[index].allocReadMsg(path);]);

			// synths for discrete channel audio playback
			synth = Synth.basicNew(\playback);
			score.add([0.1, synth.newMsg(s, [buffer: buffers[index], out: index + 100])]);

		};

		// synth for encoding all discrete channels
		synth = Synth.basicNew(\encode);
		score.add([0.1, synth.newMsg(s, addAction: 'addToTail')]);

		// end of score
		score.add([soundFileDuration, 0]);
		score.sort;

		// render score
		score.recordNRT(
			"/tmp/osc_nrt_" ++ Date.getDate.format("%Y%m%d_%H%M%S"),
			currentDirectory +/+ "render" +/+ "B-Format_" ++ Date.getDate.format("%Y%m%d_%H%M") ++ ".wav",
			options: ServerOptions.new.numOutputBusChannels_(4)
		);
		// ------------------------------------------------------------------------------<*/
	}
	{ // if more than one arguments
		"Wrong number of arguments!".postln;
		0.exit;
		// nil.yield;
	};
}).start;
)