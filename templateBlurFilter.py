from scipy import ndimage
from collections import Counter
import matplotlib.pyplot as plt
from random import choices
import numpy as np
import sys

np.set_printoptions(threshold=sys.maxsize)


def averageFilter(dim, src, cval):
    dst = [0]*(dim**2)

    # Top-Left Corner, 2x2
    dst[0] = (src[0] + src[1] + src[dim] + src[dim+1] + cval*5) // 9

    # Top-Right Corner, 2x2
    dst[dim-1] = (src[dim-2] + src[dim-1] + src[dim*2-2] + src[dim*2-1] + cval*5) // 9

    # Bottom-Left Corner, 2x2
    dst[dim*(dim-1)] = (src[dim*(dim-1)] + src[dim*(dim-1)+1] + src[dim*(dim-2)] + src[dim*(dim-2)+1] + cval*5) // 9

    # Bottom-Right Corner, 2x2
    dst[dim*dim-1] = (src[dim*dim-1] + src[dim*dim-2] + src[dim*(dim-1)-1] + src[dim*(dim-1)-2] + cval*5) // 9

    # Top Side, 2x3
    for i in range(1, (dim-1)):
        dst[i] = (src[i-1] + src[i] + src[i+1] + src[i+dim-1] + src[i+dim] + src[i+dim+1] + cval*3) // 9

    # Bottom Side, 2x3
    for i in range((dim*dim-dim+1), (dim*dim-1)):
        dst[i] = (src[i-1] + src[i] + src[i+1] + src[i-dim-1] + src[i-dim] + src[i-dim+1] + cval*3) // 9

    # Right Side, 2x3
    for i in range((dim+dim-1), (dim*dim-1), dim):
        dst[i] = (src[i-1] + src[i] + src[i-dim] + src[i-dim-1] + src[i+dim-1] + src[i+dim] + cval*3) // 9

    # Left Side, 2x3
    for i in range(dim, (dim*dim-dim), dim):
        dst[i] = (src[i-dim] + src[i-dim+1] + src[i] + src[i+1] + src[i+dim] + src[i+dim+1] + cval*3) // 9

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


dimension = 8
source = choices(range(0, 255), k=dimension**2)

inputArray = source.copy()
inputMatrix = np.asarray(convertToMatrix(dimension, source.copy()))

result = np.asarray(convertToMatrix(dimension, averageFilter(dimension, inputArray, cval=1)))
test = ndimage.filters.convolve(inputMatrix, np.full((3, 3), 1/9), mode='constant', cval=1)

output = np.array(result == test)
count = Counter(output.flatten())
print(result - test, '\n')
print(np.asarray(convertToMatrix(dimension, source)), '\n')
print(result, '\n')
print(test, '\n')
print(count[False] / count[True])

## 8x8 matrix example
## and their indices as array
#  0  1  2  3  4  5  6  7
#  8  9  10 11 12 13 14 15
#  16 17 18 19 20 21 22 23
#  24 25 26 27 28 29 30 31
#  32 33 34 35 36 37 38 39
#  40 41 42 43 44 45 46 47
#  48 49 50 51 52 53 54 55
#  56 57 58 59 60 61 62 63
