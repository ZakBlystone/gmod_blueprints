import glob
import os

for filename in glob.iglob('**/*', recursive=True):
	if filename != filename.lower():
		os.rename(filename, filename.lower())