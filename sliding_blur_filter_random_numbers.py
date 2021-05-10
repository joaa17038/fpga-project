#!/usr/bin/env python3
"""
An external Python script for generating random I/O, displaying I/O, and converting images to
grayscale input for the blur filter module. It supports a 3x3 mean filter and a 3x3 gaussian
filter. It has a command-line interface for specifying image dimensions or an image file for the
script to perform its functionality.
"""
import sys
import argparse
from random import choices
from PIL import Image
import numpy as np

np.set_printoptions(threshold=sys.maxsize)
parser = argparse.ArgumentParser(
    description="Creates simulation and assertion files for a blur filter module.")
parser.add_argument("SIMULATIONFILE", type=str,
                    help="The destination of the simulation file.")
parser.add_argument("ASSERTIONFILE1", type=str,
                    help="The destination of the first assertion file.")
parser.add_argument("ASSERTIONFILE2", type=str,
                    help="The destination of the second assertion file.")
parser.add_argument("WIDTH", type=int,
                    help="The width of the image.")
parser.add_argument("HEIGHT", type=int,
                    help="The height the image.")
parser.add_argument("PACKETSIZE", type=int,
                    help="The height of the image.")
parser.add_argument("PIXELSIZE", type=int,
                    help="The pixel size of the image in bits.")
parser.add_argument("-img", "--IMAGE", type=str,
                    help="The destination of the image file.")
parser.add_argument("-n", "--N", type=int, default=1,
                    help="The number of times to filter the image.")
parser.add_argument("-f", "--filter", type=str, default="mean",
                    help="Select a filter (gauss/mean).", choices=["gauss", "mean"])
args = parser.parse_args()


def gauss_filter(src):
    """Returns a gaussian filtered image"""
    dst = np.zeros_like(src)

    # TopLeft Corner
    dst[0,0] = (src[0,0]*4 + src[0,1]*2
             + src[1,0]*2 + src[1,1]) // 16

    # TopRight Corner
    dst[0,dst.shape[1]-1] = (src[0,dst.shape[1]-2]*2 + src[0,dst.shape[1]-1]*4
                          + src[1,dst.shape[1]-2] + src[1,dst.shape[1]-1]*2) // 16

    # BottomLeft Corner
    dst[dst.shape[0]-1,0] = (src[dst.shape[0]-2,0]*2 + src[dst.shape[0]-2,1]
                          + src[dst.shape[0]-1,0]*4 + src[dst.shape[0]-1,1]*2) // 16

    # BottomRight Corner
    dst[dst.shape[0]-1,dst.shape[1]-1] = (src[dst.shape[0]-2,dst.shape[1]-2]
                                       + src[dst.shape[0]-2,dst.shape[1]-1]*2
                                       + src[dst.shape[0]-1,dst.shape[1]-2]*2
                                       + src[dst.shape[0]-1,dst.shape[1]-1]*4) // 16

    # TopSide & BottomSide
    for j in range(1, dst.shape[1]-1):
        dst[0,j] = (src[0,j-1]*2 + src[0,j]*4 + src[0,j+1]*2
                  + src[1,j-1]*1 + src[1,j]*2 + src[1,j+1]*1) // 16

        dst[dst.shape[0]-1, j] = (src[dst.shape[0]-2,j-1] + src[dst.shape[0]-2,j]*2
                               + src[dst.shape[0]-2,j+1] + src[dst.shape[0]-1,j-1]*2
                               + src[dst.shape[0]-1,j]*4 + src[dst.shape[0]-1,j+1]*2) // 16

    # LeftSide & RightSide
    for i in range(1, dst.shape[0]-1):
        dst[i,0] = (src[i-1,0]*2 + src[i-1,1]
                 + src[i,0]*4 + src[i,1]*2
                 + src[i+1,0]*2 + src[i+1,1]) // 16

        dst[i,dst.shape[1]-1] = (src[i-1,dst.shape[1]-2] + src[i-1,dst.shape[1]-1]*2
                              + src[i,dst.shape[1]-2]*2 + src[i,dst.shape[1]-1]*4
                              + src[i+1,dst.shape[1]-2] + src[i+1,dst.shape[1]-1]*2) // 16

    # Middle
    for i in range(1, dst.shape[0]-1): # row-wise
        for j in range(1, dst.shape[1]-1): # column-wise
            dst[i,j] = (src[i-1,j-1] + src[i-1,j]*2 + src[i-1,j+1]
                     + src[i,j-1]*2 + src[i,j]*4 + src[i,j+1]*2
                     + src[i+1,j-1] + src[i+1,j]*2 + src[i+1,j+1]) // 16
    return dst


def mean_filter(src):
    """Returns a mean filtered image"""
    dst = np.zeros_like(src)

    # TopLeft Corner
    dst[0,0] = (src[0,0] + src[0,1]
             + src[1,0] + src[1,1]) // 4

    # TopRight Corner
    dst[0,dst.shape[1]-1] = (src[0,dst.shape[1]-2] + src[0,dst.shape[1]-1]
                          + src[1,dst.shape[1]-2] + src[1,dst.shape[1]-1]) // 4

    # BottomLeft Corner
    dst[dst.shape[0]-1,0] = (src[dst.shape[0]-2,0] + src[dst.shape[0]-2,1]
                          + src[dst.shape[0]-1,0] + src[dst.shape[0]-1,1]) // 4

    # BottomRight Corner
    dst[dst.shape[0]-1,dst.shape[1]-1] = (src[dst.shape[0]-2,dst.shape[1]-2]
                                       + src[dst.shape[0]-2,dst.shape[1]-1]
                                       + src[dst.shape[0]-1,dst.shape[1]-2]
                                       + src[dst.shape[0]-1,dst.shape[1]-1]) // 4

    # TopSide & BottomSide
    for j in range(1, dst.shape[1]-1):
        dst[0,j] = (src[0,j-1] + src[0,j] + src[0,j+1]
                 + src[1,j-1] + src[1,j] + src[1,j+1]) // 6

        dst[dst.shape[0]-1, j] = (src[dst.shape[0]-2,j-1] + src[dst.shape[0]-2,j]
                               + src[dst.shape[0]-2,j+1] + src[dst.shape[0]-1,j-1]
                               + src[dst.shape[0]-1,j] + src[dst.shape[0]-1,j+1]) // 6

    # LeftSide & RightSide
    for i in range(1, dst.shape[0]-1):
        dst[i,0] = (src[i-1,0] + src[i-1,1]
                 + src[i,0] + src[i,1]
                 + src[i+1,0] + src[i+1,1]) // 6

        dst[i,dst.shape[1]-1] = (src[i-1,dst.shape[1]-2] + src[i-1,dst.shape[1]-1]
                              + src[i,dst.shape[1]-2] + src[i,dst.shape[1]-1]
                              + src[i+1,dst.shape[1]-2] + src[i+1,dst.shape[1]-1]) // 6

    # Middle
    for i in range(1, dst.shape[0]-1): # row-wise
        for j in range(1, dst.shape[1]-1): # column-wise
            dst[i,j] = (src[i-1,j-1] + src[i-1,j] + src[i-1,j+1]
                     + src[i,j-1] + src[i,j] + src[i,j+1]
                     + src[i+1,j-1] + src[i+1,j] + src[i+1,j+1]) // 9
    return dst


def convert_to_matrix(width, array):
    """Returns a 2d numpy array"""
    return np.asarray([array[i:i+width] for i in range(0, len(array), width)])


def save_file(filename, matrix):
    """Saves a 2d numpy array to a file"""
    with open(filename, 'w') as file:
        for row in matrix:
            row = np.split(row, args.WIDTH/args.PACKETSIZE)
            for packet in row:
                file.writelines('%0.02X' % pixel for pixel in packet)
                file.write('\n')


def display_image(matrix):
    """Displays the image in 8-bit grayscale"""
    return Image.fromarray(matrix.copy().astype("uint8"), 'L')


if __name__ == "__main__":
    if args.filter == "gauss":
        blur_filter = gauss_filter
    else:
        blur_filter = mean_filter

    if args.IMAGE:
        source = np.array(Image.open(args.IMAGE).convert("L")).astype("uint16")
    else:
        source = convert_to_matrix(args.WIDTH,np.asarray(choices(range(0, 2**args.PIXELSIZE),
                                                                 k=args.WIDTH*args.HEIGHT)))

    simulation = source.copy()
    assertions_one = blur_filter(source.copy())
    assertions_two = blur_filter(assertions_one.copy())

    save_file(args.SIMULATIONFILE, simulation)
    save_file(args.ASSERTIONFILE1, assertions_one)
    save_file(args.ASSERTIONFILE2, assertions_two)

    if args.IMAGE:
        display_image(simulation).save("./images/src.png")
        filtered = source.copy()
        for number in range(1,args.N+1):
            filtered = blur_filter(filtered)
            display_image(filtered.copy()).save(f"./images/filter{number}.png")
