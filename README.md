# Contributions
* A 3x3 mean blur filter VHDL module that receives pixels in packets of configurable size from an AXI4-Stream4 with edge detection for determining the start and end of an image’s row as pixel packets and for the image’s edges to avoid black/white framing of the image.
* A self-checking VHDL testbench verifies the blur filter module and its AXI4-Stream4 with the simulation/assertions input files generated by an external Python script.
* An external Python script for generating random I/O, displaying I/O, and converting images to grayscale input for the blur filter module. It supports a 3x3 mean filter and a 3x3 gaussian filter. It has a command-line interface for specifying image dimensions or an image file for the script to perform its functionality.
# Python Script Usage
For generating a 256x256 image at packetsize 64 and grayscale pixelsize 8.
```bash
./sliding_blur_filter_random_numbers.py simulation.in assertionOne.in assertionTwo.in 256 256 64 8
```
For generating/converting/visualising an 256x256 source image at packetsize 64 and grayscale pixelsize 8.
```bash
./sliding_blur_filter_random_numbers.py simulation.in assertionOne.in assertionTwo.in 256 256 64 8 -img source.png
```
For help with command-line arguments.
```bash
./sliding_blur_filter_random_numbers.py -h
```
