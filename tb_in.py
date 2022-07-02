import cv2
import sys
import numpy as np
import matplotlib.image as mpimg
import matplotlib.pyplot as plt
import conv

image = cv2.imread("che.jpg", cv2.IMREAD_COLOR)
(b, g, r) = cv2.split(image)

print(b)
print(g)
print(r)

# plt.imshow(b)
# plt.show()

fo = open("pic.txt", "w")
for i in range(b.shape[0]):
    for j in range(b.shape[1]):
        fo.write(str(b[i,j]+g[i,j]*256+r[i,j]*65536)+'\n');
fo.close()
