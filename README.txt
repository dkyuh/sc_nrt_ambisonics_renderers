 _______________________________________________________________________

       		  SUPERCOLLIDER AMBISONICS NRT-RENDERERS

   Michele Samarotto, Daniel Höpfner - May 2018 - @ IMWI HfM-Karlsruhe
 _______________________________________________________________________


These are two SuperCollider scripts for encoding and decoding
multichannel and B-Format audio recordings.

Information about speaker positions are retrieved from a XML-file.


1 Requirements
==============

1.1 Dependencies
~~~~~~~~~~~~~~~~

1.1.1 sc3-plugins
-----------------

  Install the [SC3-plugins] from github. Installation instructions can
  be found there.


[SC3-plugins] https://github.com/supercollider/sc3-plugins


1.1.2 Quarks
------------

  Install the following quarks via:

  ,----
  | Quarks.gui;
  `----

  - atk-sc3
  - XML


1.2 XML-file format for speaker position info
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

  Speaker positions are to be supplied according to the following
  example:

  ,----
  | <Speaker x=" -2.1200" y="  2.1200" z="  2.5000"  lsNo="1"/>
  | <Speaker x="  0.0000" y="  3.0000" z="  2.5000"  lsNo="2"/>
  | ...
  `----

  Attributes `x', `y', `z' and `lsNo' must be specified within the
  `<Speaker/>' tag.

  Additional information for other uses can be included but will be
  ignored during parsing.


2 Discrete Channels --> B-Format
================================

  This script renders an ambisonics B-Format audio file (ACN, SN3D) from
  a collection of discrete channel audio files.

  Create a copy of the `B-Format_Renderer.scd' script, place it into the
  folder containing your discrete channel audio files and run it. It is
  recommended to always work with copies of the original script file.

  A child folder named `render' will be created in the current directory
  - containing the rendered B-Format audio file.


2.1 Audio files naming
~~~~~~~~~~~~~~~~~~~~~~

  Names of the audio files must contain correct channel numbering.

  IMPORTANT: single digit numbers must be written with a `0' prepended
  e.g. `01, 02, 03, 04, 05, 06, 07, 08, 09, 10, 11, ...'


3 B-Format --> Binaural
=======================

  This script renders a binaural stereo file from an ambisonics B-Format
  audio file (ACN, SN3D).

  Create a copy of the `Binaural-Decoder_Renderer.scd' script, place it
  into the folder containing your B-Format audio file and run it. It is
  recommended to always work with copies of the original script file.


3.1 Audio file naming
~~~~~~~~~~~~~~~~~~~~~

  Names of the audio files must begin with `B-Format_'.

  The script looks for files matching this name pattern and returns a
  list of all found files. You can then choose the desired B-Format file
  to decode by copying from the post window and assign it to the
  environmental variable `~filename':

  ,----
  | (
  | // use this to print all b-format files in the current directory
  | (thisProcess.nowExecutingPath.dirname  +/+ "B-Format_*.wav").pathMatch.do{
  | 	|file| 
  | 	("\"" ++ file.basename ++ "\"").postln;
  | };
  | ""
  | )
  | 
  | // copy the desired file name for the file to decode from the post window
  | ~filename = "B-Format_20180519_1916.wav";
  `----
