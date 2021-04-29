#!/usr/bin/env python3
from scipy import ndimage
from collections import Counter
from random import choices
from PIL import Image
import numpy as np
import sys

np.set_printoptions(threshold=sys.maxsize)
SIMULATIONFILE, ASSERTIONFILE1, ASSERTIONFILE2 = sys.argv[1], sys.argv[2], sys.argv[3]
WIDTH, PACKETSIZE, PIXELSIZE, DELAY = int(sys.argv[4]), int(sys.argv[5]), int(sys.argv[6]), int(sys.argv[7])


def averageFilter(src):
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
    dst[dst.shape[0]-1,dst.shape[1]-1] = (src[dst.shape[0]-2,dst.shape[1]-2] + src[dst.shape[0]-2,dst.shape[1]-1]
                                        + src[dst.shape[0]-1,dst.shape[1]-2] + src[dst.shape[0]-1,dst.shape[1]-1]) // 4

    # TopSide & BottomSide
    for j in range(1, dst.shape[1]-1):
        dst[0,j] = (src[0,j-1] + src[0,j] + src[0,j+1]
                  + src[1,j-1] + src[1,j] + src[1,j+1]) // 6

        dst[dst.shape[0]-1, j] = (src[dst.shape[0]-2,j-1] + src[dst.shape[0]-2,j] + src[dst.shape[0]-2,j+1]
                                + src[dst.shape[0]-1,j-1] + src[dst.shape[0]-1,j] + src[dst.shape[0]-1,j+1]) // 6

    # LeftSide & RightSide
    for i in range(1, dst.shape[0]-1):
        dst[i,0] = (src[i-1,0] + src[i-1,1]
                  + src[i,0]   + src[i,1]
                  + src[i+1,0] + src[i+1,1]) // 6

        dst[i,dst.shape[1]-1] = (src[i-1,dst.shape[1]-2] + src[i-1,dst.shape[1]-1]
                               + src[i,dst.shape[1]-2]   + src[i,dst.shape[1]-1]
                               + src[i+1,dst.shape[1]-2] + src[i+1,dst.shape[1]-1]) // 6

    # Middle
    for i in range(1, dst.shape[0]-1): # row-wise
        for j in range(1, dst.shape[1]-1): # column-wise
            dst[i,j] = (src[i-1,j-1] + src[i-1,j] + src[i-1,j+1]
                      + src[i,j-1]   + src[i,j]   + src[i,j+1]
                      + src[i+1,j-1] + src[i+1,j] + src[i+1,j+1]) // 9
    return dst


def convertToMatrix(dimension, array):
    return np.asarray([array[i:i+dimension] for i in range(0, len(array), dimension)])


def saveToFile(filename, matrix, delay=0):
    with open(filename, 'w') as f:
        if delay: f.writelines("00"*PACKETSIZE+"\n" for i in range(delay))
        for row in matrix:
            row = np.split(row, WIDTH/PACKETSIZE)
            for packet in row:
                f.writelines('%0.02X' % pixel for pixel in packet)
                f.write('\n')

def displayImage(matrix):
    return Image.fromarray(matrix.copy().astype("uint8"), 'L')


#source = choices(range(0, 2**PIXELSIZE), k=DIMENSION**2)
source = np.array(Image.open("../images/black.jpg").convert("L")).astype("uint16")
simulation = source.copy()
assertionsOne = averageFilter(source.copy())
assertionsTwo = averageFilter(assertionsOne.copy())

saveToFile(SIMULATIONFILE, simulation)
saveToFile(ASSERTIONFILE1, assertionsOne, DELAY)
saveToFile(ASSERTIONFILE2, assertionsTwo, DELAY-1)

displayImage(simulation).save("src.png")
filtered = source.copy()
for i in range(2):
    filtered = averageFilter(filtered)
    displayImage(filtered.copy()).save(f"filter{i}.png")


#inputMatrix = np.asarray(convertToMatrix(dimension, source.copy()))
#result = np.asarray(convertToMatrix(dimension, averageFilter(dimension, inputArray, cval=1)))
#test = ndimage.filters.convolve(inputMatrix, np.full((3, 3), 1/9), mode='constant', cval=1)
#output = np.array(result == test)
#count = Counter(output.flatten())
#print(result - test, '\n')
#print(np.asarray(convertToMatrix(dimension, source)), '\n')
#print(result, '\n')
#print(test, '\n')
#print(count[False] / count[True])
