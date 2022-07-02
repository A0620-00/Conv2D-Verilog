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

filt = np.array([[ -1,-1, -1],[ -1, 8, -1],[  -1, -1, -1]])
# res = cv2.filter2D(image,-1,filt)
res = conv.convolve(image,filt,'fill')
(b1, g1, r1) = cv2.split(res)
g1 = np.zeros([g.shape[0], g.shape[1]], dtype="uint8")
r1 = np.zeros([r.shape[0], r.shape[1]], dtype="uint8")
conv1=cv2.merge([b1,g1,r1])
plt.subplot(2,1,1)
plt.imshow(conv1)

b2 = np.zeros([b.shape[0], b.shape[1]], dtype="uint8")
g2 = np.zeros([g.shape[0], g.shape[1]], dtype="uint8")
r2 = np.zeros([r.shape[0], r.shape[1]], dtype="uint8")
fi = open("conv.txt", "r")
j = -1
k = 0
for i in fi.readlines():
    i = i.strip('\n')
    if j < b.shape[1]-1:
        j = j+1
    else:
        j = 0
        k = k+1
    #print(j,k)
    b2[k][j] = i
fi.close()
conv2=cv2.merge([b2,g2,r2])

# cv2.imshow("BLUE",conv2)
# cv2.waitKey(0)
plt.subplot(2,1,2)
plt.imshow(conv2)
plt.show()