with open('tmp.txt', 'r') as f:
    for line in f:
       if 'Subject: UID =' in line:
       		 data = line.split(",",1)
       		 topicId = data[0].split("Subject: UID =",1)
       		 print("Topic ID is " + topicId[1])
           
