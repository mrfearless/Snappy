.686
.MMX
.XMM
.model flat,stdcall
option casemap:none
include \masm32\macros\macros.asm

;DEBUG32 EQU 1

IFDEF DEBUG32
    PRESERVEXMMREGS equ 1
    Includelib M:\Masm32\lib\Debug32.lib
    DBG32LIB equ 1
    DEBUGEXE textequ <'M:\Masm32\DbgWin.exe'>
    Include M:\Masm32\include\debug32.inc
ENDIF


Include Snappy.inc


.CODE


Main PROC

    Invoke ConsoleStarted
    .IF eax == TRUE ; Started From Console

        Invoke ConsoleAttach
        Invoke ConsoleSetIcon, ICO_MAIN
        Invoke ConsoleGetTitle, Addr szConTitle, SIZEOF szConTitle
        Invoke ConsoleSetTitle, Addr TitleName
        Invoke SnappyConInfo, CON_OUT_INFO
        
        ; Start main console processing
        Invoke SnappyMain
        ; Exit main console processing
        
        ;Invoke ConsolePause, CON_PAUSE_ANY_KEY_CONTINUE
        Invoke ConsoleSetTitle, Addr szConTitle
        Invoke ConsoleSetIcon, ICO_CMD
        Invoke ConsoleShowCursor
        Invoke ConsoleFree

    .ELSE ; Started From Explorer

	    Invoke ConsoleAttach
        Invoke ConsoleSetIcon, ICO_MAIN
        Invoke ConsoleSetTitle, Addr TitleName 
        Invoke SnappyConInfo, CON_OUT_INFO
        Invoke SnappyConInfo, CON_OUT_ABOUT
        ;Invoke SnappyConInfo, CON_OUT_USAGE
        Invoke ConsolePause, CON_PAUSE_ANY_KEY_EXIT
        Invoke ConsoleSetIcon, ICO_CMD
        Invoke ConsoleFree

    .ENDIF

    Invoke  ExitProcess,0
    ret
Main ENDP


;-------------------------------------------------------------------------------------
; SnappyMain
;-------------------------------------------------------------------------------------
SnappyMain PROC

    Invoke SnappyRegisterSwitches
    Invoke SnappyRegisterCommands
    Invoke SnappyProcessCmdLine

    .IF eax == CMDLINE_NOTHING || eax == CMDLINE_HELP ; no switch provided or /?
        Invoke SnappyConInfo, CON_OUT_HELP

    .ELSEIF eax == CMDLINE_FILEIN
        Invoke SnappyConInfo, CON_OUT_MODE
        ;PrintText 'Processing single input file'
        Invoke SnappyOutFilename, Addr szSnappyInFilename, Addr szSnappyOutFilename
        .IF eax == TRUE || SNAPPY_MODE_SPECIFIED == TRUE
            Invoke SnappySingleFileProcess, Addr szSnappyInFilename, Addr szSnappyOutFilename
            .IF eax == SUCCESS_COMPRESS
                Invoke SnappyConInfo, CON_OUT_SUCCESS_COMPRESS
            .ELSEIF eax == SUCCESS_DECOMPRESS
                Invoke SnappyConInfo, CON_OUT_SUCCESS_DECOMPRESS
            .ELSE
                Invoke SnappyConErr, eax
            .ENDIF

        .ELSE
            Invoke ConsoleStdOut, Addr szInFile
            Invoke ConsoleStdOut, Addr szSnappyInFilename
            Invoke ConsoleStdOut, Addr szCRLF       
            Invoke ConsoleStdOut, Addr szInfo
            Invoke ConsoleStdOut, Addr szSnappyInFilename
            .IF SNAPPY_MODE == SNAPPY_MODE_SNAP
                Invoke ConsoleStdOut, Addr szInFilenameAlreadyCompressed
            .ELSE
                Invoke ConsoleStdOut, Addr szInFilenameAlreadyDecompressed
            .ENDIF
            Invoke ConsoleStdOut, Addr szCRLF
        .ENDIF

    .ELSEIF eax == CMDLINE_FOLDER_FILESPEC
        Invoke SnappyConInfo, CON_OUT_MODE
        ;PrintText 'Processing folder for input file(s)'
        Invoke ConsoleStdOut, Addr szInFileSpec
        Invoke ConsoleStdOut, Addr szSnappyInFilename
        Invoke ConsoleStdOut, Addr szCRLF
        Invoke SnappyBatchProcess, Addr szSnappyInFilename

    .ELSEIF eax == CMDLINE_FILEIN_FILESPEC
        Invoke SnappyConInfo, CON_OUT_MODE
        ;PrintText 'Processing filespec for input file(s)'
        Invoke ConsoleStdOut, Addr szInFileSpec
        Invoke ConsoleStdOut, Addr szSnappyInFilename
        Invoke ConsoleStdOut, Addr szCRLF
        Invoke SnappyBatchProcess, Addr szSnappyInFilename

    .ELSEIF eax == CMDLINE_FILEIN_FILEOUT
        Invoke SnappyConInfo, CON_OUT_MODE
        ;PrintText 'Processing input file and output file'
        Invoke SnappyChkFilename, Addr szSnappyInFilename
        .IF eax == TRUE || SNAPPY_MODE_SPECIFIED == TRUE
            Invoke SnappySingleFileProcess, Addr szSnappyInFilename, Addr szSnappyOutFilename
            .IF eax == SUCCESS_COMPRESS
                Invoke SnappyConInfo, CON_OUT_SUCCESS_COMPRESS
            .ELSEIF eax == SUCCESS_DECOMPRESS
                Invoke SnappyConInfo, CON_OUT_SUCCESS_DECOMPRESS
            .ELSE
                Invoke SnappyConErr, eax
            .ENDIF

        .ELSE
            Invoke ConsoleStdOut, Addr szInFile
            Invoke ConsoleStdOut, Addr szSnappyInFilename
            Invoke ConsoleStdOut, Addr szCRLF        
            Invoke ConsoleStdOut, Addr szInfo
            Invoke ConsoleStdOut, Addr szSnappyInFilename
            .IF SNAPPY_MODE == SNAPPY_MODE_SNAP
                Invoke ConsoleStdOut, Addr szInFilenameAlreadyCompressed
            .ELSE
                Invoke ConsoleStdOut, Addr szInFilenameAlreadyDecompressed
            .ENDIF
            Invoke ConsoleStdOut, Addr szCRLF
        .ENDIF        

    .ELSE

        Invoke SnappyConErr, eax

    .ENDIF
    
    ret
SnappyMain ENDP


;-----------------------------------------------------------------------------------------
; Process command line information
;-----------------------------------------------------------------------------------------
SnappyProcessCmdLine PROC USES EBX
    LOCAL dwLenCmdLineParameter:DWORD
    LOCAL bFileIn:DWORD
    LOCAL bCommand:DWORD
    
    Invoke GetCommandLine
    Invoke ConsoleParseCmdLine, Addr CmdLineParameters
    mov TotalCmdLineParameters, eax ; will be at least 1 as param 0 is name of exe
    
   .IF TotalCmdLineParameters == 1 ; nothing extra specified
        mov eax, CMDLINE_NOTHING
        ret       
    .ENDIF       

    Invoke ConsoleCmdLineParam, Addr CmdLineParameters, 1, TotalCmdLineParameters, Addr CmdLineParameter
    .IF sdword ptr eax > 0
        mov dwLenCmdLineParameter, eax
    .ELSE
        mov eax, CMDLINE_ERROR
        ret
    .ENDIF
    
    Invoke SnappyModeSelf
    mov SNAPPY_MODE, eax
    
    .IF TotalCmdLineParameters == 2
        
        Invoke ConsoleCmdLineParamType, Addr CmdLineParameters, 1, TotalCmdLineParameters
        .IF eax == CMDLINE_PARAM_TYPE_ERROR
            ;PrintText 'ConsoleCmdLineParamType CMDLINE_PARAM_TYPE_ERROR'
            mov eax, CMDLINE_ERROR
            ret
            
        .ELSEIF eax == CMDLINE_PARAM_TYPE_UNKNOWN
            ;PrintText 'ConsoleCmdLineParamType CMDLINE_PARAM_TYPE_UNKNOWN'
            
        .ELSEIF eax == CMDLINE_PARAM_TYPE_SWITCH
            ;PrintText 'ConsoleCmdLineParamType CMDLINE_PARAM_TYPE_SWITCH'
            Invoke ConsoleSwitchID, Addr CmdLineParameter, FALSE
            .IF eax == SWITCH_HELP || eax == SWITCH_HELP_UNIX || eax == SWITCH_HELP_UNIX2 
                mov eax, CMDLINE_HELP
                ret
            
            .ELSEIF eax == SWITCH_COMPRESS_MODE || eax == SWITCH_DECOMPRESS_MODE 
                mov eax, CMDLINE_COMMAND_WITHOUT_FILEIN
                ret
                
            .ELSE
                mov eax, CMDLINE_UNKNOWN_SWITCH
                ret
            .ENDIF
            
        .ELSEIF eax == CMDLINE_PARAM_TYPE_COMMAND
            ;PrintText 'ConsoleCmdLineParamType CMDLINE_PARAM_TYPE_COMMAND'
            Invoke ConsoleCommandID, Addr CmdLineParameter, FALSE
            ;PrintDec eax
            .IF eax == -1 
                mov eax, CMDLINE_UNKNOWN_COMMAND
                ret
            .ELSE
                mov eax, CMDLINE_COMMAND_WITHOUT_FILEIN
                ret
            .ENDIF

        .ELSEIF eax == CMDLINE_PARAM_TYPE_FILESPEC
            ;PrintText 'ConsoleCmdLineParamType CMDLINE_PARAM_TYPE_FILESPEC'
            Invoke szCopy, Addr CmdLineParameter, Addr szSnappyInFilename
            .IF SNAPPY_MODE == SNAPPY_MODE_NOP || SNAPPY_MODE == SNAPPY_MODE_ERROR
                mov eax, CMDLINE_NO_SNAPPY_MODE
                ret
            .ELSE
                mov eax, CMDLINE_FILEIN_FILESPEC
                ret            
            .ENDIF
            
        .ELSEIF eax == CMDLINE_PARAM_TYPE_FILENAME
            ;PrintText 'ConsoleCmdLineParamType CMDLINE_PARAM_TYPE_FILENAME'
            Invoke szCopy, Addr CmdLineParameter, Addr szSnappyInFilename
            Invoke exist, Addr szSnappyInFilename
            .IF eax == TRUE ; does exist
                .IF SNAPPY_MODE == SNAPPY_MODE_NOP || SNAPPY_MODE == SNAPPY_MODE_ERROR
                    Invoke SnappyMode, Addr szSnappyInFilename
                    mov SNAPPY_MODE, eax
                    .IF SNAPPY_MODE == SNAPPY_MODE_NOP || SNAPPY_MODE == SNAPPY_MODE_ERROR
                        mov eax, CMDLINE_NO_SNAPPY_MODE
                        ret
                    .ENDIF
                .ENDIF
                mov eax, CMDLINE_FILEIN
                ret
            .ELSE
                mov eax, CMDLINE_FILEIN_NOT_EXIST
                ret
            .ENDIF
                
        .ELSEIF eax == CMDLINE_PARAM_TYPE_FOLDER
            ;PrintText 'ConsoleCmdLineParamType CMDLINE_PARAM_TYPE_FOLDER'
            Invoke szCopy, Addr CmdLineParameter, Addr szSnappyInFilename
            Invoke exist, Addr szSnappyInFilename
            .IF eax == TRUE ; does exist
                .IF SNAPPY_MODE == SNAPPY_MODE_NOP || SNAPPY_MODE == SNAPPY_MODE_ERROR
                    mov eax, CMDLINE_NO_SNAPPY_MODE
                    ret
                .ENDIF
                ; assume filespec of *.* in folder provided
                Invoke lstrcat, Addr szSnappyInFilename, Addr szFolderAllFiles
                mov eax, CMDLINE_FOLDER_FILESPEC
                ret
            .ELSE
                mov eax, CMDLINE_FILEIN_NOT_EXIST
                ret
            .ENDIF
        .ENDIF
        
    .ENDIF


    ;-------------------------------------------------------------------------------------
    ; FILENAMEIN FILENAMEOUT or OPTION FILENAMEIN/FILESPECIN
    ;-------------------------------------------------------------------------------------    
    mov bFileIn, FALSE
    mov bCommand, FALSE
    .IF TotalCmdLineParameters == 3
        Invoke ConsoleCmdLineParamType, Addr CmdLineParameters, 1, TotalCmdLineParameters
        .IF eax == CMDLINE_PARAM_TYPE_ERROR
            ;PrintText '3 ConsoleCmdLineParamType CMDLINE_PARAM_TYPE_ERROR'
            mov eax, CMDLINE_ERROR
            ret    

        .ELSEIF eax == CMDLINE_PARAM_TYPE_UNKNOWN
        
        .ELSEIF eax == CMDLINE_PARAM_TYPE_SWITCH
            ;PrintText '3 ConsoleCmdLineParamType CMDLINE_PARAM_TYPE_SWITCH'
            Invoke ConsoleSwitchID, Addr CmdLineParameter, FALSE
            .IF eax == SWITCH_HELP || eax == SWITCH_HELP_UNIX || eax == SWITCH_HELP_UNIX2 
                mov eax, CMDLINE_HELP
                ret
            
            .ELSEIF eax == SWITCH_COMPRESS_MODE
                mov SNAPPY_MODE, SNAPPY_MODE_SNAP
                mov SNAPPY_MODE_SPECIFIED, TRUE
                mov bCommand, TRUE
            .ELSEIF eax == SWITCH_DECOMPRESS_MODE
                mov SNAPPY_MODE, SNAPPY_MODE_UNSNAP
                mov SNAPPY_MODE_SPECIFIED, TRUE
                mov bCommand, TRUE
            .ELSE
                mov eax, CMDLINE_UNKNOWN_SWITCH
                ret
            .ENDIF
            
        .ELSEIF eax == CMDLINE_PARAM_TYPE_COMMAND
            Invoke ConsoleCommandID, Addr CmdLineParameter, FALSE
            ;PrintDec eax
            .IF eax == -1 
                mov eax, CMDLINE_UNKNOWN_COMMAND
                ret
            .ELSE
                .IF eax == COMMAND_COMPRESS
                    mov SNAPPY_MODE, SNAPPY_MODE_SNAP
                    mov SNAPPY_MODE_SPECIFIED, TRUE
                    
                .ELSEIF eax == COMMAND_DECOMPRESS
                    mov SNAPPY_MODE, SNAPPY_MODE_UNSNAP
                    mov SNAPPY_MODE_SPECIFIED, TRUE
                    
                .ELSE
                    mov eax, CMDLINE_UNKNOWN_COMMAND
                    ret
                .ENDIF
            .ENDIF
            mov bCommand, TRUE
            
        .ELSEIF eax == CMDLINE_PARAM_TYPE_FILESPEC
            Invoke szCopy, Addr CmdLineParameter, Addr szSnappyInFilename
            
        .ELSEIF eax == CMDLINE_PARAM_TYPE_FILENAME
            Invoke szCopy, Addr CmdLineParameter, Addr szSnappyInFilename
            Invoke exist, Addr szSnappyInFilename
            .IF eax == TRUE ; does exist
                .IF SNAPPY_MODE == SNAPPY_MODE_NOP || SNAPPY_MODE == SNAPPY_MODE_ERROR
                    Invoke SnappyMode, Addr szSnappyInFilename
                    mov SNAPPY_MODE, eax
                    .IF SNAPPY_MODE == SNAPPY_MODE_NOP || SNAPPY_MODE == SNAPPY_MODE_ERROR
                        mov eax, CMDLINE_NO_SNAPPY_MODE
                        ret
                    .ENDIF
                .ENDIF
                ;mov bFileIn, TRUE
                ;mov eax, CMDLINE_FILEIN
                ;ret
            .ELSE
                mov eax, CMDLINE_FILEIN_NOT_EXIST
                ret
            .ENDIF            
            
        .ELSEIF eax == CMDLINE_PARAM_TYPE_FOLDER
            Invoke szCopy, Addr CmdLineParameter, Addr szSnappyInFilename
            Invoke exist, Addr szSnappyInFilename
            .IF eax == TRUE ; does exist
                ; assume filespec of *.* in folder provided
                Invoke lstrcat, Addr szSnappyInFilename, Addr szFolderAllFiles
            .ELSE
                mov eax, CMDLINE_FILEIN_NOT_EXIST
                ret
            .ENDIF            
            
        .ENDIF
        
        ; Get 2nd param
        Invoke ConsoleCmdLineParam, Addr CmdLineParameters, 2, TotalCmdLineParameters, Addr CmdLineParameter
        .IF sdword ptr eax > 0
            mov dwLenCmdLineParameter, eax
        .ELSE
            mov eax, CMDLINE_ERROR
            ret
        .ENDIF
        
        Invoke ConsoleCmdLineParamType, Addr CmdLineParameters, 2, TotalCmdLineParameters
        .IF eax == CMDLINE_PARAM_TYPE_ERROR
            mov eax, CMDLINE_ERROR
            ret
            
        .ELSEIF eax == CMDLINE_PARAM_TYPE_UNKNOWN
        
        .ELSEIF eax == CMDLINE_PARAM_TYPE_SWITCH
            ;PrintText '32 ConsoleCmdLineParamType CMDLINE_PARAM_TYPE_SWITCH'
            Invoke ConsoleSwitchID, Addr CmdLineParameter, FALSE
            .IF eax == SWITCH_HELP || eax == SWITCH_HELP_UNIX || eax == SWITCH_HELP_UNIX2 
                mov eax, CMDLINE_HELP
                ret
                
            .ELSEIF eax == SWITCH_COMPRESS_MODE
                Invoke ConsoleCmdLineParamType, Addr CmdLineParameters, 1, TotalCmdLineParameters
                .IF eax == CMDLINE_PARAM_TYPE_FILESPEC || eax == CMDLINE_PARAM_TYPE_FILENAME || eax == CMDLINE_PARAM_TYPE_FOLDER              
                    mov SNAPPY_MODE, SNAPPY_MODE_SNAP
                    mov SNAPPY_MODE_SPECIFIED, TRUE
                   .IF eax == CMDLINE_PARAM_TYPE_FILESPEC || eax == CMDLINE_PARAM_TYPE_FOLDER
                        mov eax, CMDLINE_FILEIN_FILESPEC
                    .ELSE
                        mov eax, CMDLINE_FILEIN
                    .ENDIF
                    ret
                .ELSE
                    mov eax, CMDLINE_COMMAND_WITHOUT_FILEIN
                    ret
                .ENDIF                    
                
            .ELSEIF eax == SWITCH_DECOMPRESS_MODE
                Invoke ConsoleCmdLineParamType, Addr CmdLineParameters, 1, TotalCmdLineParameters
                .IF eax == CMDLINE_PARAM_TYPE_FILESPEC || eax == CMDLINE_PARAM_TYPE_FILENAME || eax == CMDLINE_PARAM_TYPE_FOLDER                
                    mov SNAPPY_MODE, SNAPPY_MODE_UNSNAP
                    mov SNAPPY_MODE_SPECIFIED, TRUE                
                   .IF eax == CMDLINE_PARAM_TYPE_FILESPEC || eax == CMDLINE_PARAM_TYPE_FOLDER
                        mov eax, CMDLINE_FILEIN_FILESPEC
                    .ELSE
                        mov eax, CMDLINE_FILEIN
                    .ENDIF
                    ret
                .ELSE
                    mov eax, CMDLINE_COMMAND_WITHOUT_FILEIN
                    ret
                .ENDIF
                
            .ELSE
                mov eax, CMDLINE_UNKNOWN_SWITCH
                ret
            .ENDIF
            
        .ELSEIF eax == CMDLINE_PARAM_TYPE_COMMAND ; user specified filename/filespec/folder first then command?
            Invoke ConsoleCommandID, Addr CmdLineParameter, FALSE
            .IF eax == -1 
                mov eax, CMDLINE_UNKNOWN_COMMAND
                ret
            .ELSE
                .IF eax == COMMAND_COMPRESS
                    Invoke ConsoleCmdLineParamType, Addr CmdLineParameters, 1, TotalCmdLineParameters
                    .IF eax == CMDLINE_PARAM_TYPE_FILESPEC || eax == CMDLINE_PARAM_TYPE_FILENAME || eax == CMDLINE_PARAM_TYPE_FOLDER                
                        mov SNAPPY_MODE, SNAPPY_MODE_SNAP
                        mov SNAPPY_MODE_SPECIFIED, TRUE
                        .IF eax == CMDLINE_PARAM_TYPE_FILESPEC || eax == CMDLINE_PARAM_TYPE_FOLDER
                            mov eax, CMDLINE_FILEIN_FILESPEC
                        .ELSE
                            mov eax, CMDLINE_FILEIN
                        .ENDIF
                        ret
                    .ELSE
                        mov eax, CMDLINE_COMMAND_WITHOUT_FILEIN
                        ret
                    .ENDIF
                .ELSEIF eax == COMMAND_DECOMPRESS
                    Invoke ConsoleCmdLineParamType, Addr CmdLineParameters, 1, TotalCmdLineParameters
                    .IF eax == CMDLINE_PARAM_TYPE_FILESPEC || eax == CMDLINE_PARAM_TYPE_FILENAME || eax == CMDLINE_PARAM_TYPE_FOLDER 
                        mov SNAPPY_MODE, SNAPPY_MODE_UNSNAP
                        mov SNAPPY_MODE_SPECIFIED, TRUE
                        .IF eax == CMDLINE_PARAM_TYPE_FILESPEC || eax == CMDLINE_PARAM_TYPE_FOLDER
                            mov eax, CMDLINE_FILEIN_FILESPEC
                        .ELSE
                            mov eax, CMDLINE_FILEIN
                        .ENDIF                        
                        ret
                    .ELSE
                        mov eax, CMDLINE_COMMAND_WITHOUT_FILEIN
                        ret
                    .ENDIF
                .ELSE
                    mov eax, CMDLINE_UNKNOWN_COMMAND
                    ret
                .ENDIF
            .ENDIF

        .ELSEIF eax == CMDLINE_PARAM_TYPE_FILESPEC
            Invoke szCopy, Addr CmdLineParameter, Addr szSnappyInFilename
            .IF bCommand == TRUE
                mov eax, CMDLINE_FILEIN_FILESPEC
                ret
            .ELSE
                mov eax, CMDLINE_FILESPEC_NOT_SUPPORTED
                ret
            .ENDIF
            
        .ELSEIF eax == CMDLINE_PARAM_TYPE_FILENAME
            .IF bCommand == TRUE
                Invoke szCopy, Addr CmdLineParameter, Addr szSnappyInFilename
                Invoke exist, Addr szSnappyInFilename
                .IF eax == TRUE ; does exist
                    mov eax, CMDLINE_FILEIN
                    ret
                .ELSE
                    mov eax, CMDLINE_FILEIN_NOT_EXIST
                    ret
                .ENDIF
            .ELSE
                Invoke szCopy, Addr CmdLineParameter, Addr szSnappyOutFilename
                Invoke ConsoleCmdLineParamType, Addr CmdLineParameters, 1, TotalCmdLineParameters
                .IF eax == CMDLINE_PARAM_TYPE_FILENAME
                    mov eax, CMDLINE_FILEIN_FILEOUT
                    ret
                .ELSEIF eax == CMDLINE_PARAM_TYPE_FILESPEC
                    mov eax, CMDLINE_FILESPEC_NOT_SUPPORTED
                    ret
                .ELSEIF eax == CMDLINE_PARAM_TYPE_FOLDER
                    mov eax, CMDLINE_FOLDER_NOT_SUPPORTED
                    ret
                .ELSE
                    mov eax, CMDLINE_ERROR
                    ret
                .ENDIF
            .ENDIF
       
        .ELSEIF eax == CMDLINE_PARAM_TYPE_FOLDER
            .IF bCommand == TRUE
                Invoke szCopy, Addr CmdLineParameter, Addr szSnappyInFilename
                Invoke exist, Addr szSnappyInFilename
                .IF eax == TRUE ; does exist
                    ; assume filespec of *.* in folder provided
                    Invoke lstrcat, Addr szSnappyInFilename, Addr szFolderAllFiles
                    mov eax, CMDLINE_FOLDER_FILESPEC
                    ret
                .ELSE
                    mov eax, CMDLINE_FILEIN_NOT_EXIST
                    ret
                .ENDIF        
            .ELSE
                mov eax, CMDLINE_FILESPEC_NOT_SUPPORTED
                ret
            .ENDIF
        .ENDIF
    .ENDIF
    
    ;-------------------------------------------------------------------------------------
    ; OPTION FILENAMEIN FILENAMEOUT
    ;-------------------------------------------------------------------------------------

    Invoke ConsoleCmdLineParamType, Addr CmdLineParameters, 1, TotalCmdLineParameters
    .IF eax == CMDLINE_PARAM_TYPE_ERROR
        mov eax, CMDLINE_ERROR
        ret

    .ELSEIF eax == CMDLINE_PARAM_TYPE_SWITCH
        Invoke ConsoleSwitchID, Addr CmdLineParameter, FALSE
        .IF eax == SWITCH_HELP || eax == SWITCH_HELP_UNIX || eax == SWITCH_HELP_UNIX2 
            mov eax, CMDLINE_HELP
            ret
            
        .ELSEIF eax == SWITCH_COMPRESS_MODE
            mov SNAPPY_MODE, SNAPPY_MODE_SNAP
            mov SNAPPY_MODE_SPECIFIED, TRUE
            mov bCommand, TRUE
        .ELSEIF eax == SWITCH_DECOMPRESS_MODE
            mov SNAPPY_MODE, SNAPPY_MODE_UNSNAP
            mov SNAPPY_MODE_SPECIFIED, TRUE
            mov bCommand, TRUE
        .ELSE
            mov eax, CMDLINE_UNKNOWN_SWITCH
            ret
        .ENDIF    

    .ELSEIF eax == CMDLINE_PARAM_TYPE_COMMAND
        Invoke ConsoleCommandID, Addr CmdLineParameter, FALSE
        .IF eax == -1 
            mov eax, CMDLINE_UNKNOWN_COMMAND
            ret
        .ELSE
            .IF eax == COMMAND_COMPRESS
                mov SNAPPY_MODE, SNAPPY_MODE_SNAP
                mov SNAPPY_MODE_SPECIFIED, TRUE
            .ELSEIF eax == COMMAND_DECOMPRESS
                mov SNAPPY_MODE, SNAPPY_MODE_UNSNAP
                mov SNAPPY_MODE_SPECIFIED, TRUE
            .ELSE
                mov eax, CMDLINE_UNKNOWN_COMMAND
                ret
            .ENDIF
        .ENDIF
        mov bCommand, TRUE
    
    .ELSE
        mov eax, CMDLINE_ERROR
        ret
    .ENDIF
    
    ; Get 2nd param
    Invoke ConsoleCmdLineParam, Addr CmdLineParameters, 2, TotalCmdLineParameters, Addr CmdLineParameter
    .IF sdword ptr eax > 0
        mov dwLenCmdLineParameter, eax
    .ELSE
        mov eax, CMDLINE_ERROR
        ret
    .ENDIF
    
    Invoke ConsoleCmdLineParamType, Addr CmdLineParameters, 2, TotalCmdLineParameters
    .IF eax == CMDLINE_PARAM_TYPE_ERROR
        mov eax, CMDLINE_ERROR
        ret

    .ELSEIF eax == CMDLINE_PARAM_TYPE_FILENAME
        Invoke szCopy, Addr CmdLineParameter, Addr szSnappyInFilename
        Invoke exist, Addr szSnappyInFilename
        .IF eax == TRUE ; does exist
        .ELSE
            mov eax, CMDLINE_FILEIN_NOT_EXIST
            ret
        .ENDIF

    .ELSEIF eax == CMDLINE_PARAM_TYPE_FILESPEC
        mov eax, CMDLINE_FILESPEC_NOT_SUPPORTED
        ret
    
    .ELSEIF eax == CMDLINE_PARAM_TYPE_FOLDER
        mov eax, CMDLINE_FOLDER_NOT_SUPPORTED
        ret
    
    .ELSE
        mov eax, CMDLINE_ERROR
        ret
        
    .ENDIF

    ; Get 3rd param
    Invoke ConsoleCmdLineParam, Addr CmdLineParameters, 3, TotalCmdLineParameters, Addr CmdLineParameter
    .IF sdword ptr eax > 0
        mov dwLenCmdLineParameter, eax
    .ELSE
        mov eax, CMDLINE_ERROR
        ret
    .ENDIF
    
    Invoke ConsoleCmdLineParamType, Addr CmdLineParameters, 3, TotalCmdLineParameters
    .IF eax == CMDLINE_PARAM_TYPE_ERROR
        mov eax, CMDLINE_ERROR
        ret
    
    .ELSEIF eax == CMDLINE_PARAM_TYPE_FILENAME
        Invoke szCopy, Addr CmdLineParameter, Addr szSnappyOutFilename
        mov eax, CMDLINE_FILEIN_FILEOUT
        ret
        
    .ELSEIF eax == CMDLINE_PARAM_TYPE_FILESPEC
        mov eax, CMDLINE_FILESPEC_NOT_SUPPORTED
        ret
    
    .ELSEIF eax == CMDLINE_PARAM_TYPE_FOLDER
        mov eax, CMDLINE_FOLDER_NOT_SUPPORTED
        ret
    
    .ELSE
        mov eax, CMDLINE_ERROR
        ret
        
    .ENDIF

    
    ;mov eax, CMDLINE_UNKNOWN_SWITCH
    ret

SnappyProcessCmdLine ENDP


;-----------------------------------------------------------------------------------------
; Register switches for use on command line
;-----------------------------------------------------------------------------------------
SnappyRegisterSwitches PROC
    Invoke ConsoleSwitchRegister, CTEXT("/?"), SWITCH_HELP
    Invoke ConsoleSwitchRegister, CTEXT("-?"), SWITCH_HELP_UNIX
    Invoke ConsoleSwitchRegister, CTEXT("--?"), SWITCH_HELP_UNIX2
    Invoke ConsoleSwitchRegister, CTEXT("/C"), SWITCH_COMPRESS_MODE
    Invoke ConsoleSwitchRegister, CTEXT("-C"), SWITCH_COMPRESS_MODE
    Invoke ConsoleSwitchRegister, CTEXT("--C"), SWITCH_COMPRESS_MODE
    Invoke ConsoleSwitchRegister, CTEXT("/D"), SWITCH_DECOMPRESS_MODE
    Invoke ConsoleSwitchRegister, CTEXT("-D"), SWITCH_DECOMPRESS_MODE
    Invoke ConsoleSwitchRegister, CTEXT("--D"), SWITCH_DECOMPRESS_MODE
    ret
SnappyRegisterSwitches ENDP


;-----------------------------------------------------------------------------------------
; Register commands for use on command line
;-----------------------------------------------------------------------------------------
SnappyRegisterCommands PROC
    Invoke ConsoleCommandRegister, CTEXT("c"), COMMAND_COMPRESS
    Invoke ConsoleCommandRegister, CTEXT("d"), COMMAND_DECOMPRESS
    ret
SnappyRegisterCommands ENDP


;-----------------------------------------------------------------------------------------
; Prints out console information
;-----------------------------------------------------------------------------------------
SnappyConInfo PROC dwMsgType:DWORD
    mov eax, dwMsgType
    .IF eax == CON_OUT_INFO
        Invoke ConsoleStdOut, Addr szSnappyConInfo
    .ELSEIF eax == CON_OUT_ABOUT
        Invoke ConsoleStdOut, Addr szSnappyConAbout
    .ELSEIF eax == CON_OUT_USAGE
        Invoke ConsoleStdOut, Addr szSnappyConHelpUsage
    .ELSEIF eax == CON_OUT_HELP
        Invoke ConsoleStdOut, Addr szSnappyConHelp
    .ELSEIF eax == CON_OUT_MODE
        mov eax, SNAPPY_MODE
        .IF eax == SNAPPY_MODE_SNAP
            Invoke ConsoleStdOut, Addr szSnappyConModeCompress
        .ELSEIF eax == SNAPPY_MODE_UNSNAP
            Invoke ConsoleStdOut, Addr szSnappyConModeDecompress
        .ENDIF    
    .ELSEIF eax == CON_OUT_SUCCESS_COMPRESS
        Invoke ConsoleStdOut, Addr szSnappyConCompressSuccess
    .ELSEIF eax == CON_OUT_SUCCESS_DECOMPRESS
        Invoke ConsoleStdOut, Addr szSnappyConDecompressSuccess
    .ENDIF  
    ret
SnappyConInfo ENDP


;-----------------------------------------------------------------------------------------
; Prints out error information to console
;-----------------------------------------------------------------------------------------
SnappyConErr PROC dwErrorType:DWORD
    mov eax, dwErrorType
    .IF eax == CMDLINE_UNKNOWN_SWITCH || eax == CMDLINE_UNKNOWN_COMMAND || eax == CMDLINE_COMMAND_WITHOUT_FILEIN || eax == CMDLINE_UNKNOWN_SWITCH_FILEIN || eax == CMDLINE_FILESPEC_NOT_SUPPORTED || eax == CMDLINE_FOLDER_NOT_SUPPORTED
        Invoke ConsoleStdOut, Addr szError
        Invoke ConsoleStdOut, Addr szSingleQuote
        Invoke ConsoleStdOut, Addr CmdLineParameter
        Invoke ConsoleStdOut, Addr szSingleQuote
        mov eax, dwErrorType
        .IF eax == CMDLINE_UNKNOWN_SWITCH
            Invoke ConsoleStdOut, Addr szErrorUnknownSwitch
        .ELSEIF eax == CMDLINE_UNKNOWN_COMMAND
            Invoke ConsoleStdOut, Addr szErrorUnknownCommand
        .ELSEIF eax == CMDLINE_COMMAND_WITHOUT_FILEIN
            Invoke ConsoleStdOut, Addr szErrorCommandWithoutFile
        .ELSEIF eax == CMDLINE_UNKNOWN_SWITCH_FILEIN
            Invoke ConsoleStdOut, Addr szErrorUnknownSwitchFileIn
        .ELSEIF eax == CMDLINE_FILESPEC_NOT_SUPPORTED
            Invoke ConsoleStdOut, Addr szErrorFileSpecNotSupported
        .ELSEIF eax == CMDLINE_FOLDER_NOT_SUPPORTED
            Invoke ConsoleStdOut, Addr szErrorFolderNotSupported
        .ENDIF
        Invoke ConsoleStdOut, Addr szCRLF
        Invoke ConsoleStdOut, Addr szCRLF
        Invoke SnappyConInfo, CON_OUT_USAGE
    
    .ELSEIF eax == CMDLINE_NO_SNAPPY_MODE
        Invoke ConsoleStdOut, Addr szError
        Invoke ConsoleStdOut, Addr szErrorNoSnappyMode
        Invoke ConsoleStdOut, Addr szCRLF
        Invoke ConsoleStdOut, Addr szCRLF
        Invoke SnappyConInfo, CON_OUT_USAGE

    .ELSEIF eax == CMDLINE_FILEIN_NOT_EXIST
        Invoke ConsoleStdOut, Addr szError
        Invoke ConsoleStdOut, Addr szSingleQuote
        Invoke ConsoleStdOut, Addr szSnappyInFilename
        Invoke ConsoleStdOut, Addr szSingleQuote
        Invoke ConsoleStdOut, Addr szErrorFilenameNotExist
        Invoke ConsoleStdOut, Addr szCRLF
        Invoke ConsoleStdOut, Addr szCRLF
        
    .ELSEIF eax == CMDLINE_ERROR
        Invoke ConsoleStdOut, Addr szError
        Invoke ConsoleStdOut, Addr szErrorOther
        Invoke ConsoleStdOut, Addr szCRLF
        Invoke ConsoleStdOut, Addr szCRLF
    
    .ELSEIF eax == ERROR_FILEIN_IS_EMPTY
        Invoke ConsoleStdOut, Addr szError
        Invoke ConsoleStdOut, Addr szSingleQuote
        Invoke ConsoleStdOut, Addr szSnappyInFilename
        Invoke ConsoleStdOut, Addr szSingleQuote
        Invoke ConsoleStdOut, Addr szErrorFileZeroBytes
        Invoke ConsoleStdOut, Addr szCRLF
        Invoke ConsoleStdOut, Addr szCRLF
    
    .ELSEIF eax == ERROR_OPENING_FILEIN
        Invoke ConsoleStdOut, Addr szError
        Invoke ConsoleStdOut, Addr szSingleQuote
        Invoke ConsoleStdOut, Addr szSnappyInFilename
        Invoke ConsoleStdOut, Addr szSingleQuote
        Invoke ConsoleStdOut, Addr szErrorOpeningInFile
        Invoke ConsoleStdOut, Addr szCRLF
        Invoke ConsoleStdOut, Addr szCRLF
            
    .ELSEIF eax == ERROR_CREATING_FILEOUT
        Invoke ConsoleStdOut, Addr szError
        Invoke ConsoleStdOut, Addr szSingleQuote
        Invoke ConsoleStdOut, Addr szSnappyOutFilename
        Invoke ConsoleStdOut, Addr szSingleQuote
        Invoke ConsoleStdOut, Addr szErrorCreatingOutFile
        Invoke ConsoleStdOut, Addr szCRLF
        Invoke ConsoleStdOut, Addr szCRLF
    
    .ELSEIF eax == ERROR_ALLOC_MEMORY
        Invoke ConsoleStdOut, Addr szError
        Invoke ConsoleStdOut, Addr szSingleQuote
        Invoke ConsoleStdOut, Addr szSnappyOutFilename
        Invoke ConsoleStdOut, Addr szSingleQuote        
        Invoke ConsoleStdOut, Addr szErrorAllocMemory
        Invoke ConsoleStdOut, Addr szCRLF
        Invoke ConsoleStdOut, Addr szCRLF
        
    .ELSEIF eax == ERROR_WRITING_COMPRESS_DATA
        Invoke ConsoleStdOut, Addr szError
        Invoke ConsoleStdOut, Addr szSingleQuote
        Invoke ConsoleStdOut, Addr szSnappyOutFilename
        Invoke ConsoleStdOut, Addr szSingleQuote
        Invoke ConsoleStdOut, Addr szErrorWritingCompressData
        Invoke ConsoleStdOut, Addr szCRLF
        Invoke ConsoleStdOut, Addr szCRLF
        
    .ELSEIF eax == ERROR_INVALID_INPUT_COMPRESS
        Invoke ConsoleStdOut, Addr szError
        Invoke ConsoleStdOut, Addr szSingleQuote
        Invoke ConsoleStdOut, Addr szSnappyInFilename
        Invoke ConsoleStdOut, Addr szSingleQuote
        Invoke ConsoleStdOut, Addr szErrorCompressInputInvalid
        Invoke ConsoleStdOut, Addr szCRLF
        Invoke ConsoleStdOut, Addr szCRLF
        
    .ELSEIF eax == ERROR_WRITING_DECOMPRESS_DATA
        Invoke ConsoleStdOut, Addr szError
        Invoke ConsoleStdOut, Addr szSingleQuote
        Invoke ConsoleStdOut, Addr szSnappyOutFilename
        Invoke ConsoleStdOut, Addr szSingleQuote
        Invoke ConsoleStdOut, Addr szErrorWritingDecompressData
        Invoke ConsoleStdOut, Addr szCRLF
        Invoke ConsoleStdOut, Addr szCRLF
              
    .ELSEIF eax == ERROR_INVALID_INPUT_DECOMPRESS
        Invoke ConsoleStdOut, Addr szError
        Invoke ConsoleStdOut, Addr szSingleQuote
        Invoke ConsoleStdOut, Addr szSnappyInFilename
        Invoke ConsoleStdOut, Addr szSingleQuote
        Invoke ConsoleStdOut, Addr szErrorDecompressInputInvalid
        Invoke ConsoleStdOut, Addr szCRLF
        Invoke ConsoleStdOut, Addr szCRLF
    
    
    .ENDIF
    ret
SnappyConErr ENDP


;-------------------------------------------------------------------------------------
; SnappyFileInOpen - Open file to process
;-------------------------------------------------------------------------------------
SnappyFileInOpen PROC lpszFilename:DWORD

    .IF lpszFilename == NULL
        mov eax, FALSE
        ret
    .ENDIF
    
    ; Tell user we are loading file
    mov hFileIn, NULL
    mov hMemMapIn, NULL
    mov hMemMapInPtr, NULL
    mov DWORD ptr qwFileSize+4, 0
    mov DWORD ptr qwFileSize, 0    
    mov dwFileSize, 0
    mov dwFileSizeHigh, 0

    Invoke CreateFile, lpszFilename, GENERIC_READ, FILE_SHARE_READ, NULL, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, NULL
    .IF eax == INVALID_HANDLE_VALUE
        ; Tell user that file did not load
        mov eax, FALSE
        ret
    .ENDIF
    mov hFileIn, eax

    Invoke CreateFileMapping, hFileIn, NULL, PAGE_READONLY, 0, 0, NULL ; Create memory mapped file
    .IF eax == NULL
        ; Tell user that file did not map
        Invoke CloseHandle, hFileIn
        mov eax, FALSE
        ret
    .ENDIF
    mov hMemMapIn, eax

    Invoke MapViewOfFileEx, hMemMapIn, FILE_MAP_READ, 0, 0, 0, NULL
    .IF eax == NULL
        ; Tell user that file did not mapview
        Invoke CloseHandle, hMemMapIn
        Invoke CloseHandle, hFileIn
        mov eax, FALSE
        ret
    .ENDIF
    mov hMemMapInPtr, eax  
    
    Invoke GetFileSizeEx, hFileIn, Addr qwFileSize
    mov	eax, DWORD ptr qwFileSize
    mov dwFileSize, eax
	mov	eax, DWORD ptr qwFileSize+4
	mov dwFileSizeHigh, eax
	
    mov eax, TRUE
    
    ret

SnappyFileInOpen ENDP


;-------------------------------------------------------------------------------------
; SnappyFileInClose - Closes currently opened file
;-------------------------------------------------------------------------------------
SnappyFileInClose PROC

    .IF hMemMapInPtr != NULL
        Invoke UnmapViewOfFile, hMemMapInPtr
        mov hMemMapInPtr, NULL
    .ENDIF
    .IF hMemMapIn != NULL
        Invoke CloseHandle, hMemMapIn
        mov hMemMapIn, NULL
    .ENDIF
    .IF hFileIn != NULL
        Invoke CloseHandle, hFileIn
        mov hFileIn, NULL
    .ENDIF
    
    mov DWORD ptr qwFileSize+4, 0
    mov DWORD ptr qwFileSize, 0
    mov dwFileSize, 0
    mov dwFileSizeHigh, 0

    ret
SnappyFileInClose ENDP


;-------------------------------------------------------------------------------------
; SnappyFileOutOpen - Create out file
;-------------------------------------------------------------------------------------
SnappyFileOutOpen PROC lpszFilename:DWORD

    .IF lpszFilename == NULL
        mov eax, FALSE
        ret
    .ENDIF
    
    ; Tell user we are loading file
    mov hFileOut, NULL
    mov hMemMapOut, NULL
    mov hMemMapOutPtr, NULL

    Invoke CreateFile, lpszFilename, GENERIC_READ + GENERIC_WRITE, FILE_SHARE_READ + FILE_SHARE_WRITE + FILE_SHARE_DELETE, NULL, CREATE_ALWAYS, FILE_FLAG_WRITE_THROUGH, NULL
    .IF eax == INVALID_HANDLE_VALUE
        ; Tell user that file did not load
        mov eax, FALSE
        ret
    .ENDIF
    mov hFileOut, eax

    mov eax, TRUE
    
    ret

SnappyFileOutOpen ENDP


;-------------------------------------------------------------------------------------
; SnappyFileOutClose - Closes output file
;-------------------------------------------------------------------------------------
SnappyFileOutClose PROC
    .IF hFileOut != NULL
        Invoke CloseHandle, hFileOut
        mov hFileOut, NULL
    .ENDIF
    ret
SnappyFileOutClose ENDP


;-------------------------------------------------------------------------------------
; Compress/Decompress single input filename to specified output filename 
;-------------------------------------------------------------------------------------
SnappySingleFileProcess PROC USES EBX lpszInFilename:DWORD, lpszOutFilename:DWORD
    LOCAL dwCompressedSize:DWORD
    LOCAL dwUncompressedSize:DWORD
    LOCAL ptrData:DWORD
    LOCAL dwBytesWritten:DWORD
    LOCAL bLargeFile:DWORD

    ; Display infilename
    Invoke ConsoleStdOut, Addr szInFile
    Invoke ConsoleStdOut, lpszInFilename
    Invoke ConsoleStdOut, Addr szCRLF
    
    Invoke SnappyFileInOpen, lpszInFilename
    .IF eax == FALSE
        ;Invoke SnappyConErr, ERROR_OPENING_FILEIN
        mov eax, ERROR_OPENING_FILEIN ;FALSE
        ret
    .ENDIF

    .IF dwFileSize == 0
        ;Invoke SnappyConErr, ERROR_FILEIN_IS_EMPTY
        mov eax, ERROR_FILEIN_IS_EMPTY ;FALSE
        ret
    .ENDIF
    
    .IF sdword ptr dwFileSize > 3FFFFFFh ; 67,108,863 bytes
        mov bLargeFile, TRUE
    .ELSE
        mov bLargeFile, FALSE
    .ENDIF

    ; Display outfilename
    Invoke ConsoleStdOut, Addr szOutFile
    .IF bLargeFile == TRUE
        Invoke ConsoleAnimateIconStart, ICO_SPINNER1, ICO_SPINNER4, 150, 0
        ;Invoke ConsoleSpinnerStart, 0, 0, -3, 0
    .ENDIF
    Invoke ConsoleStdOut, lpszOutFilename
    Invoke ConsoleStdOut, Addr szCRLF
    
    Invoke SnappyFileOutOpen, lpszOutFilename
    .IF eax == FALSE
        ;PrintText 'SnappyFileOutOpen failed'
        ;Invoke SnappyConErr, ERROR_CREATING_FILEOUT
        .IF bLargeFile == TRUE
            Invoke ConsoleAnimateIconStop
            Invoke ConsoleSetIcon, ICO_MAIN
            ;Invoke ConsoleSpinnerStop
        .ENDIF
        mov eax, ERROR_CREATING_FILEOUT ;FALSE
        ret
    .ENDIF
    ;PrintDec dwFileSize
    
    mov eax, SNAPPY_MODE
    .IF eax == SNAPPY_MODE_SNAP
        ;PrintText 'SNAPPY_MODE_SNAP'
        Invoke snappy_max_compressed_length, dwFileSize
        mov dwCompressedSize, eax
        ;PrintDec dwCompressedSize
        Invoke GlobalAlloc, GMEM_FIXED or GMEM_ZEROINIT, dwCompressedSize
        .IF eax == NULL
            .IF bLargeFile == TRUE
                Invoke ConsoleAnimateIconStop
                Invoke ConsoleSetIcon, ICO_MAIN
                ;Invoke ConsoleSpinnerStop
            .ENDIF
            ;Invoke SnappyConErr, ERROR_ALLOC_MEMORY
            mov eax, ERROR_ALLOC_MEMORY ;FALSE
            ret
        .ENDIF
        mov ptrData, eax

        Invoke snappy_compress, hMemMapInPtr, dwFileSize, ptrData, Addr dwCompressedSize
        .IF eax == SNAPPY_OK
            ;PrintText 'SNAPPY_OK'
            Invoke WriteFile, hFileOut, ptrData, dwCompressedSize, Addr dwBytesWritten, NULL
            .IF eax == 0
                ;Invoke SnappyConErr, ERROR_WRITING_COMPRESS_DATA
                .IF bLargeFile == TRUE
                    Invoke ConsoleAnimateIconStop
                    Invoke ConsoleSetIcon, ICO_MAIN
                    ;Invoke ConsoleSpinnerStop
                .ENDIF                
                Invoke GlobalFree, ptrData
                Invoke SnappyFileOutClose
                Invoke SnappyFileInClose
                mov eax, ERROR_WRITING_COMPRESS_DATA ;FALSE
                ret
            .ENDIF
            .IF bLargeFile == TRUE
                Invoke ConsoleAnimateIconStop
                Invoke ConsoleSetIcon, ICO_MAIN
                ;Invoke ConsoleSpinnerStop
            .ENDIF            
            Invoke SetEndOfFile, hFileOut
            Invoke GlobalFree, ptrData
            Invoke SnappyFileOutClose
            Invoke SnappyFileInClose
            mov eax, SUCCESS_COMPRESS
            ret
            ;Invoke SnappyConInfo, CON_OUT_SUCCESS_COMPRESS

        .ELSEIF eax == SNAPPY_INVALID_INPUT
            ;PrintText 'SNAPPY_INVALID_INPUT'
            ;Invoke SnappyConErr, ERROR_INVALID_INPUT_COMPRESS
            .IF bLargeFile == TRUE
                Invoke ConsoleAnimateIconStop
                Invoke ConsoleSetIcon, ICO_MAIN
                ;Invoke ConsoleSpinnerStop
            .ENDIF            
            Invoke GlobalFree, ptrData
            Invoke SnappyFileOutClose
            Invoke SnappyFileInClose
            mov eax, ERROR_INVALID_INPUT_COMPRESS ;FALSE
            ret
            
        .ELSEIF eax == SNAPPY_BUFFER_TOO_SMALL    
            ;PrintText 'SNAPPY_BUFFER_TOO_SMALL'
            ;Invoke SnappyConErr, ERROR_INVALID_INPUT_COMPRESS
            .IF bLargeFile == TRUE
                Invoke ConsoleAnimateIconStop
                Invoke ConsoleSetIcon, ICO_MAIN
                ;Invoke ConsoleSpinnerStop
            .ENDIF            
            Invoke GlobalFree, ptrData
            Invoke SnappyFileOutClose
            Invoke SnappyFileInClose
            mov eax, ERROR_INVALID_INPUT_COMPRESS ;FALSE
            ret
            
        .ENDIF

    .ELSE
        
        ;PrintText 'SNAPPY_MODE_UNSNAP'
        Invoke snappy_uncompressed_length, hMemMapInPtr, dwFileSize, Addr dwUncompressedSize
        ;PrintDec dwUncompressedSize
        Invoke snappy_validate_compressed_buffer, hMemMapInPtr, dwFileSize
        .IF eax == SNAPPY_OK
            ;PrintText 'SNAPPY_MODE_UNSNAP validated'
            Invoke GlobalAlloc, GMEM_FIXED or GMEM_ZEROINIT, dwUncompressedSize
            .IF eax == NULL
                ;Invoke SnappyConErr, ERROR_ALLOC_MEMORY
                .IF bLargeFile == TRUE
                    Invoke ConsoleAnimateIconStop
                    Invoke ConsoleSetIcon, ICO_MAIN
                    ;Invoke ConsoleSpinnerStop
                .ENDIF                
                Invoke SnappyFileOutClose
                Invoke SnappyFileInClose
                mov eax, ERROR_ALLOC_MEMORY ;FALSE
                ret
            .ENDIF
            mov ptrData, eax

            Invoke snappy_uncompress, hMemMapInPtr, dwFileSize, ptrData, Addr dwUncompressedSize
            .IF eax == SNAPPY_OK
                ;PrintText 'SNAPPY_OK'
                Invoke WriteFile, hFileOut, ptrData, dwUncompressedSize, Addr dwBytesWritten, NULL
                .IF eax == 0
                    ;Invoke SnappyConErr, ERROR_WRITING_DECOMPRESS_DATA
                    .IF bLargeFile == TRUE
                        Invoke ConsoleAnimateIconStop
                        Invoke ConsoleSetIcon, ICO_MAIN
                        ;Invoke ConsoleSpinnerStop
                    .ENDIF                    
                    Invoke GlobalFree, ptrData
                    Invoke SnappyFileOutClose
                    Invoke SnappyFileInClose
                    mov eax, ERROR_WRITING_DECOMPRESS_DATA ;FALSE
                    ret
                .ENDIF
                .IF bLargeFile == TRUE
                    Invoke ConsoleAnimateIconStop
                    Invoke ConsoleSetIcon, ICO_MAIN
                    ;Invoke ConsoleSpinnerStop
                .ENDIF                
                Invoke SetEndOfFile, hFileOut
                Invoke GlobalFree, ptrData
                Invoke SnappyFileOutClose
                Invoke SnappyFileInClose
                mov eax, SUCCESS_DECOMPRESS
                ret                
                ;Invoke SnappyConInfo, CON_OUT_SUCCESS_DECOMPRESS
                
            .ELSEIF eax == SNAPPY_INVALID_INPUT
                ;PrintText 'SNAPPY_INVALID_INPUT'
                ;Invoke SnappyConErr, ERROR_INVALID_INPUT_DECOMPRESS
                .IF bLargeFile == TRUE
                    Invoke ConsoleAnimateIconStop
                    Invoke ConsoleSetIcon, ICO_MAIN
                    ;Invoke ConsoleSpinnerStop
                .ENDIF                
                Invoke GlobalFree, ptrData
                Invoke SnappyFileOutClose
                Invoke SnappyFileInClose
                mov eax, ERROR_INVALID_INPUT_DECOMPRESS ;FALSE
                ret
                
            .ELSEIF eax == SNAPPY_BUFFER_TOO_SMALL    
                ;PrintText 'SNAPPY_BUFFER_TOO_SMALL'
                ;Invoke SnappyConErr, ERROR_INVALID_INPUT_DECOMPRESS
                .IF bLargeFile == TRUE
                    Invoke ConsoleAnimateIconStop
                    Invoke ConsoleSetIcon, ICO_MAIN
                    ;Invoke ConsoleSpinnerStop
                .ENDIF                
                Invoke GlobalFree, ptrData
                Invoke SnappyFileOutClose
                Invoke SnappyFileInClose
                mov eax, ERROR_INVALID_INPUT_DECOMPRESS ;FALSE
                ret
                
            .ENDIF

        .ELSE
            ;PrintText 'SNAPPY_MODE_UNSNAP not validated'
            ;Invoke SnappyConErr, ERROR_INVALID_INPUT_DECOMPRESS
            .IF bLargeFile == TRUE
                Invoke ConsoleAnimateIconStop
                Invoke ConsoleSetIcon, ICO_MAIN
                ;Invoke ConsoleSpinnerStop
            .ENDIF            
            Invoke SnappyFileOutClose
            Invoke SnappyFileInClose         
            mov eax, ERROR_INVALID_INPUT_DECOMPRESS ;FALSE
            ret
        .ENDIF
    .ENDIF
    
    ;Invoke GlobalFree, ptrData
    ;Invoke SnappyFileOutClose
    ;Invoke SnappyFileInClose
    ;mov eax, TRUE
    ret
SnappySingleFileProcess ENDP


;-------------------------------------------------------------------------------------
; Compress/Decompress multiple files based on filespec
;-------------------------------------------------------------------------------------
SnappyBatchProcess PROC USES EBX FileSpec:DWORD
    LOCAL WFD:WIN32_FIND_DATA
    LOCAL hFind:DWORD
    LOCAL bContinueFind:DWORD
    LOCAL nFileCount:DWORD
    LOCAL nFileFailCount:DWORD
    
    ; get first file
    Invoke FindFirstFile, FileSpec, Addr WFD
    .IF eax == INVALID_HANDLE_VALUE
        Invoke GetLastError
        ;PrintDec eax
        mov eax, FALSE
        ret
    .ENDIF    
    mov hFind, eax
	mov bContinueFind, TRUE
	
	lea ebx, WFD.cFileName
	.IF byte ptr [ebx] == '.' && byte ptr [ebx+1] == 0 ;entry == "."
		;"." entry found means NOT ROOT directory and next entry MUST BE ".."
		;so...eat the ".." entry up :)
		Invoke FindNextFile, hFind, Addr WFD
		;make the scan point to the first valid file/directory (if any) :)
		Invoke FindNextFile, hFind, Addr WFD
		mov bContinueFind, eax
	.ENDIF    
  
    mov nFileCount, 0
    mov nFileFailCount, 0

    ; start loop
    .WHILE bContinueFind == TRUE
		mov eax, WFD.dwFileAttributes
		and eax, FILE_ATTRIBUTE_DIRECTORY
		.IF eax != FILE_ATTRIBUTE_DIRECTORY

            Invoke szCopy, Addr WFD.cFileName, Addr szSnappyInFilename
;            Invoke ConsoleStdOut, Addr szInFile
;            Invoke ConsoleStdOut, Addr szSnappyInFilename
;            Invoke ConsoleStdOut, Addr szCRLF            
 
            Invoke SnappyOutFilename, Addr szSnappyInFilename, Addr szSnappyOutFilename
            .IF eax == TRUE
;                Invoke ConsoleStdOut, Addr szOutFile
;                Invoke ConsoleSpinnerStart, 0, 0, -3, 0
;                Invoke ConsoleStdOut, Addr szSnappyOutFilename
;                Invoke ConsoleStdOut, Addr szCRLF
                Invoke SnappySingleFileProcess, Addr szSnappyInFilename, Addr szSnappyOutFilename
;                push eax
;                Invoke ConsoleSpinnerStop
;                pop eax
                .IF eax == SUCCESS_COMPRESS
                    ;Invoke SnappyConInfo, CON_OUT_SUCCESS_COMPRESS
                    inc nFileCount
                .ELSEIF eax == SUCCESS_DECOMPRESS
                    ;Invoke SnappyConInfo, CON_OUT_SUCCESS_DECOMPRESS
                    inc nFileCount
                .ELSE
                    Invoke SnappyConErr, eax
                    inc nFileFailCount
                .ENDIF                
            .ELSE
                Invoke ConsoleStdOut, Addr szInFile
                Invoke ConsoleStdOut, Addr szSnappyInFilename
                Invoke ConsoleStdOut, Addr szCRLF                
                Invoke ConsoleStdOut, Addr szInfo
                Invoke ConsoleStdOut, Addr szSnappyInFilename
                .IF SNAPPY_MODE == SNAPPY_MODE_SNAP
                    Invoke ConsoleStdOut, Addr szInFilenameAlreadyCompressed
                .ELSE
                    Invoke ConsoleStdOut, Addr szInFilenameAlreadyDecompressed
                .ENDIF
                Invoke ConsoleStdOut, Addr szCRLF
            .ENDIF            
		.ENDIF
		
		Invoke FindNextFile, hFind, Addr WFD
	    mov bContinueFind, eax
	.ENDW
    Invoke FindClose, hFind
    
    mov eax, nFileCount
    mov ebx, nFileFailCount
    .IF eax == 0 && ebx == 0 ; no files processed
        Invoke ConsoleStdOut, Addr szSnappyConBatchNoFiles
        
    .ELSEIF eax == 0 && ebx != 0 ; errors occured
        .IF SNAPPY_MODE == SNAPPY_MODE_SNAP
            Invoke ConsoleStdOut, Addr szSnappyConCompBatchFail
        .ELSE
            Invoke ConsoleStdOut, Addr szSnappyConDecompBatchFail
        .ENDIF
        
    .ELSEIF eax != 0 && ebx != 0 ; partial success and errors
        .IF SNAPPY_MODE == SNAPPY_MODE_SNAP
            Invoke ConsoleStdOut, Addr szSnappyConCompBatchPartial
        .ELSE
            Invoke ConsoleStdOut, Addr szSnappyConDecompBatchPartial
        .ENDIF
        
    .ELSEIF eax != 0 && ebx == 0 ; success
        .IF SNAPPY_MODE == SNAPPY_MODE_SNAP
            Invoke ConsoleStdOut, Addr szSnappyConCompBatchSuccess
        .ELSE
            Invoke ConsoleStdOut, Addr szSnappyConDecompBatchSuccess
        .ENDIF
    .ENDIF
    
    ret

SnappyBatchProcess ENDP


;-------------------------------------------------------------------------------------
; Determine mode of operation by self modulename
;-------------------------------------------------------------------------------------
SnappyModeSelf PROC
    Invoke ConsoleCmdLineParam, Addr CmdLineParameters, 0, TotalCmdLineParameters, Addr szSnappySelfFilepath
    .IF sdword ptr eax > 0
        Invoke JustFnameExt, Addr szSnappySelfFilepath, Addr szSnappySelfFilename
        Invoke szUpper, Addr szSnappySelfFilename

        Invoke szCmp, Addr szSnappySelfFilename, Addr szSNSnap
        .IF sdword ptr eax > 0 ; match
            mov eax, SNAPPY_MODE_SNAP
            ret
        .ENDIF

        Invoke szCmp, Addr szSnappySelfFilename, Addr szSNZip
        .IF sdword ptr eax > 0 ; match
            mov eax, SNAPPY_MODE_SNAP
            ret
        .ENDIF

        Invoke szCmp, Addr szSnappySelfFilename, Addr szSNUnsnap
        .IF sdword ptr eax > 0 ; match
            mov eax, SNAPPY_MODE_SNAP
            ret
        .ENDIF

        Invoke szCmp, Addr szSnappySelfFilename, Addr szSNUnzip
        .IF sdword ptr eax > 0 ; match
            mov eax, SNAPPY_MODE_SNAP
            ret
        .ENDIF

        mov eax, SNAPPY_MODE_NOP
    .ELSE
        mov eax, SNAPPY_MODE_NOP
    .ENDIF
    ret
SnappyModeSelf ENDP


;-------------------------------------------------------------------------------------
; determine mode by filename .sz = unsnap file, no .sz then snap file
;-------------------------------------------------------------------------------------
SnappyModeFilename PROC USES EBX lpszFilename:DWORD
    
    .IF lpszFilename == NULL
        mov eax, SNAPPY_MODE_ERROR
        ret
    .ENDIF
    
    Invoke szLen, lpszFilename
    .IF eax == SNAPPY_MODE_ERROR
        ret
    .ENDIF
    
    mov ebx, lpszFilename
    add ebx, eax ; len to ebx
    sub ebx, 3
    mov eax, [ebx]
    .IF eax == 'zs.'
        mov eax, SNAPPY_MODE_UNSNAP
    .ELSE
        mov eax, SNAPPY_MODE_NOP
    .ENDIF
    ret
SnappyModeFilename ENDP


;-------------------------------------------------------------------------------------
; create output filename from input filename
;-------------------------------------------------------------------------------------
SnappyOutFilename PROC USES EBX lpszInFilename:DWORD, lpszOutFilename:DWORD
    LOCAL LenFilename:DWORD
    
    .IF lpszInFilename == NULL || lpszOutFilename == NULL
        mov eax, FALSE
        ret
    .ENDIF
    
    Invoke szLen, lpszInFilename
    .IF eax == 0
        mov eax, FALSE
        ret
    .ENDIF
    mov LenFilename, eax
    
    mov eax, SNAPPY_MODE
    .IF eax == SNAPPY_MODE_SNAP
        mov ebx, lpszInFilename
        add ebx, LenFilename
        sub ebx, 3
        mov eax, [ebx]
        .IF eax == 'zs.'
            Invoke szCopy, lpszInFilename, lpszOutFilename
            Invoke szCatStr, lpszOutFilename, Addr szExtSZ        
            mov eax, FALSE ; already compressed
            ret
        .ELSE
            Invoke szCopy, lpszInFilename, lpszOutFilename
            Invoke szCatStr, lpszOutFilename, Addr szExtSZ
            mov eax, TRUE
            ret
        .ENDIF
        
    .ELSEIF eax == SNAPPY_MODE_UNSNAP
        mov ebx, lpszInFilename
        add ebx, LenFilename
        sub ebx, 3
        mov eax, [ebx]
        .IF eax == 'zs.'    
            Invoke szCopy, lpszInFilename, lpszOutFilename
            mov ebx, lpszOutFilename
            add ebx, LenFilename
            sub ebx, 3
            mov byte ptr [ebx], 0
            mov eax, TRUE
            ret
        .ELSE
            Invoke szCopy, lpszInFilename, lpszOutFilename
            Invoke szCatStr, lpszOutFilename, Addr szExtSZU       
            mov eax, FALSE ; already decompressed
            ret
        .ENDIF
        
    .ELSE
        mov eax, FALSE
    .ENDIF
    
    ret
SnappyOutFilename ENDP


;-------------------------------------------------------------------------------------
; Check filename extension to see if its a .sz file already
;-------------------------------------------------------------------------------------
SnappyChkFilename PROC USES EBX lpszInFilename:DWORD
    LOCAL LenFilename:DWORD
    
    .IF lpszInFilename == NULL
        mov eax, FALSE
        ret
    .ENDIF
    
    Invoke szLen, lpszInFilename
    .IF eax == 0
        mov eax, FALSE
        ret
    .ENDIF
    mov LenFilename, eax

    mov eax, SNAPPY_MODE
    .IF eax == SNAPPY_MODE_SNAP
        mov ebx, lpszInFilename
        add ebx, LenFilename
        sub ebx, 3
        mov eax, [ebx]
        .IF eax == 'zs.'
            mov eax, FALSE ; already compressed
            ret
        .ELSE
            mov eax, TRUE
            ret
        .ENDIF
        
    .ELSEIF eax == SNAPPY_MODE_UNSNAP
        mov ebx, lpszInFilename
        add ebx, LenFilename
        sub ebx, 3
        mov eax, [ebx]
        .IF eax == 'zs.'    
            mov eax, TRUE
            ret
        .ELSE
            mov eax, FALSE ; already decompressed
            ret
        .ENDIF
        
    .ELSE
        mov eax, FALSE
    .ENDIF
    ret
SnappyChkFilename ENDP


;-------------------------------------------------------------------------------------
; Determine mode based on .exe name: SNSNAP|SNZIP or SNUNSNAP|SNUNZIP
;-------------------------------------------------------------------------------------
SnappyMode PROC lpszFilename:DWORD
    Invoke SnappyModeFilename, lpszFilename
    .IF eax == SNAPPY_MODE_NOP
        Invoke SnappyModeSelf
        .IF eax == SNAPPY_MODE_NOP
            mov eax, SNAPPY_MODE_SNAP
        .ENDIF
    .ENDIF
    ret
SnappyMode ENDP


;**************************************************************************
; Strip path name to just filename with extention
;**************************************************************************
JustFnameExt PROC USES ESI EDI szFilePathName:DWORD, szFileName:DWORD
	LOCAL LenFilePathName:DWORD
	LOCAL nPosition:DWORD
	
	Invoke szLen, szFilePathName
	mov LenFilePathName, eax
	mov nPosition, eax
	
	.IF LenFilePathName == 0
	    mov edi, szFileName
		mov byte ptr [edi], 0
		mov eax, FALSE
		ret
	.ENDIF
	
	mov esi, szFilePathName
	add esi, eax
	
	mov eax, nPosition
	.WHILE eax != 0
		movzx eax, byte ptr [esi]
		.IF al == '\' || al == ':' || al == '/'
			inc esi
			.BREAK
		.ENDIF
		dec esi
		dec nPosition
		mov eax, nPosition
	.ENDW
	mov edi, szFileName
	mov eax, nPosition
	.WHILE eax != LenFilePathName
		movzx eax, byte ptr [esi]
		mov byte ptr [edi], al
		inc edi
		inc esi
		inc nPosition
		mov eax, nPosition
	.ENDW
	mov byte ptr [edi], 0h ; null out filename
	mov eax, TRUE
	ret

JustFnameExt ENDP


END Main





