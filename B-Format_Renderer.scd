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

(
var
document, speakerPosXMLFile, xmlString, speakerList,
soundFile, soundFileDuration, currentDirectory, currentDirectoryPath,
score,
buffers, synth,
encoderMatrix, decoderMatrix;

currentDirectory = thisProcess.nowExecutingPath.dirname;
currentDirectoryPath = PathName(currentDirectory);

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
// ------------------------------------------------------------------------------<
)