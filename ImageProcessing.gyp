import cv2
import numpy
import os
import glob
from tqdm import tqdm

def originalImageToBlackAndWhite(originalImage):
    grayImage = cv2.cvtColor(originalImage, cv2.COLOR_BGR2GRAY)
    (thresh, blackAndWhiteImage) = cv2.threshold(grayImage, 128, 255, cv2.THRESH_BINARY | cv2.THRESH_OTSU)
    blackToWhite = cv2.subtract(255, blackAndWhiteImage)
    return blackToWhite

# 이미지 읽어서 dictionary 에 set

imageFolder = 'rps-cv-images'
listdir = os.listdir(imageFolder)

cvImageDic = dict()

for dirName in listdir:
    subPath = imageFolder + '/' + dirName
    if os.path.isdir(subPath):
        images = [cv2.imread(file) for file in glob.glob( subPath + "/*.png")]
        cvImageDic[dirName] = images

print(len(cvImageDic))
print(cvImageDic.keys())


# 읽은 이미지로 black And white 이미지로 output 하는 코드

for (key, value) in cvImageDic.items():
    tot_sum = 0

    # 폴더 없으면 폴더 생성

    folderPath = 'processedImages/' + key

    if not os.path.exists(folderPath):
        os.makedirs(folderPath)
    
    for (index, image) in enumerate(tqdm(value)):
        processedImage = originalImageToBlackAndWhite(image)
        processedPath = folderPath + '/' + str(index) + '.png'
        cv2.imwrite(os.path.join(processedPath), processedImage)
        tot_sum += index
    print(tot_sum)
