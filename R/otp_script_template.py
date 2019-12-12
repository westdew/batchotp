import time
from datetime import datetime
import base64

# Get the router
router = otp.getRouter('{{{router_id}}}')

# Load data
origs_data_base64 = "{{{origs_data_base64}}}"
f = open("origs.csv", "w")
f.write(base64.b64decode(origs_data_base64))
f.close()
origs = otp.loadCSVPopulation('origs.csv', 'lat', 'lon')

dests_data_base64 = "{{{dests_data_base64}}}"
f = open("dests.csv", "w")
f.write(base64.b64decode(dests_data_base64))
f.close()
dests = otp.loadCSVPopulation('dests.csv', 'lat', 'lon')

# Create a CSV output object
csvOutput = otp.createCSVOutput()
csvOutput.setHeader([ 'oid', 'olat', 'olon', 'did', 'dlat', 'dlon', 'time', 'boardings', 'walkdistance' ])

req = otp.createRequest()
req.setModes('{{{modes}}}')

# Define helper functions
def addCsvOutputRow(orig, dest):
  csvOutput.addRow([ orig.getStringData('id'), orig.getLocation().getLat(), orig.getLocation().getLon(), \
                     dest.getStringData('id'), dest.getLocation().getLat(), dest.getLocation().getLon(), \
                     r.getTime(), r.getBoardings(), r.getWalkDistance() ])

if {{{arrive_by}}}:
  # For each destination
  for dest in dests:
    # Setup the SPT request
  	print "Processing: ", dest.getStringData('id')
  	req.setDestination(dest)
  	t = time.strptime(dest.getStringData('time'), '%H:%M')
  	d = datetime.strptime("{{{date}}}", "%Y-%m-%d")
  	req.setDateTime(d.year, d.month, d.day, t.tm_hour, t.tm_min, 00)
  	req.setArriveBy(True)
  	req.setMaxTimeSec({{{max_time}}}) # this line must come after setDateTime
  
  	# Send the SPT request
  	spt = router.plan(req)
  	if spt is None: continue # couldn't find destination
  	
  	# Evaluate the SPT response for all origins
  	res = spt.eval(origs)
  	if len(res) == 0: continue # couldn't find origin
  	else:
  		for r in res:
  			orig = r.getIndividual()
  			addCsvOutputRow(orig, dest) # Write the output
else:
  # For each origin
  for orig in origs:
    # Setup the SPT request
  	print "Processing: ", orig.getStringData('id')
  	req.setOrigin(orig)
  	t = time.strptime(orig.getStringData('time'), '%H:%M')
  	req.setDateTime(2018, 4, 11, t.tm_hour, t.tm_min, 00)
  	req.setArriveBy(False)
  	req.setMaxTimeSec({{{max_time}}}) # this line must come after setDateTime
  
  	# Send the SPT request
  	spt = router.plan(req)
  	if spt is None: continue # couldn't find destination
  	
  	# Evaluate the SPT response for all origins
  	res = spt.eval(dests)
  	if len(res) == 0: continue # couldn't find origin
  	else:
  		for r in res:
  			dest = r.getIndividual()
  			addCsvOutputRow(orig, dest) # Write the output

# Return the csv text
otp.setRetval(csvOutput.asText())
