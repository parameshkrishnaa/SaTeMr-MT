import sys
import re

dictfile = sys.argv[1]
inpfile = sys.argv[2]

#open file using open file mode
fp1 = open(dictfile) # Open file on read mode -- input file
lines1 = fp1.read().split("\n") # Create a list containing all lines
fp1.close() # Close file

#open file using open file mode
fp2 = open(inpfile) # Open file on read mode -- input file
lines2 = fp2.read().split("\n") # Create a list containing all lines
fp2.close() # Close file

gender_hash = {}
for l1 in lines1:
	if(l1 == ""):
		continue
	arr = l1.split(",")
	if(arr[0] in gender_hash):
		tmp = gender_hash[arr[0]]
		gender_hash[arr[0]] = tmp + ":" + arr[1]
	else:
		gender_hash[arr[0]] = arr[1]

for l2 in lines2:
	if(l2 == ""):
		continue
	l2 = l2.strip()
	arr = l2.split(",")
	if(arr[0] in gender_hash):
		print("%s,%s,%s,%s" %(arr[0], gender_hash[arr[0]], arr[2], gender_hash[arr[0]]))
	else:
		print(l2)

