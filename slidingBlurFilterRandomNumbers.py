#!/usr/bin/env python3
from scipy import ndimage
from collections import Counter
from random import choices
import numpy as np
import sys

SIMULATIONFILE, ASSERTIONFILE1, ASSERTIONFILE2 = sys.argv[1], sys.argv[2], sys.argv[3]
DIMENSION, PIXELSIZE, DELAY = int(sys.argv[4]), int(sys.argv[5]), int(sys.argv[6])


def averageFilter(dim, src):
    dst = [0]*(dim**2)

    # Top-Left Corner, 2x2
    dst[0] = (src[0] + src[1] + src[dim] + src[dim+1]) // 4

    # Top-Right Corner, 2x2
    dst[dim-1] = (src[dim-2] + src[dim-1] + src[dim*2-2] + src[dim*2-1]) // 4

    # Bottom-Left Corner, 2x2
    dst[dim*(dim-1)] = (src[dim*(dim-1)] + src[dim*(dim-1)+1] + src[dim*(dim-2)] + src[dim*(dim-2)+1]) // 4

    # Bottom-Right Corner, 2x2
    dst[dim*dim-1] = (src[dim*dim-1] + src[dim*dim-2] + src[dim*(dim-1)-1] + src[dim*(dim-1)-2]) // 4

    # Top Side, 2x3
    for i in range(1, (dim-1)):
        dst[i] = (src[i-1] + src[i] + src[i+1] + src[i+dim-1] + src[i+dim] + src[i+dim+1]) // 6

    # Bottom Side, 2x3
    for i in range((dim*dim-dim+1), (dim*dim-1)):
        dst[i] = (src[i-1] + src[i] + src[i+1] + src[i-dim-1] + src[i-dim] + src[i-dim+1]) // 6

    # Right Side, 2x3
    for i in range((dim+dim-1), (dim*dim-1), dim):
        dst[i] = (src[i-1] + src[i] + src[i-dim] + src[i-dim-1] + src[i+dim-1] + src[i+dim]) // 6

    # Left Side, 2x3
    for i in range(dim, (dim*dim-dim), dim):
        dst[i] = (src[i-dim] + src[i-dim+1] + src[i] + src[i+1] + src[i+dim] + src[i+dim+1]) // 6

    # Middle, 3x3
    squareMiddleIdx = dim
    for i in range(1, (dim-1)):
        for j in range(1, (dim-1)):
            squareMiddleIdx += 1
            dst[squareMiddleIdx] = (src[squareMiddleIdx-dim+1]
                                 + src[squareMiddleIdx-dim]
                                 + src[squareMiddleIdx-dim-1]
                                 + src[squareMiddleIdx-1]
                                 + src[squareMiddleIdx]
                                 + src[squareMiddleIdx+1]
                                 + src[squareMiddleIdx+dim-1]
                                 + src[squareMiddleIdx+dim]
                                 + src[squareMiddleIdx+dim+1]) // 9
        squareMiddleIdx += 2
    return dst


def convertToMatrix(dimension, array):
    return [array[i:i+dimension] for i in range(0, len(array), dimension)]


def saveToFile(filename, matrix, delay=0):
    with open(filename, 'w') as f:
        if delay: f.writelines("00"*64+"\n" for i in range(delay))
        for row in matrix:
            row = np.split(row, DIMENSION/64)
            for packet in row:
                f.writelines('%0.02X' % pixel for pixel in packet)
                f.write('\n')


source = choices(range(0, 2**PIXELSIZE), k=DIMENSION**2)
simulation = np.asarray(convertToMatrix(DIMENSION, source.copy()))
assertions = averageFilter(DIMENSION, source.copy())
assertionsOne = np.asarray(convertToMatrix(DIMENSION, assertions))
assertionsTwo = np.asarray(convertToMatrix(DIMENSION, averageFilter(DIMENSION, assertions.copy())))

saveToFile(SIMULATIONFILE, simulation)
saveToFile(ASSERTIONFILE1, assertionsOne, DELAY)
saveToFile(ASSERTIONFILE2, assertionsTwo, DELAY-1)

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
