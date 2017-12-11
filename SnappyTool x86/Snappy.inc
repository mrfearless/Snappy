include windows.inc
include user32.inc
include kernel32.inc
include shell32.inc
include masm32.inc
includelib user32.lib
includelib kernel32.lib
includelib shell32.lib
includelib masm32.lib

include Console.inc
includelib Console.lib


includelib .\msvcrt.lib
includelib .\libcpmt.lib

include snappy_x86.inc
includelib snappy_x86.lib


;-----------------------------------------------------------------------------------------
; Snappy Prototypes
;-----------------------------------------------------------------------------------------
SnappyMain                      PROTO
SnappyRegisterSwitches          PROTO
SnappyRegisterCommands          PROTO
SnappyProcessCmdLine            PROTO

SnappyConInfo                   PROTO :DWORD
SnappyConErr                    PROTO :DWORD

SnappyFileInOpen                PROTO :DWORD
SnappyFileInClose               PROTO
SnappyFileOutOpen               PROTO :DWORD
SnappyFileOutClose              PROTO

SnappySingleFileProcess         PROTO :DWORD, :DWORD
SnappyBatchProcess              PROTO :DWORD
SnappyOutFilename               PROTO :DWORD, :DWORD
SnappyChkFilename               PROTO :DWORD

SnappyMode                      PROTO :DWORD
SnappyModeSelf                  PROTO
SnappyModeFilename              PROTO :DWORD
SnappyOptionMode                PROTO :DWORD
SnappyFilespec                  PROTO :DWORD


JustFnameExt                    PROTO :DWORD, :DWORD

IFNDEF GetCommandLineA
GetCommandLineA                 PROTO 
GetCommandLine                  EQU <GetCommandLineA>
ENDIF


.CONST
;-----------------------------------------------------------------------------------------
; Snappy Constants
;-----------------------------------------------------------------------------------------
ICO_MAIN                        EQU 100
ICO_CMD                         EQU 101

ICO_SPINNER1                    EQU 111
ICO_SPINNER2                    EQU 112
ICO_SPINNER3                    EQU 113
ICO_SPINNER4                    EQU 114

ICO_SZ1                         EQU 121
ICO_SZ2                         EQU 122
ICO_SZ3                         EQU 123
ICO_SZ4                         EQU 124
ICO_SZ5                         EQU 125
ICO_SZ6                         EQU 126
ICO_SZ7                         EQU 127
ICO_SZ8                         EQU 128

; SnappyConInfo dwMsgType:
CON_OUT_INFO                    EQU 0   ; Header information
CON_OUT_ABOUT                   EQU 1   ; About information
CON_OUT_USAGE                   EQU 2   ; Usage information: switches/commands and params
CON_OUT_HELP                    EQU 3   ; Help information
CON_OUT_MODE                    EQU 4   ; Snappy mode being used (compress/decompress)
CON_OUT_SUCCESS_COMPRESS        EQU 5   ; Successful compression of file(s)
CON_OUT_SUCCESS_DECOMPRESS      EQU 6   ; Successful decompression of file(s)

; Constants for SnappyProcessCmdLine
; return values and for SnappyConErr
; dwErrorType:
ERROR_INVALID_INPUT_DECOMPRESS  EQU -21 ; snappy_x86.lib Decompress function returned SNAPPY_INVALID_INPUT
ERROR_INVALID_INPUT_COMPRESS    EQU -20 ; snappy_x86.lib Compress function returned SNAPPY_INVALID_INPUT
ERROR_WRITING_DECOMPRESS_DATA   EQU -15 ; Writefile failed with writing data out
ERROR_WRITING_COMPRESS_DATA     EQU -14 ; Writefile failed with writing data out
ERROR_ALLOC_MEMORY              EQU -13 ; GlobalAlloc failed for some reason
ERROR_CREATING_FILEOUT          EQU -12 ; Couldnt create temporary output file
ERROR_OPENING_FILEIN            EQU -11 ; Couldnt open input filename
ERROR_FILEIN_IS_EMPTY           EQU -10 ; 0 byte file
CMDLINE_NO_SNAPPY_MODE          EQU -9  ; No command c d supplied and couldnt decide on mode based on self.exe or inputfilename<.sz?>
CMDLINE_COMMAND_WITHOUT_FILEIN  EQU -8  ; User forgot to supply a filename or filespec or folder with command
CMDLINE_UNKNOWN_SWITCH_FILEIN   EQU -7  ; Couldnt decide if unknown switch or parameter is a filename - not sure if using this.
CMDLINE_FOLDER_NOT_SUPPORTED    EQU -6  ; A folder (assumes <foldername>\*.* filespec) provided whilst supplying output filename
CMDLINE_FILESPEC_NOT_SUPPORTED  EQU -5  ; Using *.* etc wildcards whilst supplying output filename
CMDLINE_FILEIN_NOT_EXIST        EQU -4  ; Filename or filepath provided does not exist
CMDLINE_ERROR                   EQU -3  ; General error reading parameters
CMDLINE_UNKNOWN_COMMAND         EQU -2  ; User provided a <X> command that wasnt recognised
CMDLINE_UNKNOWN_SWITCH          EQU -1  ; User provided a /<X> or -<X> switch that wasnt recognised
CMDLINE_NOTHING                 EQU 0   ;
CMDLINE_HELP                    EQU 1   ; User specified /? -? --? as a parameter
CMDLINE_FILEIN                  EQU 2   ; A single filename was specified
CMDLINE_FILEIN_FILESPEC         EQU 3   ; A filespec (*.*, *.txt) was specified
CMDLINE_FILEIN_FILEOUT          EQU 4   ; A filename for input and a filename for output was specified
CMDLINE_FOLDER_FILESPEC         EQU 5   ; A folder was specified (assumes <foldername>\*.* filespec)
SUCCESS_COMPRESS                EQU 10  ; Compression operation was successfull
SUCCESS_DECOMPRESS              EQU 11  ; Decompression operation was successfull

; Snappy modes (compress/decompress/none/error):
SNAPPY_MODE_ERROR               EQU -1  ; error
SNAPPY_MODE_NOP                 EQU 0   ; not known/undecided
SNAPPY_MODE_UNSNAP              EQU 1   ; decompress
SNAPPY_MODE_SNAP                EQU 2   ; compress
SNAPPY_MODE_UNZIP               EQU SNAPPY_MODE_UNSNAP
SNAPPY_MODE_ZIP                 EQU SNAPPY_MODE_SNAP

; Snappy Switch IDs: /? -? --?
SWITCH_HELP                     EQU 0   ; /? help switch
SWITCH_HELP_UNIX                EQU 1   ; -? help switch
SWITCH_HELP_UNIX2               EQU 2   ; --? help switch
SWITCH_COMPRESS_MODE            EQU 3
SWITCH_DECOMPRESS_MODE          EQU 4

; Snappy Command IDs: c d 
COMMAND_COMPRESS                EQU 0   ; c - set snappy mode to compress
COMMAND_DECOMPRESS              EQU 1   ; d - set snappy mode to decompress

.DATA
;-----------------------------------------------------------------------------------------
; Snappy Initialized Data
;-----------------------------------------------------------------------------------------
AppName                         DB 'Snappy',0
TitleName                       DB 'Snappy Tool v1.0.0.0',0
szConTitle                      DB MAX_PATH DUP (0)
CmdLineParameters               DB 512 DUP (0)
CmdLineParameter                DB 256 DUP (0)
ErrParameter                    DB 256 DUP (0)
TotalCmdLineParameters          DD 0
SNAPPY_MODE                     DD 0
SNAPPY_MODE_SPECIFIED           DD FALSE

; Console Output
szSnappyConInfo                 DB 13,10,"[Snappy] v1.00 - Compression/Decompression Tool - Copyright (C) 2017 fearless",13,10,13,10,0

szSnappyConAbout                DB "About:",13,10
                                DB "========",13,10
                                DB "Snappy is a console program which needs to be ran from a command prompt.",13,10
                                DB 13,10
                                DB "The command prompt can be opened on modern windows operating systems from:",13,10
                                DB "Start Button, Run, type: 'cmd' and press enter to open the command prompt.",13,10
                                DB 13,10
                                DB "For detailed help on the Snappy options, specify Snappy /? at the prompt.",13,10
                                DB 13,10,13,10
                                DB "Credits:",13,10
                                DB "========",13,10
                                DB "Snappy is designed and programmed by fearless (C) Copyright 2017",13,10
                                DB "Written using Microsoft Macro Assembler, Steve Hutch MASM32 libraries and",13,10
                                DB "uses static builds of Google's Snappy compression/decompression library.",13,10
                                DB 13,10,0

szSnappyConHelp                 DB "  Usage:      Snappy [ /? | -? ]",13,10
                                DB "              Snappy [ switch | command ] [ <infile> [ <outfile> ] ]",13,10
                                DB "              Snappy [ switch | command ] <filespec>",13,10
                                DB "              Snappy [ switch | command ] <folder>",13,10
                                DB 13,10
                                DB 13,10
                                DB "  Switches:",13,10     
                                DB 13,10
                                DB "  /? | -?     Displays this help.",13,10
                                DB "  /c | -c     Switch to set mode of operation to compression.",13,10
                                DB "  /d | -d     Switch to set mode of operation to decompression.",13,10
                                DB 13,10
                                DB 13,10
                                DB "  Commands:",13,10
                                DB 13,10
                                DB "  c           Command to set mode of operation to compression.",13,10
                                DB "  d           Command to set mode of operation to decompression.",13,10
                                DB 13,10
                                DB 13,10
                                DB "  Parameters:",13,10
                                DB 13,10
                                DB "  <infile>    The name of an existing filename to compress/decompress.",13,10
                                DB 13,10
                                DB "  <outfile>   The the name of a filename to compress/decompress <infile> to.",13,10
                                DB "              If no <outfile> is provided, filename is determined by mode, see notes.",13,10
                                DB 13,10
                                DB "  <filespec>  A set of files to compress/decompress, which supports the use of",13,10
                                DB "              the wildcards * and ? for specifying which files to include.",13,10
                                DB 13,10
                                DB "  <folder>    A folder to compress/decompress all files contained within and",13,10
                                DB "              assumes the use of <folder\*.*> for processing file operations.",13,10
                                DB 13,10
                                DB 13,10
                                DB "  Notes:      <filespec> and <folder> do not support an <outfile> parameter.",13,10
                                DB 13,10
                                DB "              If no compress/decompress mode is specified via switches or commands,",13,10
                                DB "              then the mode of operation is determined by filename of the <infile>, ",13,10
                                DB "              a .sz extension indicates mode is decompress, otherwise it is compress.",13,10
                                DB 13,10
                                DB "              If no <outfile> is provided, then <outfile> filename is determined by",13,10
                                DB "              mode and based on the <infile> filename. Compression mode adds a '.sz'",13,10
                                DB "              extension and decompression mode removes any '.sz' extension.",13,10
                                DB 13,10
                                DB "              Snappy.exe renamed to snsnap.exe|snzip.exe = default mode is compress.",13,10
                                DB "              Snappy.exe renamed to snunsnap.exe|snunzip.exe = mode is decompress.",13,10
                                DB 13,10
                                DB "              The default modes can be overidden by providing switches or commands.",13,10
                                DB 13,10
                                DB "              Switches and commands are not case sensitive.",13,10
                                DB 13,10
                                DB 13,10,0

szSnappyConHelpUsage            DB "  Usage:      Snappy [/?|-?|--?]",13,10
                                DB "                     [c|d] [infile [outfile]]",13,10
                                DB "                     c|d infilespec",13,10
                                DB "                     c|d infolder",13,10
                                DB 13,10,0

szSnappyConModeCompress         DB "[~] Mode: Compress",13,10,0
szSnappyConModeDecompress       DB "[*] Mode: Decompress",13,10,0
szSnappyConCompressSuccess      DB 13,10,"[=] Finished: compression operation successfull.",13,10,0
szSnappyConDecompressSuccess    DB 13,10,"[=] Finished: decompression operation successfull.",13,10,0
szSnappyConCompBatchSuccess     DB 13,10,"[=] Finished: compression operation on all files successfull.",13,10,0
szSnappyConDecompBatchSuccess   DB 13,10,"[=] Finished: decompression operation on all files successfull.",13,10,0
szSnappyConCompBatchFail        DB 13,10,"[x] Finished: compression operation on all files failed!",13,10,0
szSnappyConDecompBatchFail      DB 13,10,"[x] Finished: decompression operation on all files failed!",13,10,0
szSnappyConCompBatchPartial     DB 13,10,"[i] Finished: compression operation on some files failed.",13,10,0
szSnappyConDecompBatchPartial   DB 13,10,"[i] Finished: decompression operation on some files failed.",13,10,0
szSnappyConBatchNoFiles         DB 13,10,"[ ] Finished: no files where processed for current operation.",13,10,0
szInFileSpec                    DB "[=] Filespec: ",0
szInFile                        DB "[<] ",0
szOutFile                       DB "[>] ",0
szInfo                          DB "[i] ",0



; Error message
szError                         DB "[!] Error: ",0
szErrorUnknownSwitch            DB " invalid switch specified.",0
szErrorUnknownCommand           DB " invalid command specified.",0
szErrorCommandWithoutFile       DB " command specified but no filename or filespec provided.",0
szErrorUnknownSwitchFileIn      DB " filename does not exist or invalid switch.",0
szErrorFileSpecNotSupported     DB " wildcard filespec not supported for input file(s) when also specifying output filename as well.",0
szErrorFilenameNotExist         DB " filename/filepath does not exist.",0
szErrorOther                    DB "unknown error occured whilst parsing parameters and switches.",0
szErrorNoSnappyMode             DB "command mode (to compress or decompress) not provided or determined.",0
szErrorFolderNotSupported       DB " folder (assumes *.*) not supported for input file(s) when also specifying output filename as well.",0
szInFilenameAlreadyCompressed   DB " already compressed, skipping.",0
szInFilenameAlreadyDecompressed DB " already decompressed, skipping.",0
szErrorFileZeroBytes            DB " file 0 bytes, skipping.",0
szErrorCompressing              DB " failed to compress file.",0
szErrorDecompressing            DB " failed to decompress file.",0
szErrorOpeningInFile            DB " failed to open input file.",0
szErrorCreatingOutFile          DB " failed to create output file.",0
szErrorAllocMemory              DB " failed to allocate memory for compress/decompress operation.",0
szErrorWritingCompressData      DB " writing compressed data to output file.",0
szErrorCompressInputInvalid     DB " input file data cant be compressed.",0
szErrorWritingDecompressData    DB " writing Decompressed data to output file..",0
szErrorDecompressInputInvalid   DB " input file data cant be decompressed.",0




; Punctuation
szComma                         DB ',',0
szSpace                         DB ' ',0
szColon                         DB ':',0
szLeftBracket                   DB '{',0
szRightBracket                  DB '}',0
szBackslash                     DB '\',0
szLeftSquareBracket             DB '[',0
szRightSquareBracket            DB ']',0
szQuote                         DB '"',0
szSingleQuote                   DB "'",0
szDash                          DB '-',0
szForwardslash                  DB '/',0
szWildCardStar                  DB '*',0
szWildCardQuestion              DB '?',0
szLF                            DB 10,0
szCRLF                          DB 13,10,0
szExtSZ                         DB '.sz',0
szExtSZU                        DB '.uncompressed',0
szFolderAllFiles                DB '\*.*',0

; Switches - unused?
SwitchHelp0                     DB '?',0
SwitchHelp                      DB '/?',0
SwitchHelpAlt                   DB '-?',0
SwitchHelpAlt2                  DB '--?',0
SwitchCompress0                 DB 'c',0
SwitchCompress                  DB '/c',0
SwitchCompressAlt               DB '-c',0
SwitchCompressAlt2              DB '--c',0
SwitchDecompress0               DB 'd',0
SwitchDecompress                DB '/d',0
SwitchDecompressAlt             DB '-d',0
SwitchDecompressAlt2            DB '--d',0

; Used to check self.exe
szSNSnap                        DB "SNSNAP",0
szSNUnsnap                      DB "SNUNSNAP",0
szSNZip                         DB "SNZIP",0
szSNUnzip                       DB "SNUNZIP",0

; Filename Buffers
szSnappySelfFilename            DB MAX_PATH DUP (0)
szSnappySelfFilepath            DB MAX_PATH DUP (0)
szSnappyInFilename              DB MAX_PATH DUP (0)
szSnappyOutFilename             DB MAX_PATH DUP (0)


.DATA?
;-----------------------------------------------------------------------------------------
; Snappy Uninitialized Data
;-----------------------------------------------------------------------------------------
hFileIn                         DD ?
hMemMapIn                       DD ?
hMemMapInPtr                    DD ?
hFileOut                        DD ?
hMemMapOut                      DD ?
hMemMapOutPtr                   DD ?
qwFileSize                      DQ ?
dwFileSize                      DD ?
dwFileSizeHigh                  DD ?















