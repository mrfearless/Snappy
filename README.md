# Snappy
Windows command line compression/decompression tool based on Google's snappy library - written in assembler

Snappy is designed and programmed by fearless (C) Copyright 2017 and uses static builds of Google's Snappy compression/decompression library.



## Usage

```
Snappy [ /? | -? ]
Snappy [ switch | command ] [ <infile> [ <outfile> ] ]
Snappy [ switch | command ] <filespec>
Snappy [ switch | command ] <folder>
```



#### Switches:     

- `/?` | `-?` - Displays this help.

- `/c` | `-c` - Switch to set mode of operation to compression.
- `/d` | `-d` - Switch to set mode of operation to decompression.



#### Commands:

- `c` - Command to set mode of operation to compression.

- `d` - Command to set mode of operation to decompression.



#### Parameters:

- `<infile>`- The name of an existing filename to compress/decompress.

- `<outfile>` - The the name of a filename to compress/decompress `<infile>` to. If no `<outfile>` is provided, filename is determined by mode, see notes.
- `<filespec>` - A set of files to compress/decompress, which supports the use of the wildcards `*` and `?` for specifying which files to include.
- `<folder>` - A folder to compress/decompress all files contained within and assumes the use of `<folder\*.*>` for processing file operations.



#### Notes:

- `<filespec>` and `<folder>` do not support an `<outfile>` parameter.

- If no compress/decompress mode is specified via switches or commands, then the mode of operation is determined by filename of the `<infile>`, a .sz extension indicates mode is decompress, otherwise it is compress.

- If no `<outfile>` is provided, then `<outfile>` filename is determined by mode and based on the `<infile>` filename. Compression mode adds a `.sz` extension and decompression mode removes any `.sz` extension.

- `Snappy.exe` can be renamed to `snsnap.exe` or `snzip.exe` to set the default mode to compression.
  `Snappy.exe` can be renamed to `snunsnap.exe` or `snunzip.exe` to set the default mode to decompress.

- The default modes can be overridden by providing switches or commands.
  Switches and commands are not case sensitive.




## Build

Compiling the Snappy tool requires the following static library dependencies: 

- Console x86 library - https://github.com/mrfearless/libraries
- Snappy x86 library - https://github.com/mrfearless/libraries
